import 'package:enjoy/services/promociones_flash_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';

import 'promo_flash_form_screen.dart';

/// Gestión de promociones flash del local (admin-local).
class MisPromosFlashScreen extends StatefulWidget {
  /// Cuando es true, no envuelve con EnjoyScaffold/EnjoyAppBar (para
  /// embeber dentro del panel del home empresa).
  final bool embedded;
  const MisPromosFlashScreen({super.key, this.embedded = false});

  @override
  State<MisPromosFlashScreen> createState() => _MisPromosFlashScreenState();
}

class _MisPromosFlashScreenState extends State<MisPromosFlashScreen> {
  final _svc = PromocionesFlashService();

  List<Map<String, dynamic>> _items = [];
  int _activas = 0;
  int _max = 5;
  bool _loading = true;
  String? _procesandoId;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final res = await _svc.mias();
      final data = res['data'];
      if (mounted) {
        setState(() {
          _items =
              data is List ? List<Map<String, dynamic>>.from(data) : [];
          _activas = (res['activas'] ?? 0) as int;
          _max = (res['max'] ?? 5) as int;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _crear() async {
    if (_activas >= _max) {
      _snack('Ya tienes el máximo de $_max promociones activas');
      return;
    }
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PromoFlashFormScreen()),
    );
    if (ok == true) _cargar();
  }

  Future<void> _editar(Map<String, dynamic> p) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PromoFlashFormScreen(promo: p)),
    );
    if (ok == true) _cargar();
  }

  Future<void> _togglePausa(Map<String, dynamic> p) async {
    final id = p['_id'].toString();
    final nuevo = p['estado'] == 'PAUSADA' ? 'ACTIVA' : 'PAUSADA';
    setState(() => _procesandoId = id);
    try {
      await _svc.actualizar(id, {'estado': nuevo});
      await _cargar();
    } catch (_) {
      _snack('No se pudo actualizar');
    } finally {
      if (mounted) setState(() => _procesandoId = null);
    }
  }

  Future<void> _eliminar(Map<String, dynamic> p) async {
    final ec = context.ec;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ec.surfaceTop,
        title: Text('Eliminar promoción',
            style: EnjoyTheme.heading(size: 16, color: ec.text)),
        content: Text('¿Eliminar "${p['titulo']}"? No se puede deshacer.',
            style: EnjoyTheme.body(size: 14, color: ec.textSoft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: EnjoyTheme.body(color: ec.textMute)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: EnjoyTheme.body(color: ec.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _procesandoId = p['_id'].toString());
    try {
      await _svc.eliminar(p['_id'].toString());
      await _cargar();
    } catch (_) {
      _snack('No se pudo eliminar');
    } finally {
      if (mounted) setState(() => _procesandoId = null);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: widget.embedded
          ? null
          : const EnjoyAppBar(title: 'Promociones flash'),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: ec.orange))
          : RefreshIndicator(
              color: ec.orange,
              backgroundColor: ec.surfaceTop,
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  // Contador + descripción
                  GlassCard(
                    accent: true,
                    child: Row(
                      children: [
                        const IconBox(Icons.bolt_rounded, accent: true),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$_activas / $_max activas',
                                  style: EnjoyTheme.heading(
                                      size: 16, color: ec.text)),
                              const SizedBox(height: 2),
                              Text(
                                'Publica anuncios de tiempo limitado para tu local',
                                style: EnjoyTheme.body(
                                    size: 12, color: ec.textMute),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          IconBox(Icons.bolt_outlined,
                              size: 64, radius: 18, iconSize: 30),
                          const SizedBox(height: 12),
                          Text('Sin promociones flash',
                              style: EnjoyTheme.heading(
                                  size: 16, color: ec.text)),
                          const SizedBox(height: 4),
                          Text('Crea tu primera promoción flash.',
                              style: EnjoyTheme.body(
                                  size: 13, color: ec.textMute)),
                        ],
                      ),
                    )
                  else
                    ..._items.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PromoCard(
                            p: p,
                            procesando: _procesandoId == p['_id'].toString(),
                            onEditar: () => _editar(p),
                            onPausa: () => _togglePausa(p),
                            onEliminar: () => _eliminar(p),
                          ),
                        )),
                ],
              ),
            ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              backgroundColor: _activas >= _max ? ec.surfaceTop : ec.orange,
              foregroundColor:
                  _activas >= _max ? ec.textMute : ec.onAccent,
              onPressed: _crear,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Crear'),
            ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final Map<String, dynamic> p;
  final bool procesando;
  final VoidCallback onEditar;
  final VoidCallback onPausa;
  final VoidCallback onEliminar;

  const _PromoCard({
    required this.p,
    required this.procesando,
    required this.onEditar,
    required this.onPausa,
    required this.onEliminar,
  });

  String _fmt(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final estado = (p['estado'] ?? 'ACTIVA').toString();
    final vencida = p['vencida'] == true || estado == 'VENCIDA';
    final pausada = estado == 'PAUSADA';
    final inicia = DateTime.tryParse(p['inicia']?.toString() ?? '')?.toLocal();
    final programada =
        !vencida && !pausada && inicia != null && inicia.isAfter(DateTime.now());

    final (estadoLabel, estadoVariant) = vencida
        ? ('Vencida', PillVariant.red)
        : pausada
            ? ('Pausada', PillVariant.orange)
            : programada
                ? ('Programada', PillVariant.blue)
                : ('Activa', PillVariant.green);

    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: (p['imagenUrl'] != null)
                      ? EnjoyImage(p['imagenUrl'].toString(), fit: BoxFit.cover)
                      : Container(color: ec.glass),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (p['titulo'] ?? '').toString(),
                      style: EnjoyTheme.heading(size: 14, color: ec.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Pill(estadoLabel, variant: estadoVariant, dense: true),
                        const SizedBox(width: 6),
                        if (p['canjeable'] == true)
                          Pill('Canjeable',
                              variant: PillVariant.blue, dense: true),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Vence ${_fmt(p['vence']?.toString())} · 👁 ${p['vistas'] ?? 0} · 🎟 ${p['canjes'] ?? 0}',
                      style: EnjoyTheme.body(size: 11, color: ec.textMute),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const EnjoyDivider(height: 18),
          Row(
            children: [
              Expanded(
                child: EnjoyButton(
                  label: 'Editar',
                  icon: Icons.edit_outlined,
                  variant: EnjoyButtonVariant.ghost,
                  dense: true,
                  onPressed: procesando ? null : onEditar,
                ),
              ),
              const SizedBox(width: 8),
              if (!vencida)
                Expanded(
                  child: EnjoyButton(
                    label: pausada ? 'Activar' : 'Pausar',
                    icon: pausada
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    variant: EnjoyButtonVariant.ghost,
                    dense: true,
                    loading: procesando,
                    onPressed: procesando ? null : onPausa,
                  ),
                ),
              const SizedBox(width: 8),
              EnjoyButton(
                label: 'Eliminar',
                icon: Icons.delete_outline_rounded,
                variant: EnjoyButtonVariant.red,
                dense: true,
                expand: false,
                onPressed: procesando ? null : onEliminar,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
