import 'package:enjoy/services/core/api_client.dart';
import 'package:enjoy/services/usuarios_empresa_service.dart';
import 'package:enjoy/ui/palette.dart';
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Palette.kAccent));
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
                decoration: InputDecoration(
                  hintText: 'Buscar usuario...',
                  hintStyle: const TextStyle(color: Palette.kMuted, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: Palette.kMuted, size: 20),
                  filled: true,
                  fillColor: Palette.kSurface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Palette.kBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Palette.kBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.kAccent)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _RolChip(label: 'Todos', selected: _filtroRol == null, onTap: () => setState(() => _filtroRol = null)),
                    ..._rolesLista.map((r) => _RolChip(
                          label: r.label,
                          selected: _filtroRol == r.slug,
                          onTap: () => setState(() => _filtroRol = _filtroRol == r.slug ? null : r.slug),
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Contador
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              Text(
                '${_filtrados.length} usuario${_filtrados.length != 1 ? 's' : ''}',
                style: const TextStyle(color: Palette.kMuted, fontSize: 12, fontWeight: FontWeight.w500),
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
                  color: Palette.kAccent,
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

// ── Chip de filtro ───────────────────────────────────────────────────────────

class _RolChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RolChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Palette.kAccent : Palette.kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Palette.kAccent : Palette.kBorder),
          boxShadow: selected ? [BoxShadow(color: Palette.kAccent.withOpacity(0.3), blurRadius: 6)] : [],
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? Colors.white : Palette.kMuted, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
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

  String _rolLabel(String rol) {
    switch (rol.toLowerCase()) {
      case 'admin-local': return 'Admin Local';
      case 'admin': return 'Admin';
      case 'staff': return 'Staff';
      default: return rol.isEmpty ? 'Sin rol' : rol;
    }
  }

  Color _rolColor(String rol) {
    switch (rol.toLowerCase()) {
      case 'admin': return const Color(0xFF7B2D8B);
      case 'admin-local': return const Color(0xFF1565C0);
      case 'staff': return Palette.kMuted;
      default: return Palette.kAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = _nombre.isNotEmpty ? _nombre[0].toUpperCase() : '?';
    final rolColor = _rolColor(_rol);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Palette.kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Palette.kBorder),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: rolColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: rolColor.withOpacity(0.2)),
                ),
                child: Center(
                  child: Text(initial, style: TextStyle(color: rolColor, fontWeight: FontWeight.w800, fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_nombre,
                        style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700, fontSize: 14),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(_correo,
                        style: const TextStyle(color: Palette.kMuted, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _Badge(label: _rolLabel(_rol), color: rolColor),
                        const SizedBox(width: 6),
                        _Badge(
                          label: _activo ? 'Activo' : 'Inactivo',
                          color: _activo ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Palette.kBorder, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET DE EDICIÓN DE USUARIO
// ══════════════════════════════════════════════════════════════════════════════

class _EditUsuarioSheet extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final UsuariosEmpresaService svc;
  const _EditUsuarioSheet({required this.usuario, required this.svc});

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
    _original = Map<String, dynamic>.from(widget.usuario);

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.green.shade700 : info ? Colors.blue.shade700 : Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── UI ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final nombre = (_original['nombre'] ?? 'Usuario').toString();
    final initial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U';
    final rolColor = _rolColor(_rol);

    return Container(
      decoration: const BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(width: 44, height: 5,
                decoration: BoxDecoration(color: Palette.kBorder, borderRadius: BorderRadius.circular(99))),
          ),

          // Cabecera con avatar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: rolColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: rolColor.withOpacity(0.25)),
                  ),
                  child: Center(child: Text(initial, style: TextStyle(color: rolColor, fontWeight: FontWeight.w800, fontSize: 18))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Editar usuario', style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w800, fontSize: 17)),
                      Text(nombre, style: const TextStyle(color: Palette.kMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Palette.kBorder),

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
                    _sectionLabel('DATOS GENERALES'),
                    _field(_nombre, 'Nombre', Icons.person_rounded, required: true),
                    _field(_email, 'Correo electrónico', Icons.email_rounded,
                        keyboard: TextInputType.emailAddress, required: true),
                    _field(_identificacion, 'CI / RUC', Icons.badge_rounded,
                        keyboard: TextInputType.number, required: true),

                    // ── ROL ───────────────────────────────────────
                    const SizedBox(height: 4),
                    _sectionLabel('ROL'),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _rolesLoading
                          ? Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: Palette.kField,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Palette.kBorder),
                              ),
                              child: const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Palette.kAccent))),
                            )
                          : DropdownButtonFormField<String>(
                              value: _rolesDisponibles.any((r) => r.slug == _rol) ? _rol : null,
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.manage_accounts_rounded, size: 18, color: _rolColor(_rol)),
                                filled: true,
                                fillColor: Palette.kField,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Palette.kBorder)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Palette.kBorder)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.kAccent, width: 1.5)),
                              ),
                              dropdownColor: Palette.kSurface,
                              style: const TextStyle(color: Palette.kTitle, fontSize: 14),
                              hint: const Text('Seleccionar rol', style: TextStyle(color: Palette.kMuted, fontSize: 13)),
                              validator: (v) => (v == null || v.isEmpty) ? 'Selecciona un rol' : null,
                              items: _rolesDisponibles.map((r) {
                                final rc = _rolColor(r.slug);
                                return DropdownMenuItem<String>(
                                  value: r.slug,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8, height: 8,
                                        decoration: BoxDecoration(color: rc, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(r.label),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) { if (v != null) setState(() => _rol = v); },
                            ),
                    ),

                    // ── ESTADO ────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Palette.kField,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Palette.kBorder),
                        ),
                        child: SwitchListTile(
                          title: const Text('Usuario activo',
                              style: TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(_estado ? 'Puede iniciar sesión' : 'Acceso bloqueado',
                              style: TextStyle(
                                  color: _estado ? Colors.green.shade600 : Colors.red.shade600,
                                  fontSize: 11)),
                          value: _estado,
                          onChanged: (v) => setState(() => _estado = v),
                          activeColor: Palette.kAccent,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                      ),
                    ),

                    // ── CONTRASEÑA ────────────────────────────────
                    _sectionLabel('CONTRASEÑA'),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('Dejar vacío para no modificar la contraseña actual.',
                          style: const TextStyle(color: Palette.kMuted, fontSize: 11)),
                    ),
                    const SizedBox(height: 8),
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
                          child: OutlinedButton(
                            onPressed: _saving ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Palette.kBorder),
                              foregroundColor: Palette.kMuted,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saving ? null : _guardar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Palette.kAccent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _saving
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Guardar cambios', style: TextStyle(fontWeight: FontWeight.w700)),
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

  // ── Helpers de color ─────────────────────────────────────────────
  Color _rolColor(String rol) {
    switch (rol.toLowerCase()) {
      case 'admin': return const Color(0xFF7B2D8B);
      case 'admin-local': return const Color(0xFF1565C0);
      default: return Palette.kMuted;
    }
  }

  // ── Helpers de UI ─────────────────────────────────────────────────
  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(label, style: const TextStyle(color: Palette.kMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
  );

  Widget _field(TextEditingController ctrl, String hint, IconData icon, {
    TextInputType keyboard = TextInputType.text,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        style: const TextStyle(color: Palette.kTitle, fontSize: 14),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null : null,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Palette.kMuted, fontSize: 13),
          prefixIcon: Icon(icon, size: 18, color: Palette.kMuted),
          filled: true, fillColor: Palette.kField,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Palette.kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Palette.kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.kAccent, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        obscureText: obscure,
        style: const TextStyle(color: Palette.kTitle, fontSize: 14),
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Palette.kMuted, fontSize: 13),
          prefixIcon: const Icon(Icons.lock_rounded, size: 18, color: Palette.kMuted),
          suffixIcon: IconButton(
            onPressed: toggleObscure,
            icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: Palette.kMuted),
          ),
          filled: true, fillColor: Palette.kField,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Palette.kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Palette.kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.kAccent, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
        ),
      ),
    );
  }
}

// ── Badge ────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: Palette.kField, borderRadius: BorderRadius.circular(20)),
              child: Icon(icon, size: 36, color: Palette.kMuted),
            ),
            const SizedBox(height: 16),
            Text(titulo, style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            Text(subtitulo, textAlign: TextAlign.center, style: const TextStyle(color: Palette.kMuted, fontSize: 13)),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.wifi_off_rounded, size: 36, color: Colors.red),
            ),
            const SizedBox(height: 16),
            const Text('Error de conexión', style: TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Palette.kMuted, fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.kAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
