// lib/screens/auth/solicitud_empresa_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:enjoy/services/registration_api.dart';
import 'package:enjoy/widgets/pill_field.dart';
import 'package:enjoy/widgets/branded_modal.dart';
import 'package:enjoy/ui/palette.dart';

class SolicitudEmpresaScreen extends StatefulWidget {
  const SolicitudEmpresaScreen({super.key});

  @override
  State<SolicitudEmpresaScreen> createState() => _SolicitudEmpresaScreenState();
}

class _SolicitudEmpresaScreenState extends State<SolicitudEmpresaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = RegistrationApi();

  // Campos
  final _empresa = TextEditingController();
  final _ruc = TextEditingController();
  final _contacto = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();
  final _ciudad = TextEditingController();
  final _mensaje = TextEditingController();

  bool _loading = false;

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

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Requerido' : null;

  String? _emailVal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Requerido';
    final rx = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return rx.hasMatch(v.trim()) ? null : 'Email inválido';
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;

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
      await showBrandedDialog(
        context,
        title: 'Solicitud enviada',
        message: 'Nos pondremos en contacto contigo muy pronto.',
        icon: Icons.check_circle_outline,
      );
      context.pop();
    } catch (e) {
      // Si el backend devuelve 409 (conflict por email duplicado) lo verás como mensaje acá
      await showBrandedDialog(
        context,
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
        backgroundColor: Palette.kBg,
        elevation: 0,
        foregroundColor: Palette.kTitle,
        title: const Text('Quiero ser parte de Enjoy'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header card alineada a la UI global
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Palette.kSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Palette.kBorder),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                            color: Colors.black.withOpacity(0.05),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          // Avatar gradiente
                          _GradientCircleIcon(),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Déjanos tus datos y te contactaremos',
                              style: TextStyle(
                                color: Palette.kTitle,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Nombre del negocio',
                        style: TextStyle(color: Palette.kSub)),
                    const SizedBox(height: 8),
                    PillField(
                      hint: 'Mi Restaurante S.A.',
                      controller: _empresa,
                      icon: Icons.store_outlined,
                      validator: _req,
                    ),
                    const SizedBox(height: 16),

                    const Text('RUC (opcional)',
                        style: TextStyle(color: Palette.kSub)),
                    const SizedBox(height: 8),
                    PillField(
                      hint: '1234567890001',
                      controller: _ruc,
                      icon: Icons.numbers_outlined,
                    ),
                    const SizedBox(height: 16),

                    const Text('Persona de contacto',
                        style: TextStyle(color: Palette.kSub)),
                    const SizedBox(height: 8),
                    PillField(
                      hint: 'Nombre y apellido',
                      controller: _contacto,
                      icon: Icons.person_outline,
                      validator: _req,
                    ),
                    const SizedBox(height: 16),

                    const Text('Email', style: TextStyle(color: Palette.kSub)),
                    const SizedBox(height: 8),
                    PillField(
                      hint: 'empresa@correo.com',
                      controller: _email,
                      icon: Icons.alternate_email,
                      keyboardType: TextInputType.emailAddress,
                      validator: _emailVal,
                    ),
                    const SizedBox(height: 16),

                    const Text('Teléfono',
                        style: TextStyle(color: Palette.kSub)),
                    const SizedBox(height: 8),
                    PillField(
                      hint: '+593...',
                      controller: _telefono,
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: _req,
                    ),
                    const SizedBox(height: 16),

                    const Text('Ciudad', style: TextStyle(color: Palette.kSub)),
                    const SizedBox(height: 8),
                    PillField(
                      hint: 'Ambato',
                      controller: _ciudad,
                      icon: Icons.location_city_outlined,
                      validator: _req,
                    ),
                    const SizedBox(height: 16),

                    const Text('Mensaje (opcional)',
                        style: TextStyle(color: Palette.kSub)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Palette.kField,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Palette.kBorder),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      child: TextFormField(
                        controller: _mensaje,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText:
                              'Cuéntanos brevemente sobre tu negocio...',
                          hintStyle: TextStyle(color: Palette.kMuted),
                        ),
                        style: const TextStyle(color: Palette.kTitle),
                      ),
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Palette.kPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _loading ? null : _enviar,
                        icon: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded,
                                color: Colors.white),
                        label: Text(
                          _loading ? 'Enviando…' : 'Enviar solicitud',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800),
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

class _GradientCircleIcon extends StatelessWidget {
  const _GradientCircleIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      width: 46,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Palette.kPrimary, Palette.kAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.handshake_outlined, color: Colors.white),
    );
  }
}
