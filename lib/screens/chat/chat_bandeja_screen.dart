import 'dart:async';
import 'package:enjoy/services/chat_service.dart';
import 'package:enjoy/services/chat_socket_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';

import 'chat_conversacion_screen.dart';

/// Bandeja compartida para usuarios con permiso `chat.ver` (equipo de soporte).
/// Lista todos los hilos de los locales, con búsqueda, filtros y badge de no-leídos.
class ChatBandejaScreen extends StatefulWidget {
  /// Cuando es true, no envuelve el contenido con EnjoyScaffold/EnjoyAppBar.
  /// Útil para embeber dentro de un panel mayor (home empresa).
  final bool embedded;
  const ChatBandejaScreen({super.key, this.embedded = false});

  @override
  State<ChatBandejaScreen> createState() => _ChatBandejaScreenState();
}

class _ChatBandejaScreenState extends State<ChatBandejaScreen> {
  final _svc = ChatService();
  final _socket = ChatSocketService.instance;
  final _searchCtl = TextEditingController();

  List<Map<String, dynamic>> _hilos = [];
  bool _loading = true;
  String _filtroEstado = 'ABIERTA'; // ABIERTA | CERRADA | TODOS
  bool _soloMisAsignados = false;
  Timer? _debounce;
  StreamSubscription? _subConv;

  @override
  void initState() {
    super.initState();
    _cargar();
    _socket.connect();
    _subConv = _socket.onConversacionActualizada.listen((conv) {
      _mergeHilo(conv);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _subConv?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final r = await _svc.listarHilos(
        q: _searchCtl.text.trim().isEmpty ? null : _searchCtl.text.trim(),
        estado: _filtroEstado == 'TODOS' ? null : _filtroEstado,
        asignadoMi: _soloMisAsignados,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _hilos = List<Map<String, dynamic>>.from(r['items'] ?? []);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _mergeHilo(Map<String, dynamic> conv) {
    final id = conv['_id']?.toString();
    if (id == null) return;
    setState(() {
      final i = _hilos.indexWhere((h) => h['_id']?.toString() == id);
      if (i >= 0) {
        _hilos[i] = {..._hilos[i], ...conv};
      } else {
        _hilos.insert(0, conv);
      }
      _hilos.sort((a, b) {
        final fa = a['updatedAt']?.toString() ?? '';
        final fb = b['updatedAt']?.toString() ?? '';
        return fb.compareTo(fa);
      });
    });
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _cargar);
  }

  String _formatTiempo(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return 'ahora';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final content = Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
            child: TextField(
              controller: _searchCtl,
              onChanged: _onSearchChanged,
              style: EnjoyTheme.body(color: ec.text),
              decoration: InputDecoration(
                hintText: 'Buscar local…',
                hintStyle: EnjoyTheme.body(color: ec.textMute),
                prefixIcon: Icon(Icons.search_rounded, color: ec.textMute),
                filled: true,
                fillColor: ec.glass,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: ec.stroke),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: ec.stroke),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: ec.orange),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          // Filtros chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                _chip('Abiertos', _filtroEstado == 'ABIERTA', () {
                  setState(() => _filtroEstado = 'ABIERTA');
                  _cargar();
                }),
                const SizedBox(width: 6),
                _chip('Cerrados', _filtroEstado == 'CERRADA', () {
                  setState(() => _filtroEstado = 'CERRADA');
                  _cargar();
                }),
                const SizedBox(width: 6),
                _chip('Todos', _filtroEstado == 'TODOS', () {
                  setState(() => _filtroEstado = 'TODOS');
                  _cargar();
                }),
                const SizedBox(width: 6),
                _chip('Mis asignados', _soloMisAsignados, () {
                  setState(() => _soloMisAsignados = !_soloMisAsignados);
                  _cargar();
                }),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: ec.orange))
                : _hilos.isEmpty
                    ? Center(
                        child: Text(
                          'No hay conversaciones',
                          style: EnjoyTheme.body(color: ec.textMute),
                        ),
                      )
                    : RefreshIndicator(
                        color: ec.orange,
                        onRefresh: _cargar,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                          itemCount: _hilos.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _tile(_hilos[i]),
                        ),
                      ),
          ),
        ],
      );

    if (widget.embedded) return content;
    return EnjoyScaffold(
      appBar: const EnjoyAppBar(title: 'Soporte'),
      padding: EdgeInsets.zero,
      body: content,
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

  Widget _tile(Map<String, dynamic> h) {
    final ec = context.ec;
    final ultimo = (h['ultimoMensaje'] as Map?) ?? {};
    final noLeidos = (h['noLeidosSoporte'] as num?)?.toInt() ?? 0;
    final cerrado = (h['estado']?.toString() ?? '') == 'CERRADA';
    final atiende = (h['atendiendoAhora'] as Map?);
    final atiendeNombre = atiende?['nombre']?.toString() ?? '';
    final hayQuienAtiende = atiendeNombre.isNotEmpty;
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatConversacionScreen(
              hiloId: h['_id'].toString(),
              esSoporte: true,
            ),
          ),
        );
        _cargar();
      },
      child: GlassCard(
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 46,
                height: 46,
                child: (h['localLogo'] ?? '').toString().isNotEmpty
                    ? EnjoyImage(h['localLogo'].toString(), fit: BoxFit.cover)
                    : Container(
                        color: ec.glass,
                        child: Icon(Icons.storefront_rounded,
                            color: ec.textMute),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (h['localNombre'] ?? '(Sin nombre)').toString(),
                          style: EnjoyTheme.heading(size: 15, color: ec.text),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTiempo(
                            (ultimo['fecha'] ?? h['updatedAt'])?.toString()),
                        style: EnjoyTheme.body(size: 11, color: ec.textMute),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ultimo['texto']?.toString() ??
                              (cerrado ? '(conversación cerrada)' : 'Sin mensajes aún'),
                          style: EnjoyTheme.body(
                            size: 13,
                            color: noLeidos > 0 ? ec.text : ec.textMute,
                            weight: noLeidos > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (noLeidos > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: ec.orange,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            noLeidos > 99 ? '99+' : '$noLeidos',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else if (cerrado)
                        Pill('Cerrada', variant: PillVariant.glass),
                    ],
                  ),
                  if (hayQuienAtiende) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: ec.green,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '$atiendeNombre atendiendo',
                            style: EnjoyTheme.body(
                              size: 11,
                              color: ec.green,
                              weight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
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
}
