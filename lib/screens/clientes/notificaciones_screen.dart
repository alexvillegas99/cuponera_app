import 'package:enjoy/screens/clientes/comercio_detalle_mini_screen.dart';
import 'package:enjoy/screens/clientes/notificacion_prefs_screen.dart';
import 'package:enjoy/screens/clientes/promocion_flash_detalle_screen.dart';
import 'package:enjoy/services/campanas_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificacionesScreen extends StatefulWidget {
  /// Si viene del tap a un push, abre directamente esa entrega.
  final String? abrirEntregaId;
  const NotificacionesScreen({super.key, this.abrirEntregaId});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final _svc = CampanasService();
  final _scroll = ScrollController();

  List<Map<String, dynamic>> _items = [];
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hayMas = true;
  bool _filtroNoLeidas = false;

  @override
  void initState() {
    super.initState();
    _cargarPrimera();
    _scroll.addListener(() {
      if (_scroll.position.pixels >=
              _scroll.position.maxScrollExtent - 200 &&
          !_loadingMore &&
          _hayMas) {
        _cargarMas();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargarPrimera() async {
    setState(() {
      _loading = true;
      _page = 1;
      _items = [];
      _hayMas = true;
    });
    try {
      final r = await _svc.feed(
        page: 1,
        limit: 25,
        soloNoLeidas: _filtroNoLeidas,
      );
      if (!mounted) return;
      final list = List<Map<String, dynamic>>.from(r['items'] ?? []);
      setState(() {
        _items = list;
        _hayMas = list.length >= 25;
        _loading = false;
      });

      // Si vino del tap a un push, abrir el detalle.
      if (widget.abrirEntregaId != null) {
        final match = list.firstWhere(
          (e) => e['_id']?.toString() == widget.abrirEntregaId,
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _abrirDetalle(match));
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cargarMas() async {
    setState(() => _loadingMore = true);
    try {
      _page++;
      final r = await _svc.feed(
        page: _page,
        limit: 25,
        soloNoLeidas: _filtroNoLeidas,
      );
      final list = List<Map<String, dynamic>>.from(r['items'] ?? []);
      if (!mounted) return;
      setState(() {
        _items.addAll(list);
        _hayMas = list.length >= 25;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _marcarTodasLeidas() async {
    try {
      await _svc.leerTodas();
      if (!mounted) return;
      setState(() {
        _items = _items.map((m) {
          return {...m, 'leida': true};
        }).toList();
      });
    } catch (_) {}
  }

  /// Elimina una entrega de la bandeja del cliente (sin tocar la campaña
  /// global). Optimista: quita del listado y si falla la vuelve a poner.
  Future<void> _eliminarUna(Map<String, dynamic> entrega) async {
    final id = entrega['_id']?.toString();
    if (id == null || id.isEmpty) return;
    final idx = _items.indexWhere((e) => e['_id']?.toString() == id);
    if (idx < 0) return;
    final backup = _items[idx];
    setState(() => _items.removeAt(idx));
    try {
      await _svc.eliminarEntrega(id);
    } catch (_) {
      if (!mounted) return;
      // Revertir si falló.
      setState(() {
        _items.insert(idx.clamp(0, _items.length), backup);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos eliminar la notificación.')),
      );
    }
  }

  Future<void> _vaciarBandeja() async {
    if (_items.isEmpty) return;
    final ec = context.ec;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ec.surfaceTop,
        title: Text('Vaciar bandeja',
            style: EnjoyTheme.heading(size: 17, color: ec.text)),
        content: Text(
          'Se borrarán todas tus notificaciones. ¿Continuar?',
          style: EnjoyTheme.body(color: ec.textSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ec.red),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final backup = List<Map<String, dynamic>>.from(_items);
    setState(() => _items = []);
    try {
      await _svc.vaciarBandeja();
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = backup);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos vaciar la bandeja.')),
      );
    }
  }

  Future<void> _abrirDetalle(Map<String, dynamic> entrega) async {
    // Marca leída de inmediato (optimista).
    final id = entrega['_id']?.toString() ?? '';
    if (entrega['leida'] != true && id.isNotEmpty) {
      _svc.leerUna(id).catchError((_) => null);
      setState(() {
        final i = _items.indexWhere((e) => e['_id']?.toString() == id);
        if (i >= 0) _items[i] = {..._items[i], 'leida': true};
      });
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.ec.surfaceMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _DetalleSheet(
        entrega: entrega,
        onAccion: () => _ejecutarAccion(entrega),
      ),
    );
  }

  Future<void> _ejecutarAccion(Map<String, dynamic> entrega) async {
    final tipo = entrega['tipoAccion']?.toString();
    final ref = entrega['accionRefId']?.toString();
    final url = entrega['accionUrl']?.toString();
    Navigator.pop(context); // cierra sheet
    if (tipo == 'LOCAL' && ref != null && ref.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ComercioDetalleMiniScreen(usuarioId: ref),
        ),
      );
    } else if (tipo == 'FLASH' && ref != null && ref.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PromocionFlashDetalleScreen(promocionId: ref),
        ),
      );
    } else if (tipo == 'URL' && url != null && url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: EnjoyAppBar(
        title: 'Notificaciones',
        actions: [
          GlassIconButton(
            icon: Icons.tune_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificacionPrefsScreen(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GlassIconButton(
            icon: Icons.done_all_rounded,
            onTap: _items.any((e) => e['leida'] != true)
                ? _marcarTodasLeidas
                : null,
          ),
          const SizedBox(width: 6),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            color: ec.surfaceTop,
            icon: Icon(Icons.more_vert_rounded, color: ec.text),
            onSelected: (v) {
              if (v == 'vaciar') _vaciarBandeja();
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'vaciar',
                enabled: _items.isNotEmpty,
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded,
                        size: 18, color: ec.red),
                    const SizedBox(width: 8),
                    Text('Vaciar bandeja',
                        style: EnjoyTheme.body(size: 14, color: ec.text)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: Row(
              children: [
                _chip('Todas', !_filtroNoLeidas, () {
                  setState(() => _filtroNoLeidas = false);
                  _cargarPrimera();
                }),
                const SizedBox(width: 6),
                _chip('No leídas', _filtroNoLeidas, () {
                  setState(() => _filtroNoLeidas = true);
                  _cargarPrimera();
                }),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: ec.orange))
                : _items.isEmpty
                    ? _empty(ec)
                    : RefreshIndicator(
                        color: ec.orange,
                        onRefresh: _cargarPrimera,
                        child: ListView.separated(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
                          itemCount: _items.length + (_hayMas ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            if (i >= _items.length) {
                              return Center(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: ec.orange,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return _tile(_items[i]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) {
    final ec = context.ec;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? ec.orange.withValues(alpha: 0.18) : ec.glass,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? ec.orange : ec.stroke),
        ),
        child: Text(
          label,
          style: EnjoyTheme.body(
            size: 13,
            color: on ? ec.orange : ec.textSoft,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _empty(EnjoyColors ec) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_rounded,
                size: 48, color: ec.textMute.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(_filtroNoLeidas ? 'Todas leídas' : 'Sin notificaciones aún',
                style: EnjoyTheme.heading(size: 16, color: ec.text)),
            const SizedBox(height: 4),
            Text(
              _filtroNoLeidas
                  ? 'No tienes notificaciones pendientes.'
                  : 'Cuando recibas novedades aparecerán aquí.',
              style: EnjoyTheme.body(size: 13, color: ec.textMute),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> e) {
    final ec = context.ec;
    final leida = e['leida'] == true;
    final titulo = (e['titulo'] ?? '').toString();
    final cuerpo = (e['cuerpo'] ?? '').toString();
    final img = (e['imagenUrl'] ?? '').toString();
    final fecha = e['createdAt']?.toString() ?? '';
    final id = e['_id']?.toString() ?? '';

    return Dismissible(
      key: ValueKey('notif-$id'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: ec.red.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ec.red.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, color: ec.red),
            const SizedBox(width: 8),
            Text('Eliminar',
                style: EnjoyTheme.body(
                  size: 13, color: ec.red, weight: FontWeight.w700,
                )),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: ec.surfaceTop,
                title: Text('Eliminar notificación',
                    style: EnjoyTheme.heading(size: 16, color: ec.text)),
                content: Text(
                  'Esta notificación se borrará de tu bandeja.',
                  style: EnjoyTheme.body(color: ec.textSoft),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(foregroundColor: ec.red),
                    child: const Text('Eliminar'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => _eliminarUna(e),
      child: GestureDetector(
      onTap: () => _abrirDetalle(e),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: leida ? ec.glass : ec.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: leida
                ? ec.stroke
                : ec.orange.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (img.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: EnjoyImage(img, fit: BoxFit.cover),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconBox(
                  Icons.notifications_active_rounded,
                  accent: !leida,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          titulo,
                          style: EnjoyTheme.heading(
                            size: 14,
                            color: ec.text,
                            weight:
                                leida ? FontWeight.w600 : FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!leida)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: ec.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cuerpo,
                    style: EnjoyTheme.body(size: 12.5, color: ec.textSoft),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (fecha.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatFecha(fecha),
                      style: EnjoyTheme.body(size: 11, color: ec.textMute),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  String _formatFecha(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(d);
      if (diff.inMinutes < 1) return 'ahora';
      if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'hace ${diff.inHours} h';
      if (diff.inDays < 7) return 'hace ${diff.inDays} d';
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return '';
    }
  }
}

class _DetalleSheet extends StatelessWidget {
  final Map<String, dynamic> entrega;
  final VoidCallback onAccion;
  const _DetalleSheet({required this.entrega, required this.onAccion});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final titulo = (entrega['titulo'] ?? '').toString();
    final cuerpo = (entrega['cuerpo'] ?? '').toString();
    final img = (entrega['imagenUrl'] ?? '').toString();
    final tipo = entrega['tipoAccion']?.toString();
    final tieneAccion = tipo != null && tipo != 'NINGUNA';

    final labelBtn = switch (tipo) {
      'LOCAL' => 'Ver local',
      'FLASH' => 'Ver promoción',
      'PROMO' => 'Ver promoción',
      'URL' => 'Abrir enlace',
      _ => 'Ver',
    };

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          18,
          22,
          MediaQuery.of(context).viewInsets.bottom + 22,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ec.strokeStrong,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            if (img.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: EnjoyImage(img, fit: BoxFit.cover),
              ),
            if (img.isNotEmpty) const SizedBox(height: 14),
            Text(
              titulo,
              style: EnjoyTheme.heading(size: 18, color: ec.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              cuerpo,
              style: EnjoyTheme.body(size: 14, color: ec.textSoft, height: 1.45),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (tieneAccion)
              SizedBox(
                width: double.infinity,
                child: EnjoyButton(
                  label: labelBtn,
                  icon: Icons.arrow_forward_rounded,
                  onPressed: onAccion,
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: EnjoyButton(
                  label: 'Cerrar',
                  variant: EnjoyButtonVariant.ghost,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
