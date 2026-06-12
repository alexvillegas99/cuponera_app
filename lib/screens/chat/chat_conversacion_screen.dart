import 'dart:async';

import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/chat_service.dart';
import 'package:enjoy/services/chat_socket_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:enjoy/utils/image_compress.dart';
import 'package:flutter/material.dart';

/// Pantalla de conversación completa (estilo WhatsApp con Premium Dark).
/// - Carga histórica paginada (scroll arriba)
/// - Mensajes en vivo por WebSocket
/// - Adjuntar imagen comprimida <1MB
/// - "Escribiendo…" + doble check + presencia
/// - Acciones de soporte: asignarme, cerrar/reabrir
class ChatConversacionScreen extends StatefulWidget {
  final String hiloId;
  final bool esSoporte;
  /// Cuando es true, oculta el AppBar propio (se usa el del contenedor).
  final bool embedded;
  const ChatConversacionScreen({
    super.key,
    required this.hiloId,
    this.esSoporte = false,
    this.embedded = false,
  });

  @override
  State<ChatConversacionScreen> createState() => _ChatConversacionScreenState();
}

class _ChatConversacionScreenState extends State<ChatConversacionScreen> {
  final _svc = ChatService();
  final _socket = ChatSocketService.instance;
  final _scroll = ScrollController();
  final _textCtl = TextEditingController();
  final _auth = AuthService();

  Map<String, dynamic>? _hilo;
  final List<Map<String, dynamic>> _mensajes = [];
  String? _cursor;
  bool _hayMas = true;
  bool _cargandoMas = false;
  bool _enviando = false;
  bool _cargaInicial = true;

  String _miUserId = '';
  String _peerNombre = '';
  bool _peerEscribiendo = false;
  Timer? _typingTimer;
  Timer? _miTypingDebounce;
  Timer? _heartbeatTimer;

  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _typingTimer?.cancel();
    _miTypingDebounce?.cancel();
    _heartbeatTimer?.cancel();
    _socket.leaveConversacion(widget.hiloId);
    // Soporte libera la atención al salir.
    if (widget.esSoporte) {
      _svc.liberar(widget.hiloId).catchError((_) => null);
    }
    _scroll.dispose();
    _textCtl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final user = await _auth.getUser();
    _miUserId = (user?['_id'] ?? user?['id'] ?? '').toString();

    try {
      final hilo = await _svc.obtenerHilo(widget.hiloId);
      final msgs = await _svc.mensajes(widget.hiloId, limit: 30);
      if (!mounted) return;
      setState(() {
        _hilo = hilo;
        _mensajes
          ..clear()
          ..addAll(List<Map<String, dynamic>>.from(msgs['items'] ?? []));
        _cursor = msgs['nextCursor']?.toString();
        _hayMas = _cursor != null;
        _cargaInicial = false;
        _peerNombre = (hilo['localNombre'] ?? '').toString();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _irAlFinal(jump: true));
    } catch (_) {
      if (mounted) setState(() => _cargaInicial = false);
    }

    // Marcar leídos al entrar
    _svc.marcarLeidos(widget.hiloId).catchError((_) => null);

    // Soporte: reclamar / refrescar atención + heartbeat cada 60s.
    if (widget.esSoporte) {
      try {
        final hiloUpd = await _svc.atender(widget.hiloId);
        if (mounted) setState(() => _hilo = hiloUpd);
      } catch (_) {}
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
        if (!mounted) return;
        if (_atendidoPorMi()) {
          _svc.heartbeat(widget.hiloId).catchError((_) => null);
        }
      });
    }

    // Conectar WS + escuchar eventos
    await _socket.connect();
    _socket.joinConversacion(widget.hiloId);

    _subs.add(_socket.onMensaje.listen((m) {
      if (m['conversacionId']?.toString() != widget.hiloId) return;
      setState(() => _mensajes.add(m));
      WidgetsBinding.instance.addPostFrameCallback((_) => _irAlFinal());
      // Si lo recibí estando en pantalla, marcar leído.
      if (m['autorId']?.toString() != _miUserId) {
        _svc.marcarLeidos(widget.hiloId).catchError((_) => null);
      }
    }));

    _subs.add(_socket.onLeido.listen((info) {
      if (info['conversacionId']?.toString() != widget.hiloId) return;
      final lectorTipo = info['lectorTipo']?.toString();
      setState(() {
        for (final m in _mensajes) {
          if (m['autorId']?.toString() == _miUserId &&
              m['leidoEn'] == null &&
              m['autorTipo']?.toString() != lectorTipo) {
            m['leidoEn'] = info['fecha']?.toString() ?? DateTime.now().toIso8601String();
          }
        }
      });
    }));

    _subs.add(_socket.onEscribiendo.listen((info) {
      if (info['conversacionId']?.toString() != widget.hiloId) return;
      if (info['userId']?.toString() == _miUserId) return;
      final escribiendo = info['escribiendo'] == true;
      setState(() => _peerEscribiendo = escribiendo);
      _typingTimer?.cancel();
      if (escribiendo) {
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _peerEscribiendo = false);
        });
      }
    }));
  }

  void _onScroll() {
    if (_scroll.position.pixels <= 80 && !_cargandoMas && _hayMas) {
      _cargarMas();
    }
  }

  Future<void> _cargarMas() async {
    if (_cursor == null) return;
    setState(() => _cargandoMas = true);
    try {
      final r = await _svc.mensajes(widget.hiloId, cursor: _cursor, limit: 30);
      final nuevos = List<Map<String, dynamic>>.from(r['items'] ?? []);
      if (!mounted) return;
      setState(() {
        _mensajes.insertAll(0, nuevos);
        _cursor = r['nextCursor']?.toString();
        _hayMas = _cursor != null;
        _cargandoMas = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  void _irAlFinal({bool jump = false}) {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (jump) {
      _scroll.jumpTo(max);
    } else {
      _scroll.animateTo(
        max,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _onTextChanged(String _) {
    _miTypingDebounce?.cancel();
    _socket.emitirEscribiendo(widget.hiloId, true);
    _miTypingDebounce = Timer(const Duration(seconds: 2), () {
      _socket.emitirEscribiendo(widget.hiloId, false);
    });
  }

  Future<void> _enviar({String? imagenDataUrl}) async {
    final texto = _textCtl.text.trim();
    if (texto.isEmpty && imagenDataUrl == null) return;
    setState(() => _enviando = true);
    try {
      final r = await _svc.enviar(
        widget.hiloId,
        texto: texto.isEmpty ? null : texto,
        imagenBase64: imagenDataUrl,
      );
      _textCtl.clear();
      _socket.emitirEscribiendo(widget.hiloId, false);
      // Si por algún motivo el WS no nos lo devuelve, lo agregamos local.
      if (!_mensajes.any((m) => m['_id']?.toString() == r['_id']?.toString())) {
        setState(() => _mensajes.add(r));
        WidgetsBinding.instance.addPostFrameCallback((_) => _irAlFinal());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No se pudo enviar: ${e.toString()}'),
          backgroundColor: context.ec.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _adjuntarImagen() async {
    final data = await pickCropAndCompress(targetKB: 800);
    if (data == null) return;
    await _enviar(imagenDataUrl: data);
  }

  Future<void> _accionesSoporte() async {
    final ec = context.ec;
    final cerrada = (_hilo?['estado']?.toString() ?? '') == 'CERRADA';
    await showModalBottomSheet(
      context: context,
      backgroundColor: ec.surfaceMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.assignment_ind_rounded, color: ec.orange),
              title: Text('Asignarme', style: EnjoyTheme.body(color: ec.text)),
              onTap: () async {
                Navigator.pop(context);
                final upd = await _svc.asignar(widget.hiloId);
                if (mounted) setState(() => _hilo = upd);
              },
            ),
            ListTile(
              leading: Icon(
                cerrada ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                color: cerrada ? ec.green : ec.red,
              ),
              title: Text(
                cerrada ? 'Reabrir conversación' : 'Cerrar conversación',
                style: EnjoyTheme.body(color: ec.text),
              ),
              onTap: () async {
                Navigator.pop(context);
                final upd = cerrada
                    ? await _svc.reabrir(widget.hiloId)
                    : await _svc.cerrar(widget.hiloId);
                if (mounted) setState(() => _hilo = upd);
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _atendidoPorMi() {
    final a = (_hilo?['atendiendoAhora'] as Map?);
    final uid = a?['userId']?.toString();
    return uid != null && uid == _miUserId;
  }

  bool _atendidoPorOtro() {
    final a = (_hilo?['atendiendoAhora'] as Map?);
    final uid = a?['userId']?.toString();
    return uid != null && uid != _miUserId;
  }

  String _nombreAtiende() {
    return (_hilo?['atendiendoAhora'] as Map?)?['nombre']?.toString() ?? '';
  }

  String _formatHora(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final cerrada = (_hilo?['estado']?.toString() ?? '') == 'CERRADA';
    final titulo = widget.esSoporte
        ? (_hilo?['localNombre']?.toString() ?? 'Conversación')
        : 'Soporte';

    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: widget.embedded
          ? null
          : EnjoyAppBar(
              title: titulo,
              actions: [
                if (widget.esSoporte)
                  IconButton(
                    icon: Icon(Icons.more_vert_rounded, color: ec.text),
                    onPressed: _accionesSoporte,
                  ),
              ],
            ),
      body: Column(
        children: [
          if (widget.esSoporte && _atendidoPorOtro())
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
              color: ec.green.withValues(alpha: 0.10),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: ec.green,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_nombreAtiende()} está atendiendo este hilo',
                      style: EnjoyTheme.body(
                        size: 12,
                        color: ec.green,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (widget.esSoporte && _atendidoPorMi())
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
              color: ec.orange.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Icon(Icons.support_agent_rounded,
                      size: 14, color: ec.orange),
                  const SizedBox(width: 6),
                  Text(
                    'Estás atendiendo',
                    style: EnjoyTheme.body(
                      size: 11,
                      color: ec.orange,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          if (_peerEscribiendo)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${widget.esSoporte ? _peerNombre : "Soporte"} escribiendo…',
                  style: EnjoyTheme.body(size: 12, color: ec.orangeSoft),
                ),
              ),
            ),
          Expanded(
            child: _cargaInicial
                ? Center(child: CircularProgressIndicator(color: ec.orange))
                : _mensajes.isEmpty
                    ? Center(
                        child: Text(
                          'Empieza la conversación',
                          style: EnjoyTheme.body(color: ec.textMute),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        itemCount: _mensajes.length + (_cargandoMas ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (_cargandoMas && i == 0) {
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Center(
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
                          final idx = _cargandoMas ? i - 1 : i;
                          final m = _mensajes[idx];
                          final mio = m['autorId']?.toString() == _miUserId;
                          return _Burbuja(
                            mensaje: m,
                            mio: mio,
                            hora: _formatHora(m['createdAt']?.toString()),
                          );
                        },
                      ),
          ),
          if (cerrada)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: ec.glass,
              child: Text(
                'Conversación cerrada. Envía un mensaje para reabrirla.',
                textAlign: TextAlign.center,
                style: EnjoyTheme.body(size: 12, color: ec.textMute),
              ),
            ),
          _Composer(
            controller: _textCtl,
            enviando: _enviando,
            onSend: () => _enviar(),
            onAttach: _adjuntarImagen,
            onChanged: _onTextChanged,
          ),
        ],
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  final Map<String, dynamic> mensaje;
  final bool mio;
  final String hora;
  const _Burbuja({
    required this.mensaje,
    required this.mio,
    required this.hora,
  });

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final texto = (mensaje['texto'] ?? '').toString();
    final adj = (mensaje['adjuntoUrl'] ?? '').toString();
    final leido = mensaje['leidoEn'] != null;

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
      bottomLeft: Radius.circular(mio ? 14 : 4),
      bottomRight: Radius.circular(mio ? 4 : 14),
    );

    final burbuja = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.78,
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        gradient: mio ? ec.accentGradient : null,
        color: mio ? null : ec.glass,
        borderRadius: radius,
        border: mio ? null : Border.all(color: ec.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (adj.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: EnjoyImage(adj, width: 240, fit: BoxFit.cover),
            ),
            if (texto.isNotEmpty) const SizedBox(height: 6),
          ],
          if (texto.isNotEmpty)
            Text(
              texto,
              style: EnjoyTheme.body(
                size: 14,
                color: mio ? Colors.white : ec.text,
              ),
            ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                hora,
                style: TextStyle(
                  fontSize: 10,
                  color: mio ? Colors.white70 : ec.textMute,
                ),
              ),
              if (mio) ...[
                const SizedBox(width: 4),
                Icon(
                  leido ? Icons.done_all_rounded : Icons.done_rounded,
                  size: 14,
                  color: leido ? Colors.white : Colors.white70,
                ),
              ],
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: mio ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [burbuja],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool enviando;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final ValueChanged<String> onChanged;
  const _Composer({
    required this.controller,
    required this.enviando,
    required this.onSend,
    required this.onAttach,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          color: ec.surfaceMid,
          border: Border(top: BorderSide(color: ec.stroke)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.image_outlined, color: ec.orange),
              onPressed: enviando ? null : onAttach,
              tooltip: 'Adjuntar imagen',
            ),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                style: EnjoyTheme.body(color: ec.text),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje…',
                  hintStyle: EnjoyTheme.body(color: ec.textMute),
                  filled: true,
                  fillColor: ec.glass,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: ec.stroke),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: ec.stroke),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: ec.orange),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              decoration: BoxDecoration(
                gradient: ec.accentGradient,
                borderRadius: BorderRadius.circular(999),
              ),
              child: IconButton(
                icon: enviando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white),
                onPressed: enviando ? null : onSend,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
