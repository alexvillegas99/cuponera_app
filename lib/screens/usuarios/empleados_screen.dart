import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/usuarios_empresa_service.dart';
import 'package:enjoy/ui/palette.dart';
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Palette.kAccent));
    }

    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _cargar);
    }

    return Column(
      children: [
        // Barra de búsqueda
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _busqueda = v),
            decoration: InputDecoration(
              hintText: 'Buscar empleado...',
              hintStyle: const TextStyle(color: Palette.kMuted, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: Palette.kMuted, size: 20),
              filled: true,
              fillColor: Palette.kSurface,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                style: const TextStyle(
                  color: Palette.kMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
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
                  subtitulo: 'No se encontraron empleados.',
                )
              : RefreshIndicator(
                  color: Palette.kAccent,
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: _filtrados.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _EmpleadoCard(usuario: _filtrados[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Card de empleado ────────────────────────────────────────────────────────

class _EmpleadoCard extends StatelessWidget {
  final Map<String, dynamic> usuario;
  const _EmpleadoCard({required this.usuario});

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
    final initial = _nombre.isNotEmpty ? _nombre[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar con inicial
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Palette.kAccent, Palette.kAccentLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nombre,
                    style: const TextStyle(
                      color: Palette.kTitle,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _correo,
                    style: const TextStyle(color: Palette.kMuted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Badge(label: _rolLabel(_rol), color: _rolColor(_rol)),
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

            Icon(Icons.chevron_right_rounded, color: Palette.kBorder, size: 22),
          ],
        ),
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

  Color _rolColor(String rol) {
    switch (rol.toLowerCase()) {
      case 'admin': return Colors.purple.shade700;
      case 'admin-local': return Colors.blue.shade700;
      default: return Palette.kMuted;
    }
  }
}

// ── Widgets helpers ─────────────────────────────────────────────────────────

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
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Palette.kField,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 36, color: Palette.kMuted),
            ),
            const SizedBox(height: 16),
            Text(titulo,
                style: const TextStyle(
                    color: Palette.kTitle,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            const SizedBox(height: 6),
            Text(subtitulo,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Palette.kMuted, fontSize: 13)),
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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.wifi_off_rounded, size: 36, color: Colors.red),
            ),
            const SizedBox(height: 16),
            const Text('Error de conexión',
                style: TextStyle(
                    color: Palette.kTitle,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Palette.kMuted, fontSize: 13)),
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
