import 'dart:convert';
import 'dart:io';

import 'package:enjoy/screens/usuarios/contrato_lectura_screen.dart';
import 'package:enjoy/screens/usuarios/selfie_liveness_screen.dart';
import 'package:enjoy/services/contrato_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Pantalla bloqueante que el admin-local NUEVO ve la primera vez que entra.
/// Form de datos faltantes + scroll obligatorio del contrato + foto de cédula
/// + checkbox de aceptación. Al firmar, el back genera el PDF y queda
/// almacenado en S3.
class ContratoAdminLocalScreen extends StatefulWidget {
  /// El home se cierra al firmar y se reabre desde cero para refrescar
  /// cualquier estado dependiente.
  final VoidCallback onFirmado;

  const ContratoAdminLocalScreen({super.key, required this.onFirmado});

  @override
  State<ContratoAdminLocalScreen> createState() =>
      _ContratoAdminLocalScreenState();
}

class _ContratoAdminLocalScreenState extends State<ContratoAdminLocalScreen> {
  final _svc = ContratoService();
  final _picker = ImagePicker();

  bool _cargando = true;
  bool _guardando = false;
  bool _omitiendo = false;
  ContratoEstado? _estado;

  // Datos del local
  final _rucCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _repreCtrl = TextEditingController();
  final _cedulaRepreCtrl = TextEditingController();
  final _celularCtrl = TextEditingController();
  String _estadoCivil = 'soltero';

  /// Claves de los campos que llegaron con valor del backend — se muestran
  /// como solo lectura y no pueden editarse desde este flujo. Los faltantes
  /// se piden acá y suben en el POST /contratos/aceptar.
  final Set<String> _bloqueados = <String>{};

  // Selfie con liveness (paso 1)
  String? _selfieBase64;

  // Cédula (paso 2)
  File? _cedulaFile;
  String? _cedulaBase64;

  // Estado de UI
  bool _scrollCompleto = false;
  bool _aceptaTerminos = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _rucCtrl.dispose();
    _direccionCtrl.dispose();
    _repreCtrl.dispose();
    _cedulaRepreCtrl.dispose();
    _celularCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final e = await _svc.miEstado();
      if (!mounted) return;
      setState(() {
        _estado = e;

        // Datos del representante legal: se prellenan si ya existen, pero
        // quedan EDITABLES para que el admin-local pueda corregirlos al firmar.
        // Solo los datos del local (RUC, dirección, celular) se bloquean.
        const editables = {'representanteLegal', 'cedulaRepresentante'};

        void aplicar(String key, TextEditingController ctrl) {
          final valor = (e.datosLocal[key] ?? '').toString();
          ctrl.text = valor;
          if (valor.trim().isNotEmpty && !editables.contains(key)) {
            _bloqueados.add(key);
          }
        }

        aplicar('ruc', _rucCtrl);
        aplicar('direccion', _direccionCtrl);
        aplicar('representanteLegal', _repreCtrl);
        aplicar('cedulaRepresentante', _cedulaRepreCtrl);
        aplicar('celular', _celularCtrl);

        // Estado civil siempre editable: solo prellenamos el valor guardado.
        final ec = (e.datosLocal['estadoCivilRepresentante'] ?? '').toString();
        if (ec.isNotEmpty) {
          _estadoCivil = ec;
        }
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  Future<void> _elegirCedula() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 75,
    );
    if (picked == null) return;
    final file = File(picked.path);
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      _toast('La foto es muy grande. Tomala con menor resolución.');
      return;
    }
    setState(() {
      _cedulaFile = file;
      _cedulaBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    });
  }

  Future<void> _elegirCedulaGaleria() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 75,
    );
    if (picked == null) return;
    final file = File(picked.path);
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      _toast('La foto es muy grande.');
      return;
    }
    setState(() {
      _cedulaFile = file;
      _cedulaBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    });
  }

  bool get _puedeFirmar =>
      _scrollCompleto &&
      _aceptaTerminos &&
      _selfieBase64 != null &&
      _cedulaBase64 != null &&
      _rucCtrl.text.trim().isNotEmpty &&
      _direccionCtrl.text.trim().isNotEmpty &&
      _repreCtrl.text.trim().isNotEmpty &&
      _cedulaRepreCtrl.text.trim().isNotEmpty &&
      _celularCtrl.text.trim().isNotEmpty;

  /// Abre la pantalla con cámara frontal + ML Kit y guarda el selfie en estado.
  Future<void> _capturarSelfie() async {
    final result = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (_) => const SelfieLivenessScreen(),
        fullscreenDialog: true,
      ),
    );
    if (result != null && mounted) {
      setState(() => _selfieBase64 = result);
    }
  }

  /// Abre el contrato en su propia pantalla a pantalla completa. Cuando el
  /// usuario llega al final y toca "He leído", volvemos con `true` y
  /// habilitamos el checkbox de aceptación.
  Future<void> _abrirContrato() async {
    final nombre =
        (_estado?.datosLocal['nombreLocal'] ?? '').toString();
    final leido = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ContratoLecturaScreen(nombreLocal: nombre),
        fullscreenDialog: true,
      ),
    );
    if (leido == true && mounted) {
      setState(() => _scrollCompleto = true);
    }
  }

  /// Llama al endpoint /contratos/omitir. Cierra la pantalla al confirmarse.
  /// Antes pide confirmación y avisa cuántas omisiones le quedarán después.
  Future<void> _omitirContrato() async {
    final estado = _estado;
    if (estado == null || estado.omisionesRestantes <= 0) return;

    final restantesTrasEsta = estado.omisionesRestantes - 1;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ec = ctx.ec;
        return AlertDialog(
          backgroundColor: ec.surfaceTop,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Omitir por ahora',
            style: EnjoyTheme.heading(
                size: 17, color: ec.text, weight: FontWeight.w800),
          ),
          content: Text(
            restantesTrasEsta > 0
                ? 'Podrás usar la app, pero te vamos a volver a pedir la firma la próxima vez. Después de esta te quedarán $restantesTrasEsta omisiones.'
                : 'Esta es tu última omisión. La próxima vez que entres tendrás que firmar el contrato sí o sí para poder operar.',
            style: EnjoyTheme.body(size: 13.5, color: ec.textSoft, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar',
                  style: EnjoyTheme.body(size: 13.5, color: ec.textSoft)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Sí, omitir',
                style: EnjoyTheme.body(
                    size: 13.5,
                    color: ec.orange,
                    weight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );
    if (confirmar != true || !mounted) return;

    setState(() => _omitiendo = true);
    try {
      await _svc.omitir();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _omitiendo = false);
      String backMsg = '';
      try {
        final dyn = e as dynamic;
        backMsg = (dyn.response?.data?['message'] ??
                dyn.response?.data?.toString() ??
                '')
            .toString();
      } catch (_) {}
      _toast(backMsg.isNotEmpty ? backMsg : 'No pudimos omitir. Intentá más tarde.');
    }
  }

  Future<void> _firmar() async {
    if (!_puedeFirmar) {
      _toast(
        'Completá los datos, leé el contrato hasta el final, subí tu cédula y aceptá los términos.',
      );
      return;
    }
    // 1) Pedir OTP → email al admin-local.
    setState(() => _guardando = true);
    Map<String, String> info;
    try {
      info = await _svc.solicitarOtp();
    } catch (e) {
      setState(() => _guardando = false);
      _toast('No se pudo enviar el código. Reintentá.');
      return;
    }
    setState(() => _guardando = false);
    if (!mounted) return;

    // 2) Pedir el código al usuario.
    final otp = await _pedirOtpDialog(info['email'] ?? '');
    if (otp == null) return; // canceló

    // 3) Enviar firma con OTP + selfie (ya capturado antes).
    setState(() => _guardando = true);
    try {
      await _svc.aceptar(
        cedulaBase64: _cedulaBase64!,
        selfieBase64: _selfieBase64,
        datosLocal: {
          'ruc': _rucCtrl.text.trim(),
          'direccion': _direccionCtrl.text.trim(),
          'representanteLegal': _repreCtrl.text.trim(),
          'cedulaRepresentante': _cedulaRepreCtrl.text.trim(),
          'estadoCivilRepresentante': _estadoCivil,
          'celular': _celularCtrl.text.trim(),
        },
        aceptaTerminos: true,
        otp: otp,
      );
      if (!mounted) return;
      _toast('¡Contrato firmado!');
      widget.onFirmado();
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      // Extraer el mensaje real del back. Dio envuelve la respuesta:
      // e.response.data.message → '... no solicitaste código ...' etc.
      String backMsg = '';
      try {
        final dyn = e as dynamic;
        backMsg = (dyn.response?.data?['message'] ??
                dyn.response?.data?.toString() ??
                '')
            .toString();
      } catch (_) {}
      final raw = (backMsg.isNotEmpty ? backMsg : e.toString()).toLowerCase();
      String msg;
      if (raw.contains('código') ||
          raw.contains('codigo') ||
          raw.contains('otp')) {
        msg =
            'El código no es válido o expiró. Pedí uno nuevo (la app puede haberse reiniciado).';
      } else if (raw.contains('timeout') || raw.contains('connection')) {
        msg =
            'Sin conexión estable. Verificá tu internet y volvé a intentar.';
      } else if (backMsg.isNotEmpty) {
        msg = backMsg;
      } else {
        msg = 'No pudimos firmar tu contrato. Intentá de nuevo.';
      }
      _toast(msg);
    }
  }

  /// Modal con input de 6 dígitos. Retorna el código o null si cancela.
  Future<String?> _pedirOtpDialog(String emailEnmascarado) async {
    final ctrl = TextEditingController();
    final ec = context.ec;
    bool reenviando = false;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ec.surfaceMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final bottom = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ec.stroke,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Icon(Icons.mark_email_read_outlined, color: ec.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Código de firma enviado',
                        style: EnjoyTheme.heading(
                            size: 17, weight: FontWeight.w800, color: ec.text),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Te enviamos un código de 6 dígitos a $emailEnmascarado. Ingresalo para completar la firma del contrato.',
                  style: EnjoyTheme.body(size: 13, color: ec.textSoft, height: 1.4),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: EnjoyTheme.heading(
                      size: 26,
                      weight: FontWeight.w800,
                      color: ec.text,
                      letterSpacing: 8),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    hintStyle: EnjoyTheme.heading(
                        size: 26,
                        weight: FontWeight.w800,
                        color: ec.textMute,
                        letterSpacing: 8),
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
                      borderSide: BorderSide(color: ec.orange, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: reenviando
                          ? null
                          : () async {
                              setLocal(() => reenviando = true);
                              try {
                                await _svc.solicitarOtp();
                                if (!mounted) return;
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                      content: Text('Te enviamos un código nuevo.')),
                                );
                              } catch (_) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                      content: Text('No se pudo reenviar.')),
                                );
                              }
                              setLocal(() => reenviando = false);
                            },
                      icon: Icon(Icons.refresh, color: ec.orangeSoft, size: 18),
                      label: Text(
                        reenviando ? 'Enviando…' : 'Reenviar código',
                        style: EnjoyTheme.body(
                            size: 13,
                            color: ec.orangeSoft,
                            weight: FontWeight.w700),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Cancelar',
                        style:
                            EnjoyTheme.body(size: 13.5, color: ec.textSoft),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: EnjoyButton(
                    label: 'Confirmar firma',
                    icon: Icons.verified_user_outlined,
                    onPressed: () {
                      final v = ctrl.text.trim();
                      if (v.length != 6) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text('Ingresá los 6 dígitos.')),
                        );
                        return;
                      }
                      Navigator.pop(ctx, v);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;

    // Mientras se está firmando (subiendo cédula/selfie, generando PDF,
    // subiendo a S3, enviando mail), tapamos toda la pantalla con un loader
    // claro y descriptivo. Sin esto, parecía que la app se colgaba.
    if (_guardando) {
      return PopScope(
        canPop: false,
        child: EnjoyScaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(
                      color: ec.orange,
                      strokeWidth: 4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Firmando tu contrato…',
                    textAlign: TextAlign.center,
                    style: EnjoyTheme.heading(
                      size: 20,
                      weight: FontWeight.w800,
                      color: ec.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Estamos generando tu PDF, subiendo tu cédula y selfie, y enviándote una copia por email. Esto puede tardar unos segundos. Por favor no cierres la app.',
                    textAlign: TextAlign.center,
                    style: EnjoyTheme.body(
                      size: 13.5,
                      color: ec.textSoft,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false, // no se puede volver atrás
      child: EnjoyScaffold(
        appBar: const EnjoyAppBar(title: 'Contrato de cooperación'),
        body: _cargando
            ? Center(child: CircularProgressIndicator(color: ec.orange))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Aviso arriba explicando por qué algunos campos están
                    // bloqueados — evita que el usuario piense que la app
                    // está rota cuando no puede tocar RUC/dirección/etc.
                    if (_bloqueados.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4, bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: ec.glass,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ec.stroke),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                color: ec.orangeSoft, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Algunos datos ya están cargados en tu ficha y no se pueden editar acá. Completá los faltantes y firmá el contrato.',
                                style: EnjoyTheme.body(
                                    size: 12.5,
                                    color: ec.textSoft,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Datos del local
                    _sectionTitle(ec, 'Datos del local'),
                    _label('RUC del local *'),
                    _input(_rucCtrl,
                        hint: '1801234567001',
                        readOnly: _bloqueados.contains('ruc')),
                    _label('Dirección del local *'),
                    _input(_direccionCtrl,
                        hint: 'Calle, número, sector',
                        readOnly: _bloqueados.contains('direccion')),
                    _label('Representante legal *'),
                    _input(_repreCtrl,
                        hint: 'Nombres y apellidos',
                        readOnly: _bloqueados.contains('representanteLegal')),
                    _label('Cédula del representante *'),
                    _input(_cedulaRepreCtrl,
                        hint: '1801234567',
                        readOnly:
                            _bloqueados.contains('cedulaRepresentante')),
                    _label('Estado civil'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: ec.glass,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ec.stroke),
                      ),
                      child: DropdownButton<String>(
                        value: _estadoCivil,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        dropdownColor: ec.surfaceTop,
                        items: const [
                          DropdownMenuItem(
                              value: 'soltero', child: Text('Soltero/a')),
                          DropdownMenuItem(
                              value: 'casado', child: Text('Casado/a')),
                          DropdownMenuItem(
                              value: 'divorciado', child: Text('Divorciado/a')),
                          DropdownMenuItem(
                              value: 'viudo', child: Text('Viudo/a')),
                          DropdownMenuItem(
                              value: 'union_libre', child: Text('Unión libre')),
                        ],
                        onChanged: (v) =>
                            setState(() => _estadoCivil = v ?? 'soltero'),
                      ),
                    ),
                    _label('Celular *'),
                    _input(_celularCtrl,
                        hint: '0991234567',
                        readOnly: _bloqueados.contains('celular')),

                    const SizedBox(height: 18),
                    _sectionTitle(ec, 'Contrato de cooperación'),
                    Text(
                      'Se abre en pantalla completa. Leelo hasta el final para poder aceptar.',
                      style: EnjoyTheme.body(
                          size: 12.5, color: ec.textSoft, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: EnjoyButton(
                        label: _scrollCompleto
                            ? 'Volver a leer el contrato'
                            : 'Leer el contrato',
                        icon: _scrollCompleto
                            ? Icons.menu_book
                            : Icons.menu_book_outlined,
                        onPressed: _abrirContrato,
                        variant: _scrollCompleto
                            ? EnjoyButtonVariant.ghost
                            : EnjoyButtonVariant.orange,
                      ),
                    ),
                    if (_scrollCompleto)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: ec.green, size: 16),
                            const SizedBox(width: 6),
                            Text('Contrato leído',
                                style: EnjoyTheme.body(
                                    size: 12.5, color: ec.green)),
                          ],
                        ),
                      ),

                    // ─── Paso 1: Selfie con prueba de vida ───
                    const SizedBox(height: 18),
                    _sectionTitle(ec, 'Selfie del representante *'),
                    Text(
                      'Tomate una selfie con prueba de vida (sonreí, parpadeá y girá la cabeza). Queda como anexo del contrato.',
                      style: EnjoyTheme.body(
                          size: 12.5, color: ec.textSoft, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    if (_selfieBase64 != null)
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: ec.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: ec.green, width: 1.5),
                              ),
                              child: Icon(Icons.check_circle,
                                  color: ec.green, size: 36),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selfie capturado ✓',
                                  style: EnjoyTheme.heading(
                                      size: 14,
                                      weight: FontWeight.w800,
                                      color: ec.text),
                                ),
                                const SizedBox(height: 4),
                                TextButton.icon(
                                  onPressed: _capturarSelfie,
                                  icon: Icon(Icons.refresh,
                                      color: ec.orangeSoft, size: 16),
                                  label: Text(
                                    'Volver a tomar',
                                    style: EnjoyTheme.body(
                                        size: 12.5,
                                        color: ec.orangeSoft,
                                        weight: FontWeight.w700),
                                  ),
                                  style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 0)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: EnjoyButton(
                          label: 'Tomar selfie con prueba de vida',
                          icon: Icons.face_retouching_natural,
                          onPressed: _capturarSelfie,
                          variant: EnjoyButtonVariant.ghost,
                        ),
                      ),

                    // ─── Paso 2: Cédula ───
                    const SizedBox(height: 18),
                    _sectionTitle(ec, 'Foto de tu cédula *'),
                    if (_cedulaFile != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              _cedulaFile!,
                              width: double.infinity,
                              height: 180,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _cedulaFile = null;
                                _cedulaBase64 = null;
                              }),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: EnjoyButton(
                              label: 'Cámara',
                              icon: Icons.photo_camera_outlined,
                              onPressed: _elegirCedula,
                              variant: EnjoyButtonVariant.ghost,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: EnjoyButton(
                              label: 'Galería',
                              icon: Icons.photo_outlined,
                              onPressed: _elegirCedulaGaleria,
                              variant: EnjoyButtonVariant.ghost,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _aceptaTerminos,
                          onChanged: _scrollCompleto
                              ? (v) =>
                                  setState(() => _aceptaTerminos = v ?? false)
                              : null,
                          activeColor: ec.orange,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'Acepto los términos y condiciones del contrato de cooperación con Club Enjoy. Confirmo que leí el contrato completo y que los datos son verídicos.',
                              style: EnjoyTheme.body(
                                  size: 13, color: ec.text, height: 1.4),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: EnjoyButton(
                        label: _guardando ? 'Firmando…' : 'Firmar y continuar',
                        icon: Icons.check_circle_outline,
                        onPressed: _guardando || !_puedeFirmar ? null : _firmar,
                      ),
                    ),
                    if ((_estado?.omisionesRestantes ?? 0) > 0) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: (_guardando || _omitiendo)
                              ? null
                              : _omitirContrato,
                          icon: Icon(Icons.schedule,
                              size: 18, color: ec.textSoft),
                          label: Text(
                            _omitiendo
                                ? 'Omitiendo…'
                                : 'Omitir por ahora  ·  te quedan ${_estado!.omisionesRestantes} de 3',
                            style: EnjoyTheme.body(
                              size: 13,
                              color: ec.textSoft,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _sectionTitle(EnjoyColors ec, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          t,
          style: EnjoyTheme.heading(
            size: 16,
            color: ec.text,
            weight: FontWeight.w800,
          ),
        ),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(
          t,
          style: EnjoyTheme.body(
            size: 12.5,
            color: context.ec.textSoft,
            weight: FontWeight.w600,
          ),
        ),
      );

  Widget _input(
    TextEditingController ctrl, {
    String? hint,
    bool readOnly = false,
  }) {
    final ec = context.ec;
    return TextField(
      controller: ctrl,
      readOnly: readOnly,
      style: EnjoyTheme.body(color: readOnly ? ec.textSoft : ec.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: EnjoyTheme.body(color: ec.textMute),
        filled: true,
        fillColor: readOnly ? ec.stroke.withValues(alpha: 0.25) : ec.glass,
        suffixIcon: readOnly
            ? Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(Icons.lock_outline, size: 18, color: ec.textMute),
              )
            : null,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 32, minHeight: 32),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          borderSide: BorderSide(color: readOnly ? ec.stroke : ec.orange),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

}
