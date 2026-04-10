import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'payphone_webview_screen.dart';

import '../../ui/palette.dart';
import '../../services/configuracion_service.dart';
import '../../services/solicitud_cuponera_service.dart';
import '../../services/versiones_service.dart';
import '../../services/pagos_service.dart';
import 'detalle_version_screen.dart';
import 'mapa_version_screen.dart';

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
  final _montoCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchConfigs();
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchConfigs() async {
    // Cargar configuración, versiones activas y métodos de pago en paralelo
    final results = await Future.wait([
      ConfiguracionService.obtenerTodas(),
      VersionesService.listarActivas(),
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
    final picked = await _picker.pickImage(source: source, imageQuality: 70);
    if (picked != null && mounted) {
      setState(() => _comprobante = File(picked.path));
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Seleccionar imagen',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Palette.kTitle,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Palette.kAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: Palette.kAccent),
                ),
                title: const Text('Galeria'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Palette.kAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: Palette.kAccent),
                ),
                title: const Text('Camara'),
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

  Future<void> _submit() async {
    if (_selectedCuponera == null) {
      _showSnack('Selecciona una cuponera');
      return;
    }
    if (_comprobante == null) {
      _showSnack('Sube tu comprobante de pago');
      return;
    }
    if (_montoCtrl.text.trim().isEmpty) {
      _showSnack('Ingresa el monto transferido');
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
      'montoTransferido': _montoCtrl.text.trim(),
      'observaciones': _obsCtrl.text.trim(),
      'comprobanteBase64': base64Image,
    };

    final ok = await SolicitudCuponeraService.enviar(dto);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud enviada correctamente'),
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
      _showSnack('Selecciona una cuponera');
      return;
    }

    setState(() => _submitting = true);
    final cuponera = _cuponeras[_selectedCuponera!];

    try {
      final result = await PagosService.iniciarPayPhone(
        clienteId: widget.clienteId,
        nombreCliente: widget.nombreCliente,
        emailCliente: widget.emailCliente,
        telefonoCliente: widget.telefonoCliente,
        cuponeraNombre: cuponera['nombre'] ?? '',
        cuponeraPrecio: cuponera['precio'] ?? '0.00',
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
                Text('¡Pago aprobado! Tu cuponera ha sido activada.'),
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
      _showSnack('Selecciona una cuponera');
      return;
    }

    setState(() => _submitting = true);
    final cuponera = _cuponeras[_selectedCuponera!];

    try {
      final result = await PagosService.crearPayPal(
        clienteId: widget.clienteId,
        nombreCliente: widget.nombreCliente,
        emailCliente: widget.emailCliente,
        cuponeraNombre: cuponera['nombre'] ?? '',
        cuponeraPrecio: cuponera['precio'] ?? '0.00',
        returnUrl: 'https://ecuenjoy.com/pago/exito',
        cancelUrl: 'https://ecuenjoy.com/pago/cancelado',
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
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Palette.kAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Palette.kAccent, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Palette.kTitle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child, bool selected = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: selected
            ? Border.all(color: Palette.kAccent, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Palette.kMuted, fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, color: Palette.kAccent, size: 20) : null,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.kAccent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  // ─── Sections ───────────────────────────────────────────────

  Widget _buildCuponeraCard(Map<String, dynamic> c, {bool selected = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: _card(
        selected: selected,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected ? Palette.kAccent.withOpacity(0.15) : Palette.kBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.local_activity,
                      color: selected ? Palette.kAccent : Palette.kMuted),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['nombre']?.toString() ?? 'Cuponera',
                          style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15,
                            color: selected ? Palette.kTitle : Palette.kSub,
                          ),
                        ),
                        if (c['descripcion'] != null && c['descripcion'].toString().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(c['descripcion'].toString(),
                            style: const TextStyle(color: Palette.kMuted, fontSize: 13),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                        if (c['ciudadesDisponibles'] is List && (c['ciudadesDisponibles'] as List).isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text((c['ciudadesDisponibles'] as List).join(', '),
                            style: const TextStyle(color: Palette.kMuted, fontSize: 12),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                  Text('\$${c['precio'] ?? '0.00'}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18,
                      color: selected ? Palette.kAccent : Palette.kTitle,
                    ),
                  ),
                ],
              ),
              if (selected) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _verLocales(c),
                        icon: const Icon(Icons.store_outlined, size: 18),
                        label: const Text('Ver locales'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Palette.kAccent,
                          side: BorderSide(color: Palette.kAccent.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _verMapa(c),
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Mapa'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Palette.kPrimary,
                        side: BorderSide(color: Palette.kPrimary.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
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
    final total = _cuponeras.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.card_giftcard, 'Selecciona tu cuponera'),
        const SizedBox(height: 12),

        if (total == 0)
          const Text('No hay cuponeras disponibles.', style: TextStyle(color: Palette.kMuted))

        // Más de 5: modo selector
        else if (total > 5) ...[
          if (_selectedCuponera != null) ...[
            _buildCuponeraCard(_cuponeras[_selectedCuponera!], selected: true),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _abrirSelectorCuponeras,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Cambiar cuponera'),
                style: TextButton.styleFrom(foregroundColor: Palette.kAccent),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _abrirSelectorCuponeras,
                icon: const Icon(Icons.local_activity, size: 20),
                label: Text('Seleccionar cuponera ($total disponibles)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Palette.kTitle,
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
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
    if (_cuentas.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.account_balance, 'Datos de transferencia'),
        const SizedBox(height: 12),
        ..._cuentas.map((cuenta) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cuenta['banco']?.toString() ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Palette.kTitle,
                      ),
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
                              const Text(
                                'Numero de cuenta',
                                style: TextStyle(color: Palette.kMuted, fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                cuenta['numero']?.toString() ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Palette.kTitle,
                                  letterSpacing: 0.5,
                                ),
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
                          icon: const Icon(Icons.copy, color: Palette.kAccent, size: 20),
                          tooltip: 'Copiar numero',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _cuentaRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(color: Palette.kMuted, fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Palette.kTitle, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstruccionesSection() {
    if (_instrucciones.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.info_outline, 'Instrucciones'),
        const SizedBox(height: 12),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _instrucciones,
              style: const TextStyle(color: Palette.kTitle, fontSize: 14, height: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComprobanteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.upload_file, 'Sube tu comprobante'),
        const SizedBox(height: 12),
        if (_comprobante != null) ...[
          Stack(
            children: [
              _card(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _comprobante!,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
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
        GestureDetector(
          onTap: _showImageSourceSheet,
          child: _card(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Palette.kAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_outlined, color: Palette.kAccent, size: 28),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _comprobante == null ? 'Toca para subir comprobante' : 'Cambiar imagen',
                    style: const TextStyle(
                      color: Palette.kMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.edit_note, 'Detalles del pago'),
        const SizedBox(height: 12),
        TextField(
          controller: _montoCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _inputDecoration('Monto transferido (\$)', icon: Icons.attach_money),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _obsCtrl,
          maxLines: 3,
          decoration: _inputDecoration('Observaciones (opcional)', icon: Icons.notes),
        ),
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
        'color': const Color(0xFF2E7D32),
      });
    }
    if (_payphoneActivo) {
      metodos.add({
        'id': 'payphone',
        'label': 'PayPhone',
        'icon': Icons.payment,
        'color': const Color(0xFF1A73E8),
      });
    }
    if (_paypalActivo) {
      metodos.add({
        'id': 'paypal',
        'label': 'PayPal',
        'icon': Icons.account_balance_wallet,
        'color': const Color(0xFF003087),
      });
    }

    if (metodos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.credit_card, 'Método de pago'),
        const SizedBox(height: 12),
        ...metodos.map((m) {
          final selected = _metodoPago == m['id'];
          final color = m['color'] as Color;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => setState(() => _metodoPago = m['id'] as String),
              child: _card(
                selected: selected,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(selected ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(m['icon'] as IconData, color: color, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          m['label'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: selected ? Palette.kTitle : Palette.kSub,
                          ),
                        ),
                      ),
                      if (selected)
                        const Icon(Icons.check_circle, color: Palette.kAccent, size: 22)
                      else
                        const Icon(Icons.radio_button_unchecked, color: Palette.kMuted, size: 22),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
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
        _buildComprobanteSection(),
        const SizedBox(height: 24),
        _buildFormFields(),
        const SizedBox(height: 28),
        _buildSubmitButton(),
      ];
    }
    if (_metodoPago == 'payphone') {
      return [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _pagarConPayPhone,
            icon: const Icon(Icons.payment, size: 20),
            label: Text(
              _submitting ? 'Procesando...' : 'Pagar con PayPhone',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ];
    }
    if (_metodoPago == 'paypal') {
      return [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _pagarConPayPal,
            icon: const Icon(Icons.account_balance_wallet, size: 20),
            label: Text(
              _submitting ? 'Procesando...' : 'Pagar con PayPal',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003087),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ];
    }
    return [];
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _submitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Palette.kAccent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Palette.kAccent.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Enviar solicitud',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        backgroundColor: Palette.kPrimary,
        foregroundColor: Colors.white,
        title: const Text(
          'Comprar Cuponera',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Palette.kAccent),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCuponerasSection(),
                  if (_selectedCuponera != null) ...[
                    const SizedBox(height: 24),
                    _buildMetodoPagoSelector(),
                  ],
                  if (_metodoPago != null) ...[
                    const SizedBox(height: 24),
                    ..._buildContenidoMetodo(),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

/// Pantalla de selección cuando hay más de 5 cuponeras
class _SelectorCuponerasPage extends StatelessWidget {
  final List<Map<String, dynamic>> cuponeras;
  const _SelectorCuponerasPage({required this.cuponeras});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        backgroundColor: Palette.kPrimary,
        foregroundColor: Colors.white,
        title: const Text('Seleccionar cuponera',
          style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: cuponeras.length,
        itemBuilder: (context, i) {
          final c = cuponeras[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => Navigator.pop(context, i),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Palette.kBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_activity, color: Palette.kMuted),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c['nombre']?.toString() ?? 'Cuponera',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Palette.kTitle)),
                          if (c['descripcion'] != null && c['descripcion'].toString().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(c['descripcion'].toString(),
                              style: const TextStyle(color: Palette.kMuted, fontSize: 13),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                          if (c['ciudadesDisponibles'] is List && (c['ciudadesDisponibles'] as List).isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text((c['ciudadesDisponibles'] as List).join(', '),
                              style: const TextStyle(color: Palette.kMuted, fontSize: 12),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text('\$${c['precio'] ?? '0.00'}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Palette.kTitle)),
                        const SizedBox(height: 4),
                        const Icon(Icons.chevron_right, color: Palette.kMuted, size: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
