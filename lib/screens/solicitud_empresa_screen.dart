import 'package:flutter/material.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:go_router/go_router.dart';
import 'package:enjoy/services/registration_api.dart';
import 'package:enjoy/widgets/branded_modal.dart';
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
      if (!mounted) return;
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
    final ec = context.ec;
    return EnjoyScaffold(
      appBar: const EnjoyAppBar(title: 'Solicitar acceso'),
      padding: EdgeInsets.zero,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // ── Header destacado ──
                  GlassCard(
                    accent: true,
                    child: Row(
                      children: [
                        IconBox(Icons.handshake_outlined,
                            accent: true, size: 40, radius: 11, iconSize: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Déjanos tus datos y te contactaremos',
                            style: EnjoyTheme.heading(
                                size: 15,
                                weight: FontWeight.w600,
                                color: ec.text),
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
                        cursorColor: ec.orange,
                        style: EnjoyTheme.body(size: 14, color: ec.text),
                        decoration: const InputDecoration(
                          hintText: 'Nombre del negocio',
                          prefixIcon: Icon(Icons.store_outlined, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ruc,
                        cursorColor: ec.orange,
                        style: EnjoyTheme.body(size: 14, color: ec.text),
                        decoration: const InputDecoration(
                          hintText: 'RUC (opcional)',
                          prefixIcon: Icon(Icons.numbers_outlined, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ciudad,
                        validator: _req,
                        cursorColor: ec.orange,
                        style: EnjoyTheme.body(size: 14, color: ec.text),
                        decoration: const InputDecoration(
                          hintText: 'Ciudad',
                          prefixIcon:
                              Icon(Icons.location_city_outlined, size: 20),
                        ),
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
                        cursorColor: ec.orange,
                        style: EnjoyTheme.body(size: 14, color: ec.text),
                        decoration: const InputDecoration(
                          hintText: 'Nombre y apellido',
                          prefixIcon: Icon(Icons.person_outline, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _email,
                        validator: _emailVal,
                        keyboardType: TextInputType.emailAddress,
                        cursorColor: ec.orange,
                        style: EnjoyTheme.body(size: 14, color: ec.text),
                        decoration: const InputDecoration(
                          hintText: 'Email',
                          prefixIcon: Icon(Icons.alternate_email, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _telefono,
                        validator: _req,
                        keyboardType: TextInputType.phone,
                        cursorColor: ec.orange,
                        style: EnjoyTheme.body(size: 14, color: ec.text),
                        decoration: const InputDecoration(
                          hintText: 'Teléfono',
                          prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        ),
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
                      cursorColor: ec.orange,
                      style: EnjoyTheme.body(size: 14, color: ec.text),
                      decoration: const InputDecoration(
                        hintText: 'Cuéntanos sobre tu negocio...',
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Términos y condiciones ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      EnjoyToggle(
                        value: _aceptaTerminos,
                        onChanged: (v) =>
                            setState(() => _aceptaTerminos = v),
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
                                    decoration: TextDecoration.underline,
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

                  // ── Submit ──
                  EnjoyButton(
                    label: _loading ? 'Enviando…' : 'Enviar solicitud',
                    icon: Icons.send,
                    loading: _loading,
                    onPressed:
                        (_loading || !_aceptaTerminos) ? null : _enviar,
                  ),

                  const SizedBox(height: 20),
                ],
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
    final ec = context.ec;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            IconBox(icon, size: 32, radius: 9, iconSize: 16),
            const SizedBox(width: 10),
            Text(title,
                style: EnjoyTheme.heading(
                    size: 14, weight: FontWeight.w600, color: ec.text)),
          ]),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
