import 'package:enjoy/services/core/api_client.dart';
import 'package:enjoy/services/usuarios_empresa_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';

class UsuariosAdminScreen extends StatefulWidget {
  const UsuariosAdminScreen({super.key});

  @override
  State<UsuariosAdminScreen> createState() => _UsuariosAdminScreenState();
}

class _UsuariosAdminScreenState extends State<UsuariosAdminScreen> {
  final _svc = UsuariosEmpresaService();

  List<Map<String, dynamic>> _usuarios = [];
  bool _loading = true;
  String? _error;
  String _busqueda = '';
  String? _filtroRol;

  List<({String slug, String label})> _rolesLista = [];

  static const _rolesFallback = [
    (slug: 'staff', label: 'Staff'),
    (slug: 'admin-local', label: 'Admin Local'),
    (slug: 'admin', label: 'Administrador'),
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
    _cargarRoles();
  }

  Future<void> _cargarRoles() async {
    try {
      final resp = await ApiClient.instance.get('/roles');
      final data = resp.data;
      List<dynamic> lista = data is List ? data : (data is Map ? (data['items'] ?? data['data'] ?? data['roles'] ?? []) as List : []);
      final roles = lista
          .where((r) => r is Map && r['estado'] != false)
          .map<({String slug, String label})>((r) {
            final slug = (r['slug'] ?? r['nombre'] ?? '').toString();
            final label = (r['nombre'] ?? slug).toString();
            return (slug: slug, label: label);
          })
          .where((r) => r.slug.isNotEmpty)
          .toList();
      if (mounted) setState(() => _rolesLista = roles.isNotEmpty ? roles : List.from(_rolesFallback));
    } catch (_) {
      if (mounted) setState(() => _rolesLista = List.from(_rolesFallback));
    }
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _svc.listarAdmin();
      if (mounted) setState(() { _usuarios = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'No se pudo cargar los usuarios.'; _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtrados {
    return _usuarios.where((u) {
      final nombre = '${u['nombre'] ?? u['nombres'] ?? ''} ${u['apellidos'] ?? ''}'.toLowerCase();
      final correo = (u['correo'] ?? u['email'] ?? '').toString().toLowerCase();
      final rol = (u['rol'] ?? '').toString().toLowerCase();
      final matchText = _busqueda.isEmpty ||
          nombre.contains(_busqueda.toLowerCase()) ||
          correo.contains(_busqueda.toLowerCase());
      final matchRol = _filtroRol == null || rol == _filtroRol;
      return matchText && matchRol;
    }).toList();
  }

  Future<void> _abrirEdicion(Map<String, dynamic> usuario) async {
    final id = usuario['_id']?.toString() ?? '';
    if (id.isEmpty) return;

    final actualizado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditUsuarioSheet(usuario: usuario, svc: _svc),
    );

    if (actualizado == true) _cargar();
  }

  Future<void> _abrirCrear() async {
    final creado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditUsuarioSheet(svc: _svc), // usuario null = crear
    );
    if (creado == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    if (_loading) return Center(child: CircularProgressIndicator(color: ec.orange));
    if (_error != null) return _ErrorState(message: _error!, onRetry: _cargar);

    return Column(
      children: [
        // Búsqueda + Filtro
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _busqueda = v),
                style: EnjoyTheme.body(size: 14, color: ec.text),
                cursorColor: ec.orange,
                decoration: const InputDecoration(
                  hintText: 'Buscar usuario...',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Pill(
                        'Todos',
                        variant: _filtroRol == null ? PillVariant.orange : PillVariant.glass,
                        onTap: () => setState(() => _filtroRol = null),
                      ),
                    ),
                    ..._rolesLista.map((r) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Pill(
                            r.label,
                            variant: _filtroRol == r.slug ? PillVariant.orange : PillVariant.glass,
                            onTap: () => setState(() => _filtroRol = _filtroRol == r.slug ? null : r.slug),
                          ),
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Contador + Agregar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                '${_filtrados.length} usuario${_filtrados.length != 1 ? 's' : ''}',
                style: EnjoyTheme.body(size: 12, weight: FontWeight.w500, color: ec.textMute),
              ),
              const Spacer(),
              Pill(
                'Agregar',
                icon: Icons.person_add_alt_1_rounded,
                variant: PillVariant.orange,
                onTap: _abrirCrear,
              ),
            ],
          ),
        ),

        // Lista
        Expanded(
          child: _filtrados.isEmpty
              ? const _EmptyState(
                  icon: Icons.manage_accounts_outlined,
                  titulo: 'Sin usuarios',
                  subtitulo: 'No se encontraron usuarios con ese filtro.',
                )
              : RefreshIndicator(
                  color: ec.orange,
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: _filtrados.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _UsuarioCard(
                      usuario: _filtrados[i],
                      onTap: () => _abrirEdicion(_filtrados[i]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

}

// ── Helpers de rol (compartidos) ─────────────────────────────────────────────

String _rolLabel(String rol) {
  switch (rol.toLowerCase()) {
    case 'admin-local': return 'Admin Local';
    case 'admin': return 'Admin';
    case 'staff': return 'Staff';
    default: return rol.isEmpty ? 'Sin rol' : rol;
  }
}

/// Variante de pill según el rol.
PillVariant _rolPill(String rol) {
  switch (rol.toLowerCase()) {
    case 'admin': return PillVariant.orange;
    case 'admin-local': return PillVariant.blue;
    default: return PillVariant.glass;
  }
}

// ── Card de usuario ─────────────────────────────────────────────────────────

class _UsuarioCard extends StatelessWidget {
  final Map<String, dynamic> usuario;
  final VoidCallback onTap;
  const _UsuarioCard({required this.usuario, required this.onTap});

  String get _nombre {
    final n = (usuario['nombre'] ?? usuario['nombres'] ?? '').toString().trim();
    final a = (usuario['apellidos'] ?? '').toString().trim();
    final full = [n, a].where((s) => s.isNotEmpty).join(' ');
    return full.isEmpty ? 'Sin nombre' : full;
  }

  String get _correo => (usuario['correo'] ?? usuario['email'] ?? '—').toString();
  String get _rol => (usuario['rol'] ?? '').toString();
  bool get _activo => usuario['estado'] != false;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          EnjoyAvatar(_nombre, size: 48, radius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_nombre,
                    style: EnjoyTheme.heading(size: 14, color: ec.text),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(_correo,
                    style: EnjoyTheme.body(size: 12, color: ec.textMute),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Pill(_rolLabel(_rol), variant: _rolPill(_rol), dense: true),
                    const SizedBox(width: 6),
                    Pill(
                      _activo ? 'Activo' : 'Inactivo',
                      variant: _activo ? PillVariant.green : PillVariant.red,
                      dense: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: ec.textMute, size: 22),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET DE EDICIÓN DE USUARIO
// ══════════════════════════════════════════════════════════════════════════════

class _EditUsuarioSheet extends StatefulWidget {
  final Map<String, dynamic>? usuario; // null = crear
  final UsuariosEmpresaService svc;
  const _EditUsuarioSheet({this.usuario, required this.svc});

  @override
  State<_EditUsuarioSheet> createState() => _EditUsuarioSheetState();
}

class _EditUsuarioSheetState extends State<_EditUsuarioSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nombre;
  late TextEditingController _email;
  late TextEditingController _identificacion;
  late TextEditingController _clave;
  late TextEditingController _confirmarClave;

  late String _rol;
  late bool _estado;
  late Map<String, dynamic> _original;

  bool _saving = false;
  bool _obscureClave = true;
  bool _obscureConfirmar = true;

  bool get _isCreate => widget.usuario == null;

  List<({String slug, String label})> _rolesDisponibles = [];
  bool _rolesLoading = true;

  static const _rolesFallback = [
    (slug: 'staff', label: 'Staff'),
    (slug: 'admin-local', label: 'Admin Local'),
    (slug: 'admin', label: 'Administrador'),
  ];

  @override
  void initState() {
    super.initState();
    _original = widget.usuario != null
        ? Map<String, dynamic>.from(widget.usuario!)
        : <String, dynamic>{};

    _nombre = TextEditingController(text: _original['nombre']?.toString() ?? '');
    _email = TextEditingController(text: (_original['email'] ?? _original['correo'] ?? '').toString());
    _identificacion = TextEditingController(text: _original['identificacion']?.toString() ?? '');
    _clave = TextEditingController();
    _confirmarClave = TextEditingController();
    _rol = (_original['rol'] ?? 'staff').toString();
    _estado = _original['estado'] != false;
    _cargarRoles();
  }

  @override
  void dispose() {
    for (final c in [_nombre, _email, _identificacion, _clave, _confirmarClave]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Cargar roles desde API ────────────────────────────────────────
  Future<void> _cargarRoles() async {
    try {
      final resp = await ApiClient.instance.get('/roles');
      final data = resp.data;
      List<dynamic> lista = [];
      if (data is List) {
        lista = data;
      } else if (data is Map) {
        lista = (data['items'] ?? data['data'] ?? data['roles'] ?? []) as List;
      }
      final roles = lista
          .where((r) => r is Map && r['estado'] != false)
          .map<({String slug, String label})>((r) {
            final slug = (r['slug'] ?? r['nombre'] ?? '').toString();
            final label = (r['nombre'] ?? slug).toString();
            return (slug: slug, label: label);
          })
          .where((r) => r.slug.isNotEmpty)
          .toList();
      if (mounted) {
        setState(() {
          _rolesDisponibles = roles.isNotEmpty ? roles : List.from(_rolesFallback);
          _rolesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _rolesDisponibles = List.from(_rolesFallback);
          _rolesLoading = false;
        });
      }
    }
  }

  // ── Guardar ──────────────────────────────────────────────────────
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    // Validar contraseñas
    if (_clave.text.isNotEmpty && _clave.text != _confirmarClave.text) {
      _snack('Las contraseñas no coinciden');
      return;
    }

    // ── Modo CREAR ──
    if (_isCreate) {
      final nombre = _nombre.text.trim();
      final email = _email.text.trim();
      if (nombre.isEmpty || email.isEmpty) {
        _snack('Nombre y correo son obligatorios');
        return;
      }
      final nuevo = <String, dynamic>{
        'nombre': nombre,
        'email': email,
        if (_identificacion.text.trim().isNotEmpty)
          'identificacion': _identificacion.text.trim(),
        'rol': _rol,
        'estado': _estado,
        if (_clave.text.isNotEmpty) 'clave': _clave.text,
      };
      setState(() => _saving = true);
      try {
        await widget.svc.crear(nuevo);
        if (mounted) {
          _snack('Usuario creado. Se envió la clave por correo si no se definió.',
              success: true);
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) _snack('No se pudo crear el usuario');
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }

    // Delta update: solo campos modificados
    final payload = <String, dynamic>{};

    if (_nombre.text.trim() != (_original['nombre'] ?? '').toString()) {
      payload['nombre'] = _nombre.text.trim();
    }
    final emailActual = (_original['email'] ?? _original['correo'] ?? '').toString();
    if (_email.text.trim() != emailActual) {
      payload['email'] = _email.text.trim();
    }
    if (_identificacion.text.trim() != (_original['identificacion'] ?? '').toString()) {
      payload['identificacion'] = _identificacion.text.trim();
    }
    if (_rol != (_original['rol'] ?? '').toString()) {
      payload['rol'] = _rol;
    }
    if (_estado != (_original['estado'] != false)) {
      payload['estado'] = _estado;
    }
    if (_clave.text.isNotEmpty) {
      payload['clave'] = _clave.text;
    }

    if (payload.isEmpty) {
      _snack('Sin cambios — no se detectaron modificaciones.', info: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final id = _original['_id']?.toString() ?? '';
      await widget.svc.actualizar(id, payload);
      if (mounted) {
        _snack('Usuario actualizado correctamente', success: true);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _snack('Error al guardar los cambios');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool success = false, bool info = false}) {
    final ec = context.ec;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? ec.green : info ? ec.blue : ec.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── UI ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final nombre = (_original['nombre'] ?? 'Usuario').toString();

    return Container(
      decoration: BoxDecoration(
        gradient: ec.surfaceGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: ec.stroke),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(width: 44, height: 5,
                decoration: BoxDecoration(color: ec.strokeStrong, borderRadius: BorderRadius.circular(99))),
          ),

          // Cabecera con avatar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                EnjoyAvatar(nombre, size: 44, radius: 13),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_isCreate ? 'Nuevo usuario' : 'Editar usuario', style: EnjoyTheme.heading(size: 17, weight: FontWeight.w800, color: ec.text)),
                      Text(nombre, style: EnjoyTheme.body(size: 12, color: ec.textMute), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const EnjoyDivider(height: 1),

          // Formulario
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── DATOS GENERALES ───────────────────────────
                    const FieldLabel('Datos generales'),
                    _field(_nombre, 'Nombre', Icons.person_rounded, required: true),
                    _field(_email, 'Correo electrónico', Icons.email_rounded,
                        keyboard: TextInputType.emailAddress, required: true),
                    _field(_identificacion, 'CI / RUC', Icons.badge_rounded,
                        keyboard: TextInputType.number, required: true),

                    // ── ROL ───────────────────────────────────────
                    const SizedBox(height: 4),
                    const FieldLabel('Rol'),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _rolesLoading
                          ? Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: ec.glass,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: ec.stroke),
                              ),
                              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: ec.orange))),
                            )
                          : DropdownButtonFormField<String>(
                              initialValue: _rolesDisponibles.any((r) => r.slug == _rol) ? _rol : null,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.manage_accounts_rounded, size: 20),
                              ),
                              dropdownColor: ec.surfaceTop,
                              style: EnjoyTheme.body(size: 14, color: ec.text),
                              hint: Text('Seleccionar rol', style: EnjoyTheme.body(size: 13, color: ec.textMute)),
                              validator: (v) => (v == null || v.isEmpty) ? 'Selecciona un rol' : null,
                              items: _rolesDisponibles.map((r) {
                                return DropdownMenuItem<String>(
                                  value: r.slug,
                                  child: Text(r.label),
                                );
                              }).toList(),
                              onChanged: (v) { if (v != null) setState(() => _rol = v); },
                            ),
                    ),

                    // ── ESTADO ────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        blur: false,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Usuario activo',
                                      style: EnjoyTheme.heading(size: 14, weight: FontWeight.w600, color: ec.text)),
                                  const SizedBox(height: 2),
                                  Text(_estado ? 'Puede iniciar sesión' : 'Acceso bloqueado',
                                      style: EnjoyTheme.body(
                                          size: 11, color: _estado ? ec.green : ec.red)),
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
                    ),

                    // ── CONTRASEÑA ────────────────────────────────
                    const FieldLabel('Contraseña'),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Dejar vacío para no modificar la contraseña actual.',
                          style: EnjoyTheme.body(size: 11, color: ec.textMute)),
                    ),
                    _passwordField(_clave, 'Nueva contraseña (opcional)', _obscureClave,
                        () => setState(() => _obscureClave = !_obscureClave)),
                    _passwordField(_confirmarClave, 'Confirmar nueva contraseña', _obscureConfirmar,
                        () => setState(() => _obscureConfirmar = !_obscureConfirmar),
                        validator: (v) {
                      if (_clave.text.isNotEmpty && (v == null || v.isEmpty)) return 'Confirma la contraseña';
                      return null;
                    }),

                    const SizedBox(height: 12),

                    // ── Botones ───────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: EnjoyButton(
                            label: 'Cancelar',
                            variant: EnjoyButtonVariant.ghost,
                            onPressed: _saving ? null : () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: EnjoyButton(
                            label: 'Guardar cambios',
                            icon: Icons.check_rounded,
                            loading: _saving,
                            onPressed: _saving ? null : _guardar,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers de UI ─────────────────────────────────────────────────
  Widget _field(TextEditingController ctrl, String hint, IconData icon, {
    TextInputType keyboard = TextInputType.text,
    bool required = false,
  }) {
    final ec = context.ec;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        cursorColor: ec.orange,
        style: EnjoyTheme.body(size: 14, color: ec.text),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null : null,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
        ),
      ),
    );
  }

  Widget _passwordField(
    TextEditingController ctrl,
    String hint,
    bool obscure,
    VoidCallback toggleObscure, {
    String? Function(String?)? validator,
  }) {
    final ec = context.ec;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        obscureText: obscure,
        cursorColor: ec.orange,
        style: EnjoyTheme.body(size: 14, color: ec.text),
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.lock_rounded, size: 20),
          suffixIcon: IconButton(
            onPressed: toggleObscure,
            icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
          ),
        ),
      ),
    );
  }
}

// ── Widgets helpers ─────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String subtitulo;
  const _EmptyState({required this.icon, required this.titulo, required this.subtitulo});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBox(icon, size: 72, radius: 20, iconSize: 36),
            const SizedBox(height: 16),
            Text(titulo, style: EnjoyTheme.heading(size: 16, color: ec.text)),
            const SizedBox(height: 6),
            Text(subtitulo, textAlign: TextAlign.center, style: EnjoyTheme.body(size: 13, color: ec.textMute)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBox(Icons.wifi_off_rounded, size: 72, radius: 20, iconSize: 36, color: ec.red),
            const SizedBox(height: 16),
            Text('Error de conexión', style: EnjoyTheme.heading(size: 16, color: ec.text)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: EnjoyTheme.body(size: 13, color: ec.textMute)),
            const SizedBox(height: 20),
            EnjoyButton(
              label: 'Reintentar',
              icon: Icons.refresh_rounded,
              expand: false,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
