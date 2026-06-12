import 'package:enjoy/services/usuarios_empresa_service.dart';
import 'package:enjoy/ui/enjoy.dart';
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
        SnackBar(content: Text(msg), backgroundColor: context.ec.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: EnjoyAppBar(title: _isEdit ? 'Editar empleado' : 'Nuevo empleado'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          children: [
            FieldLabel(_isEdit ? 'Datos del empleado' : 'Información personal'),

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

            FieldLabel(
              _isEdit
                  ? 'Nueva contraseña (dejar vacío para no cambiar)'
                  : 'Contraseña',
            ),

            _Field(
              controller: _clave,
              label: _isEdit ? 'Nueva contraseña' : 'Contraseña',
              icon: Icons.lock_outline_rounded,
              obscure: _obscureClave,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureClave ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: ec.textMute,
                  size: 20,
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
              FieldLabel('Estado de la cuenta'),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _estado ? 'Activo' : 'Inactivo',
                            style: EnjoyTheme.heading(
                                size: 14,
                                weight: FontWeight.w600,
                                color: _estado ? ec.text : ec.textMute),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _estado
                                ? 'El empleado puede iniciar sesión'
                                : 'Cuenta desactivada',
                            style: EnjoyTheme.body(size: 12, color: ec.textMute),
                          ),
                        ],
                      ),
                    ),
                    EnjoyToggle(
                      value: _estado,
                      onChanged: (v) => setState(() => _estado = v),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            EnjoyButton(
              label: _isEdit ? 'Guardar cambios' : 'Crear empleado',
              loading: _saving,
              onPressed: _saving ? null : _guardar,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets privados ──────────────────────────────────────────────────────────

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
    final ec = context.ec;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      cursorColor: ec.orange,
      style: EnjoyTheme.body(size: 14, color: ec.text),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, color: ec.orangeSoft, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
