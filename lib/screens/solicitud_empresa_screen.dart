// lib/screens/auth/solicitud_empresa_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:enjoy/services/registration_api.dart';
import 'package:enjoy/widgets/pill_field.dart';

class SolicitudEmpresaScreen extends StatefulWidget {
  const SolicitudEmpresaScreen({super.key});

  @override
  State<SolicitudEmpresaScreen> createState() => _SolicitudEmpresaScreenState();
}

class _SolicitudEmpresaScreenState extends State<SolicitudEmpresaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = RegistrationApi();

  final Color _bg = const Color(0xFFF6F9FF);
  final Color _primary = const Color(0xFF2E6BE6);
  final Color _text = const Color(0xFF111827);
  final Color _muted = const Color(0xFF6B7280);

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

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null;
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
      "origen": "ENJOY_APP", // puedes usarlo para segmentar
    };

    try {
      await _api.enviarSolicitudEmpresa(dto);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Solicitud enviada'),
          content: const Text('Nos pondremos en contacto contigo muy pronto.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      context.pop(); // volver
    } catch (e) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('No se pudo enviar'),
          content: Text(e.toString()),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: _text,
        title: const Text('Quiero ser parte de Enjoy'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Déjanos tus datos y te contactaremos',
                        style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),

                    Text('Nombre del negocio', style: TextStyle(color: _muted)),
                    const SizedBox(height: 8),
                    PillField(hint: 'Mi Restaurante S.A.', controller: _empresa, icon: Icons.store_outlined, validator: _req),
                    const SizedBox(height: 16),

                    Text('RUC (opcional)', style: TextStyle(color: _muted)),
                    const SizedBox(height: 8),
                    PillField(hint: '1234567890001', controller: _ruc, icon: Icons.numbers_outlined),
                    const SizedBox(height: 16),

                    Text('Persona de contacto', style: TextStyle(color: _muted)),
                    const SizedBox(height: 8),
                    PillField(hint: 'Nombre y apellido', controller: _contacto, icon: Icons.person_outline, validator: _req),
                    const SizedBox(height: 16),

                    Text('Email', style: TextStyle(color: _muted)),
                    const SizedBox(height: 8),
                    PillField(
                      hint: 'empresa@correo.com',
                      controller: _email,
                      icon: Icons.alternate_email,
                      keyboardType: TextInputType.emailAddress,
                      validator: _emailVal,
                    ),
                    const SizedBox(height: 16),

                    Text('Teléfono', style: TextStyle(color: _muted)),
                    const SizedBox(height: 8),
                    PillField(
                      hint: '+593...',
                      controller: _telefono,
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: _req,
                    ),
                    const SizedBox(height: 16),

                    Text('Ciudad', style: TextStyle(color: _muted)),
                    const SizedBox(height: 8),
                    PillField(hint: 'Ambato', controller: _ciudad, icon: Icons.location_city_outlined, validator: _req),
                    const SizedBox(height: 16),

                    Text('Mensaje (opcional)', style: TextStyle(color: _muted)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9E6FF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: TextFormField(
                        controller: _mensaje,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Cuéntanos brevemente sobre tu negocio...',
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _enviar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                        child: _loading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Enviar solicitud', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
