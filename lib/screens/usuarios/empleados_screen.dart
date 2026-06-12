import 'package:enjoy/screens/usuarios/empleado_form_screen.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/usuarios_empresa_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';

class EmpleadosScreen extends StatefulWidget {
  const EmpleadosScreen({super.key});

  @override
  State<EmpleadosScreen> createState() => _EmpleadosScreenState();
}

class _EmpleadosScreenState extends State<EmpleadosScreen> {
  final _auth = AuthService();
  final _svc = UsuariosEmpresaService();

  List<Map<String, dynamic>> _empleados = [];
  bool _loading = true;
  String? _error;
  String _busqueda = '';
  String? _userId;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _auth.getUser();
      final userId = user?['_id']?.toString();
      if (userId == null) throw Exception('Sin ID de usuario');
      _userId = userId;
      final data = await _svc.listarPorLocal(userId);
      if (mounted) {
        setState(() {
          _empleados = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo cargar los empleados.';
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_busqueda.isEmpty) return _empleados;
    final q = _busqueda.toLowerCase();
    return _empleados.where((u) {
      final nombre = '${u['nombre'] ?? u['nombres'] ?? ''} ${u['apellidos'] ?? ''}'.toLowerCase();
      final correo = (u['correo'] ?? u['email'] ?? '').toString().toLowerCase();
      return nombre.contains(q) || correo.contains(q);
    }).toList();
  }

  void _abrirCrear() {
    if (_userId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmpleadoFormScreen(localId: _userId!),
      ),
    ).then((ok) {
      if (ok == true) _cargar();
    });
  }

  void _abrirEditar(Map<String, dynamic> empleado) {
    if (_userId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmpleadoFormScreen(
          localId: _userId!,
          empleado: empleado,
        ),
      ),
    ).then((ok) {
      if (ok == true) _cargar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: ec.orange));
    }

    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _cargar);
    }

    return Stack(
      children: [
        Column(
          children: [
            // Barra de búsqueda
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _busqueda = v),
                cursorColor: ec.orange,
                style: EnjoyTheme.body(size: 14, color: ec.text),
                decoration: const InputDecoration(
                  hintText: 'Buscar empleado...',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                ),
              ),
            ),

            // Contador
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${_filtrados.length} empleado${_filtrados.length != 1 ? 's' : ''}',
                    style: EnjoyTheme.body(
                        size: 12, weight: FontWeight.w500, color: ec.textMute),
                  ),
                ],
              ),
            ),

            // Lista
            Expanded(
              child: _filtrados.isEmpty
                  ? const _EmptyState(
                      icon: Icons.people_outline_rounded,
                      titulo: 'Sin empleados',
                      subtitulo: 'Toca + para agregar el primer empleado.',
                    )
                  : RefreshIndicator(
                      color: ec.orange,
                      backgroundColor: ec.surfaceTop,
                      onRefresh: _cargar,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: _filtrados.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _EmpleadoCard(
                          usuario: _filtrados[i],
                          onTap: () => _abrirEditar(_filtrados[i]),
                        ),
                      ),
                    ),
            ),
          ],
        ),

        // FAB
        Positioned(
          right: 16,
          bottom: 24,
          child: FloatingActionButton(
            onPressed: _abrirCrear,
            backgroundColor: ec.orange,
            foregroundColor: ec.onAccent,
            elevation: 4,
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }
}

// ── Card de empleado ────────────────────────────────────────────────────────

class _EmpleadoCard extends StatelessWidget {
  final Map<String, dynamic> usuario;
  final VoidCallback onTap;
  const _EmpleadoCard({required this.usuario, required this.onTap});

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
    final isAdmin = _rol.toLowerCase().contains('admin');
    return ListRowTile(
      onTap: onTap,
      leading: EnjoyAvatar(_nombre, size: 42, radius: 12, accent: isAdmin),
      title: _nombre,
      subtitle: _correo,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Pill(
            _rolLabel(_rol),
            variant: isAdmin ? PillVariant.blue : PillVariant.glass,
            dense: true,
          ),
          const SizedBox(height: 5),
          Pill(
            _activo ? 'Activo' : 'Inactivo',
            variant: _activo ? PillVariant.green : PillVariant.glass,
            dense: true,
          ),
        ],
      ),
    );
  }

  String _rolLabel(String rol) {
    switch (rol.toLowerCase()) {
      case 'admin-local': return 'Admin Local';
      case 'admin': return 'Admin';
      case 'staff': return 'Staff';
      default: return rol.isEmpty ? 'Sin rol' : rol;
    }
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
            Text(titulo,
                style: EnjoyTheme.heading(
                    size: 16, weight: FontWeight.w700, color: ec.text)),
            const SizedBox(height: 6),
            Text(subtitulo,
                textAlign: TextAlign.center,
                style: EnjoyTheme.body(size: 13, color: ec.textMute)),
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
            IconBox(Icons.wifi_off_rounded,
                size: 72, radius: 20, iconSize: 36, color: ec.red),
            const SizedBox(height: 16),
            Text('Error de conexión',
                style: EnjoyTheme.heading(
                    size: 16, weight: FontWeight.w700, color: ec.text)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: EnjoyTheme.body(size: 13, color: ec.textMute)),
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
