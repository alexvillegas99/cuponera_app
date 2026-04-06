import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:enjoy/services/registration_api.dart';
import 'package:enjoy/widgets/branded_modal.dart';
import 'package:enjoy/ui/palette.dart';
import 'package:url_launcher/url_launcher.dart';

class SolicitudEmpresaScreen extends StatefulWidget {
  const SolicitudEmpresaScreen({super.key});

  @override
  State<SolicitudEmpresaScreen> createState() => _SolicitudEmpresaScreenState();
}

class _SolicitudEmpresaScreenState extends State<SolicitudEmpresaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = RegistrationApi();

  final _empresa = TextEditingController();
  final _ruc = TextEditingController();
  final _contacto = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();
  final _ciudad = TextEditingController();
  final _mensaje = TextEditingController();

  bool _loading = false;
  bool _aceptaTerminos = false;

  @override
  void dispose() {
    _empresa.dispose();
    _ruc.dispose();
    _contacto.dispose();
    _email.dispose();
    _telefono.dispose();
    _ciudad.dispose();
    _mensaje.dispose();
    super.dispose();
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null;

  String? _emailVal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Requerido';
    final rx = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return rx.hasMatch(v.trim()) ? null : 'Email inválido';
  }

  InputDecoration _inputDec(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Palette.kMuted, fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, color: Palette.kMuted, size: 20) : null,
      filled: true,
      fillColor: Palette.kBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.kAccent, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
    );
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

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_aceptaTerminos) {
      _snack('Debes aceptar los Términos y Condiciones.');
      return;
    }

    setState(() => _loading = true);

    final dto = {
      "empresa": _empresa.text.trim(),
      "ruc": _ruc.text.trim().isEmpty ? null : _ruc.text.trim(),
      "contacto": _contacto.text.trim(),
      "email": _email.text.trim(),
      "telefono": _telefono.text.trim(),
      "ciudad": _ciudad.text.trim(),
      "mensaje": _mensaje.text.trim().isEmpty ? null : _mensaje.text.trim(),
      "origen": "ENJOY_APP",
    };

    try {
      await _api.enviarSolicitudEmpresa(dto);
      if (!mounted) return;
      await showBrandedDialog(context,
        title: 'Solicitud enviada',
        message: 'Nos pondremos en contacto contigo muy pronto.',
        icon: Icons.check_circle_outline,
      );
      context.pop();
    } catch (e) {
      await showBrandedDialog(context,
        title: 'No se pudo enviar',
        message: e.toString(),
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        backgroundColor: Palette.kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Solicitar acceso', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ── Header ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Palette.kPrimary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.handshake_outlined, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Déjanos tus datos y te contactaremos',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Negocio ──
                    _Section(
                      icon: Icons.store_outlined,
                      title: 'Datos del negocio',
                      child: Column(children: [
                        TextFormField(
                          controller: _empresa,
                          validator: _req,
                          cursorColor: Palette.kAccent,
                          style: const TextStyle(color: Palette.kTitle, fontSize: 14),
                          decoration: _inputDec('Nombre del negocio', icon: Icons.store_outlined),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _ruc,
                          cursorColor: Palette.kAccent,
                          style: const TextStyle(color: Palette.kTitle, fontSize: 14),
                          decoration: _inputDec('RUC (opcional)', icon: Icons.numbers_outlined),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _ciudad,
                          validator: _req,
                          cursorColor: Palette.kAccent,
                          style: const TextStyle(color: Palette.kTitle, fontSize: 14),
                          decoration: _inputDec('Ciudad', icon: Icons.location_city_outlined),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 16),

                    // ── Contacto ──
                    _Section(
                      icon: Icons.person_outline,
                      title: 'Persona de contacto',
                      child: Column(children: [
                        TextFormField(
                          controller: _contacto,
                          validator: _req,
                          cursorColor: Palette.kAccent,
                          style: const TextStyle(color: Palette.kTitle, fontSize: 14),
                          decoration: _inputDec('Nombre y apellido', icon: Icons.person_outline),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _email,
                          validator: _emailVal,
                          keyboardType: TextInputType.emailAddress,
                          cursorColor: Palette.kAccent,
                          style: const TextStyle(color: Palette.kTitle, fontSize: 14),
                          decoration: _inputDec('Email', icon: Icons.alternate_email),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _telefono,
                          validator: _req,
                          keyboardType: TextInputType.phone,
                          cursorColor: Palette.kAccent,
                          style: const TextStyle(color: Palette.kTitle, fontSize: 14),
                          decoration: _inputDec('Teléfono', icon: Icons.phone_outlined),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 16),

                    // ── Mensaje ──
                    _Section(
                      icon: Icons.chat_bubble_outline,
                      title: 'Mensaje (opcional)',
                      child: TextFormField(
                        controller: _mensaje,
                        maxLines: 3,
                        cursorColor: Palette.kAccent,
                        style: const TextStyle(color: Palette.kTitle, fontSize: 14),
                        decoration: _inputDec('Cuéntanos sobre tu negocio...'),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Términos y condiciones ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _aceptaTerminos,
                            onChanged: (v) => setState(() => _aceptaTerminos = v ?? false),
                            activeColor: Palette.kAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => launchUrl(
                              Uri.parse('https://portal.ecuenjoy.com/privacy-policy'),
                              mode: LaunchMode.externalApplication,
                            ),
                            child: Text.rich(
                              TextSpan(
                                text: 'Acepto los ',
                                style: const TextStyle(color: Palette.kMuted, fontSize: 13),
                                children: [
                                  TextSpan(
                                    text: 'Términos y Condiciones',
                                    style: TextStyle(
                                      color: Palette.kAccent,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Palette.kAccent,
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

                    // ── Submit ──
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: (_loading || !_aceptaTerminos) ? null : _enviar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Palette.kAccent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Palette.kAccent.withOpacity(0.5),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send, size: 18),
                        label: Text(
                          _loading ? 'Enviando…' : 'Enviar solicitud',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _Section({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: Palette.kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: Palette.kAccent),
            ),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(color: Palette.kTitle, fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
