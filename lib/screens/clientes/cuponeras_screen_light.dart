// lib/screens/clientes/cuponeras_screen_light.dart
import 'dart:convert';

import 'package:enjoy/mappers/cuponera.dart';
import 'package:enjoy/screens/clientes/detalle_cupon.dart';
import 'package:enjoy/screens/clientes/comprar_cuponera_screen.dart';
import 'package:enjoy/screens/clientes/mis_solicitudes_screen.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:enjoy/services/cupones_service.dart';
import 'package:enjoy/services/core/api_exception.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/versiones_service.dart';
import 'mapa_version_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../ui/palette.dart';
import '../../services/configuracion_service.dart';

class CuponerasScreenLight extends StatefulWidget {
  final List<Cuponera> cuponeras;
  final Future<void> Function()? onAddCuponera;

  const CuponerasScreenLight({
    super.key,
    required this.cuponeras,
    this.onAddCuponera,
  });

  @override
  State<CuponerasScreenLight> createState() => _CuponerasScreenLightState();
}

class _CuponerasScreenLightState extends State<CuponerasScreenLight> {
  final _cuponSvc = CuponesService();
  final _auth = AuthService();

  late List<Cuponera> _items;
  bool _reloading = false;
  String _whatsappNumero = '+593999999999';
  String _whatsappMensaje = 'Hola, quiero adquirir una cuponera.';

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.cuponeras);
    _cargarConfigWhatsApp();
  }

  Future<void> _verMapa(BuildContext context, Cuponera c) async {
    final versionId = c.versionId;
    if (versionId == null || versionId.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final locales = await VersionesService.listarLocales(versionId);
      if (!context.mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MapaVersionScreen(
            versionNombre: c.nombre,
            locales: locales,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar el mapa.')),
      );
    }
  }

  Future<void> _cargarConfigWhatsApp() async {
    final configs = await ConfiguracionService.obtenerTodas();
    if (mounted) {
      setState(() {
        _whatsappNumero = configs['whatsapp_numero'] ?? _whatsappNumero;
        _whatsappMensaje = configs['whatsapp_mensaje'] ?? _whatsappMensaje;
      });
    }
  }

  Future<void> _reloadFromServer() async {
    setState(() => _reloading = true);
    try {
      final me = await _auth.getUser();
      final clienteId = me?['_id']?.toString();
      if (clienteId != null) {
        final fresh = await _cuponSvc.listarPorCliente(
          clienteId,
          soloActivas: true,
        );
        if (!mounted) return;
        setState(() => _items = fresh);
      }
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
  }

  // ─────────────────────────── Escaneo + asignación
  Future<void> _scanAndLink(BuildContext context) async {
    final code = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const _QrScanPage()),
    );
    if (code == null || code.trim().isEmpty) return;

    final cuponId = _extractCuponId(code.trim());
    if (cuponId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código no válido para cuponera.')),
      );
      return;
    }

    final me = await _auth.getUser();
    final clienteId = me?['_id']?.toString();
    if (clienteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión.')),
      );
      return;
    }

    Map<String, dynamic> raw;
    try {
      raw = await _cuponSvc.findByIdRaw(cuponId);
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al consultar el cupón.')),
      );
      return;
    }

    final dynamic local = raw['cliente'];
    final yaAsignadoA =
        (local is Map && local['_id'] != null)
            ? local['_id'].toString()
            : (local?.toString());

    if (yaAsignadoA == null || yaAsignadoA.isEmpty) {
      final ok = await _confirmAssignSheet(
        context,
        title: 'Asignar cuponera',
        message: '¿Deseas ligar esta cuponera a tu cuenta?',
        confirmLabel: 'Sí, asignar',
        cancelLabel: 'Cancelar',
      );
      if (ok != true) return;

      try {
        await _cuponSvc.asignarACliente(clienteId, cuponId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Cuponera asignada correctamente!')),
        );
        await _reloadFromServer();
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo asignar.')),
        );
      }
    } else if (yaAsignadoA == clienteId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta cuponera ya está ligada a tu cuenta.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La cuponera ya está ligada a otro cliente.'),
        ),
      );
    }
  }

  String? _extractCuponId(String raw) {
    final reHex24 = RegExp(r'^[0-9a-fA-F]{24}$');
    if (reHex24.hasMatch(raw)) return raw;

    try {
      final uri = Uri.parse(raw);
      final id =
          uri.queryParameters['cuponId'] ?? uri.queryParameters['cupon'];
      if (id != null && reHex24.hasMatch(id)) return id;
    } catch (_) {}

    try {
      final obj = jsonDecode(raw);
      if (obj is Map) {
        final id =
            (obj['cuponId'] ?? obj['id'] ?? obj['cupon'])?.toString();
        if (id != null && reHex24.hasMatch(id)) return id;
      }
    } catch (_) {}

    return null;
  }

  // ─────────────────────────── Confirm sheet
  Future<bool?> _confirmAssignSheet(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Asignar',
    String cancelLabel = 'Cancelar',
    Map<String, dynamic>? cuponRaw,
  }) {
    final ver = cuponRaw?['version'];
    final String versionNombre =
        (ver is Map && ver['nombre'] != null) ? ver['nombre'].toString() : '—';
    final String versionDescripcion =
        (ver is Map && ver['descripcion'] != null)
            ? ver['descripcion'].toString()
            : '';
    final int? sec =
        (cuponRaw?['secuencial'] is num)
            ? (cuponRaw!['secuencial'] as num).toInt()
            : null;

    String fmtSec(int? n) =>
        n == null ? 'Nº —' : 'Nº ${n.toString().padLeft(3, '0')}';

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Palette.kBorder,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Palette.kAccent, Palette.kAccentLight],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Palette.kTitle,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(color: Palette.kMuted, fontSize: 14),
            ),
            if (cuponRaw != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Palette.kField,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Palette.kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Palette.kPrimary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(
                            Icons.layers_rounded,
                            size: 14,
                            color: Palette.kPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Versión: $versionNombre',
                            style: const TextStyle(
                              color: Palette.kTitle,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Palette.kAccent, Palette.kAccentLight],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            fmtSec(sec),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (versionDescripcion.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        versionDescripcion,
                        style: const TextStyle(
                          color: Palette.kMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Palette.kField,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Palette.kBorder),
                      ),
                      child: Center(
                        child: Text(
                          cancelLabel,
                          style: const TextStyle(
                            color: Palette.kMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Palette.kAccent, Palette.kAccentLight],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Palette.kAccent.withOpacity(0.30),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          confirmLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWhatsApp(String phone, {String? message}) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final text = Uri.encodeComponent(
      message ?? 'Hola, quiero adquirir una cuponera.',
    );
    final nativeUrl = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$text');
    final webUrl = Uri.parse('https://wa.me/$cleanPhone?text=$text');

    if (await canLaunchUrl(nativeUrl)) {
      await launchUrl(nativeUrl);
    } else {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  void _showAdquirirSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Palette.kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Palette.kBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Palette.kAccent, Palette.kAccentLight],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adquirir Cuponera',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: Palette.kTitle,
                          ),
                        ),
                        Text(
                          'Elige cómo quieres adquirir tu cuponera',
                          style: TextStyle(color: Palette.kMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _AdquirirOptionCard(
                      icon: Icons.chat_rounded,
                      title: 'WhatsApp',
                      subtitle: 'Escribir por chat',
                      onTap: () {
                        Navigator.pop(context);
                        _openWhatsApp(
                          _whatsappNumero,
                          message: _whatsappMensaje,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AdquirirOptionCard(
                      icon: Icons.credit_card_rounded,
                      title: 'Compra directa',
                      subtitle: 'Transferencia bancaria',
                      onTap: () async {
                        Navigator.pop(context);
                        final me = await _auth.getUser();
                        if (me == null || !mounted) return;
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ComprarCuponeraScreen(
                              clienteId: me['_id']?.toString() ?? '',
                              nombreCliente:
                                  '${me['nombres'] ?? ''} ${me['apellidos'] ?? ''}'
                                      .trim(),
                              emailCliente: me['email']?.toString() ?? '',
                              telefonoCliente: me['telefono']?.toString(),
                            ),
                          ),
                        );
                        if (result == true && mounted) {
                          _reloadFromServer();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Palette.kField,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Palette.kBorder),
                ),
                child: TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final me = await _auth.getUser();
                    if (me == null || !mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MisSolicitudesScreen(
                          clienteId: me['_id']?.toString() ?? '',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.receipt_long_rounded,
                    size: 18,
                    color: Palette.kPrimary,
                  ),
                  label: const Text(
                    'Ver mis solicitudes',
                    style: TextStyle(
                      color: Palette.kPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── Barra CTA inferior
  Widget _buildBottomCta(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 16),
          child: FloatingActionButton.extended(
            onPressed: () => _showAdquirirSheet(context),
            icon: const Icon(Icons.add),
            label: const Text(
              'Adquirir Cuponera',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            backgroundColor: Palette.kPrimary,
            foregroundColor: Colors.white,
            elevation: 6,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Palette.kAccent, Palette.kAccentLight],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Palette.kAccent.withOpacity(0.30),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_activity_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Sin cuponeras activas',
                    style: TextStyle(
                      color: Palette.kTitle,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Adquiere una cuponera para disfrutar descuentos en los mejores locales.',
                    style: TextStyle(color: Palette.kMuted, fontSize: 13, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: _reloadFromServer,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Actualizar'),
                    style: TextButton.styleFrom(
                      foregroundColor: Palette.kAccent,
                      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildBottomCta(context),
        ],
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          color: Palette.kAccent,
          onRefresh: _reloadFromServer,
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              88 + MediaQuery.of(context).padding.bottom,
            ),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (_, i) => _CuponeraTicketCard(
              c: _items[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CuponDetalleScreen(cuponId: _items[i].id),
                ),
              ),
              onMapTap: _items[i].versionId != null
                  ? () => _verMapa(context, _items[i])
                  : null,
            ),
          ),
        ),
        _buildBottomCta(context),
        if (_reloading)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Palette.kSurface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Palette.kAccent,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Actualizando…',
                      style: TextStyle(
                        color: Palette.kMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Ticket card
// ══════════════════════════════════════════════════════════════════
class _CuponeraTicketCard extends StatelessWidget {
  final Cuponera c;
  final VoidCallback onTap;
  final VoidCallback? onMapTap;

  const _CuponeraTicketCard({
    required this.c,
    required this.onTap,
    this.onMapTap,
  });

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _secFmt(String s) {
    final n = int.tryParse(s);
    final pretty = n != null ? n.toString().padLeft(3, '0') : s;
    return 'Nº $pretty';
  }

  int? _diasRestantes(DateTime? expira) {
    if (expira == null) return null;
    final now = DateTime.now();
    if (expira.isBefore(now)) return 0;
    final base = DateTime(now.year, now.month, now.day);
    return expira.difference(base).inDays;
  }

  double? _lifeProgress(DateTime emitida, DateTime? expira) {
    if (expira == null) return null;
    final total = expira.difference(emitida).inSeconds;
    if (total <= 0) return 1;
    final elapsed = DateTime.now().difference(emitida).inSeconds;
    return (elapsed / total).clamp(0, 1).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final dias = _diasRestantes(c.expiraEl);
    final vencida = c.expiraEl != null && c.expiraEl!.isBefore(DateTime.now());
    final porExpirar = !vencida && dias != null && dias <= 7;

    final statusLabel =
        vencida ? 'Vencida' : (porExpirar ? 'Por expirar' : 'Activa');
    final statusColor =
        vencida
            ? Colors.redAccent
            : (porExpirar ? Colors.amber.shade700 : const Color(0xFF27AE60));

    final String? lastUse = c.scans.isNotEmpty
        ? _fmt(
            (List.of(c.scans)..sort((a, b) => b.fecha.compareTo(a.fecha)))
                .first
                .fecha,
          )
        : (c.lastScanAt != null ? _fmt(c.lastScanAt!) : null);

    final count = c.scans.isNotEmpty ? c.scans.length : c.totalEscaneos;
    final progress = _lifeProgress(c.emitidaEl, c.expiraEl);
    final progressColor =
        vencida
            ? Colors.redAccent
            : (porExpirar ? Colors.amber.shade700 : Palette.kAccent);

    return GestureDetector(
      onTap: onTap,
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
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // ── Header gradiente ──
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Palette.kAccent, Palette.kAccentLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_activity_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        // Secuencial pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _secFmt(c.secuencial),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Divisor tipo ticket ──
            SizedBox(
              height: 20,
              child: Stack(
                children: [
                  const Positioned.fill(child: _DashedDivider()),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Palette.kBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: Palette.kBorder),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Palette.kBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: Palette.kBorder),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Descripción
                  if (c.descripcion.trim().isNotEmpty) ...[
                    Text(
                      c.descripcion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Palette.kMuted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Stats row
                  Row(
                    children: [
                      _statPill(
                        icon: Icons.qr_code_scanner_rounded,
                        label: '$count ${count == 1 ? "escaneo" : "escaneos"}',
                        color: Palette.kPrimary,
                      ),
                      if (lastUse != null) ...[
                        const SizedBox(width: 8),
                        _statPill(
                          icon: Icons.history_rounded,
                          label: 'Último: $lastUse',
                          color: Palette.kMuted,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Fechas
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Palette.kField,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Palette.kBorder),
                    ),
                    child: Row(
                      children: [
                        _dateItem(
                          icon: Icons.event_available_rounded,
                          label: 'Emitida',
                          value: _fmt(c.emitidaEl),
                          color: const Color(0xFF27AE60),
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          color: Palette.kBorder,
                        ),
                        _dateItem(
                          icon: Icons.event_busy_rounded,
                          label: 'Expira',
                          value: c.expiraEl != null
                              ? _fmt(c.expiraEl!)
                              : 'Sin límite',
                          color: vencida
                              ? Colors.redAccent
                              : (porExpirar
                                  ? Colors.amber.shade700
                                  : Palette.kMuted),
                        ),
                      ],
                    ),
                  ),

                  // Barra de progreso
                  if (progress != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 8,
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Palette.kField,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progressColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Inicio',
                          style: TextStyle(
                            color: Palette.kMuted,
                            fontSize: 11,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: progressColor.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            dias == null
                                ? 'Sin límite'
                                : (vencida
                                    ? 'Vencida'
                                    : 'Restan $dias días'),
                            style: TextStyle(
                              color: progressColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Botón mapa
                  if (onMapTap != null) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: onMapTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Palette.kPrimary.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Palette.kPrimary.withOpacity(0.15),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.map_rounded,
                              size: 16,
                              color: Palette.kPrimary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Ver locales en el mapa',
                              style: TextStyle(
                                color: Palette.kPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _statPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Palette.kTitle,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Divisor punteado (estilo ticket)
// ══════════════════════════════════════════════════════════════════
class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedPainter(color: Palette.kBorder),
      child: const SizedBox.expand(),
    );
  }
}

class _DashedPainter extends CustomPainter {
  final Color color;
  _DashedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 6.0, dashSpace = 6.0;
    double startX = 28;
    final endX = size.width - 28;
    final y = size.height / 2;
    while (startX < endX) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(startX + dashWidth, y),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════════
// Página de escáner QR
// ══════════════════════════════════════════════════════════════════
class _QrScanPage extends StatefulWidget {
  const _QrScanPage();

  @override
  State<_QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<_QrScanPage> {
  final _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (_handled) return;
    final codes = cap.barcodes;
    if (codes.isEmpty) return;
    final raw = codes.first.rawValue ?? '';
    if (raw.isEmpty) return;
    _handled = true;
    Navigator.pop(context, raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Escanear cuponera'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            fit: BoxFit.cover,
          ),
          // Marco de escaneo
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.72,
              height: MediaQuery.of(context).size.width * 0.72,
              decoration: BoxDecoration(
                border: Border.all(color: Palette.kAccent, width: 2.5),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white54,
                  size: 28,
                ),
                SizedBox(height: 8),
                Text(
                  'Apunta al código QR de tu cuponera',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Opción de adquisición
// ══════════════════════════════════════════════════════════════════
class _AdquirirOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdquirirOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Palette.kField,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Palette.kBorder),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Palette.kAccent, Palette.kAccentLight],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Palette.kTitle,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: Palette.kMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
