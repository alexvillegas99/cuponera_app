import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/usuarios_empresa_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:enjoy/widgets/account_switcher_section.dart';
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
    final ec = context.ec;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: ec.orange));
    }

    if (_error != null && _usuario == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: ec.red),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: EnjoyTheme.body(size: 14, color: ec.textMute)),
              const SizedBox(height: 16),
              EnjoyButton(
                label: 'Reintentar',
                icon: Icons.refresh_rounded,
                expand: false,
                onPressed: _cargar,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: ec.orange,
      backgroundColor: ec.surfaceTop,
      onRefresh: _cargar,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            // ─── Header de perfil ──────────────────────────────────────
            GlassCard(
              accent: true,
              radius: 20,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  EnjoyAvatar(_nombre, size: 72, radius: 22),
                  const SizedBox(height: 14),
                  Text(
                    _nombre,
                    textAlign: TextAlign.center,
                    style: EnjoyTheme.heading(
                        size: 20, weight: FontWeight.w800, color: ec.text),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Pill(_rolLabel(_rol), variant: PillVariant.blue),
                      const SizedBox(width: 8),
                      Pill(
                        _activo ? 'Activo' : 'Inactivo',
                        variant: _activo ? PillVariant.green : PillVariant.red,
                        dot: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── Cambiar de cuenta (solo si hay cuenta de cliente del mismo correo) ─
            const Align(
              alignment: Alignment.centerLeft,
              child: AccountSwitcherSection(showAdd: false),
            ),

            // ─── Información de contacto ───────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: FieldLabel('Información de contacto'),
            ),
            ListRowTile(
              leading: const IconBox(Icons.mail_outline_rounded),
              title: _correo,
              subtitle: 'Correo',
              trailing: _CopyButton(
                onTap: () => _copiar(_correo, 'Correo copiado'),
              ),
            ),
            const SizedBox(height: 10),
            ListRowTile(
              leading: const IconBox(Icons.phone_outlined),
              title: _telefono,
              subtitle: 'Teléfono',
              trailing: _telefono != '—'
                  ? _CopyButton(
                      onTap: () => _copiar(_telefono, 'Teléfono copiado'),
                    )
                  : null,
            ),

          ],
        ),
      ),
    );
  }

  void _copiar(String text, String msg) {
    Clipboard.setData(ClipboardData(text: text));
    final ec = context.ec;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ec.surfaceTop,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ── Widgets internos ────────────────────────────────────────────────────────

class _CopyButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CopyButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ec.glassStrong,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ec.stroke),
        ),
        child: Icon(Icons.copy_rounded, size: 16, color: ec.textMute),
      ),
    );
  }
}
