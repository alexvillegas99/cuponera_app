import 'dart:ui' show ImageFilter;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/comentarios_service.dart';
import 'package:enjoy/services/compartidos_service.dart';
import 'package:enjoy/services/cupones_service.dart';
import 'package:flutter/material.dart';
import 'package:enjoy/ui/palette.dart';
import 'package:enjoy/services/comercios_service.dart';
import 'package:enjoy/mappers/comercio_mini.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class ComercioDetalleMiniScreen extends StatefulWidget {
  final String usuarioId;
  const ComercioDetalleMiniScreen({super.key, required this.usuarioId});

  @override
  State<ComercioDetalleMiniScreen> createState() =>
      _ComercioDetalleMiniScreenState();
}

class _ComercioDetalleMiniScreenState
    extends State<ComercioDetalleMiniScreen> {
  final _svc = ComerciosService();
  final _compSvc = CompartidosService();
  final authService = AuthService();
  bool _editandoMiResena = false;
  final _comentSvc = ComentariosService();
  bool _eligibileParaComentar = false;
  Map<String, dynamic>? _miComentario;
  int _myRating = 0;
  final _myCommentCtrl = TextEditingController();
  bool _saving = false;

  List<Map<String, dynamic>> _cuponesDisponibles = [];
  bool _cuponesExpandido = false;

  ComercioMini? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _loadElegibilidad();
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

      try {
        final cupones = await CuponesService().disponiblesParaLocal(
          clienteId,
          widget.usuarioId,
        );
        if (mounted) setState(() => _cuponesDisponibles = cupones);
      } catch (_) {}

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
        _editandoMiResena = mio == null;
      });
    } catch (_) {}
  }

  void _startEditar() => setState(() => _editandoMiResena = true);

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Comentario guardado!')),
      );
      await _load();
      await _loadElegibilidad();
      if (!mounted) return;
      setState(() => _editandoMiResena = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes iniciar sesión.')),
        );
        return;
      }
      await _comentSvc.eliminarMiComentario(
        usuarioId: widget.usuarioId,
        clienteId: clienteId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comentario eliminado.')),
      );
      setState(() {
        _miComentario = null;
        _myRating = 0;
        _myCommentCtrl.text = '';
      });
      await _load();
      await _loadElegibilidad();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─────────────────────────── Sección cupón disponible
  Widget _buildCuponDisponibleSection() {
    final total = _cuponesDisponibles.length;

    if (total == 1) {
      final cupon = _cuponesDisponibles.first;
      final version = cupon['version'] as Map<String, dynamic>? ?? {};
      final nombreVersion = (version['nombre'] ?? 'Cupón').toString();
      final secuencial = cupon['secuencial']?.toString() ?? '';

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Palette.kAccent.withValues(alpha: 0.10),
              Palette.kAccent.withValues(alpha: 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Palette.kAccent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Palette.kAccent, Palette.kAccentLight],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.confirmation_number_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cupón disponible',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Palette.kTitle,
                    ),
                  ),
                  Text(
                    '$nombreVersion · Nº $secuencial',
                    style: const TextStyle(color: Palette.kMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _mostrarQrCupon(cupon),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Palette.kAccent, Palette.kAccentLight],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Palette.kAccent.withOpacity(0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Canjear',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Más de 1 cupón → colapsable
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Palette.kAccent.withValues(alpha: 0.10),
            Palette.kAccent.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.kAccent.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _cuponesExpandido = !_cuponesExpandido),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Palette.kAccent, Palette.kAccentLight],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.confirmation_number_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cupones disponibles para canjear',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Palette.kTitle,
                          ),
                        ),
                        Text(
                          '$total cupones disponibles',
                          style: const TextStyle(
                            color: Palette.kMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _cuponesExpandido
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Palette.kAccent,
                  ),
                ],
              ),
            ),
          ),
          if (_cuponesExpandido) ...[
            Container(height: 1, color: Palette.kAccent.withOpacity(0.15)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                children: _cuponesDisponibles.map((cupon) {
                  final version = cupon['version'] as Map<String, dynamic>? ?? {};
                  final nombreVersion = (version['nombre'] ?? 'Cupón').toString();
                  final secuencial = cupon['secuencial']?.toString() ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombreVersion,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Palette.kTitle,
                                ),
                              ),
                              Text(
                                'Nº $secuencial',
                                style: const TextStyle(
                                  color: Palette.kMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _mostrarQrCupon(cupon),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Palette.kAccent.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Palette.kAccent.withOpacity(0.3),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.qr_code_rounded,
                                    color: Palette.kAccent, size: 15),
                                SizedBox(width: 5),
                                Text(
                                  'Canjear',
                                  style: TextStyle(
                                    color: Palette.kAccent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _mostrarQrCupon(Map<String, dynamic> cupon) {
    final version = cupon['version'] as Map<String, dynamic>? ?? {};
    final nombreVersion = (version['nombre'] ?? 'Cupón').toString();
    final secuencial = cupon['secuencial']?.toString() ?? '';
    final cuponId = cupon['_id']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Palette.kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Palette.kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Palette.kAccent, Palette.kAccentLight],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.confirmation_number_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              nombreVersion,
              style: const TextStyle(
                color: Palette.kTitle,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Nº $secuencial',
              style: const TextStyle(color: Palette.kMuted, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(data: cuponId, size: 200),
            ),
            const SizedBox(height: 16),
            Text(
              'Muestra este QR al comercio para canjear',
              style: const TextStyle(color: Palette.kMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── Helpers de acción

  /// Normaliza cualquier formato de teléfono al formato internacional SIN '+'
  /// que necesita WhatsApp: `wa.me/<número>` y `whatsapp://send?phone=<número>`
  ///
  /// Casos soportados:
  ///   09XXXXXXXX  → 5939XXXXXXXX  (Ecuador local → internacional)
  ///   +5939XX...  → 5939XXXXXXXX  (ya internacional con '+')
  ///   5939XX...   → 5939XXXXXXXX  (ya internacional sin '+')
  String _sanitizePhone(String raw) {
    // Quita todo excepto dígitos y '+'
    final clean = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return clean;

    // Ecuador local: empieza con 0
    if (clean.startsWith('0') && !clean.startsWith('00')) {
      return '593${clean.substring(1)}';
    }

    // Internacional con '+'
    if (clean.startsWith('+')) {
      return clean.substring(1);
    }

    // Ya en formato internacional sin '+'
    return clean;
  }

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
      if (dir.isNotEmpty) '📌 Dirección: ${p.address!.trim()}',
      '',
      '¿Podrían brindarme más información? ¡Gracias!',
    ];
    return parts.join('\n');
  }

  Future<void> _abrirGoogleMaps(double lat, double lng) async {
    final native = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final web = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (await canLaunchUrl(native)) {
      await launchUrl(native);
    } else {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
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

  // ─────────────────────────── Helpers de nombre
  String _placeName(PromoPrincipal? p) {
    if ((p?.placeName ?? '').trim().isNotEmpty) return p!.placeName!.trim();
    return p?.title?.trim() ?? 'Comercio';
  }

  // ─────────────────────────── BUILD
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Palette.kBg,
        body: const Center(
          child: CircularProgressIndicator(color: Palette.kAccent),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Palette.kBg,
        appBar: _plainAppBar('Detalle'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'No se pudo cargar',
                  style: TextStyle(
                    color: Palette.kTitle,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style: const TextStyle(color: Palette.kMuted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_data == null) {
      return Scaffold(
        backgroundColor: Palette.kBg,
        appBar: _plainAppBar('Detalle'),
        body: const Center(child: Text('Sin datos')),
      );
    }

    final p = _data!.promoPrincipal;
    final telefono = _data?.telefono ?? p?.telefono;

    return Scaffold(
      backgroundColor: Palette.kBg,
      body: RefreshIndicator(
        color: Palette.kAccent,
        onRefresh: () async {
          await _load();
          await _loadElegibilidad();
        },
        child: CustomScrollView(
          slivers: [
            _buildSliverHero(context, p, telefono),
            SliverToBoxAdapter(
              child: _buildBody(context, p, telefono),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _plainAppBar(String title) => AppBar(
        title: Text(title),
        backgroundColor: Palette.kSurface,
        foregroundColor: Palette.kTitle,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: Palette.kBorder)),
      );

  // ─────────────────────────── HERO
  SliverAppBar _buildSliverHero(
    BuildContext ctx,
    PromoPrincipal? p,
    String? telefono,
  ) {
    final hasImage = (p?.imageUrl ?? '').isNotEmpty;
    final hasLogo = (p?.logoUrl ?? '').isNotEmpty;

    return SliverAppBar(
      pinned: true,
      expandedHeight: 300,
      backgroundColor: Palette.kAccent,
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
      // Mostrar nombre + back cuando está colapsado
      title: Text(
        _placeName(p),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, size: 22),
        color: Colors.white,
        onPressed: () => Navigator.of(ctx).maybePop(),
      ),
      actions: [
        if (p != null)
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, size: 22),
            color: Colors.white,
            onPressed: () => _sharePromo(p),
          ),
      ],
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background ──
            if (hasImage)
              Image.network(
                p!.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _heroFallback(),
              )
            else
              _heroFallback(),

            // ── Bottom gradient ──
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.10),
                        Colors.black.withOpacity(0.70),
                      ],
                      stops: const [0.30, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // ── Top gradient (status bar legibility) ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: MediaQuery.of(ctx).padding.top + 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.50),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Bottom: logo + name + action pills ──
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo + name
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (hasLogo) ...[
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.85),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.30),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.network(
                              p!.logoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const ColoredBox(
                                color: Colors.white54,
                                child: Icon(
                                  Icons.store_mall_directory_outlined,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _placeName(p),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 21,
                                shadows: [
                                  Shadow(
                                    blurRadius: 10,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                            ),
                            if (p != null &&
                                (p.title ?? '').isNotEmpty &&
                                p.title != p.placeName)
                              Text(
                                p.title!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.80),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Action pills
                  if (_hasActionPills(p, telefono)) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if ((telefono ?? '').isNotEmpty && p != null) ...[
                          Expanded(
                            child: _heroPill(
                              icon: Icons.chat_rounded,
                              label: 'WhatsApp',
                              onTap: () => _openWhatsApp(telefono!, p),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (_data?.lat != null && _data?.lng != null)
                          Expanded(
                            child: _heroPill(
                              icon: Icons.directions_rounded,
                              label: 'Cómo llegar',
                              onTap: () =>
                                  _abrirGoogleMaps(_data!.lat!, _data!.lng!),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasActionPills(PromoPrincipal? p, String? telefono) {
    return ((telefono ?? '').isNotEmpty && p != null) ||
        (_data?.lat != null && _data?.lng != null);
  }

  Widget _heroFallback() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Palette.kPrimary, Color(0xFF1E4080)],
          ),
        ),
      );

  Widget _blurCircleBtn({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.black.withOpacity(0.28),
          shape: const StadiumBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroPill({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.30)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── BODY
  Widget _buildBody(
    BuildContext ctx,
    PromoPrincipal? p,
    String? telefono,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // ── Info card ──
          _buildInfoCard(p),

          // ── Cupón disponible ──
          if (_cuponesDisponibles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildCuponDisponibleSection(),
            ),
          ],

          // ── Descripción ──
          if ((p?.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildSectionCard(
              icon: Icons.info_outline_rounded,
              iconColor: Palette.kPrimary,
              title: 'Acerca del local',
              child: Text(
                p!.description!,
                style: const TextStyle(
                  color: Palette.kMuted,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ),
          ],

          // ── Detalles de la promo ──
          if (_hasPromoDetails(p)) ...[
            const SizedBox(height: 12),
            _buildPromoDetailsCard(p!),
          ],

          // ── Categorías y ciudades ──
          if (_data!.ciudades.isNotEmpty || _data!.categorias.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildChipsCard(),
          ],

          // ── Ubicación ──
          if ((p?.address ?? '').isNotEmpty || _data?.lat != null) ...[
            const SizedBox(height: 12),
            _buildLocationCard(p),
          ],

          // ── Reseñas ──
          const SizedBox(height: 12),
          _buildReviewsBlock(),
        ],
      ),
    );
  }

  bool _hasPromoDetails(PromoPrincipal? p) {
    if (p == null) return false;
    return (p.isTwoForOne == true) ||
        (p.isFlash == true) ||
        (p.startDate != null) ||
        (p.tags.isNotEmpty) ||
        (p.aplicaTodosLosDias == true);
  }

  // ─────────────────────────── SECTION CARD HELPER
  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Palette.kSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: iconColor),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Palette.kTitle,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: Palette.kBorder),
            Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── INFO CARD
  Widget _buildInfoCard(PromoPrincipal? p) {
    if (p == null) return const SizedBox.shrink();
    final safeRating = (_data!.promedioCalificacion.isNaN ||
            _data!.promedioCalificacion.isInfinite)
        ? 0.0
        : _data!.promedioCalificacion.clamp(0.0, 5.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Palette.kSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + badges
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _placeName(p),
                    style: const TextStyle(
                      color: Palette.kTitle,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
                if (p.isFlash == true) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFFF9F1C)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, color: Colors.white, size: 11),
                        SizedBox(width: 2),
                        Text(
                          'FLASH',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (p.isTwoForOne == true) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Palette.kAccent, Palette.kAccentLight],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '2×1',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            if ((p.title ?? '').isNotEmpty && p.title != p.placeName) ...[
              const SizedBox(height: 4),
              Text(
                p.title!,
                style: const TextStyle(color: Palette.kMuted, fontSize: 14),
              ),
            ],

            const SizedBox(height: 12),
            Container(height: 1, color: Palette.kBorder),
            const SizedBox(height: 12),

            // Rating
            Row(
              children: [
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < safeRating.round()
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: Colors.amber,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  safeRating.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Palette.kTitle,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${_data!.totalComentarios})',
                  style: const TextStyle(color: Palette.kMuted, fontSize: 13),
                ),
                if ((p.distanceLabel ?? '').isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Palette.kMuted.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    p.distanceLabel!,
                    style: const TextStyle(
                      color: Palette.kMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),

            // Schedule
            if ((p.scheduleLabel ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 15,
                    color: Palette.kMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      p.scheduleLabel!,
                      style: const TextStyle(
                        color: Palette.kMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Cities inline
            if (_data!.ciudades.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_city_rounded,
                    size: 15,
                    color: Palette.kMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _data!.ciudades.join(' · '),
                      style: const TextStyle(
                        color: Palette.kMuted,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // Categories chips
            if (_data!.categorias.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _data!.categorias
                    .map(
                      (c) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Palette.kPrimary.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          c,
                          style: const TextStyle(
                            color: Palette.kPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── PROMO DETAILS CARD
  Widget _buildPromoDetailsCard(PromoPrincipal p) {
    return _buildSectionCard(
      icon: Icons.local_activity_rounded,
      iconColor: Palette.kAccent,
      title: 'Detalles de la promoción',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.startDate != null && p.endDate != null) ...[
            _detailRow(
              icon: Icons.date_range_rounded,
              iconColor: Palette.kAccent,
              text:
                  '${_fmt(p.startDate!)}  →  ${_fmt(p.endDate!)}',
            ),
          ],
          if (p.isTwoForOne == true) ...[
            if (p.startDate != null) const SizedBox(height: 10),
            _detailRow(
              icon: Icons.people_outline_rounded,
              iconColor: Palette.kAccent,
              text: 'Paga uno, disfruta dos (2×1)',
            ),
          ],
          if (p.isFlash == true) ...[
            const SizedBox(height: 10),
            _detailRow(
              icon: Icons.bolt_rounded,
              iconColor: const Color(0xFFFF6B35),
              text: 'Oferta Flash — por tiempo limitado',
            ),
          ],
          if (p.aplicaTodosLosDias == true) ...[
            const SizedBox(height: 10),
            _detailRow(
              icon: Icons.calendar_today_rounded,
              iconColor: Colors.green,
              text: 'Válida todos los días',
            ),
          ],
          if (p.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: p.tags
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Palette.kField,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Palette.kBorder),
                      ),
                      child: Text(
                        t,
                        style: const TextStyle(
                          color: Palette.kTitle,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              text,
              style: const TextStyle(
                color: Palette.kTitle,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ─────────────────────────── CHIPS CARD
  Widget _buildChipsCard() {
    return _buildSectionCard(
      icon: Icons.label_outline_rounded,
      iconColor: Palette.kPrimary,
      title: 'Categorías y ciudades',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_data!.ciudades.isNotEmpty) ...[
            _chipGroup(
              label: 'Ciudades',
              icon: Icons.location_city_rounded,
              color: Palette.kPrimary,
              items: _data!.ciudades,
            ),
          ],
          if (_data!.ciudades.isNotEmpty && _data!.categorias.isNotEmpty)
            const SizedBox(height: 14),
          if (_data!.categorias.isNotEmpty)
            _chipGroup(
              label: 'Categorías',
              icon: Icons.category_rounded,
              color: Palette.kAccent,
              items: _data!.categorias,
            ),
        ],
      ),
    );
  }

  Widget _chipGroup({
    required String label,
    required IconData icon,
    required Color color,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Palette.kMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: items
              .map(
                (item) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 12, color: color),
                      const SizedBox(width: 4),
                      Text(
                        item,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  // ─────────────────────────── LOCATION CARD
  Widget _buildLocationCard(PromoPrincipal? p) {
    return _buildSectionCard(
      icon: Icons.location_on_rounded,
      iconColor: Colors.redAccent,
      title: 'Ubicación',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((p?.address ?? '').isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.place_rounded,
                    size: 14,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      p!.address!,
                      style: const TextStyle(
                        color: Palette.kTitle,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_data?.lat != null) const SizedBox(height: 14),
          ],
          if (_data?.lat != null && _data?.lng != null)
            GestureDetector(
              onTap: () => _abrirGoogleMaps(_data!.lat!, _data!.lng!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 160,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(_data!.lat!, _data!.lng!),
                          initialZoom: 15,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.enjoy.app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(_data!.lat!, _data!.lng!),
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_pin,
                                  color: Palette.kAccent,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.directions_rounded,
                              size: 14,
                              color: Palette.kAccent,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Cómo llegar',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Palette.kAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────── REVIEWS BLOCK
  Widget _buildReviewsBlock() {
    final safeRating = (_data!.promedioCalificacion.isNaN ||
            _data!.promedioCalificacion.isInfinite)
        ? 0.0
        : _data!.promedioCalificacion.clamp(0.0, 5.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // ── Rating hero card ──
          Container(
            decoration: BoxDecoration(
              color: Palette.kSurface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Opiniones',
                  style: TextStyle(
                    color: Palette.kTitle,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Text(
                  safeRating.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Palette.kTitle,
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < safeRating.round()
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: Colors.amber,
                          size: 15,
                        ),
                      ),
                    ),
                    Text(
                      '${_data!.totalComentarios} reseñas',
                      style: const TextStyle(
                        color: Palette.kMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Mi reseña ──
          _MiResenaCard(
            elegible: _eligibileParaComentar,
            miComentario: _miComentario,
            modoEdicion: _miComentario == null ? true : _editandoMiResena,
            rating: _myRating,
            onRatingChanged: (v) => setState(() => _myRating = v),
            commentCtrl: _myCommentCtrl,
            saving: _saving,
            onGuardar: _guardarMiComentario,
            onEliminar: _miComentario == null ? null : _eliminarMiComentario,
            onEditar: _startEditar,
            onCancelar: _miComentario == null ? null : _cancelarEdicion,
          ),

          // ── Comentarios ──
          if (_data!.comentarios.isNotEmpty) ...[
            const SizedBox(height: 10),
            ..._data!.comentarios.map((c) => _ComentarioTilePro(c: c)),
          ] else ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Palette.kSurface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Palette.kField,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Palette.kMuted,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sin reseñas aún',
                    style: TextStyle(
                      color: Palette.kTitle,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '¡Sé el primero en opinar!',
                    style: TextStyle(color: Palette.kMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Mi reseña card
// ══════════════════════════════════════════════════════════════════
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

  @override
  Widget build(BuildContext context) {
    if (!elegible) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Palette.kSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Palette.kField,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 15,
                color: Palette.kMuted,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Usa al menos una promoción en este local para dejar una reseña.',
                style: TextStyle(color: Palette.kMuted, fontSize: 13),
              ),
            ),
          ],
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Palette.kSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Palette.kPrimary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.rate_review_rounded,
                    size: 15,
                    color: Palette.kPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Tu reseña',
                  style: TextStyle(
                    color: Palette.kTitle,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                // Edit
                GestureDetector(
                  onTap: onEditar,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Palette.kPrimary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_rounded,
                            size: 14, color: Palette.kPrimary),
                        SizedBox(width: 4),
                        Text(
                          'Editar',
                          style: TextStyle(
                            color: Palette.kPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Delete
                if (onEliminar != null)
                  GestureDetector(
                    onTap: onEliminar,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(height: 1, color: Palette.kBorder),
            const SizedBox(height: 10),
            _StarDisplay(value: calif, color: Palette.kPrimary),
            if (texto.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Palette.kField,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Palette.kBorder),
                ),
                child: Text(
                  texto,
                  style: const TextStyle(
                    color: Palette.kMuted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // ── VISTA EDICIÓN / CREACIÓN ──
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Palette.kPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.rate_review_rounded,
                  size: 15,
                  color: Palette.kPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                existe ? 'Editar tu reseña' : 'Escribe tu reseña',
                style: const TextStyle(
                  color: Palette.kTitle,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: Palette.kBorder),
          const SizedBox(height: 12),
          _StarPicker(
            value: rating,
            onChanged: onRatingChanged,
            activeColor: Palette.kAccent,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: commentCtrl,
            maxLines: 3,
            maxLength: 100,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Cuéntanos en pocas palabras… (máx. 100)',
              hintStyle: const TextStyle(color: Palette.kMuted, fontSize: 13),
              filled: true,
              fillColor: Palette.kField,
              border: OutlineInputBorder(
                borderSide: const BorderSide(color: Palette.kBorder),
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Palette.kBorder),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide:
                    const BorderSide(color: Palette.kAccent, width: 1.4),
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.all(12),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: saving ? null : onGuardar,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: saving
                          ? LinearGradient(
                              colors: [
                                Palette.kAccent.withOpacity(0.4),
                                Palette.kAccentLight.withOpacity(0.3),
                              ],
                            )
                          : const LinearGradient(
                              colors: [Palette.kAccent, Palette.kAccentLight],
                            ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: saving
                          ? []
                          : [
                              BoxShadow(
                                color: Palette.kAccent.withOpacity(0.30),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Center(
                      child: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.save_rounded,
                                  color: Colors.white,
                                  size: 17,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  existe ? 'Guardar cambios' : 'Publicar',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              if (onCancelar != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: saving ? null : onCancelar,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Palette.kField,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Palette.kBorder),
                    ),
                    child: const Center(
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          color: Palette.kMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
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

// ══════════════════════════════════════════════════════════════════
// Tile de comentario
// ══════════════════════════════════════════════════════════════════
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Gradient avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Palette.kPrimary, Color(0xFF1E4080)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _initials(c.autorNombre),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.autorNombre ?? 'Anónimo',
                      style: const TextStyle(
                        color: Palette.kTitle,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (c.fecha != null)
                      Text(
                        '${c.fecha!.day.toString().padLeft(2, '0')}/${c.fecha!.month.toString().padLeft(2, '0')}/${c.fecha!.year}',
                        style: const TextStyle(
                          color: Palette.kMuted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              if (c.rating != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 14, color: Colors.amber),
                      const SizedBox(width: 3),
                      Text(
                        c.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Palette.kTitle,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if ((c.texto ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              c.texto!,
              style: const TextStyle(
                color: Palette.kMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Star picker (interactivo)
// ══════════════════════════════════════════════════════════════════
class _StarPicker extends StatelessWidget {
  final int value;
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

// ══════════════════════════════════════════════════════════════════
// Star display (solo lectura)
// ══════════════════════════════════════════════════════════════════
class _StarDisplay extends StatelessWidget {
  final int value;
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
