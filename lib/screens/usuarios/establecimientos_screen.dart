import 'package:enjoy/screens/usuarios/establecimiento_detalle_screen.dart';
import 'package:enjoy/screens/usuarios/establecimiento_form_screen.dart';
import 'package:enjoy/services/establecimientos_empresa_service.dart';
import 'package:enjoy/services/permissions_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';

class EstablecimientosScreen extends StatefulWidget {
  const EstablecimientosScreen({super.key});

  @override
  State<EstablecimientosScreen> createState() => _EstablecimientosScreenState();
}

class _EstablecimientosScreenState extends State<EstablecimientosScreen> {
  final _svc = EstablecimientosEmpresaService();
  final _permissions = PermissionsService();

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String _busqueda = '';
  String? _filtroCiudad;
  bool _canEdit = false;
  bool _canEditFotos = false;
  bool _canCrear = false;
  bool _canActivar = false; // activar/desactivar desde la lista: solo admin
  String? _togglingId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // canAccess usa permisos dinámicos si existen, sino fallback por rol
    _canEdit = await _permissions.canAccess(
      permission: 'establecimientos.editar',
      fallbackRoles: ['admin'],
    );
    _canEditFotos = await _permissions.canAccess(
      permission: 'establecimientos.fotos',
      fallbackRoles: ['admin'],
    );
    _canCrear = await _permissions.canAccess(
      permission: 'establecimientos.crear',
      fallbackRoles: ['admin'],
    );
    _canActivar = await _permissions.canAccess(
      permission: 'dashboard.ver',
      fallbackRoles: ['admin'],
    );
    await _cargar();
  }

  Future<void> _toggleEstado(Map<String, dynamic> item) async {
    final id = item['_id']?.toString();
    if (id == null || _togglingId != null) return;
    final activar = item['estado'] == false;
    final ec = context.ec;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ec.surfaceTop,
        title: Text(
          activar ? 'Activar establecimiento' : 'Desactivar establecimiento',
          style: EnjoyTheme.heading(size: 16, color: ec.text),
        ),
        content: Text(
          activar
              ? '"${item['nombre']}" volverá a mostrarse a los clientes.'
              : '"${item['nombre']}" dejará de mostrarse a los clientes.',
          style: EnjoyTheme.body(size: 14, color: ec.textSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: EnjoyTheme.body(color: ec.textMute)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(activar ? 'Activar' : 'Desactivar',
                style: EnjoyTheme.body(color: activar ? ec.green : ec.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _togglingId = id);
    try {
      await _svc.actualizar(id, {'estado': activar});
      if (mounted) {
        setState(() {
          item['estado'] = activar;
          _togglingId = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _togglingId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar el estado')),
        );
      }
    }
  }

  Future<void> _abrirNuevo() async {
    // Creación rápida: solo datos principales + ubicación actual. El resto
    // (promoción, horarios, categorías, fotos) se completa luego editando.
    final creado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EstablecimientoFormScreen()),
    );
    if (creado == true) {
      await _cargar();
    }
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _svc.listar();
      if (mounted) {
        setState(() {
          _items = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo cargar los establecimientos.';
          _loading = false;
        });
      }
    }
  }

  // ── Ciudades únicas para filtro ──────────────────────────────────
  List<String> get _ciudades {
    final set = <String>{};
    for (final e in _items) {
      final c = e['ciudades'];
      if (c is List) {
        for (final x in c) {
          final nombre = x is Map ? (x['nombre'] ?? '').toString() : x.toString();
          if (nombre.isNotEmpty) set.add(nombre);
        }
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  // ── Filtrado ─────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filtrados {
    return _items.where((e) {
      final nombre = (e['nombre'] ?? '').toString().toLowerCase();
      final ciudadesStr = _getCiudades(e).toLowerCase();
      final categoriasStr = _getCategorias(e).toLowerCase();
      final titulo = (_getDetalle(e)['title'] ?? '').toString().toLowerCase();

      final matchText = _busqueda.isEmpty ||
          nombre.contains(_busqueda.toLowerCase()) ||
          ciudadesStr.contains(_busqueda.toLowerCase()) ||
          categoriasStr.contains(_busqueda.toLowerCase()) ||
          titulo.contains(_busqueda.toLowerCase());

      final matchCiudad = _filtroCiudad == null ||
          ciudadesStr.contains(_filtroCiudad!.toLowerCase());

      return matchText && matchCiudad;
    }).toList();
  }

  // ── Helpers ──────────────────────────────────────────────────────
  String _getCiudades(Map<String, dynamic> e) {
    final c = e['ciudades'];
    if (c is! List) return '';
    return c.map((x) => x is Map ? (x['nombre'] ?? '') : x.toString()).join(', ');
  }

  String _getCategorias(Map<String, dynamic> e) {
    final c = e['categorias'];
    if (c is! List) return '';
    return c.map((x) => x is Map ? (x['nombre'] ?? '') : x.toString()).join(', ');
  }

  Map<String, dynamic> _getDetalle(Map<String, dynamic> e) {
    final d = e['detallePromocion'];
    return d is Map<String, dynamic> ? d : {};
  }

  void _abrirDetalle(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EstablecimientoDetalleScreen(
          establecimiento: item,
          canEdit: _canEdit,
          canEditFotos: _canEditFotos,
        ),
      ),
    ).then((_) => _cargar());
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;

    Widget content;
    if (_loading) {
      content = Center(child: CircularProgressIndicator(color: ec.orange));
    } else if (_error != null) {
      content = _ErrorState(message: _error!, onRetry: _cargar);
    } else {
      content = _buildList(ec);
    }

    // La pantalla se monta como cuerpo de una pestaña; se asegura el fondo del
    // Design System para que el vidrio de las tarjetas se lea correctamente.
    return Container(
      decoration: BoxDecoration(gradient: ec.bgGradient),
      child: content,
    );
  }

  Widget _buildList(EnjoyColors ec) {
    final ciudades = _ciudades;

    return Stack(
      children: [
        Column(
          children: [
            // ── Búsqueda ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: TextField(
                onChanged: (v) => setState(() => _busqueda = v),
                style: EnjoyTheme.body(size: 14, color: ec.text),
                decoration: InputDecoration(
                  hintText: 'Buscar establecimiento...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _busqueda.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => setState(() => _busqueda = ''),
                        )
                      : null,
                ),
              ),
            ),

            // ── Filtro por ciudad (pills) ──
            if (ciudades.isNotEmpty)
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Pill(
                        'Todas',
                        variant: _filtroCiudad == null
                            ? PillVariant.orange
                            : PillVariant.glass,
                        onTap: () => setState(() => _filtroCiudad = null),
                      ),
                    ),
                    ...ciudades.map((c) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Pill(
                            c,
                            variant: _filtroCiudad == c
                                ? PillVariant.orange
                                : PillVariant.glass,
                            onTap: () => setState(() =>
                                _filtroCiudad = _filtroCiudad == c ? null : c),
                          ),
                        )),
                  ],
                ),
              ),

            // ── Contador + permisos ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  Text(
                    '${_filtrados.length} establecimiento${_filtrados.length != 1 ? 's' : ''}',
                    style: EnjoyTheme.body(
                        size: 12, weight: FontWeight.w500, color: ec.textMute),
                  ),
                  const Spacer(),
                  if (_canEdit)
                    const Pill('Editar',
                        variant: PillVariant.orange,
                        icon: Icons.edit_rounded,
                        dense: true),
                  if (_canEditFotos) ...[
                    const SizedBox(width: 6),
                    const Pill('Fotos',
                        variant: PillVariant.blue,
                        icon: Icons.camera_alt_rounded,
                        dense: true),
                  ],
                ],
              ),
            ),

            // ── Lista ──
            Expanded(
              child: _filtrados.isEmpty
                  ? const _EmptyState(
                      icon: Icons.location_city_outlined,
                      titulo: 'Sin establecimientos',
                      subtitulo: 'No se encontraron establecimientos.',
                    )
                  : RefreshIndicator(
                      color: ec.orange,
                      backgroundColor: ec.surfaceTop,
                      onRefresh: _cargar,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: _filtrados.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _EstablecimientoCard(
                          item: _filtrados[i],
                          getDetalle: _getDetalle,
                          getCiudades: _getCiudades,
                          getCategorias: _getCategorias,
                          canEdit: _canEdit || _canEditFotos,
                          canActivar: _canActivar,
                          procesando:
                              _togglingId == _filtrados[i]['_id']?.toString(),
                          onToggle: () => _toggleEstado(_filtrados[i]),
                          onTap: () => _abrirDetalle(_filtrados[i]),
                        ),
                      ),
                    ),
            ),
          ],
        ),
        if (_canCrear)
          Positioned(
            right: 16,
            bottom: 20,
            child: EnjoyButton(
              label: 'Nuevo',
              icon: Icons.add_rounded,
              expand: false,
              dense: true,
              onPressed: _abrirNuevo,
            ),
          ),
      ],
    );
  }
}

// ── Card compacta ─────────────────────────────────────────────────────────────

class _EstablecimientoCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Map<String, dynamic> Function(Map<String, dynamic>) getDetalle;
  final String Function(Map<String, dynamic>) getCiudades;
  final String Function(Map<String, dynamic>) getCategorias;
  final bool canEdit;
  final bool canActivar;
  final bool procesando;
  final VoidCallback? onToggle;
  final VoidCallback onTap;

  const _EstablecimientoCard({
    required this.item,
    required this.getDetalle,
    required this.getCiudades,
    required this.getCategorias,
    required this.canEdit,
    this.canActivar = false,
    this.procesando = false,
    this.onToggle,
    required this.onTap,
  });

  String get _nombre => (item['nombre'] ?? 'Sin nombre').toString();
  bool get _activo => item['estado'] != false && item['activo'] != false;

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final detalle = getDetalle(item);
    final ciudades = getCiudades(item);
    final categorias = getCategorias(item);
    final logoUrl = detalle['logoUrl']?.toString();
    final titulo = detalle['title']?.toString() ?? '';
    final horario = detalle['scheduleLabel']?.toString() ?? '';
    final isTwoForOne = detalle['isTwoForOne'] == true;
    final hasLogo = logoUrl != null && logoUrl.isNotEmpty;

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Logo ──
          if (hasLogo)
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Image.network(
                logoUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const IconBox(Icons.storefront_rounded),
              ),
            )
          else
            const IconBox(Icons.storefront_rounded, accent: true),
          const SizedBox(width: 12),

          // ── Info ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre + estado
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(_nombre,
                          style: EnjoyTheme.heading(size: 14, color: ec.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    Pill(
                      _activo ? 'Activo' : 'Inactivo',
                      variant: _activo ? PillVariant.green : PillVariant.red,
                      dense: true,
                    ),
                    if (canActivar) ...[
                      const SizedBox(width: 2),
                      procesando
                          ? const SizedBox(
                              width: 26,
                              height: 26,
                              child: Center(
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            )
                          : SizedBox(
                              width: 30,
                              height: 30,
                              child: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                tooltip: 'Opciones',
                                icon: Icon(Icons.more_vert_rounded,
                                    size: 20, color: ec.textMute),
                                onSelected: (v) {
                                  if (v == 'toggle') onToggle?.call();
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Row(
                                      children: [
                                        Icon(
                                          _activo
                                              ? Icons.visibility_off_rounded
                                              : Icons.visibility_rounded,
                                          size: 18,
                                          color: _activo ? ec.red : ec.green,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(_activo
                                            ? 'Desactivar'
                                            : 'Activar'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ],
                  ],
                ),

                // Título promo
                if (titulo.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(titulo,
                      style: EnjoyTheme.body(size: 12, color: ec.textSoft),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],

                // Categoría + ciudad
                if (categorias.isNotEmpty || ciudades.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (categorias.isNotEmpty) ...[
                        Icon(Icons.category_rounded,
                            size: 12, color: ec.textMute),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(categorias,
                              style: EnjoyTheme.body(
                                  size: 11, color: ec.textMute),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      if (categorias.isNotEmpty && ciudades.isNotEmpty)
                        Text('  ·  ',
                            style: EnjoyTheme.body(
                                size: 11, color: ec.textMute)),
                      if (ciudades.isNotEmpty) ...[
                        Icon(Icons.location_on_rounded,
                            size: 12, color: ec.textMute),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(ciudades,
                              style: EnjoyTheme.body(
                                  size: 11, color: ec.textMute),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                ],

                // Horario + badges
                if (horario.isNotEmpty || isTwoForOne) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (horario.isNotEmpty) ...[
                        Icon(Icons.schedule_rounded,
                            size: 12, color: ec.textMute),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(horario,
                              style: EnjoyTheme.body(
                                  size: 11, color: ec.textMute),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      if (isTwoForOne) ...[
                        const SizedBox(width: 6),
                        const Pill('2×1',
                            variant: PillVariant.orange, dense: true),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Flecha / acción ──
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4),
            child: Icon(
              canEdit ? Icons.edit_rounded : Icons.chevron_right_rounded,
              size: canEdit ? 16 : 18,
              color: canEdit ? ec.orangeSoft : ec.textMute,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets helpers ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String subtitulo;
  const _EmptyState(
      {required this.icon, required this.titulo, required this.subtitulo});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBox(icon, size: 72, radius: 20, iconSize: 34),
            const SizedBox(height: 16),
            Text(titulo, style: EnjoyTheme.heading(size: 16, color: ec.text)),
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
                size: 72, radius: 20, iconSize: 34, color: ec.red),
            const SizedBox(height: 16),
            Text('Error de conexión',
                style: EnjoyTheme.heading(size: 16, color: ec.text)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: EnjoyTheme.body(size: 13, color: ec.textMute)),
            const SizedBox(height: 20),
            EnjoyButton(
              label: 'Reintentar',
              icon: Icons.refresh_rounded,
              expand: false,
              dense: true,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
