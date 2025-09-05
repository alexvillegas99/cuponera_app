import 'dart:ui' show ImageFilter;
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/compartidos_service.dart';
import 'package:flutter/material.dart';
import 'package:enjoy/ui/palette.dart';
import 'package:enjoy/services/comercios_service.dart';
import 'package:enjoy/mappers/comercio_mini.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class ComercioDetalleMiniScreen extends StatefulWidget {
  final String usuarioId;
  const ComercioDetalleMiniScreen({super.key, required this.usuarioId});

  @override
  State<ComercioDetalleMiniScreen> createState() =>
      _ComercioDetalleMiniScreenState();
}

class _ComercioDetalleMiniScreenState extends State<ComercioDetalleMiniScreen> {
  final _svc = ComerciosService();
  final _compSvc = CompartidosService();
  final authService = AuthService();
  ComercioMini? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _svc.obtenerInformacionComercioMini(widget.usuarioId);
      if (!mounted) return;
      setState(() => _data = d);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ───────────────────────── helpers de acciones
  String _sanitizePhone(String raw) => raw.replaceAll(RegExp(r'[^0-9+]'), '');

  String _waMessage(PromoPrincipal p) {
    final nombre = (p.placeName ?? '').trim();
    final titulo = (p.title ?? '').trim();
    final horario = (p.scheduleLabel ?? '').trim();
    final dir = (p.address ?? '').trim();

    final parts = <String>[
      'Hola 👋, vi este local en ENJOY:',
      if (nombre.isNotEmpty) '• Nombre: $nombre',
      if (titulo.isNotEmpty) '• Promo: $titulo',
      if (horario.isNotEmpty) '• Horario: $horario',
      if (dir.isNotEmpty) '• Dirección: $dir',
    ];
    return parts.join('\n');
  }

  String buildWhatsAppPromoMsg(PromoPrincipal p) {
    final nombre = (p.placeName ?? '').trim();
    final titulo = (p.title ?? '').trim();
    final horario = (p.scheduleLabel ?? '').trim();
    final dir = (p.address ?? '').trim();

    final parts = <String>[
      'Hola 👋, vi este local en ENJOY y me gustaría saber más sobre las promociones que tienen.',
      if (nombre.isNotEmpty) '📍 Local: $nombre',
      if (titulo.isNotEmpty) '⭐ Promo destacada: ${p.title!.trim()}',
      if ((dir ?? '').trim().isNotEmpty) '📌 Dirección: ${p.address!.trim()}',
      '',
      '¿Podrían brindarme más información? ¡Gracias!',
    ];
    return parts.join('\n');
  }

  Future<void> _openPhone(String phone) async {
    final uri = Uri.parse('tel:${_sanitizePhone(phone)}');
    await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String phone, PromoPrincipal p) async {
    final usuario = await authService.getUser();

    final clienteId = usuario?['_id'];
    final String usuarioId = widget.usuarioId;

    final ph = _sanitizePhone(phone);
    final txt = Uri.encodeComponent(buildWhatsAppPromoMsg(p));
    final native = Uri.parse('whatsapp://send?phone=$ph&text=$txt');
    final web = Uri.parse('https://wa.me/$ph?text=$txt');
    // 1) Registrar el evento
    try {
      await _compSvc.registrar(
        clienteId: clienteId,
        usuarioId: usuarioId,
        canal: CanalCompartir.whatsapp,
        telefonoDestino: ph,
        mensaje: buildWhatsAppPromoMsg(p),
        origen: 'comercio',
        origenId: usuarioId,
      );
    } catch (_) {}

    // 2) Abrir WhatsApp
    if (await canLaunchUrl(native)) {
      await launchUrl(native);
    } else {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sharePromo(PromoPrincipal p) async {
    final text = _waMessage(p);
    final usuario = await authService.getUser();

    final clienteId = usuario?['_id'];
    final String usuarioId = widget.usuarioId;
    // 1) Registrar el evento
    try {
      await _compSvc.registrar(
        clienteId: clienteId,
        usuarioId: usuarioId,
        canal: CanalCompartir.sistema,
        mensaje: text,
        origen: 'comercio',
        origenId: usuarioId,
      );
    } catch (_) {}

    // 2) Abrir share sheet
    await Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Palette.kBg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: Palette.kBg,
        appBar: AppBar(
          title: const Text('Detalle'),
          backgroundColor: Palette.kSurface,
          foregroundColor: Palette.kTitle,
        ),
        body: Center(child: Text(_error!, textAlign: TextAlign.center)),
      );
    }
    if (_data == null) {
      return Scaffold(
        backgroundColor: Palette.kBg,
        appBar: AppBar(
          title: const Text('Detalle'),
          backgroundColor: Palette.kSurface,
          foregroundColor: Palette.kTitle,
        ),
        body: const Center(child: Text('Sin datos')),
      );
    }

    final p = _data!.promoPrincipal;
    final telefono = _data?.telefono ?? _data?.promoPrincipal?.telefono;
    final placeName = (p?.placeName?.trim().isNotEmpty ?? false)
        ? p!.placeName!.trim()
        : (p?.title?.trim() ?? 'Comercio');

    return Scaffold(
      backgroundColor: Palette.kBg,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            // ───────────── HEADER con frosted pill
            SliverAppBar(
              pinned: true,
              expandedHeight: 280,
              backgroundColor: Palette.kSurface,
              foregroundColor: Palette.kTitle,
              title: Text('', maxLines: 1, overflow: TextOverflow.ellipsis),
              flexibleSpace: FlexibleSpaceBar(
                background: _HeaderFrosted(
                  p: p,
                  telefono: telefono,
                  onCall: (tel) => _openPhone(tel),
                  onWhats: (tel, promo) => _openWhatsApp(tel, promo),
                  onShare: (promo) => _sharePromo(promo),
                ),
              ),
            ),

            // ───────────── CONTENIDO
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chips de ciudades y categorías
                    if (_data!.ciudades.isNotEmpty)
                      _ChipsSection(
                        label: 'Ciudades',
                        items: _data!.ciudades,
                        icon: Icons.location_city,
                      ),
                    if (_data!.categorias.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _ChipsSection(
                        label: 'Categorías',
                        items: _data!.categorias,
                        icon: Icons.category_outlined,
                      ),
                    ],

                    const SizedBox(height: 14),
                    _RatingResumen(
                      rating: _data!.promedioCalificacion,
                      total: _data!.totalComentarios,
                    ),

                    // Etiquetas de la promo
                    if (p != null && p.tags.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Etiquetas',
                        style: TextStyle(
                          color: Palette.kTitle,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: -6,
                        children: p.tags
                            .map(
                              (t) => Chip(
                                label: Text(
                                  t,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                side: const BorderSide(color: Palette.kBorder),
                                backgroundColor: Palette.kField,
                              ),
                            )
                            .toList(),
                      ),
                    ],

                    // Descripción
                    if ((p?.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Descripción',
                        style: TextStyle(
                          color: Palette.kTitle,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p!.description!,
                        style: TextStyle(color: Palette.kMuted),
                      ),
                    ],

                    // Dirección
                    if ((p?.address ?? '').isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Dirección',
                        style: TextStyle(
                          color: Palette.kTitle,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              p!.address!,
                              style: TextStyle(color: Palette.kMuted),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Comentarios
                    const SizedBox(height: 18),
                    if (_data!.comentarios.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Comentarios',
                            style: TextStyle(
                              color: Palette.kTitle,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${_data!.comentarios.length}',
                            style: TextStyle(color: Palette.kMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._data!.comentarios.map(
                        (c) => _ComentarioTilePro(c: c),
                      ),
                    ] else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Palette.kSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Palette.kBorder),
                        ),
                        child: Text(
                          'Aún no hay comentarios',
                          style: TextStyle(color: Palette.kMuted),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Header con “frosted pill” + acciones
class _HeaderFrosted extends StatelessWidget {
  final PromoPrincipal? p;
  final String? telefono;
  final void Function(String tel)? onCall;
  final void Function(String tel, PromoPrincipal promo)? onWhats;
  final void Function(PromoPrincipal promo)? onShare;

  const _HeaderFrosted({
    required this.p,
    required this.telefono,
    this.onCall,
    this.onWhats,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final promo = p;
    final hasImage = (promo?.imageUrl ?? '').isNotEmpty;
    final hasLogo = (promo?.logoUrl ?? '').isNotEmpty;
    final placeName = (promo?.placeName?.trim().isNotEmpty ?? false)
        ? promo!.placeName!.trim()
        : (promo?.title?.trim() ?? 'Comercio');

    return Stack(
      fit: StackFit.expand,
      children: [
        // Fondo
        if (hasImage)
          Image.network(promo!.imageUrl!, fit: BoxFit.cover)
        else
          Container(color: Palette.kField),

        // Logo circular
        Positioned(
          left: 16,
          bottom: 116,
          child: CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white,
            backgroundImage: hasLogo ? NetworkImage(promo!.logoUrl!) : null,
            child: !hasLogo
                ? const Icon(
                    Icons.store_mall_directory_outlined,
                    color: Colors.black54,
                  )
                : null,
          ),
        ),

        // “Píldora” frosted con texto
        Positioned(
          left: 12,
          right: 12,
          bottom: 70,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.28),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      placeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    if ((promo?.title ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        promo!.title!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if ((promo?.scheduleLabel ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              promo!.scheduleLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),

        // Acciones
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Row(
            children: [
              if ((telefono ?? '').isNotEmpty && promo != null) ...[
                Expanded(
                  child: _ActionPillButton(
                    icon: Icons.chat_outlined,
                    label: 'WhatsApp',
                    onTap: onWhats == null
                        ? null
                        : () => onWhats!(telefono!, promo),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _ActionPillButton(
                  icon: Icons.share_outlined,
                  label: 'Compartir',
                  onTap: promo == null || onShare == null
                      ? null
                      : () => onShare!(promo),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionPillButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final bg = enabled ? Colors.white : Colors.white.withOpacity(0.6);
    final fg = enabled ? Colors.black87 : Colors.black38;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.black12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: fg, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Bloques auxiliares del cuerpo
class _ChipsSection extends StatelessWidget {
  final String label;
  final List<String> items;
  final IconData icon;
  const _ChipsSection({
    required this.label,
    required this.items,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: -6,
          children: items
              .map(
                (t) => Chip(
                  avatar: Icon(icon, size: 14),
                  label: Text(t, style: const TextStyle(fontSize: 12)),
                  side: const BorderSide(color: Palette.kBorder),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: Palette.kField,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _RatingResumen extends StatelessWidget {
  final double rating;
  final int total;
  const _RatingResumen({required this.rating, required this.total});

  @override
  Widget build(BuildContext context) {
    final r = (rating.isNaN ? 0.0 : rating).clamp(0.0, 5.0);
    return Row(
      children: [
        const Icon(Icons.star, size: 18, color: Colors.amber),
        const SizedBox(width: 6),
        Text(
          r.toStringAsFixed(1),
          style: TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 6),
        Text('($total)', style: TextStyle(color: Palette.kMuted)),
      ],
    );
  }
}

class _ComentarioTilePro extends StatelessWidget {
  final ComentarioMini c;
  const _ComentarioTilePro({required this.c});

  String _initials(String? name) {
    final n = (name ?? '').trim();
    if (n.isEmpty) return 'A';
    final parts = n.split(RegExp(r'\s+'));
    final first = parts.isNotEmpty ? parts.first.characters.first : 'A';
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Palette.kField,
                child: Text(
                  _initials(c.autorNombre),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  c.autorNombre ?? 'Anónimo',
                  style: TextStyle(
                    color: Palette.kTitle,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (c.rating != null)
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(c.rating!.toStringAsFixed(1)),
                  ],
                ),
            ],
          ),
          if ((c.texto ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(c.texto!, style: TextStyle(color: Palette.kMuted)),
            ),
          if (c.fecha != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    '${c.fecha!.day.toString().padLeft(2, '0')}/${c.fecha!.month.toString().padLeft(2, '0')}/${c.fecha!.year}',
                    style: TextStyle(color: Palette.kMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
