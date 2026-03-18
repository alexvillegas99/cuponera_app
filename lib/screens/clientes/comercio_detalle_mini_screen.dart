import 'dart:ui' show ImageFilter;
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/comentarios_service.dart';
import 'package:enjoy/services/compartidos_service.dart';
import 'package:enjoy/widgets/action_pill_button.dart';
import 'package:enjoy/widgets/blur_icon_button.dart';
import 'package:enjoy/widgets/corner_logo.dart';
import 'package:enjoy/widgets/frosted_card.dart';
import 'package:flutter/material.dart';
import 'package:enjoy/ui/palette.dart';
import 'package:enjoy/services/comercios_service.dart';
import 'package:enjoy/mappers/comercio_mini.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

// 👇 NUEVO

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
  bool _editandoMiResena = false;
  // 👇 NUEVO
  final _comentSvc = ComentariosService();
  bool _eligibileParaComentar = false;
  Map<String, dynamic>? _miComentario; // { _id, texto, calificacion, ... }
  int _myRating = 0;
  final _myCommentCtrl = TextEditingController();
  bool _saving = false;

  ComercioMini? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _loadElegibilidad(); // en paralelo; no depende del detalle
  }

  @override
  void dispose() {
    _myCommentCtrl.dispose();
    super.dispose();
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

  // ───────────────────────── NUEVO: elegibilidad + mi comentario
  Future<void> _loadElegibilidad() async {
    try {
      final usuario = await authService.getUser();
      final clienteId = usuario?['_id']?.toString();
      if (clienteId == null) {
        setState(() {
          _eligibileParaComentar = false;
          _miComentario = null;
          _myRating = 0;
          _myCommentCtrl.text = '';
          _editandoMiResena = false;
        });
        return;
      }

      final e = await _comentSvc.elegibilidad(
        usuarioId: widget.usuarioId,
        clienteId: clienteId,
      );

      Map<String, dynamic>? mio;
      if (e['tieneComentario'] == true) {
        mio = await _comentSvc.obtenerMiComentario(
          usuarioId: widget.usuarioId,
          clienteId: clienteId,
        );
      }

      setState(() {
        _eligibileParaComentar = e['elegible'] == true;
        _miComentario = mio;
        _myRating = (mio?['calificacion'] is num)
            ? (mio!['calificacion'] as num).toInt()
            : 0;
        _myCommentCtrl.text = (mio?['texto'] ?? '') as String;
        _editandoMiResena =
            mio == null; // si no hay reseña, entra directo en modo crear
      });
    } catch (_) {}
  }

  void _startEditar() {
    setState(() => _editandoMiResena = true);
  }

  void _cancelarEdicion() {
    setState(() {
      _editandoMiResena = false;
      if (_miComentario != null) {
        _myRating = (_miComentario!['calificacion'] as num?)?.toInt() ?? 0;
        _myCommentCtrl.text = (_miComentario!['texto'] ?? '') as String;
      }
    });
  }

  Future<void> _guardarMiComentario() async {
    if (_myRating < 1 || _myRating > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una calificación (1 a 5).')),
      );
      return;
    }
    try {
      setState(() => _saving = true);
      final usuario = await authService.getUser();
      final clienteId = usuario?['_id']?.toString();
      if (clienteId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes iniciar sesión para comentar.')),
        );
        return;
      }

      await _comentSvc.upsertMiComentario(
        usuarioId: widget.usuarioId,
        clienteId: clienteId,
        calificacion: _myRating,
        texto: _myCommentCtrl.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('¡Comentario guardado!')));

      await _load();
      await _loadElegibilidad();
      if (!mounted) return;
      setState(() => _editandoMiResena = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _eliminarMiComentario() async {
    try {
      setState(() => _saving = true);
      final usuario = await authService.getUser();
      final clienteId = usuario?['_id']?.toString();
      if (clienteId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Debes iniciar sesión.')));
        return;
      }

      await _comentSvc.eliminarMiComentario(
        usuarioId: widget.usuarioId,
        clienteId: clienteId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Comentario eliminado.')));

      // Limpiar UI y refrescar
      setState(() {
        _miComentario = null;
        _myRating = 0;
        _myCommentCtrl.text = '';
      });
      await _load();
      await _loadElegibilidad();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
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
    final dir = (p.address ?? '').trim();

    final parts = <String>[
      'Hola 👋, vi este local en ENJOY y me gustaría saber más sobre las promociones que tienen.',
      if (nombre.isNotEmpty) '📍 Local: $nombre',
      if (titulo.isNotEmpty) '⭐ Promo destacada: ${p.title!.trim()}',
      if ((dir).isNotEmpty) '📌 Dirección: ${p.address!.trim()}',
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

    return Scaffold(
      backgroundColor: Palette.kBg,
      body: RefreshIndicator(
        onRefresh: () async {
          await _load();
          await _loadElegibilidad();
        },
        child: CustomScrollView(
          slivers: [
            // ───────────── HEADER con frosted pill
            SliverAppBar(
              pinned: true,
              expandedHeight: 280,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
              systemOverlayStyle: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    HeaderFrosted(
                      promo: p,
                      telefono: telefono,
                      onWhats: (tel, promo) => _openWhatsApp(tel, promo),
                      onShare: (promo) => _sharePromo(promo),
                    ),

                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Container(
                          height: MediaQuery.of(context).padding.top + 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.55),
                                Colors.black.withOpacity(0.20),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if ((p?.logoUrl ?? '').isNotEmpty)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 8,
                        right: 12,
                        child: _CornerLogo(url: p!.logoUrl!),
                      ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 12,
                      child: _BlurBackButton(
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ],
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
                    if (_data!.ciudades.isNotEmpty)
                      ChipsSection(
                        label: 'Ciudades',
                        items: _data!.ciudades,
                        icon: Icons.location_city,
                      ),
                    if (_data!.categorias.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ChipsSection(
                        label: 'Categorías',
                        items: _data!.categorias,
                        icon: Icons.category_outlined,
                      ),
                    ],

                    const SizedBox(height: 14),
                    RatingSummary(
                      rating: _data!.promedioCalificacion,
                      total: _data!.totalComentarios,
                    ),

                    // ───────────── NUEVO: MI RESEÑA
                    const SizedBox(height: 14),
                    _MiResenaCard(
                      elegible: _eligibileParaComentar,
                      miComentario: _miComentario,
                      // si no hay reseña ⇒ modo crear (true). Si hay, controlado por _editandoMiResena
                      modoEdicion: _miComentario == null
                          ? true
                          : _editandoMiResena,
                      rating: _myRating,
                      onRatingChanged: (v) => setState(() => _myRating = v),
                      commentCtrl: _myCommentCtrl,
                      saving: _saving,
                      onGuardar: _guardarMiComentario,
                      onEliminar: _miComentario == null
                          ? null
                          : _eliminarMiComentario,
                      onEditar: _startEditar,
                      onCancelar: _miComentario == null
                          ? null
                          : _cancelarEdicion,
                    ),

                    // Etiquetas
                    // Etiquetas
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
                        children: p!.tags
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
class HeaderFrosted extends StatelessWidget {
  final PromoPrincipal? promo;
  final String? telefono;
  final VoidCallback? onBack;
  final void Function(String tel, PromoPrincipal promo)? onWhats;
  final void Function(PromoPrincipal promo)? onShare;

  const HeaderFrosted({
    super.key,
    required this.promo,
    required this.telefono,
    this.onBack,
    this.onWhats,
    this.onShare,
  });

  bool get _hasImage => (promo?.imageUrl ?? '').isNotEmpty;

  String get _placeName {
    if ((promo?.placeName ?? '').trim().isNotEmpty) {
      return promo!.placeName!.trim();
    }
    return promo?.title?.trim() ?? 'Comercio';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildBackground(),
        _buildTopGradient(context),
        _buildBackButton(context),
        _buildLogo(context),
        _buildInfoCard(),
        _buildActions(),
      ],
    );
  }

  // ───────────────── Background
  Widget _buildBackground() {
    if (_hasImage) {
      return Image.network(promo!.imageUrl!, fit: BoxFit.cover);
    }
    return Container(color: Palette.kField);
  }

  // ───────────────── Top gradient
  Widget _buildTopGradient(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Container(
          height: MediaQuery.of(context).padding.top + 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.55),
                Colors.black.withOpacity(0.20),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────── Back
  Widget _buildBackButton(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      child: BlurIconButton(
        icon: Icons.arrow_back,
        onTap: onBack ?? () => Navigator.of(context).maybePop(),
      ),
    );
  }

  // ───────────────── Logo
  Widget _buildLogo(BuildContext context) {
    if ((promo?.logoUrl ?? '').isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      right: 12,
      child: CornerLogo(url: promo!.logoUrl!),
    );
  }

  // ───────────────── Info frosted card
  Widget _buildInfoCard() {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 70,
      child: FrostedCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _placeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            if ((promo?.title ?? '').isNotEmpty)
              Text(
                promo!.title!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if ((promo?.scheduleLabel ?? '').isNotEmpty)
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
        ),
      ),
    );
  }

  // ───────────────── Actions
  Widget _buildActions() {
    if (promo == null) return const SizedBox.shrink();

    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Row(
        children: [
          if ((telefono ?? '').isNotEmpty && onWhats != null) ...[
            Expanded(
              child: ActionPillButton(
                icon: Icons.chat_outlined,
                label: 'WhatsApp',
                onTap: () => onWhats!(telefono!, promo!),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: ActionPillButton(
              icon: Icons.share_outlined,
              label: 'Compartir',
              onTap: onShare == null ? null : () => onShare!(promo!),
            ),
          ),
        ],
      ),
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
class ChipsSection extends StatelessWidget {
  final String label;
  final List<String> items;
  final IconData? icon;

  const ChipsSection({
    super.key,
    required this.label,
    required this.items,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Palette.kTitle,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: -6,
          children: items.map(_buildChip).toList(),
        ),
      ],
    );
  }

  Widget _buildChip(String text) {
    return Chip(
      avatar: icon != null ? Icon(icon, size: 14) : null,
      label: Text(text, style: const TextStyle(fontSize: 12)),
      side: const BorderSide(color: Palette.kBorder),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: Palette.kField,
    );
  }
}

class RatingSummary extends StatelessWidget {
  final double rating; // 0.0 – 5.0
  final int total;
  final int decimals;

  const RatingSummary({
    super.key,
    required this.rating,
    required this.total,
    this.decimals = 1,
  });

  double get _safeRating {
    if (rating.isNaN || rating.isInfinite) return 0.0;
    return rating.clamp(0.0, 5.0);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.star, size: 18, color: Colors.amber),
        const SizedBox(width: 6),
        Text(
          _safeRating.toStringAsFixed(decimals),
          style: TextStyle(
            color: Palette.kTitle,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '($total)',
          style: TextStyle(color: Palette.kMuted),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// NUEVO: Card de “Mi reseña”
class _MiResenaCard extends StatelessWidget {
  final bool elegible;
  final Map<String, dynamic>? miComentario;
  final bool modoEdicion;
  final int rating;
  final ValueChanged<int> onRatingChanged;
  final TextEditingController commentCtrl;
  final bool saving;
  final VoidCallback onGuardar;
  final VoidCallback? onEliminar;
  final VoidCallback onEditar;
  final VoidCallback? onCancelar;

  const _MiResenaCard({
    required this.elegible,
    required this.miComentario,
    required this.modoEdicion,
    required this.rating,
    required this.onRatingChanged,
    required this.commentCtrl,
    required this.saving,
    required this.onGuardar,
    required this.onEliminar,
    required this.onEditar,
    required this.onCancelar,
  });

  Color get _primary => const Color(0xFF0A3D62); // azul oscurito

  @override
  Widget build(BuildContext context) {
    if (!elegible) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Palette.kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Palette.kBorder),
        ),
        child: Text(
          'Para dejar un comentario debes haber usado al menos una promoción en este local.',
          style: TextStyle(color: Palette.kMuted),
        ),
      );
    }

    final existe = miComentario != null;

    // ── VISTA SOLO LECTURA ──
    if (existe && !modoEdicion) {
      final calif = (miComentario!['calificacion'] as num?)?.toInt() ?? 0;
      final texto = (miComentario!['texto'] ?? '') as String;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Palette.kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Palette.kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Tu reseña',
                  style: TextStyle(
                    color: Palette.kTitle,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: onEliminar,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Eliminar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: BorderSide(color: _primary),
                    shape: const StadiumBorder(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onEditar,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _StarDisplay(value: calif, color: _primary),
            if (texto.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Palette.kField,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Palette.kBorder),
                ),
                child: Text(texto, style: TextStyle(color: Palette.kMuted)),
              ),
            ],
          ],
        ),
      );
    }

    // ── VISTA EDICIÓN / CREACIÓN ──
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            existe ? 'Editar reseña' : 'Escribe tu reseña',
            style: TextStyle(
              color: Palette.kTitle,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          _StarPicker(
            value: rating,
            onChanged: onRatingChanged,
            activeColor: _primary,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: commentCtrl,
            maxLines: 3,
            maxLength: 100, // ← límite 100
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            decoration: InputDecoration(
              hintText: 'Cuéntanos en pocas palabras… (máx. 100)',
              filled: true,
              fillColor: Palette.kField,
              border: OutlineInputBorder(
                borderSide: const BorderSide(color: Palette.kBorder),
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Palette.kBorder),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: _primary, width: 1.4),
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.all(12),
              counterText: '', // oculta contador numérico si prefieres
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: saving ? null : onGuardar,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(existe ? 'Guardar cambios' : 'Publicar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              if (onCancelar != null) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: saving ? null : onCancelar,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Cancelar'),
                  style: TextButton.styleFrom(
                    foregroundColor: _primary,
                    shape: const StadiumBorder(),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
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

class _StarPicker extends StatelessWidget {
  final int value; // 0..5
  final ValueChanged<int> onChanged;
  final Color activeColor;
  const _StarPicker({
    required this.value,
    required this.onChanged,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final idx = i + 1;
        final filled = value >= idx;
        return IconButton(
          onPressed: () => onChanged(idx),
          icon: Icon(
            filled ? Icons.star_rounded : Icons.star_border_rounded,
            size: 28,
          ),
          color: filled ? activeColor : Colors.grey.shade400,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          splashRadius: 22,
        );
      }),
    );
  }
}

// Solo lectura (para la vista read-only)
class _StarDisplay extends StatelessWidget {
  final int value; // 0..5
  final Color color;
  const _StarDisplay({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        5,
        (i) => Icon(
          i < value ? Icons.star_rounded : Icons.star_border_rounded,
          color: i < value ? color : Colors.grey.shade400,
          size: 22,
        ),
      ),
    );
  }
}

class _BlurBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BlurBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.black.withOpacity(0.35),
          shape: const StadiumBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerLogo extends StatelessWidget {
  final String url;
  const _CornerLogo({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const ColoredBox(
            color: Colors.white,
            child: Icon(
              Icons.store_mall_directory_outlined,
              color: Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}
