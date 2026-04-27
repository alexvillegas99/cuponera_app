import 'package:enjoy/services/usuarios_empresa_service.dart';
import 'package:enjoy/ui/palette.dart';
import 'package:flutter/material.dart';

/// Pantalla de creación / edición de un empleado (staff).
/// - Si [empleado] es null → modo crear.
/// - Si [empleado] no es null → modo editar.
class EmpleadoFormScreen extends StatefulWidget {
  final String localId;
  final Map<String, dynamic>? empleado;

  const EmpleadoFormScreen({
    super.key,
    required this.localId,
    this.empleado,
  });

  @override
  State<EmpleadoFormScreen> createState() => _EmpleadoFormScreenState();
}

class _EmpleadoFormScreenState extends State<EmpleadoFormScreen> {
  final _svc = UsuariosEmpresaService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombre;
  late final TextEditingController _email;
  late final TextEditingController _identificacion;
  late final TextEditingController _clave;

  bool _estado = true;
  bool _saving = false;
  bool _obscureClave = true;

  bool get _isEdit => widget.empleado != null;

  @override
  void initState() {
    super.initState();
    final e = widget.empleado;
    _nombre = TextEditingController(text: (e?['nombre'] ?? '').toString());
    _email = TextEditingController(text: (e?['email'] ?? e?['correo'] ?? '').toString());
    _identificacion = TextEditingController(text: (e?['identificacion'] ?? '').toString());
    _clave = TextEditingController();
    _estado = e?['estado'] != false;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _identificacion.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        final data = <String, dynamic>{
          'nombre': _nombre.text.trim(),
          'estado': _estado,
        };
        if (_clave.text.isNotEmpty) data['clave'] = _clave.text;
        await _svc.actualizar(widget.empleado!['_id'].toString(), data);
      } else {
        await _svc.crearParaLocal(widget.localId, {
          'nombre': _nombre.text.trim(),
          'email': _email.text.trim().toLowerCase(),
          'identificacion': _identificacion.text.trim(),
          'clave': _clave.text,
          'ciudades': [],
          'categorias': [],
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        backgroundColor: Palette.kSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Palette.kTitle),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEdit ? 'Editar empleado' : 'Nuevo empleado',
          style: const TextStyle(
            color: Palette.kTitle,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: Palette.kSurface,
            border: Border(bottom: BorderSide(color: Palette.kBorder)),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionLabel(label: _isEdit ? 'Datos del empleado' : 'Información personal'),
            const SizedBox(height: 12),

            _Field(
              controller: _nombre,
              label: 'Nombre completo',
              icon: Icons.person_outline_rounded,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),

            if (!_isEdit) ...[
              _Field(
                controller: _email,
                label: 'Correo electrónico',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requerido';
                  if (!v.contains('@')) return 'Email inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _identificacion,
                label: 'Identificación',
                icon: Icons.badge_outlined,
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 20),
            ],

            _SectionLabel(
              label: _isEdit
                  ? 'Nueva contraseña (dejar vacío para no cambiar)'
                  : 'Contraseña',
            ),
            const SizedBox(height: 12),

            _Field(
              controller: _clave,
              label: _isEdit ? 'Nueva contraseña' : 'Contraseña',
              icon: Icons.lock_outline_rounded,
              obscure: _obscureClave,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureClave ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: Palette.kMuted,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscureClave = !_obscureClave),
              ),
              validator: _isEdit
                  ? (v) => (v != null && v.isNotEmpty && v.length < 6)
                      ? 'Mínimo 6 caracteres'
                      : null
                  : (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      if (v.length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    },
            ),

            if (_isEdit) ...[
              const SizedBox(height: 20),
              const _SectionLabel(label: 'Estado de la cuenta'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Palette.kSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Palette.kBorder),
                ),
                child: SwitchListTile(
                  title: Text(
                    _estado ? 'Activo' : 'Inactivo',
                    style: TextStyle(
                      color: _estado ? Palette.kTitle : Palette.kMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    _estado
                        ? 'El empleado puede iniciar sesión'
                        : 'Cuenta desactivada',
                    style: const TextStyle(color: Palette.kMuted, fontSize: 12),
                  ),
                  value: _estado,
                  onChanged: (v) => setState(() => _estado = v),
                  activeColor: Palette.kAccent,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                ),
              ),
            ],

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.kAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  disabledBackgroundColor: Palette.kAccent.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isEdit ? 'Guardar cambios' : 'Crear empleado',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets privados ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: Palette.kMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(color: Palette.kTitle, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Palette.kMuted, fontSize: 14),
        prefixIcon: Icon(icon, color: Palette.kMuted, size: 18),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Palette.kField,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Palette.kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Palette.kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Palette.kAccent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
