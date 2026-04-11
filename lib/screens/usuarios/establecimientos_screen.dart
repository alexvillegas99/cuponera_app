import 'package:enjoy/screens/usuarios/establecimiento_detalle_screen.dart';
import 'package:enjoy/services/establecimientos_empresa_service.dart';
import 'package:enjoy/services/permissions_service.dart';
import 'package:enjoy/ui/palette.dart';
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
    await _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _svc.listar();
      if (mounted) setState(() { _items = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'No se pudo cargar los establecimientos.'; _loading = false; });
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Palette.kAccent));
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _cargar);
    }

    final ciudades = _ciudades;

    return Column(
      children: [
        // ── Búsqueda ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _busqueda = v),
            decoration: InputDecoration(
              hintText: 'Buscar establecimiento...',
              hintStyle: const TextStyle(color: Palette.kMuted, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: Palette.kMuted, size: 20),
              suffixIcon: _busqueda.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Palette.kMuted, size: 18),
                      onPressed: () => setState(() => _busqueda = ''),
                    )
                  : null,
              filled: true,
              fillColor: Palette.kSurface,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Palette.kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Palette.kBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.kAccent)),
            ),
          ),
        ),

        // ── Filtro por ciudad ──
        if (ciudades.isNotEmpty)
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _CiudadChip(
                  label: 'Todas',
                  selected: _filtroCiudad == null,
                  onTap: () => setState(() => _filtroCiudad = null),
                ),
                ...ciudades.map((c) => _CiudadChip(
                      label: c,
                      selected: _filtroCiudad == c,
                      onTap: () => setState(() => _filtroCiudad = _filtroCiudad == c ? null : c),
                    )),
              ],
            ),
          ),

        // ── Contador + permisos ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text(
                '${_filtrados.length} establecimiento${_filtrados.length != 1 ? 's' : ''}',
                style: const TextStyle(color: Palette.kMuted, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              if (_canEdit) _PermBadge(label: 'Editar', icon: Icons.edit_rounded, color: Palette.kAccent),
              if (_canEditFotos) ...[
                const SizedBox(width: 6),
                _PermBadge(label: 'Fotos', icon: Icons.camera_alt_rounded, color: Colors.blue.shade600),
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
                  color: Palette.kAccent,
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: _filtrados.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _EstablecimientoCard(
                      item: _filtrados[i],
                      getDetalle: _getDetalle,
                      getCiudades: _getCiudades,
                      getCategorias: _getCategorias,
                      canEdit: _canEdit || _canEditFotos,
                      onTap: () => _abrirDetalle(_filtrados[i]),
                    ),
                  ),
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
  final VoidCallback onTap;

  const _EstablecimientoCard({
    required this.item,
    required this.getDetalle,
    required this.getCiudades,
    required this.getCategorias,
    required this.canEdit,
    required this.onTap,
  });

  String get _nombre => (item['nombre'] ?? 'Sin nombre').toString();
  bool get _activo => item['estado'] != false && item['activo'] != false;

  @override
  Widget build(BuildContext context) {
    final detalle = getDetalle(item);
    final ciudades = getCiudades(item);
    final categorias = getCategorias(item);
    final inicial = _nombre.isNotEmpty ? _nombre[0].toUpperCase() : 'E';
    final logoUrl = detalle['logoUrl']?.toString();
    final titulo = detalle['title']?.toString() ?? '';
    final horario = detalle['scheduleLabel']?.toString() ?? '';
    final isTwoForOne = detalle['isTwoForOne'] == true;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Palette.kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Palette.kBorder),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Logo ──
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Palette.kPrimary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Palette.kBorder),
                ),
                child: (logoUrl != null && logoUrl.isNotEmpty)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.network(
                          logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(inicial,
                                style: const TextStyle(
                                    color: Palette.kPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18)),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(inicial,
                            style: const TextStyle(
                                color: Palette.kPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 18)),
                      ),
              ),
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
                              style: const TextStyle(
                                  color: Palette.kTitle,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: (_activo ? Colors.green : Colors.red).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _activo ? 'Activo' : 'Inactivo',
                            style: TextStyle(
                                color: _activo ? Colors.green.shade700 : Colors.red.shade700,
                                fontSize: 10,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),

                    // Título promo
                    if (titulo.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(titulo,
                          style: const TextStyle(color: Palette.kMuted, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],

                    // Categoría + ciudad
                    if (categorias.isNotEmpty || ciudades.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (categorias.isNotEmpty) ...[
                            const Icon(Icons.category_rounded, size: 11, color: Palette.kMuted),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(categorias,
                                  style: const TextStyle(color: Palette.kMuted, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                          if (categorias.isNotEmpty && ciudades.isNotEmpty)
                            const Text('  ·  ', style: TextStyle(color: Palette.kMuted, fontSize: 11)),
                          if (ciudades.isNotEmpty) ...[
                            const Icon(Icons.location_on_rounded, size: 11, color: Palette.kMuted),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(ciudades,
                                  style: const TextStyle(color: Palette.kMuted, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ],
                      ),
                    ],

                    // Horario + badges
                    if (horario.isNotEmpty || isTwoForOne) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (horario.isNotEmpty) ...[
                            const Icon(Icons.schedule_rounded, size: 11, color: Palette.kMuted),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(horario,
                                  style: const TextStyle(color: Palette.kMuted, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                          if (isTwoForOne) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Palette.kAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text('2×1',
                                  style: TextStyle(
                                      color: Palette.kAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // ── Flecha ──
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  canEdit ? Icons.edit_rounded : Icons.chevron_right_rounded,
                  size: canEdit ? 16 : 18,
                  color: canEdit ? Palette.kAccent : Palette.kBorder,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chip de ciudad ────────────────────────────────────────────────────────────

class _CiudadChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CiudadChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Palette.kAccent : Palette.kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Palette.kAccent : Palette.kBorder),
          boxShadow: selected
              ? [BoxShadow(color: Palette.kAccent.withOpacity(0.25), blurRadius: 6)]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Palette.kMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Widgets helpers ───────────────────────────────────────────────────────────

class _PermBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _PermBadge({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
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
