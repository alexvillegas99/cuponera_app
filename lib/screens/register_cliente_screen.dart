// lib/screens/auth/register_cliente_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:enjoy/services/registration_api.dart';
import 'package:enjoy/widgets/pill_field.dart';

enum TipoIdentificacion { CEDULA, RUC, PASAPORTE }

class RegisterClienteScreen extends StatefulWidget {
  const RegisterClienteScreen({super.key});

  @override
  State<RegisterClienteScreen> createState() => _RegisterClienteScreenState();
}

class _RegisterClienteScreenState extends State<RegisterClienteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = RegistrationApi();

  // Paleta
  final Color _bg = const Color(0xFFF6F9FF);
  final Color _primary = const Color(0xFF2E6BE6);
  final Color _text = const Color(0xFF111827);
  final Color _muted = const Color(0xFF6B7280);

  // Controllers
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _identificacion = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _telefono = TextEditingController();
  final _direccion = TextEditingController();
  DateTime? _fechaNac;
  TipoIdentificacion _tipo = TipoIdentificacion.CEDULA;

  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _nombres.dispose();
    _apellidos.dispose();
    _identificacion.dispose();
    _email.dispose();
    _password.dispose();
    _telefono.dispose();
    _direccion.dispose();
    super.dispose();
  }

  String get _fechaLabel =>
      _fechaNac == null ? 'Selecciona fecha' : '${_fechaNac!.day.toString().padLeft(2, '0')}/${_fechaNac!.month.toString().padLeft(2, '0')}/${_fechaNac!.year}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _fechaNac = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final dto = {
      "nombres": _nombres.text.trim(),
      "apellidos": _apellidos.text.trim(),
      "tipoIdentificacion": _tipo.name,
      "identificacion": _identificacion.text.trim(),
      "email": _email.text.trim(),
      "password": _password.text, // se hashea en el backend
      "telefono": _telefono.text.trim().isEmpty ? null : _telefono.text.trim(),
      "direccion": _direccion.text.trim().isEmpty ? null : _direccion.text.trim(),
      "fechaNacimiento": _fechaNac?.toIso8601String(),
    };

    try {
      await _api.crearCliente(dto);
      if (!mounted) return;
      await _ok('Cuenta creada', 'Tu cuenta ha sido registrada. Ahora puedes iniciar sesión.');
      context.pop(); // volver al login
    } catch (e) {
      _error('No se pudo registrar', e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ok(String t, String m) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t),
        content: Text(m),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  void _error(String t, String m) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t),
        content: Text(m),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
      ),
    );
  }

  String? _reqMin2(String? v) => (v == null || v.trim().length < 2) ? 'Requerido (mín. 2 caracteres)' : null;
  String? _reqNotEmpty(String? v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null;
  String? _emailVal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Requerido';
    final rx = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return rx.hasMatch(v.trim()) ? null : 'Email inválido';
  }
  String? _pwdVal(String? v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: _text,
        title: const Text('Registro de Cliente'),
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
                    Text('Completa tus datos', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),

                    // Nombres / Apellidos
                    Text('Nombres', style: TextStyle(color: _muted)),
                    const SizedBox(height: 8),
                    PillField(hint: 'Tus nombres', controller: _nombres, icon: Icons.badge_outlined, validator: _reqMin2),
                    const SizedBox(height: 16),

                    Text('Apellidos', style: TextStyle(color: _muted)),
                    const SizedBox(height: 8),
                    PillField(hint: 'Tus apellidos', controller: _apellidos, icon: Icons.badge_outlined, validator: _reqMin2),
                    const SizedBox(height: 16),

                    // Tipo + Identificación
                    Text('Tipo de identificación', style: TextStyle(color: _muted)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9E6FF),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: DropdownButtonFormField<TipoIdentificacion>(
                        value: _tipo,
                        decoration: const InputDecoration(border: InputBorder.none),
                        items: TipoIdentificacion.values
                            .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                            .toList(),
                        onChanged: (v) => setState(() => _tipo = v ?? TipoIdentificacion.CEDULA),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text('Identificación', style: TextStyle(color: _muted)),
                    const SizedBox(height: 8),
                    PillField(
                      hint: _tipo == TipoIdentificacion.RUC ? 'RUC' : 'Cédula / Pasaporte',
                      controller: _identificacion,
                      icon: Icons.credit_card,
                      keyboardType: TextInputType.text,
                      validator: _reqNotEmpty,
                    ),
                    const SizedBox(height: 16),

                    // Email / Password
                    Text('Email', style: TextStyle(color: _muted)),
                    const SizedBox(height: 8),
                    PillField(
                      hint: 'email@ejemplo.com',
                      controller: _email,
                      icon: Icons.alternate_email,
                      keyboardType: TextInputType.emailAddress,
                      validator: _emailVal,
                    ),
                    const SizedBox(height: 16),

                    Text('Contraseña', style: TextStyle(color: _muted)),
                    const SizedBox(height: 8),
                    PillField(
                      hint: 'Mínimo 6 caracteres',
                      controller: _password,
                      icon: Icons.lock_outline,
                      obscure: _obscure,
                      onToggleObscure: () => setState(() => _obscure = !_obscure),
                      validator: _pwdVal,
                    ),
                    const SizedBox(height: 16),

                    // Teléfono / Dirección / Fecha (opcionales)
                    Text('Teléfono (opcional)', style: TextStyle(color: _muted)),
                    const SizedBox(height: 8),
                    PillField(
                      hint: '+593...',
                      controller: _telefono,
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    Text('Dirección (opcional)', style: TextStyle(color: _muted)),
                    const SizedBox(height: 8),
                    PillField(
                      hint: 'Av. Siempre Viva 123',
                      controller: _direccion,
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 16),

                    Text('Fecha de nacimiento (opcional)', style: TextStyle(color: _muted)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9E6FF),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.cake_outlined, color: Color(0xFF6B7280)),
                            const SizedBox(width: 10),
                            Text(_fechaLabel, style: TextStyle(color: _text)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Botón registrar
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                        child: _loading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Crear cuenta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
