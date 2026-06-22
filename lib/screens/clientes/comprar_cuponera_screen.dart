import 'dart:convert';
import 'dart:io';

import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'payphone_webview_screen.dart';

import '../../services/configuracion_service.dart';
import '../../services/solicitud_cuponera_service.dart';
import '../../services/versiones_service.dart';
import '../../services/pagos_service.dart';
import '../../services/cupones_service.dart';
import '../../services/promotor_service.dart';
import 'detalle_version_screen.dart';
import 'mapa_version_screen.dart';

/// Subtítulo de una membresía: "descripción · Ciudades" en una sola línea,
/// como en el mockup ("+ de N locales · Ciudad").
String _subtitulo(Map<String, dynamic> c) {
  final partes = <String>[];
  final desc = c['descripcion']?.toString().trim() ?? '';
  if (desc.isNotEmpty) partes.add(desc);
  if (c['ciudadesDisponibles'] is List) {
    final ciudades = (c['ciudadesDisponibles'] as List)
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (ciudades.isNotEmpty) partes.add(ciudades.join(', '));
  }
  return partes.join(' · ');
}

class ComprarCuponeraScreen extends StatefulWidget {
  final String clienteId;
  final String nombreCliente;
  final String emailCliente;
  final String? telefonoCliente;

  const ComprarCuponeraScreen({
    super.key,
    required this.clienteId,
    required this.nombreCliente,
    required this.emailCliente,
    this.telefonoCliente,
  });

  @override
  State<ComprarCuponeraScreen> createState() => _ComprarCuponeraScreenState();
}

class _ComprarCuponeraScreenState extends State<ComprarCuponeraScreen> {
  bool _loading = true;
  bool _submitting = false;

  List<Map<String, dynamic>> _cuponeras = [];
  List<Map<String, dynamic>> _cuentas = [];
  String _instrucciones = '';

  bool _payphoneActivo = false;
  bool _paypalActivo = false;

  int? _selectedCuponera;
  String? _metodoPago; // 'transferencia' | 'payphone' | 'paypal'
  File? _comprobante;
  final _picker = ImagePicker();

  // ── Regalo ────────────────────────────────────────────────────────────
  bool _esRegalo = false;
  final _destinatarioCtrl = TextEditingController();
  final _mensajeCtrl = TextEditingController();
  final _cuponesService = CuponesService();
  Map<String, dynamic>? _destinatario; // {id, nombre, email} validado
  bool _buscandoDest = false;
  String? _destError;

  // ── Código de promotor ──────────────────────────────────────────────
  final _codigoPromotorCtrl = TextEditingController();
  final _promotorSvc = PromotorService();
  DescuentoPromotor? _descuentoAplicado;
  bool _validandoCodigo = false;
  String? _codigoError;

  @override
  void initState() {
    super.initState();
    _fetchConfigs();
  }

  @override
  void dispose() {
    _destinatarioCtrl.dispose();
    _mensajeCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchConfigs() async {
    // Cargar configuración, versiones activas y métodos de pago en paralelo
    final results = await Future.wait([
      ConfiguracionService.obtenerTodas(),
      VersionesService.listarActivasPaginado(),
      PagosService.metodosPago(),
    ]);

    if (!mounted) return;

    final configs = results[0] as Map<String, dynamic>;
    final versiones = results[1] as List<Map<String, dynamic>>;
    final metodos = results[2] as Map<String, bool>;

    List<Map<String, dynamic>> cuentas = [];
    String instrucciones = '';

    try {
      final cuentasRaw = configs['cuentas_bancarias'] ?? '[]';
      cuentas = List<Map<String, dynamic>>.from(json.decode(cuentasRaw));
    } catch (_) {}

    instrucciones = configs['transferencia_instrucciones'] ?? '';

    setState(() {
      _cuponeras = versiones;
      _cuentas = cuentas;
      _instrucciones = instrucciones;
      _payphoneActivo = metodos['payphone'] ?? false;
      _paypalActivo = metodos['paypal'] ?? false;
      _loading = false;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 40,
      maxWidth: 1000,
      maxHeight: 1000,
    );
    if (picked != null && mounted) {
      setState(() => _comprobante = File(picked.path));
    }
  }

  void _showImageSourceSheet() {
    final ec = context.ec;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ec.surfaceTop,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: ec.stroke),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: ec.strokeStrong,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Seleccionar imagen',
                style: EnjoyTheme.heading(size: 16, color: ec.text),
              ),
              const SizedBox(height: 16),
              ListRowTile(
                leading: const IconBox(Icons.photo_library_outlined),
                title: 'Galeria',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 10),
              ListRowTile(
                leading: const IconBox(Icons.camera_alt_outlined),
                title: 'Camara',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// El regalo está listo para procesar: o no es regalo, o ya hay un
  /// destinatario validado.
  bool get _regaloOk => !_esRegalo || _destinatario != null;

  Future<void> _buscarDestinatario() async {
    final q = _destinatarioCtrl.text.trim();
    if (q.length < 3) {
      setState(() {
        _destError = 'Ingresa el correo o la cédula del destinatario';
        _destinatario = null;
      });
      return;
    }
    setState(() {
      _buscandoDest = true;
      _destError = null;
    });
    final res = await _cuponesService.buscarDestinatario(q);
    if (!mounted) return;
    setState(() {
      _buscandoDest = false;
      if (res['exists'] == true) {
        _destinatario = res;
        _destError = null;
      } else {
        _destinatario = null;
        _destError =
            'No encontramos esa cuenta. El destinatario debe tener una cuenta en Enjoy.';
      }
    });
  }

  /// Campos de regalo para enviar al backend (vacío si no es regalo).
  Map<String, dynamic> _giftPayload() {
    if (!_esRegalo || _destinatario == null) return {};
    return {
      'esRegalo': true,
      'destinatarioId': _destinatario!['id'],
      'destinatarioNombre': _destinatario!['nombre'],
      'mensajeRegalo': _mensajeCtrl.text.trim(),
    };
  }

  /// Valida el código de promotor contra el back. Si es válido, persiste
  /// [_descuentoAplicado] con el desglose para mostrar el descuento en UI.
  Future<void> _aplicarCodigoPromotor() async {
    final codigo = _codigoPromotorCtrl.text.trim().toUpperCase();
    if (codigo.isEmpty) {
      setState(() {
        _descuentoAplicado = null;
        _codigoError = null;
      });
      return;
    }
    if (_selectedCuponera == null) {
      setState(() => _codigoError = 'Elegí primero una membresía.');
      return;
    }
    final precioStr =
        (_cuponeras[_selectedCuponera!]['precio'] ?? '0').toString();
    final precio = double.tryParse(precioStr) ?? 0;
    if (precio <= 0) {
      setState(() => _codigoError = 'Precio inválido.');
      return;
    }
    setState(() {
      _validandoCodigo = true;
      _codigoError = null;
    });
    try {
      final d = await _promotorSvc.calcularDescuento(
        codigo: codigo,
        monto: precio,
      );
      if (!mounted) return;
      setState(() {
        _descuentoAplicado = d;
        _validandoCodigo = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _descuentoAplicado = null;
        _validandoCodigo = false;
        _codigoError = e.toString().contains('404')
            ? 'Código inválido. Verificá que esté bien escrito.'
            : 'No pudimos validar el código.';
      });
    }
  }

  void _quitarCodigoPromotor() {
    setState(() {
      _descuentoAplicado = null;
      _codigoError = null;
      _codigoPromotorCtrl.clear();
    });
  }

  Future<void> _submit() async {
    if (_selectedCuponera == null) {
      _showSnack('Selecciona una membresía');
      return;
    }
    if (!_regaloOk) {
      _showSnack('Valida el destinatario del regalo');
      return;
    }
    if (_comprobante == null) {
      _showSnack('Sube tu comprobante de pago');
      return;
    }

    setState(() => _submitting = true);

    String? base64Image;
    try {
      final bytes = await _comprobante!.readAsBytes();
      base64Image = base64Encode(bytes);
    } catch (_) {
      _showSnack('Error al procesar la imagen');
      setState(() => _submitting = false);
      return;
    }

    final cuponera = _cuponeras[_selectedCuponera!];
    final dto = {
      'cliente': widget.clienteId,
      'nombreCliente': widget.nombreCliente,
      'emailCliente': widget.emailCliente,
      'telefonoCliente': widget.telefonoCliente ?? '',
      'cuponeraNombre': cuponera['nombre'] ?? '',
      'cuponeraPrecio': cuponera['precio'] ?? '0.00',
      'comprobanteBase64': base64Image,
      ..._giftPayload(),
      // Si hay código promotor aplicado, lo enviamos para que el back
      // registre el snapshot y, al aprobarse, acredite la comisión.
      if (_descuentoAplicado != null)
        'codigoPromotor': _codigoPromotorCtrl.text.trim().toUpperCase(),
    };

    final ok = await SolicitudCuponeraService.enviar(dto);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _esRegalo
                ? 'Regalo enviado. Avisaremos a ${_destinatario?['nombre'] ?? 'tu destinatario'} cuando se apruebe.'
                : 'Solicitud enviada correctamente',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      _showSnack('Error al enviar la solicitud. Intenta de nuevo.');
    }
  }

  Future<void> _pagarConPayPhone() async {
    if (_selectedCuponera == null) {
      _showSnack('Selecciona una membresía');
      return;
    }
    if (!_regaloOk) {
      _showSnack('Valida el destinatario del regalo');
      return;
    }

    setState(() => _submitting = true);
    final cuponera = _cuponeras[_selectedCuponera!];
    final gift = _giftPayload();

    try {
      final result = await PagosService.iniciarPayPhone(
        clienteId: widget.clienteId,
        nombreCliente: widget.nombreCliente,
        emailCliente: widget.emailCliente,
        telefonoCliente: widget.telefonoCliente,
        cuponeraNombre: cuponera['nombre'] ?? '',
        cuponeraPrecio: cuponera['precio'] ?? '0.00',
        esRegalo: _esRegalo,
        destinatarioId: gift['destinatarioId'] as String?,
        destinatarioNombre: gift['destinatarioNombre'] as String?,
        mensajeRegalo: gift['mensajeRegalo'] as String?,
      );

      setState(() => _submitting = false);
      if (!mounted) return;

      final formularioUrl = result['formularioUrl'] as String?;
      final txn = result['clientTransactionId'] as String?;
      if (formularioUrl == null || txn == null) {
        _showError('No se pudo iniciar el pago. Intenta de nuevo.');
        return;
      }

      final outcome = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => PayPhoneWebViewScreen(
            formularioUrl: formularioUrl,
            clientTransactionId: txn,
          ),
        ),
      );

      if (!mounted) return;
      if (outcome == 'aprobado') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('¡Pago aprobado! Tu membresía ha sido activada.'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context, true);
      } else if (outcome == 'rechazado') {
        _showError('El pago no fue aprobado. Verifica tu tarjeta e intenta de nuevo.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(PagosService.mensajeError(e, fallback: 'No se pudo iniciar el pago con PayPhone. Intenta de nuevo.'));
    }
  }

  Future<void> _pagarConPayPal() async {
    if (_selectedCuponera == null) {
      _showSnack('Selecciona una membresía');
      return;
    }
    if (!_regaloOk) {
      _showSnack('Valida el destinatario del regalo');
      return;
    }

    setState(() => _submitting = true);
    final cuponera = _cuponeras[_selectedCuponera!];
    final gift = _giftPayload();

    try {
      final result = await PagosService.crearPayPal(
        clienteId: widget.clienteId,
        nombreCliente: widget.nombreCliente,
        emailCliente: widget.emailCliente,
        cuponeraNombre: cuponera['nombre'] ?? '',
        cuponeraPrecio: cuponera['precio'] ?? '0.00',
        returnUrl: 'https://ecuenjoy.com/pago/exito',
        cancelUrl: 'https://ecuenjoy.com/pago/cancelado',
        esRegalo: _esRegalo,
        destinatarioId: gift['destinatarioId'] as String?,
        destinatarioNombre: gift['destinatarioNombre'] as String?,
        mensajeRegalo: gift['mensajeRegalo'] as String?,
      );

      final approveUrl = result['approveUrl'];
      if (approveUrl != null) {
        final uri = Uri.parse(approveUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnack('Redirigiendo a PayPal para completar el pago...');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(PagosService.mensajeError(e, fallback: 'No se pudo iniciar el pago con PayPal. Intenta de nuevo.'));
    }
  }

  void _verLocales(Map<String, dynamic> version) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalleVersionScreen(
          versionId: version['_id'] ?? '',
          versionData: version,
        ),
      ),
    );
  }

  Future<void> _verMapa(Map<String, dynamic> version) async {
    final versionId = version['_id']?.toString() ?? '';
    final nombre = version['nombre']?.toString() ?? 'Mapa';
    if (versionId.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final locales = await VersionesService.listarLocales(versionId);
      if (!mounted) return;
      Navigator.pop(context); // cerrar loading
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MapaVersionScreen(
            versionNombre: nombre,
            locales: locales,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar el mapa.')),
      );
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 14))),
          ],
        ),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── Build helpers ──────────────────────────────────────────

  Widget _sectionHeader(IconData icon, String title) {
    final ec = context.ec;
    return Row(
      children: [
        IconBox(icon, size: 36, radius: 11, iconSize: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: EnjoyTheme.heading(size: 16, color: ec.text),
          ),
        ),
      ],
    );
  }

  // ─── Sections ───────────────────────────────────────────────

  Widget _buildCuponeraCard(Map<String, dynamic> c,
      {bool selected = false, VoidCallback? onTap}) {
    final ec = context.ec;
    final nombre = c['nombre']?.toString() ?? 'Membresía';
    final precio = '\$${c['precio'] ?? '0.00'}';
    final subtitulo = _subtitulo(c);

    return GlassCard(
      onTap: onTap,
      accent: selected,
      borderColor: selected ? ec.orange.withValues(alpha: 0.5) : null,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado: ícono + nombre/subtítulo + precio (no seleccionada)
              Row(
                children: [
                  IconBox(Icons.local_activity, accent: selected),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          // Espacio para el check absoluto cuando va seleccionada
                          padding: EdgeInsets.only(right: selected ? 28 : 0),
                          child: Text(
                            nombre,
                            style: EnjoyTheme.heading(
                              size: 15,
                              color: selected ? ec.text : ec.textSoft,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (subtitulo.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitulo,
                            style:
                                EnjoyTheme.body(size: 12, color: ec.textMute),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Precio compacto a la derecha solo cuando NO está seleccionada.
                  if (!selected) ...[
                    const SizedBox(width: 12),
                    Text(
                      precio,
                      style: EnjoyTheme.heading(
                        size: 18,
                        weight: FontWeight.w800,
                        color: ec.text,
                      ),
                    ),
                  ],
                ],
              ),

              // Seleccionada: divider + fila vigencia/precio grande + acciones
              if (selected) ...[
                const EnjoyDivider(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        'Membresía seleccionada',
                        style: EnjoyTheme.body(size: 12, color: ec.textMute),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      precio,
                      style: EnjoyTheme.heading(
                        size: 22,
                        weight: FontWeight.w800,
                        color: ec.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: EnjoyButton(
                        label: 'Ver locales',
                        icon: Icons.store_outlined,
                        variant: EnjoyButtonVariant.ghost,
                        dense: true,
                        onPressed: () => _verLocales(c),
                      ),
                    ),
                    const SizedBox(width: 8),
                    EnjoyButton(
                      label: 'Mapa',
                      icon: Icons.map_outlined,
                      variant: EnjoyButtonVariant.blueGlass,
                      dense: true,
                      expand: false,
                      onPressed: () => _verMapa(c),
                    ),
                  ],
                ),
              ],
            ],
          ),

          // Check naranja absoluto arriba a la derecha (mockup #6).
          if (selected)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  gradient: ec.accentGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, size: 14, color: ec.onAccent),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _abrirSelectorCuponeras() async {
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => _SelectorCuponerasPage(cuponeras: _cuponeras),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedCuponera = result;
        _metodoPago = null;
      });
    }
  }

  Widget _buildCuponerasSection() {
    final ec = context.ec;
    final total = _cuponeras.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.card_giftcard, 'Selecciona tu membresía'),
        const SizedBox(height: 12),

        if (total == 0)
          Text('No hay membresías disponibles.',
              style: EnjoyTheme.body(color: ec.textMute))

        // Más de 5: modo selector
        else if (total > 5) ...[
          if (_selectedCuponera != null) ...[
            _buildCuponeraCard(_cuponeras[_selectedCuponera!], selected: true),
            const SizedBox(height: 10),
            EnjoyButton(
              label: 'Cambiar membresía',
              icon: Icons.swap_horiz,
              variant: EnjoyButtonVariant.ghost,
              dense: true,
              onPressed: _abrirSelectorCuponeras,
            ),
          ] else
            EnjoyButton(
              label: 'Seleccionar membresía ($total disponibles)',
              icon: Icons.local_activity,
              variant: EnjoyButtonVariant.ghost,
              onPressed: _abrirSelectorCuponeras,
            ),
        ]

        // 5 o menos: listar directo
        else
          ..._cuponeras.asMap().entries.map((entry) {
            final i = entry.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildCuponeraCard(
                entry.value,
                selected: _selectedCuponera == i,
                onTap: () => setState(() {
                  _selectedCuponera = i;
                  _metodoPago = null;
                }),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCuentasSection() {
    final ec = context.ec;
    if (_cuentas.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.account_balance, 'Datos de transferencia'),
        const SizedBox(height: 12),
        ..._cuentas.map((cuenta) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cuenta['banco']?.toString() ?? '',
                    style: EnjoyTheme.heading(size: 15, color: ec.text),
                  ),
                  const SizedBox(height: 8),
                  _cuentaRow('Tipo', cuenta['tipo']?.toString() ?? ''),
                  _cuentaRow('Titular', cuenta['titular']?.toString() ?? ''),
                  _cuentaRow('CI', cuenta['ci']?.toString() ?? ''),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Numero de cuenta',
                              style: EnjoyTheme.body(
                                  size: 12, color: ec.textMute),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              cuenta['numero']?.toString() ?? '',
                              style: EnjoyTheme.heading(
                                  size: 15, color: ec.text),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          final numero = cuenta['numero']?.toString() ?? '';
                          Clipboard.setData(ClipboardData(text: numero));
                          _showSnack('Numero de cuenta copiado');
                        },
                        icon: Icon(Icons.copy, color: ec.orangeSoft, size: 20),
                        tooltip: 'Copiar numero',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _cuentaRow(String label, String value) {
    final ec = context.ec;
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label: ', style: EnjoyTheme.body(size: 13, color: ec.textMute)),
          Expanded(
            child: Text(
              value,
              style: EnjoyTheme.body(
                  size: 13, weight: FontWeight.w600, color: ec.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstruccionesSection() {
    final ec = context.ec;
    if (_instrucciones.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.info_outline, 'Instrucciones'),
        const SizedBox(height: 12),
        GlassCard(
          child: Text(
            _instrucciones,
            style: EnjoyTheme.body(size: 14, height: 1.5, color: ec.text),
          ),
        ),
      ],
    );
  }

  /// Sección "Código de descuento (opcional)". Permite al cliente aplicar
  /// el código de un promotor y ver el descuento antes de pagar.
  Widget _buildCodigoPromotorSection() {
    final ec = context.ec;
    final tieneDesc = _descuentoAplicado != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          Icons.local_offer_outlined,
          'Código de descuento (opcional)',
        ),
        const SizedBox(height: 8),
        if (tieneDesc) ...[
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: ec.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Código aplicado',
                          style: EnjoyTheme.heading(
                            size: 14,
                            weight: FontWeight.w700,
                            color: ec.text,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: ec.textMute, size: 18),
                        onPressed: _quitarCodigoPromotor,
                        tooltip: 'Quitar',
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Promotor: ${_descuentoAplicado!.promotorNombre}',
                    style: EnjoyTheme.body(size: 12.5, color: ec.textSoft),
                  ),
                  const SizedBox(height: 10),
                  _resumenLinea(
                    'Precio original',
                    '\$${_descuentoAplicado!.montoOriginal.toStringAsFixed(2)}',
                    ec,
                  ),
                  _resumenLinea(
                    '−${_descuentoAplicado!.porcentajeDescuento.toStringAsFixed(0)}% descuento',
                    '−\$${_descuentoAplicado!.montoDescuento.toStringAsFixed(2)}',
                    ec,
                    color: ec.green,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: ec.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _resumenLinea(
                      'Total a pagar',
                      '\$${_descuentoAplicado!.montoFinal.toStringAsFixed(2)}',
                      ec,
                      bold: true,
                      color: ec.orange,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codigoPromotorCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: EnjoyTheme.body(color: ec.text),
                  decoration: InputDecoration(
                    hintText: 'Ej. ALEX20',
                    hintStyle: EnjoyTheme.body(color: ec.textMute),
                    filled: true,
                    fillColor: ec.glass,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: ec.stroke),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: ec.stroke),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: ec.orange),
                    ),
                  ),
                  onSubmitted: (_) => _aplicarCodigoPromotor(),
                ),
              ),
              const SizedBox(width: 8),
              EnjoyButton(
                label: _validandoCodigo ? 'Validando…' : 'Aplicar',
                onPressed: _validandoCodigo ? null : _aplicarCodigoPromotor,
                variant: EnjoyButtonVariant.ghost,
              ),
            ],
          ),
          if (_codigoError != null) ...[
            const SizedBox(height: 6),
            Text(
              _codigoError!,
              style: EnjoyTheme.body(size: 12, color: ec.red),
            ),
          ],
        ],
      ],
    );
  }

  Widget _resumenLinea(
    String label,
    String value,
    EnjoyColors ec, {
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: EnjoyTheme.body(
                size: 13,
                color: color ?? ec.textSoft,
                weight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: EnjoyTheme.body(
              size: 13,
              color: color ?? ec.text,
              weight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComprobanteSection() {
    final ec = context.ec;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.upload_file, 'Sube tu comprobante'),
        const SizedBox(height: 12),
        if (_comprobante != null) ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(
                  _comprobante!,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => setState(() => _comprobante = null),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        _DashedUploadBox(
          onTap: _showImageSourceSheet,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: ec.orange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.camera_alt_outlined,
                    color: ec.orangeSoft, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                _comprobante == null
                    ? 'Toca para subir comprobante'
                    : 'Cambiar imagen',
                style:
                    EnjoyTheme.body(weight: FontWeight.w600, color: ec.text),
              ),
              const SizedBox(height: 4),
              Text('Cámara o galería',
                  style: EnjoyTheme.body(size: 12, color: ec.textMute)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegaloSection() {
    final ec = context.ec;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.redeem, '¿Para quién es?'),
        const SizedBox(height: 12),
        // Toggle Para mí / Es un regalo.
        Row(
          children: [
            Expanded(
              child: _SegBtn(
                label: 'Para mí',
                icon: Icons.person_outline,
                selected: !_esRegalo,
                onTap: () => setState(() {
                  _esRegalo = false;
                  _destError = null;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SegBtn(
                label: 'Es un regalo',
                icon: Icons.card_giftcard,
                selected: _esRegalo,
                onTap: () => setState(() => _esRegalo = true),
              ),
            ),
          ],
        ),
        if (_esRegalo) ...[
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'La persona debe tener una cuenta en Enjoy. Recibirá su regalo apenas se apruebe el pago.',
                  style: EnjoyTheme.body(size: 12.5, height: 1.45, color: ec.textMute),
                ),
                const SizedBox(height: 14),
                const FieldLabel('Correo o cédula del destinatario'),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _destinatarioCtrl,
                        enabled: _destinatario == null,
                        onChanged: (_) {
                          if (_destError != null) {
                            setState(() => _destError = null);
                          }
                        },
                        style: EnjoyTheme.body(size: 14, color: ec.text),
                        decoration: InputDecoration(
                          hintText: 'correo@ejemplo.com',
                          hintStyle:
                              EnjoyTheme.body(size: 14, color: ec.textMute),
                          filled: true,
                          fillColor: ec.glass,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: ec.stroke),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: ec.orange),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: ec.stroke),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_destinatario == null)
                      EnjoyButton(
                        label: 'Validar',
                        variant: EnjoyButtonVariant.ghost,
                        dense: true,
                        expand: false,
                        loading: _buscandoDest,
                        onPressed: _buscandoDest ? null : _buscarDestinatario,
                      )
                    else
                      EnjoyButton(
                        label: 'Cambiar',
                        variant: EnjoyButtonVariant.ghost,
                        dense: true,
                        expand: false,
                        onPressed: () => setState(() {
                          _destinatario = null;
                          _destinatarioCtrl.clear();
                        }),
                      ),
                  ],
                ),
                if (_destError != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.error_outline, size: 16, color: ec.red),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _destError!,
                          style: EnjoyTheme.body(size: 12.5, color: ec.red),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_destinatario != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ec.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: ec.green.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: ec.green, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _destinatario!['nombre']?.toString() ??
                                    'Destinatario',
                                style: EnjoyTheme.heading(
                                    size: 14, color: ec.text),
                              ),
                              if ((_destinatario!['email'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                Text(
                                  _destinatario!['email'].toString(),
                                  style: EnjoyTheme.body(
                                      size: 12, color: ec.textMute),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const FieldLabel('Mensaje (opcional)'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _mensajeCtrl,
                    maxLines: 3,
                    maxLength: 200,
                    style: EnjoyTheme.body(size: 14, color: ec.text),
                    decoration: InputDecoration(
                      hintText: '¡Feliz cumpleaños! Disfruta tu cuponera 🎉',
                      hintStyle: EnjoyTheme.body(size: 14, color: ec.textMute),
                      filled: true,
                      fillColor: ec.glass,
                      contentPadding: const EdgeInsets.all(14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: ec.stroke),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: ec.orange),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetodoPagoSelector() {
    final metodos = <Map<String, dynamic>>[];
    if (_cuentas.isNotEmpty) {
      metodos.add({
        'id': 'transferencia',
        'label': 'Transferencia bancaria',
        'icon': Icons.account_balance,
      });
    }
    if (_payphoneActivo) {
      metodos.add({
        'id': 'payphone',
        'label': 'PayPhone',
        'icon': Icons.payment,
      });
    }
    if (_paypalActivo) {
      metodos.add({
        'id': 'paypal',
        'label': 'PayPal',
        'icon': Icons.account_balance_wallet,
      });
    }

    if (metodos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.credit_card, 'Método de pago'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: metodos.map((m) {
            final id = m['id'] as String;
            final selected = _metodoPago == id;
            return Pill(
              m['label'] as String,
              icon: m['icon'] as IconData,
              variant: selected ? PillVariant.orange : PillVariant.glass,
              onTap: () => setState(() => _metodoPago = id),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<Widget> _buildContenidoMetodo() {
    if (_metodoPago == 'transferencia') {
      return [
        _buildCuentasSection(),
        if (_cuentas.isNotEmpty) const SizedBox(height: 24),
        _buildInstruccionesSection(),
        if (_instrucciones.isNotEmpty) const SizedBox(height: 24),
        _buildCodigoPromotorSection(),
        const SizedBox(height: 24),
        _buildComprobanteSection(),
      ];
    }
    return const [];
  }

  /// Acción del CTA inferior según el método elegido.
  VoidCallback? _ctaAction() {
    if (_submitting) return null;
    switch (_metodoPago) {
      case 'transferencia':
        return _submit;
      case 'payphone':
        return _pagarConPayPhone;
      case 'paypal':
        return _pagarConPayPal;
      default:
        return null;
    }
  }

  String _ctaLabel() {
    final precio = _selectedCuponera != null
        ? '\$${_cuponeras[_selectedCuponera!]['precio'] ?? '0.00'}'
        : '';
    if (_selectedCuponera == null) return 'Selecciona una membresía';
    switch (_metodoPago) {
      case 'transferencia':
        return 'Enviar solicitud · $precio';
      case 'payphone':
        return 'Pagar con PayPhone · $precio';
      case 'paypal':
        return 'Pagar con PayPal · $precio';
      default:
        return 'Continuar al pago · $precio';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final hasCta = _selectedCuponera != null;

    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: const EnjoyAppBar(title: 'Comprar Membresía'),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: ec.orange))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCuponerasSection(),
                  if (_selectedCuponera != null) ...[
                    const SizedBox(height: 24),
                    _buildRegaloSection(),
                    const SizedBox(height: 24),
                    _buildMetodoPagoSelector(),
                  ],
                  if (_metodoPago != null) ...[
                    const SizedBox(height: 24),
                    ..._buildContenidoMetodo(),
                  ],
                  // CTA al final del contenido (altura normal, no se estira).
                  if (hasCta) ...[
                    const SizedBox(height: 22),
                    EnjoyButton(
                      label: _ctaLabel(),
                      trailingIcon: _metodoPago == null
                          ? Icons.arrow_forward_rounded
                          : Icons.check_rounded,
                      loading: _submitting,
                      onPressed: _ctaAction(),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
    );
  }
}

/// Botón segmentado (Para mí / Es un regalo).
class _SegBtn extends StatelessWidget {
  const _SegBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            gradient: selected ? ec.accentGradient : null,
            color: selected ? null : ec.glass,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? Colors.transparent : ec.stroke,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? ec.onAccent : ec.textMute,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EnjoyTheme.heading(
                    size: 14,
                    color: selected ? ec.onAccent : ec.textSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Caja de carga de comprobante con borde punteado (mockup #7 · "drop zone").
class _DashedUploadBox extends StatelessWidget {
  const _DashedUploadBox({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: CustomPaint(
          painter: _DashedBorderPainter(color: ec.strokeStrong, radius: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
            decoration: BoxDecoration(
              color: ec.glass,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    const dash = 6.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final next = (dist + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

/// Pantalla de selección cuando hay más de 5 cuponeras
class _SelectorCuponerasPage extends StatelessWidget {
  final List<Map<String, dynamic>> cuponeras;
  const _SelectorCuponerasPage({required this.cuponeras});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: const EnjoyAppBar(title: 'Seleccionar membresía'),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        itemCount: cuponeras.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final c = cuponeras[i];
          final subtitulo = _subtitulo(c);
          return GlassCard(
            onTap: () => Navigator.pop(context, i),
            child: Row(
              children: [
                const IconBox(Icons.local_activity),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c['nombre']?.toString() ?? 'Membresía',
                          style:
                              EnjoyTheme.heading(size: 15, color: ec.text),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      if (subtitulo.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(subtitulo,
                            style: EnjoyTheme.body(
                                size: 12, color: ec.textMute),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text('\$${c['precio'] ?? '0.00'}',
                    style: EnjoyTheme.heading(
                        size: 18,
                        weight: FontWeight.w800,
                        color: ec.text)),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, color: ec.textMute, size: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
