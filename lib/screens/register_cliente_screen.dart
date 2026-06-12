import 'dart:convert';
import 'package:enjoy/models/ciudad.dart';
import 'package:enjoy/models/provincia.dart';
import 'package:enjoy/screens/usuarios/establecimiento_form_screen.dart'
    show SearchablePickerField;
import 'package:enjoy/services/ciudades_service.dart';
import 'package:enjoy/widgets/branded_modal.dart';
import 'package:flutter/material.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:enjoy/services/registration_api.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/otp_service.dart';
import 'package:enjoy/screens/otp_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

enum TipoIdentificacion { CEDULA, RUC, PASAPORTE }

class RegisterClienteScreen extends StatefulWidget {
  /// Datos pre-llenados cuando el usuario viene desde Google Sign-In.
  /// Contiene: nombres, apellidos, email, googleId (opcional).
  final Map<String, dynamic>? googleData;

  const RegisterClienteScreen({super.key, this.googleData});

  @override
  State<RegisterClienteScreen> createState() => _RegisterClienteScreenState();
}

class _RegisterClienteScreenState extends State<RegisterClienteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = RegistrationApi();
  final _auth = AuthService();
  final _otp = OtpService();

  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _identificacion = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _telefono = TextEditingController();

  TipoIdentificacion _tipo = TipoIdentificacion.CEDULA;
  bool _loading = false;
  bool _emailOk = false;
  bool _obscure = true;
  bool _aceptaTerminos = false;
  bool _fromGoogle = false;

  // ── Ubicación ──
  final _ciudadesSvc = CiudadesService();
  List<Provincia> _provincias = [];
  List<Ciudad> _ciudades = [];
  String? _provinciaId;
  String? _ciudadId;
  bool _gpsLoading = false;

  static const int _otpLen = 5;

  @override
  void initState() {
    super.initState();
    final g = widget.googleData;
    if (g != null) {
      _nombres.text = g['nombres'] ?? '';
      _apellidos.text = g['apellidos'] ?? '';
      _email.text = g['email'] ?? '';
      _fromGoogle = true;
      _emailOk = true; // Email verificado por Google, saltar OTP
    }
    _cargarProvincias();
  }

  Future<void> _cargarProvincias() async {
    try {
      final list = await _ciudadesSvc.getProvincias();
      if (!mounted) return;
      setState(() => _provincias = list);
    } catch (_) {}
  }

  Future<void> _cargarCiudades(String provinciaId) async {
    try {
      final list = await _ciudadesSvc.getParaRegistro(provinciaId: provinciaId);
      if (!mounted) return;
      setState(() => _ciudades = list);
    } catch (_) {}
  }

  /// Pide permiso, obtiene lat/lng y busca provincia/ciudad por reverse-geocode
  /// usando OpenStreetMap (sin API key). Si no encuentra match exacto en el
  /// catálogo, deja los pickers para que el usuario elija manualmente.
  Future<void> _usarMiUbicacion() async {
    setState(() => _gpsLoading = true);
    try {
      // Permisos
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _snack('Permiso de ubicación denegado.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition();

      // Reverse-geocode con OpenStreetMap (Nominatim). Sin API key.
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${pos.latitude}&lon=${pos.longitude}&format=json&zoom=10&accept-language=es',
      );
      final resp = await http.get(url, headers: {
        'User-Agent': 'EnjoyApp/1.0 (registro cliente)',
      });
      if (resp.statusCode != 200) {
        _snack('No se pudo detectar tu ciudad.');
        return;
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final addr = (json['address'] as Map?) ?? {};
      final provinciaNombre = (addr['state'] ?? '').toString();
      final ciudadNombre = (addr['city'] ??
              addr['town'] ??
              addr['village'] ??
              addr['municipality'] ??
              '')
          .toString();

      // Match contra catálogo (sin tildes, case-insensitive)
      String norm(String s) => s
          .toLowerCase()
          .replaceAll(RegExp(r'á|à|ä|â'), 'a')
          .replaceAll(RegExp(r'é|è|ë|ê'), 'e')
          .replaceAll(RegExp(r'í|ì|ï|î'), 'i')
          .replaceAll(RegExp(r'ó|ò|ö|ô'), 'o')
          .replaceAll(RegExp(r'ú|ù|ü|û'), 'u')
          .trim();

      final provMatch = _provincias.firstWhere(
        (p) => norm(p.nombre) == norm(provinciaNombre),
        orElse: () => const Provincia(id: '', nombre: ''),
      );
      if (provMatch.id.isEmpty) {
        _snack('No detectamos tu provincia. Selecciónala manualmente.');
        return;
      }
      setState(() {
        _provinciaId = provMatch.id;
        _ciudadId = null;
      });
      await _cargarCiudades(provMatch.id);
      if (!mounted) return;

      final ciuMatch = _ciudades.firstWhere(
        (c) => norm(c.nombre) == norm(ciudadNombre),
        orElse: () => const Ciudad(
          id: '',
          nombre: '',
          estado: true,
          visibleParaRegistro: true,
        ),
      );
      if (ciuMatch.id.isNotEmpty) {
        setState(() => _ciudadId = ciuMatch.id);
        _snack('Ubicación detectada: ${provMatch.nombre} / ${ciuMatch.nombre}');
      } else {
        _snack(
            'Provincia: ${provMatch.nombre}. Elige tu ciudad manualmente.');
      }
    } catch (e) {
      _snack('No se pudo obtener tu ubicación.');
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  @override
  void dispose() {
    _nombres.dispose();
    _apellidos.dispose();
    _identificacion.dispose();
    _email.dispose();
    _password.dispose();
    _telefono.dispose();
    super.dispose();
  }

  // ── Validaciones ──
  String? _reqMin2(String? v) =>
      (v == null || v.trim().length < 2) ? 'Requerido (mín. 2 caracteres)' : null;
  String? _reqNotEmpty(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Requerido' : null;
  String? _emailVal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Requerido';
    final rx = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return rx.hasMatch(v.trim()) ? null : 'Email inválido';
  }
  String? _pwdVal(String? v) =>
      (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null;

  // ── Paso 1: validar correo ──
  Future<void> _checkEmail() async {
    final err = _emailVal(_email.text);
    if (err != null) {
      _snack(err);
      return;
    }
    final correo = _email.text.trim();

    setState(() => _loading = true);
    try {
      final available = await _api.checkEmailAvailable(correo);
      if (!available) {
        await showBrandedDialog(context,
          title: 'Correo ya registrado',
          message: 'Usa otro correo o inicia sesión con ese email.',
          icon: Icons.warning_amber_rounded,
        );
        return;
      }
      setState(() => _emailOk = true);
      _snack('Correo disponible. Completa tus datos.');
    } catch (e) {
      await showBrandedDialog(context,
        title: 'Error al verificar',
        message: e.toString(),
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Paso 2: OTP + crear cuenta ──
  Future<void> _submit() async {
    if (!_emailOk) {
      _snack('Primero valida tu correo.');
      return;
    }
    if (!_aceptaTerminos) {
      _snack('Debes aceptar los Términos y Condiciones.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final correo = _email.text.trim();

      // Si viene de Google, el email ya está verificado — saltar OTP
      if (!_fromGoogle) {
        await _otp.sendOtp(correo);

        if (!mounted) return;
        final ok = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerifyScreen(
              length: _otpLen,
              email: correo,
              otpService: _otp,
              title: 'Verificación',
              subtitle: 'Ingresa el código de $_otpLen dígitos enviado a $correo.',
              canResend: true,
              resendSeconds: 45,
            ),
          ),
        );
        if (ok != true) return;
      }

      final dto = {
        "nombres": _nombres.text.trim(),
        "apellidos": _apellidos.text.trim(),
        "tipoIdentificacion": _tipo.name,
        "identificacion": _identificacion.text.trim(),
        "email": correo,
        // Social: sin clave (se recupera luego). Email: con clave.
        "password": _fromGoogle ? null : _password.text,
        "telefono": _telefono.text.trim().isEmpty ? null : _telefono.text.trim(),
        if (_provinciaId != null) "provincia": _provinciaId,
        if (_ciudadId != null) "ciudad": _ciudadId,
      };

      // Crea la cuenta y deja la sesión iniciada (auto-login → home).
      if (!mounted) return;
      await _auth.registerCliente(dto, context);
    } catch (e) {
      await showBrandedDialog(context,
        title: 'No se pudo registrar',
        message: e.toString(),
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return EnjoyScaffold(
      appBar: const EnjoyAppBar(title: 'Crear cuenta'),
      padding: EdgeInsets.zero,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Barra de pasos ──
                Steps(count: 2, current: _emailOk ? 2 : 1),
                const SizedBox(height: 18),

                // ── Step 1: Email ──
                _SectionCard(
                  icon: Icons.mail_outline,
                  title: 'Correo electrónico',
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _email,
                          readOnly: _emailOk || _fromGoogle,
                          keyboardType: TextInputType.emailAddress,
                          cursorColor: ec.orange,
                          style: EnjoyTheme.body(size: 14, color: ec.text),
                          decoration: const InputDecoration(
                            hintText: 'email@ejemplo.com',
                            prefixIcon: Icon(Icons.alternate_email, size: 20),
                          ),
                        ),
                      ),
                      if (!_fromGoogle) const SizedBox(width: 10),
                      if (!_fromGoogle)
                        EnjoyButton(
                          label: _emailOk ? 'Validado' : 'Verificar',
                          icon: _emailOk ? Icons.check : Icons.send,
                          variant: _emailOk
                              ? EnjoyButtonVariant.green
                              : EnjoyButtonVariant.orange,
                          expand: false,
                          dense: true,
                          loading: _loading && !_emailOk,
                          onPressed:
                              _loading || _emailOk ? null : _checkEmail,
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Step 2: Datos (bloqueado si no validó email) ──
                IgnorePointer(
                  ignoring: !_emailOk,
                  child: AnimatedOpacity(
                    opacity: _emailOk ? 1 : 0.45,
                    duration: const Duration(milliseconds: 200),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Datos personales
                          _SectionCard(
                            icon: Icons.person_outline,
                            title: 'Datos personales',
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _nombres,
                                  validator: _reqMin2,
                                  cursorColor: ec.orange,
                                  style:
                                      EnjoyTheme.body(size: 14, color: ec.text),
                                  decoration: const InputDecoration(
                                    hintText: 'Nombres',
                                    prefixIcon:
                                        Icon(Icons.badge_outlined, size: 20),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _apellidos,
                                  validator: _reqMin2,
                                  cursorColor: ec.orange,
                                  style:
                                      EnjoyTheme.body(size: 14, color: ec.text),
                                  decoration: const InputDecoration(
                                    hintText: 'Apellidos',
                                    prefixIcon:
                                        Icon(Icons.badge_outlined, size: 20),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _telefono,
                                  keyboardType: TextInputType.phone,
                                  cursorColor: ec.orange,
                                  style:
                                      EnjoyTheme.body(size: 14, color: ec.text),
                                  decoration: const InputDecoration(
                                    hintText: 'Teléfono (opcional)',
                                    prefixIcon:
                                        Icon(Icons.phone_outlined, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Ubicación (provincia + ciudad) — opcional pero
                          // recomendado para recibir notificaciones locales.
                          _SectionCard(
                            icon: Icons.place_outlined,
                            title: 'Ubicación',
                            child: Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: EnjoyButton(
                                    label: _gpsLoading
                                        ? 'Detectando…'
                                        : 'Usar mi ubicación',
                                    icon: Icons.my_location_rounded,
                                    variant: EnjoyButtonVariant.ghost,
                                    loading: _gpsLoading,
                                    onPressed:
                                        _gpsLoading ? null : _usarMiUbicacion,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SearchablePickerField(
                                  label: 'Provincia',
                                  icon: Icons.map_outlined,
                                  value: _provinciaId,
                                  items: _provincias
                                      .map((p) =>
                                          (id: p.id, label: p.nombre))
                                      .toList(),
                                  onChanged: (id) {
                                    setState(() {
                                      _provinciaId = id;
                                      _ciudadId = null;
                                      _ciudades = [];
                                    });
                                    if (id != null) _cargarCiudades(id);
                                  },
                                ),
                                const SizedBox(height: 10),
                                SearchablePickerField(
                                  label: 'Ciudad',
                                  icon: Icons.location_city_rounded,
                                  value: _ciudadId,
                                  items: _ciudades
                                      .map((c) =>
                                          (id: c.id, label: c.nombre))
                                      .toList(),
                                  onChanged: (id) =>
                                      setState(() => _ciudadId = id),
                                ),
                                if (_provinciaId == null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Opcional pero recomendado — te ayuda a recibir promociones de tu zona.',
                                    style: EnjoyTheme.body(
                                        size: 11.5, color: ec.textMute),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Identificación
                          _SectionCard(
                            icon: Icons.credit_card,
                            title: 'Identificación',
                            child: Column(
                              children: [
                                DropdownButtonFormField<TipoIdentificacion>(
                                  initialValue: _tipo,
                                  decoration: const InputDecoration(
                                    hintText: 'Tipo',
                                  ),
                                  dropdownColor: ec.surfaceMid,
                                  style:
                                      EnjoyTheme.body(size: 14, color: ec.text),
                                  items: TipoIdentificacion.values
                                      .map((t) => DropdownMenuItem(
                                            value: t,
                                            child: Text(t.name,
                                                style: EnjoyTheme.body(
                                                    size: 14, color: ec.text)),
                                          ))
                                      .toList(),
                                  onChanged: (v) => setState(() =>
                                      _tipo = v ?? TipoIdentificacion.CEDULA),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _identificacion,
                                  validator: _reqNotEmpty,
                                  cursorColor: ec.orange,
                                  style:
                                      EnjoyTheme.body(size: 14, color: ec.text),
                                  decoration: InputDecoration(
                                    hintText: _tipo == TipoIdentificacion.RUC
                                        ? 'RUC'
                                        : 'Cédula / Pasaporte',
                                    prefixIcon:
                                        const Icon(Icons.fingerprint, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Contraseña (solo registro con clave; las cuentas
                          // por redes sociales se crean sin clave).
                          if (!_fromGoogle) ...[
                            _SectionCard(
                              icon: Icons.lock_outline,
                              title: 'Contraseña',
                              child: TextFormField(
                                controller: _password,
                                validator: _pwdVal,
                                obscureText: _obscure,
                                cursorColor: ec.orange,
                                style:
                                    EnjoyTheme.body(size: 14, color: ec.text),
                                decoration: InputDecoration(
                                  hintText: 'Mínimo 6 caracteres',
                                  prefixIcon:
                                      const Icon(Icons.lock_outline, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: ec.textMute,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // ── Términos y condiciones ──
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _aceptaTerminos,
                                  onChanged: (v) => setState(
                                      () => _aceptaTerminos = v ?? false),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => launchUrl(
                                    Uri.parse(
                                        'https://portal.ecuenjoy.com/privacy-policy'),
                                    mode: LaunchMode.externalApplication,
                                  ),
                                  child: Text.rich(
                                    TextSpan(
                                      text: 'Acepto los ',
                                      style: EnjoyTheme.body(
                                          size: 13, color: ec.textMute),
                                      children: [
                                        TextSpan(
                                          text: 'Términos y Condiciones',
                                          style: EnjoyTheme.body(
                                            size: 13,
                                            weight: FontWeight.w600,
                                            color: ec.orangeSoft,
                                          ).copyWith(
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor: ec.orangeSoft,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // ── Botón submit ──
                          EnjoyButton(
                            label: _loading ? 'Creando…' : 'Crear cuenta',
                            icon: Icons.check,
                            loading: _loading,
                            onPressed:
                                (_loading || !_emailOk || !_aceptaTerminos)
                                    ? null
                                    : _submit,
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────── Section card reusable
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBox(icon, size: 32, radius: 9, iconSize: 16),
              const SizedBox(width: 10),
              Text(
                title,
                style: EnjoyTheme.heading(
                    size: 14, weight: FontWeight.w600, color: ec.text),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
