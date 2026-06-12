import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/comentarios_service.dart';
import 'package:enjoy/services/compartidos_service.dart';
import 'package:enjoy/services/cupones_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:enjoy/services/comercios_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:enjoy/mappers/comercio_mini.dart';
import 'package:enjoy/screens/clientes/promocion_flash_detalle_screen.dart';
import 'package:enjoy/models/producto.dart';
import 'package:enjoy/utils/distancia.dart';
import 'package:enjoy/widgets/galeria_media_view.dart';
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
  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    _load();
    _loadElegibilidad();
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
      });
    } catch (_) {}
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
        if (!mounted) return;
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
        if (!mounted) return;
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
    final ec = context.ec;
    final total = _cuponesDisponibles.length;

    if (total == 1) {
      final cupon = _cuponesDisponibles.first;
      final version = cupon['version'] as Map<String, dynamic>? ?? {};
      final nombreVersion = (version['nombre'] ?? 'Cupón').toString();
      final secuencial = cupon['secuencial']?.toString() ?? '';

      return GlassCard(
        accent: true,
        padding: const EdgeInsets.all(14),
        radius: 18,
        child: Row(
          children: [
            IconBox(Icons.confirmation_number_rounded, accent: true, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cupón disponible',
                    style: EnjoyTheme.heading(size: 14, color: ec.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$nombreVersion · Nº $secuencial',
                    style: EnjoyTheme.body(size: 12, color: ec.textMute),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            EnjoyButton(
              label: 'Canjear',
              icon: Icons.qr_code_rounded,
              dense: true,
              expand: false,
              onPressed: () => _mostrarQrCupon(cupon),
            ),
          ],
        ),
      );
    }

    // Más de 1 cupón → colapsable
    return GlassCard(
      accent: true,
      padding: EdgeInsets.zero,
      radius: 18,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _cuponesExpandido = !_cuponesExpandido),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  IconBox(Icons.confirmation_number_rounded,
                      accent: true, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cupones disponibles para canjear',
                          style: EnjoyTheme.heading(size: 14, color: ec.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$total cupones disponibles',
                          style:
                              EnjoyTheme.body(size: 12, color: ec.textMute),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _cuponesExpandido
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: ec.orange,
                  ),
                ],
              ),
            ),
          ),
          if (_cuponesExpandido) ...[
            Container(height: 1, color: ec.orange.withValues(alpha: 0.18)),
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
                                style: EnjoyTheme.heading(
                                    size: 13,
                                    weight: FontWeight.w600,
                                    color: ec.text),
                              ),
                              Text(
                                'Nº $secuencial',
                                style: EnjoyTheme.body(
                                    size: 11, color: ec.textMute),
                              ),
                            ],
                          ),
                        ),
                        EnjoyButton(
                          label: 'Canjear',
                          icon: Icons.qr_code_rounded,
                          variant: EnjoyButtonVariant.ghost,
                          dense: true,
                          expand: false,
                          onPressed: () => _mostrarQrCupon(cupon),
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
    final ec = context.ec;
    final version = cupon['version'] as Map<String, dynamic>? ?? {};
    final nombreVersion = (version['nombre'] ?? 'Cupón').toString();
    final secuencial = cupon['secuencial']?.toString() ?? '';
    final cuponId = cupon['_id']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: ec.surfaceMid,
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
                color: ec.strokeStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            IconBox(Icons.confirmation_number_rounded, accent: true, size: 44),
            const SizedBox(height: 12),
            Text(
              nombreVersion,
              style: EnjoyTheme.heading(
                  size: 18, weight: FontWeight.w800, color: ec.text),
            ),
            const SizedBox(height: 4),
            Text(
              'Nº $secuencial',
              style: EnjoyTheme.body(size: 14, color: ec.textMute),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: QrImageView(data: cuponId, size: 200),
            ),
            const SizedBox(height: 16),
            Text(
              'Muestra este QR al comercio para canjear',
              style: EnjoyTheme.body(size: 13, color: ec.textMute),
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

  String _waMessage(PromoPrincipal? p) {
    final nombre = (p?.placeName ?? p?.title ?? _placeName(p)).trim();
    final titulo = (p?.title ?? '').trim();
    final horario = (p?.scheduleLabel ?? '').trim();
    final dir = (p?.address ?? '').trim();
    final parts = <String>[
      'Hola 👋, vi este local en ENJOY:',
      if (nombre.isNotEmpty) '• Nombre: $nombre',
      if (titulo.isNotEmpty && titulo != nombre) '• Promo: $titulo',
      if (horario.isNotEmpty) '• Horario: $horario',
      if (dir.isNotEmpty) '• Dirección: $dir',
    ];
    return parts.join('\n');
  }

  String buildWhatsAppPromoMsg(PromoPrincipal? p) {
    final nombre = (p?.placeName ?? p?.title ?? _placeName(p)).trim();
    final titulo = (p?.title ?? '').trim();
    final dir = (p?.address ?? '').trim();
    final parts = <String>[
      'Hola 👋, vi este local en ENJOY y me gustaría saber más sobre las promociones que tienen.',
      if (nombre.isNotEmpty) '📍 Local: $nombre',
      if (titulo.isNotEmpty && titulo != nombre) '⭐ Promo destacada: $titulo',
      if (dir.isNotEmpty) '📌 Dirección: $dir',
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

  Future<void> _openWhatsApp(String phone, PromoPrincipal? p) async {
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

  Future<void> _sharePromo(PromoPrincipal? p) async {
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
    await SharePlus.instance.share(ShareParams(text: text));
  }

  // ─────────────────────────── Helpers de nombre
  String _placeName(PromoPrincipal? p) {
    if ((p?.placeName ?? '').trim().isNotEmpty) return p!.placeName!.trim();
    return p?.title?.trim() ?? 'Comercio';
  }

  // ─────────────────────────── BUILD
  @override
  Widget build(BuildContext context) {
    final ec = context.ec;

    if (_loading) {
      return EnjoyScaffold(
        body: Center(child: CircularProgressIndicator(color: ec.orange)),
      );
    }

    if (_error != null) {
      return EnjoyScaffold(
        appBar: const EnjoyAppBar(title: 'Detalle'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconBox(Icons.error_outline_rounded,
                    size: 56, iconSize: 28, color: ec.red),
                const SizedBox(height: 14),
                Text(
                  'No se pudo cargar',
                  style: EnjoyTheme.heading(size: 16, color: ec.text),
                ),
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style: EnjoyTheme.body(size: 13, color: ec.textMute),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_data == null) {
      return EnjoyScaffold(
        appBar: const EnjoyAppBar(title: 'Detalle'),
        body: Center(
            child: Text('Sin datos',
                style: EnjoyTheme.body(color: ec.textMute))),
      );
    }

    final p = _data!.promoPrincipal;
    final telefono = _data?.telefono ?? p?.telefono;

    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      safeTop: false,
      showGlow: false,
      // bottomBar temporalmente desactivado (se estiraba/sobreponía). Las
      // acciones "Cómo llegar / Canjear" van ahora al final del cuerpo.
      // bottomBar: _buildBottomBar(ec, p, telefono),
      body: RefreshIndicator(
        color: ec.orange,
        backgroundColor: ec.surfaceMid,
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

  // ─────────────────────────── BOTTOM BAR (Cómo llegar / Canjear)
  // ignore: unused_element
  Widget? _buildBottomBar(
      EnjoyColors ec, PromoPrincipal? p, String? telefono) {
    final hasMaps = _data?.lat != null && _data?.lng != null;
    final hasCupon = _cuponesDisponibles.isNotEmpty;
    if (!hasMaps && !hasCupon) return null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ec.bgBottom.withValues(alpha: 0), ec.bgBottom],
          stops: const [0.0, 0.4],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          child: Row(
            children: [
              if (hasMaps) ...[
                Expanded(
                  child: EnjoyButton(
                    label: 'Cómo llegar',
                    icon: Icons.directions_rounded,
                    variant: EnjoyButtonVariant.ghost,
                    dense: true,
                    onPressed: () =>
                        _abrirGoogleMaps(_data!.lat!, _data!.lng!),
                  ),
                ),
                if (hasCupon) const SizedBox(width: 10),
              ],
              if (hasCupon)
                Expanded(
                  flex: hasMaps ? 1 : 1,
                  child: EnjoyButton(
                    label: 'Canjear cupón',
                    icon: Icons.qr_code_rounded,
                    dense: true,
                    onPressed: () =>
                        _mostrarQrCupon(_cuponesDisponibles.first),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── HERO
  SliverAppBar _buildSliverHero(
    BuildContext ctx,
    PromoPrincipal? p,
    String? telefono,
  ) {
    final ec = ctx.ec;
    final hasImage = (p?.imageUrl ?? '').isNotEmpty;
    final hasLogo = (p?.logoUrl ?? '').isNotEmpty;

    return SliverAppBar(
      pinned: true,
      expandedHeight: 300,
      backgroundColor: ec.bgBottom,
      foregroundColor: ec.text,
      automaticallyImplyLeading: false,
      // El nombre solo aparece en la barra cuando el hero está colapsado
      // (cuando está expandido se muestra sobre la imagen, abajo).
      titleSpacing: 0,
      title: _CollapsedHeroTitle(
        text: _placeName(p),
        style: EnjoyTheme.heading(size: 17, color: ec.text),
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: BackChip(onTap: () => Navigator.of(ctx).maybePop()),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GlassIconButton(
            icon: Icons.ios_share_rounded,
            onTap: () => _sharePromo(p),
          ),
        ),
      ],
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            ec.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: ec.isDark ? Brightness.dark : Brightness.light,
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background: carrusel de la galería. Fallback a imageUrl/inicial. ──
            if ((p?.galeria ?? const []).isNotEmpty)
              GaleriaHeroView(
                items: p!.galeria,
                fallbackImageUrl: hasImage ? p.imageUrl : null,
              )
            else if (hasImage)
              EnjoyImage(
                p!.imageUrl!,
                fit: BoxFit.cover,
                errorWidget: _heroFallback(ec),
              )
            else
              _heroFallback(ec),

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
                        ec.bgBottom.withValues(alpha: 0.10),
                        ec.bgBottom,
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
                        Colors.black.withValues(alpha: 0.45),
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
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(
                              color: ec.text.withValues(alpha: 0.85),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.30),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: EnjoyImage(
                            p!.logoUrl!,
                            fit: BoxFit.cover,
                            errorWidget: ColoredBox(
                              color: ec.iconGlassBottom,
                              child: Icon(
                                Icons.store_mall_directory_outlined,
                                color: ec.orangeSoft,
                                size: 26,
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
                              style: EnjoyTheme.heading(
                                size: 21,
                                weight: FontWeight.w800,
                                color: Colors.white,
                              ).copyWith(
                                shadows: const [
                                  Shadow(
                                      blurRadius: 10, color: Colors.black54),
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
                                style: EnjoyTheme.body(
                                  size: 13,
                                  weight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.80),
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
                        if ((telefono ?? '').isNotEmpty) ...[
                          Expanded(
                            child: EnjoyButton(
                              label: 'WhatsApp',
                              icon: Icons.chat_rounded,
                              variant: EnjoyButtonVariant.green,
                              dense: true,
                              onPressed: () => _openWhatsApp(telefono!, p),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (_data?.lat != null && _data?.lng != null)
                          Expanded(
                            child: EnjoyButton(
                              label: 'Cómo llegar',
                              icon: Icons.directions_rounded,
                              variant: EnjoyButtonVariant.ghost,
                              dense: true,
                              onPressed: () =>
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
    return (telefono ?? '').isNotEmpty ||
        (_data?.lat != null && _data?.lng != null);
  }

  Widget _heroFallback(EnjoyColors ec) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ec.iconGlassTop, ec.iconGlassBottom],
          ),
        ),
      );

  // ─────────────────────────── BODY
  Widget _buildBody(
    BuildContext ctx,
    PromoPrincipal? p,
    String? telefono,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
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
              iconColor: ctx.ec.blue,
              title: 'Acerca del local',
              child: Text(
                p!.description!,
                style: EnjoyTheme.body(
                    size: 14, color: ctx.ec.textSoft, height: 1.55),
              ),
            ),
          ],

          // ── Detalles de la promo ──
          if (_hasPromoDetails(p)) ...[
            const SizedBox(height: 12),
            _buildPromoDetailsCard(p!),
          ],

          // ── Promociones flash del local ──
          if ((_data?.promocionesFlash ?? const []).isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildFlashSection(_data!.promocionesFlash),
          ],

          // ── Catálogo (productos/servicios del local) ──
          if ((p?.productos ?? const []).isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildCatalogoCard(p!.productos),
          ],

          // ── Ubicación ──
          if ((p?.address ?? '').isNotEmpty || _data?.lat != null) ...[
            const SizedBox(height: 12),
            _buildLocationCard(p),
          ],

          // ── Contacto ──
          if ((telefono ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildContactoCard(telefono!, p),
          ],

          // ── Reseñas ──
          const SizedBox(height: 12),
          _buildReviewsBlock(),

          // ── Acciones (Cómo llegar / Canjear cupón) ──
          if ((_data?.lat != null && _data?.lng != null) ||
              _cuponesDisponibles.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (_data?.lat != null && _data?.lng != null)
                    Expanded(
                      child: EnjoyButton(
                        label: 'Cómo llegar',
                        icon: Icons.directions_rounded,
                        variant: EnjoyButtonVariant.ghost,
                        onPressed: () =>
                            _abrirGoogleMaps(_data!.lat!, _data!.lng!),
                      ),
                    ),
                  if ((_data?.lat != null && _data?.lng != null) &&
                      _cuponesDisponibles.isNotEmpty)
                    const SizedBox(width: 10),
                  if (_cuponesDisponibles.isNotEmpty)
                    Expanded(
                      child: EnjoyButton(
                        label: 'Canjear cupón',
                        icon: Icons.qr_code_rounded,
                        onPressed: () =>
                            _mostrarQrCupon(_cuponesDisponibles.first),
                      ),
                    ),
                ],
              ),
            ),
          ],
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
    final ec = context.ec;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassCard(
        padding: EdgeInsets.zero,
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
                      color: iconColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 16, color: iconColor),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: EnjoyTheme.heading(size: 15, color: ec.text),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: ec.stroke),
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
  // Cabecera del local. Usa SIEMPRE los datos a nivel COMERCIO
  // (nombre, rating, ciudades, categorías, distancia). Los badges/título de
  // la promo solo se muestran si existe `promoPrincipal`, pero la tarjeta
  // nunca se oculta por su ausencia.
  Widget _buildInfoCard(PromoPrincipal? p) {
    final ec = context.ec;
    final safeRating = (_data!.promedioCalificacion.isNaN ||
            _data!.promedioCalificacion.isInfinite)
        ? 0.0
        : _data!.promedioCalificacion.clamp(0.0, 5.0);
    final scheduleLabel = (p?.scheduleLabel ?? '').trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassCard(
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
                    style: EnjoyTheme.heading(
                        size: 20, weight: FontWeight.w800, color: ec.text),
                  ),
                ),
                if (p?.isFlash == true) ...[
                  const SizedBox(width: 8),
                  Pill('FLASH',
                      variant: PillVariant.orange,
                      icon: Icons.bolt_rounded,
                      dense: true),
                ],
                if (p?.isTwoForOne == true) ...[
                  const SizedBox(width: 6),
                  Pill('2×1', variant: PillVariant.orange, dense: true),
                ],
              ],
            ),

            if (p != null &&
                (p.title ?? '').isNotEmpty &&
                p.title != p.placeName) ...[
              const SizedBox(height: 4),
              Text(
                p.title!,
                style: EnjoyTheme.body(size: 14, color: ec.textSoft),
              ),
            ],

            const EnjoyDivider(height: 24),

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
                  style: EnjoyTheme.heading(size: 14, color: ec.text),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${_data!.totalComentarios})',
                  style: EnjoyTheme.body(size: 13, color: ec.textMute),
                ),
                if ((distanciaLabel(_userLat, _userLng, _data?.lat, _data?.lng) ??
                        p?.distanceLabel ??
                        '')
                    .isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: ec.textMute.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    distanciaLabel(_userLat, _userLng, _data?.lat, _data?.lng) ??
                        p!.distanceLabel!,
                    style: EnjoyTheme.body(size: 13, color: ec.textSoft),
                  ),
                ],
              ],
            ),

            // Schedule
            if (scheduleLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time_rounded,
                      size: 15, color: ec.textSoft),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      scheduleLabel,
                      style: EnjoyTheme.body(size: 13, color: ec.textSoft),
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
                  Icon(Icons.location_city_rounded,
                      size: 15, color: ec.textSoft),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _data!.ciudades.join(' · '),
                      style: EnjoyTheme.body(size: 13, color: ec.textSoft),
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
                    .map((c) =>
                        Pill(c, variant: PillVariant.blue, dense: true))
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
    final ec = context.ec;
    return _buildSectionCard(
      icon: Icons.local_activity_rounded,
      iconColor: ec.orange,
      title: 'Detalles de la promoción',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.startDate != null && p.endDate != null) ...[
            _detailRow(
              icon: Icons.date_range_rounded,
              iconColor: ec.orange,
              text: '${_fmt(p.startDate!)}  →  ${_fmt(p.endDate!)}',
            ),
          ],
          if (p.isTwoForOne == true) ...[
            if (p.startDate != null) const SizedBox(height: 10),
            _detailRow(
              icon: Icons.people_outline_rounded,
              iconColor: ec.orange,
              text: 'Paga uno, disfruta dos (2×1)',
            ),
          ],
          if (p.isFlash == true) ...[
            const SizedBox(height: 10),
            _detailRow(
              icon: Icons.bolt_rounded,
              iconColor: ec.orange,
              text: 'Oferta Flash — por tiempo limitado',
            ),
          ],
          if (p.aplicaTodosLosDias == true) ...[
            const SizedBox(height: 10),
            _detailRow(
              icon: Icons.calendar_today_rounded,
              iconColor: ec.green,
              text: 'Válida todos los días',
            ),
          ],
          if (p.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: p.tags
                  .map((t) => Pill(t, variant: PillVariant.glass, dense: true))
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
    final ec = context.ec;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              text,
              style: EnjoyTheme.body(
                  size: 13, weight: FontWeight.w500, color: ec.text),
            ),
          ),
        ),
      ],
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ─────────────────────────── PROMOCIONES FLASH
  String _flashRestante(DateTime? vence) {
    if (vence == null) return '';
    final diff = vence.toLocal().difference(DateTime.now());
    if (diff.isNegative) return 'Finalizada';
    if (diff.inDays >= 1) return 'Termina en ${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inHours >= 1) return 'Termina en ${diff.inHours}h';
    return 'Termina en ${diff.inMinutes}m';
  }

  Widget _buildFlashSection(List<PromoFlashMini> flashes) {
    final ec = context.ec;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconBox(Icons.bolt_rounded,
                    accent: true, size: 32, radius: 9, iconSize: 16),
                const SizedBox(width: 10),
                Text('Promociones flash',
                    style: EnjoyTheme.heading(size: 15, color: ec.text)),
              ],
            ),
            const SizedBox(height: 12),
            ...flashes.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PromocionFlashDetalleScreen(promocionId: f.id),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: f.imagenUrl.isNotEmpty
                                ? EnjoyImage(f.imagenUrl, fit: BoxFit.cover)
                                : Container(color: ec.glass),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.titulo,
                                  style: EnjoyTheme.heading(
                                      size: 14, color: ec.text),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(_flashRestante(f.vence),
                                  style: EnjoyTheme.body(
                                      size: 12, color: ec.orangeSoft)),
                            ],
                          ),
                        ),
                        if (f.canjeable)
                          Pill('Canjeable',
                              variant: PillVariant.orange, dense: true),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right_rounded,
                            color: ec.textMute, size: 20),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── CATÁLOGO CARD
  Widget _buildCatalogoCard(List<Producto> productos) {
    return _buildSectionCard(
      icon: Icons.shopping_bag_rounded,
      iconColor: context.ec.orange,
      title: 'Catálogo',
      child: _CatalogoCarousel(productos: productos),
    );
  }

  // ─────────────────────────── LOCATION CARD
  Widget _buildLocationCard(PromoPrincipal? p) {
    final ec = context.ec;
    return _buildSectionCard(
      icon: Icons.location_on_rounded,
      iconColor: ec.red,
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
                    color: ec.red.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(Icons.place_rounded, size: 14, color: ec.red),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      p!.address!,
                      style:
                          EnjoyTheme.body(size: 13, color: ec.text, height: 1.5),
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
                borderRadius: BorderRadius.circular(14),
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
                                child: Icon(
                                  Icons.location_pin,
                                  color: ec.orange,
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
                      child: Pill(
                        'Cómo llegar',
                        variant: PillVariant.orange,
                        icon: Icons.directions_rounded,
                        dense: true,
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

  // ─────────────────────────── CONTACTO CARD
  Widget _buildContactoCard(String telefono, PromoPrincipal? p) {
    final ec = context.ec;
    return _buildSectionCard(
      icon: Icons.call_rounded,
      iconColor: ec.green,
      title: 'Contacto',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: ec.green.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.phone_rounded, size: 14, color: ec.green),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  telefono,
                  style: EnjoyTheme.body(
                      size: 14, weight: FontWeight.w600, color: ec.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          EnjoyButton(
            label: 'Escribir por WhatsApp',
            icon: Icons.chat_rounded,
            variant: EnjoyButtonVariant.green,
            dense: true,
            onPressed: () => _openWhatsApp(telefono, p),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── REVIEWS BLOCK
  Widget _buildReviewsBlock() {
    final ec = context.ec;
    final safeRating = (_data!.promedioCalificacion.isNaN ||
            _data!.promedioCalificacion.isInfinite)
        ? 0.0
        : _data!.promedioCalificacion.clamp(0.0, 5.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // ── Rating hero card ──
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.star_rounded,
                      size: 16, color: Colors.amber),
                ),
                const SizedBox(width: 10),
                Text(
                  'Opiniones',
                  style: EnjoyTheme.heading(size: 15, color: ec.text),
                ),
                const Spacer(),
                Text(
                  safeRating.toStringAsFixed(1),
                  style: EnjoyTheme.heading(
                      size: 28, weight: FontWeight.w800, color: ec.text),
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
                      style: EnjoyTheme.body(size: 11, color: ec.textMute),
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
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  IconBox(Icons.chat_bubble_outline_rounded,
                      size: 40, iconSize: 20, color: ec.textMute),
                  const SizedBox(height: 8),
                  Text(
                    'Sin reseñas aún',
                    style: EnjoyTheme.heading(
                        size: 14, weight: FontWeight.w600, color: ec.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '¡Sé el primero en opinar!',
                    style: EnjoyTheme.body(size: 12, color: ec.textMute),
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
// Título del hero que aparece solo cuando el SliverAppBar se colapsa
// ══════════════════════════════════════════════════════════════════
class _CollapsedHeroTitle extends StatelessWidget {
  final String text;
  final TextStyle style;
  const _CollapsedHeroTitle({required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    final settings = context
        .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    double opacity = 1;
    if (settings != null) {
      final delta = settings.maxExtent - settings.minExtent;
      // Aparece en el último tramo del colapso.
      if (delta > 0) {
        final t = (settings.currentExtent - settings.minExtent) / delta;
        opacity = (1 - (t * 2)).clamp(0.0, 1.0);
      }
    }
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: opacity,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
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
    final ec = context.ec;
    if (!elegible) {
      return GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: ec.glassStrong,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.lock_outline_rounded,
                  size: 15, color: ec.textMute),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Usa al menos una promoción en este local para dejar una reseña.',
                style: EnjoyTheme.body(size: 13, color: ec.textMute),
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

      return GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: ec.orange.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(Icons.rate_review_rounded,
                      size: 15, color: ec.orangeSoft),
                ),
                const SizedBox(width: 10),
                Text(
                  'Tu reseña',
                  style: EnjoyTheme.heading(size: 15, color: ec.text),
                ),
                const Spacer(),
                // Edit
                Pill('Editar',
                    variant: PillVariant.orange,
                    icon: Icons.edit_rounded,
                    dense: true,
                    onTap: onEditar),
                const SizedBox(width: 6),
                // Delete
                if (onEliminar != null)
                  _Tappable(
                    onTap: onEliminar,
                    borderRadius: 9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: ec.red.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(Icons.delete_outline_rounded,
                          size: 16, color: ec.red),
                    ),
                  ),
              ],
            ),
            const EnjoyDivider(height: 22),
            _StarDisplay(value: calif, color: ec.orangeSoft),
            if (texto.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ec.glassStrong,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ec.stroke),
                ),
                child: Text(
                  texto,
                  style: EnjoyTheme.body(
                      size: 13, color: ec.textSoft, height: 1.5),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // ── VISTA EDICIÓN / CREACIÓN ──
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: ec.orange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.rate_review_rounded,
                    size: 15, color: ec.orangeSoft),
              ),
              const SizedBox(width: 10),
              Text(
                existe ? 'Editar tu reseña' : 'Escribe tu reseña',
                style: EnjoyTheme.heading(size: 15, color: ec.text),
              ),
            ],
          ),
          const EnjoyDivider(height: 22),
          _StarPicker(
            value: rating,
            onChanged: onRatingChanged,
            activeColor: ec.orange,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: commentCtrl,
            maxLines: 3,
            maxLength: 100,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            style: EnjoyTheme.body(size: 14, color: ec.text),
            cursorColor: ec.orange,
            decoration: const InputDecoration(
              hintText: 'Cuéntanos en pocas palabras… (máx. 100)',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: EnjoyButton(
                  label: existe ? 'Guardar cambios' : 'Publicar',
                  icon: Icons.save_rounded,
                  loading: saving,
                  dense: true,
                  onPressed: saving ? null : onGuardar,
                ),
              ),
              if (onCancelar != null) ...[
                const SizedBox(width: 8),
                EnjoyButton(
                  label: 'Cancelar',
                  variant: EnjoyButtonVariant.ghost,
                  dense: true,
                  expand: false,
                  onPressed: saving ? null : onCancelar,
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

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EnjoyAvatar(c.autorNombre ?? 'Anónimo', size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.autorNombre ?? 'Anónimo',
                      style: EnjoyTheme.heading(
                          size: 13, weight: FontWeight.w600, color: ec.text),
                    ),
                    if (c.fecha != null)
                      Text(
                        '${c.fecha!.day.toString().padLeft(2, '0')}/${c.fecha!.month.toString().padLeft(2, '0')}/${c.fecha!.year}',
                        style: EnjoyTheme.body(size: 11, color: ec.textMute),
                      ),
                  ],
                ),
              ),
              if (c.rating != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 14, color: Colors.amber),
                      const SizedBox(width: 3),
                      Text(
                        c.rating!.toStringAsFixed(1),
                        style: EnjoyTheme.heading(size: 12, color: ec.text),
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
              style:
                  EnjoyTheme.body(size: 13, color: ec.textSoft, height: 1.5),
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
    final ec = context.ec;
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
          color: filled ? activeColor : ec.textMute,
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
    final ec = context.ec;
    return Row(
      children: List.generate(
        5,
        (i) => Icon(
          i < value ? Icons.star_rounded : Icons.star_border_rounded,
          color: i < value ? color : ec.textMute,
          size: 22,
        ),
      ),
    );
  }
}

/// Vista grande de un producto del catálogo: imagen ampliable (zoom) +
/// nombre + descripción completa scrolleable.
void _abrirProductoGrande(BuildContext context, Producto p) {
  final ec = context.ec;
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => Dialog(
      backgroundColor: ec.surfaceMid,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Stack(
              children: [
                InteractiveViewer(
                  maxScale: 4,
                  child: EnjoyImage(
                    p.url,
                    width: double.infinity,
                    height: 240,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      height: 240,
                      color: ec.iconGlassBottom,
                      child: Icon(Icons.broken_image_rounded,
                          color: ec.textMute, size: 48),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.nombre,
                    style: EnjoyTheme.heading(
                        size: 18, weight: FontWeight.w800, color: ec.text),
                  ),
                  if ((p.descripcion ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      p.descripcion!,
                      style: EnjoyTheme.body(
                          size: 14, color: ec.textSoft, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CatalogoCarousel extends StatefulWidget {
  final List<Producto> productos;
  const _CatalogoCarousel({required this.productos});

  @override
  State<_CatalogoCarousel> createState() => _CatalogoCarouselState();
}

class _CatalogoCarouselState extends State<_CatalogoCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final items = widget.productos;
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 256,
          child: PageView.builder(
            controller: _controller,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final p = items[i];
              final tieneDescripcion = (p.descripcion ?? '').isNotEmpty;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _abrirProductoGrande(context, p),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 160,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            EnjoyImage(
                              p.url,
                              fit: BoxFit.cover,
                              errorWidget: Container(
                                color: ec.iconGlassBottom,
                                child: Icon(Icons.broken_image_rounded,
                                    color: ec.textMute, size: 40),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Icon(Icons.zoom_out_map_rounded,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // El bloque de texto flexa dentro del alto restante para que
                  // descripciones largas o el escalado de fuente del sistema no
                  // provoquen overflow del PageView.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          p.nombre,
                          style: EnjoyTheme.heading(size: 15, color: ec.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (tieneDescripcion) ...[
                          const SizedBox(height: 4),
                          Flexible(
                            child: Text(
                              p.descripcion!,
                              style: EnjoyTheme.body(
                                  size: 13, color: ec.textMute, height: 1.3),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _abrirProductoGrande(context, p),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('Ver más',
                                  style: EnjoyTheme.body(
                                      size: 12,
                                      weight: FontWeight.w700,
                                      color: ec.orangeSoft)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (items.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(items.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  gradient: active ? ec.accentGradient : null,
                  color: active ? null : ec.strokeStrong,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Helper interno de toque con feedback
// ══════════════════════════════════════════════════════════════════
class _Tappable extends StatelessWidget {
  const _Tappable({this.onTap, required this.child, this.borderRadius = 12});
  final VoidCallback? onTap;
  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      ),
    );
  }
}
