import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/usuarios_empresa_service.dart';
import 'package:enjoy/ui/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PerfilLocalScreen extends StatefulWidget {
  const PerfilLocalScreen({super.key});

  @override
  State<PerfilLocalScreen> createState() => _PerfilLocalScreenState();
}

class _PerfilLocalScreenState extends State<PerfilLocalScreen> {
  final _auth = AuthService();
  final _svc = UsuariosEmpresaService();

  Map<String, dynamic>? _usuario;
  bool _loading = true;
  String? _error;

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
      final local = await _auth.getUser();
      final id = local?['_id']?.toString();

      Map<String, dynamic>? fresh;
      if (id != null) {
        try {
          fresh = await _svc.obtener(id);
        } catch (_) {
          // Si falla la API, usa datos locales
        }
      }

      if (mounted) {
        setState(() {
          _usuario = fresh ?? local;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo cargar el perfil.';
          _loading = false;
        });
      }
    }
  }

  String get _nombre {
    final n = (_usuario?['nombre'] ?? _usuario?['nombres'] ?? '').toString().trim();
    final a = (_usuario?['apellidos'] ?? '').toString().trim();
    return [n, a].where((s) => s.isNotEmpty).join(' ').trim().isEmpty
        ? 'Sin nombre'
        : [n, a].where((s) => s.isNotEmpty).join(' ');
  }

  String get _correo => (_usuario?['correo'] ?? _usuario?['email'] ?? '—').toString();
  String get _telefono => (_usuario?['telefono'] ?? '—').toString();
  String get _rol => (_usuario?['rol'] ?? '').toString();
  bool get _activo => _usuario?['estado'] != false;

  String _rolLabel(String rol) {
    switch (rol.toLowerCase()) {
      case 'admin-local': return 'Admin Local';
      case 'admin': return 'Administrador';
      case 'staff': return 'Staff';
      default: return rol.isEmpty ? 'Sin rol' : rol;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Palette.kAccent));
    }

    if (_error != null && _usuario == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Palette.kMuted)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _cargar,
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

    return RefreshIndicator(
      color: Palette.kAccent,
      onRefresh: _cargar,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ─── Header de perfil ──────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF152A47), Color(0xFF1E3A6E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar grande
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Palette.kAccent, Palette.kAccentLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Palette.kAccent.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _nombre.isNotEmpty ? _nombre[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 32,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    _nombre,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),

                  // Rol badge + estado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Palette.kAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Palette.kAccent.withOpacity(0.4)),
                        ),
                        child: Text(
                          _rolLabel(_rol),
                          style: const TextStyle(
                            color: Palette.kAccentLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (_activo ? Colors.green : Colors.red).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _activo ? Colors.greenAccent : Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _activo ? 'Activo' : 'Inactivo',
                              style: TextStyle(
                                color: _activo ? Colors.greenAccent : Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── Información de contacto ───────────────────────────────
            _SectionCard(
              title: 'Información de contacto',
              icon: Icons.contact_mail_rounded,
              children: [
                _InfoRow(
                  icon: Icons.email_rounded,
                  label: 'Correo',
                  value: _correo,
                  onCopy: () => _copiar(_correo, 'Correo copiado'),
                ),
                _InfoRow(
                  icon: Icons.phone_rounded,
                  label: 'Teléfono',
                  value: _telefono,
                  onCopy: _telefono != '—'
                      ? () => _copiar(_telefono, 'Teléfono copiado')
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _copiar(String text, String msg) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Palette.kPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ── Widgets internos ────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, size: 16, color: Palette.kAccent),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Palette.kTitle,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Palette.kBorder),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;
  const _InfoRow({required this.icon, required this.label, required this.value, this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Palette.kMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Palette.kMuted, fontSize: 11, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: Palette.kTitle, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (onCopy != null)
            GestureDetector(
              onTap: onCopy,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Palette.kField,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.copy_rounded, size: 14, color: Palette.kMuted),
              ),
            ),
        ],
      ),
    );
  }
}
