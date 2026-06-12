import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Conexión Socket.IO al gateway /ws/chat. Singleton.
class ChatSocketService {
  ChatSocketService._();
  static final ChatSocketService instance = ChatSocketService._();

  io.Socket? _socket;
  final _storage = const FlutterSecureStorage();

  // Streams para que la UI escuche eventos.
  final _mensajes = StreamController<Map<String, dynamic>>.broadcast();
  final _leido = StreamController<Map<String, dynamic>>.broadcast();
  final _escribiendo = StreamController<Map<String, dynamic>>.broadcast();
  final _presencia = StreamController<Map<String, dynamic>>.broadcast();
  final _conversacionActualizada =
      StreamController<Map<String, dynamic>>.broadcast();
  final _conectado = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get onMensaje => _mensajes.stream;
  Stream<Map<String, dynamic>> get onLeido => _leido.stream;
  Stream<Map<String, dynamic>> get onEscribiendo => _escribiendo.stream;
  Stream<Map<String, dynamic>> get onPresencia => _presencia.stream;
  Stream<Map<String, dynamic>> get onConversacionActualizada =>
      _conversacionActualizada.stream;
  Stream<bool> get onConectado => _conectado.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Inicializa la conexión. Se puede llamar múltiples veces (idempotente).
  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final token = await _storage.read(key: 'accessToken');
    if (token == null || token.isEmpty) return;

    final baseUrl = dotenv.env['API_URL'] ?? '';
    // Removemos el /api del final si está, para apuntar al host raíz.
    final host = baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

    _socket?.dispose();
    _socket = io.io(
      '$host/ws/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .setReconnectionAttempts(999)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!
      ..onConnect((_) {
        if (kDebugMode) print('[chat] conectado');
        _conectado.add(true);
      })
      ..onDisconnect((_) {
        if (kDebugMode) print('[chat] desconectado');
        _conectado.add(false);
      })
      ..onConnectError((e) {
        if (kDebugMode) print('[chat] error conexión: $e');
      })
      ..on('mensaje', (data) {
        if (data is Map) _mensajes.add(Map<String, dynamic>.from(data));
      })
      ..on('leido', (data) {
        if (data is Map) _leido.add(Map<String, dynamic>.from(data));
      })
      ..on('escribiendo', (data) {
        if (data is Map) _escribiendo.add(Map<String, dynamic>.from(data));
      })
      ..on('presencia', (data) {
        if (data is Map) _presencia.add(Map<String, dynamic>.from(data));
      })
      ..on('presencia:lista', (data) {
        if (data is Map) _presencia.add(Map<String, dynamic>.from(data));
      })
      ..on('conversacion:actualizada', (data) {
        if (data is Map) {
          _conversacionActualizada.add(Map<String, dynamic>.from(data));
        }
      });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _conectado.add(false);
  }

  /// Se une a la sala de una conversación para recibir mensajes en vivo.
  void joinConversacion(String conversacionId) {
    _socket?.emit('join', {'conversacionId': conversacionId});
  }

  void leaveConversacion(String conversacionId) {
    _socket?.emit('leave', {'conversacionId': conversacionId});
  }

  void emitirEscribiendo(String conversacionId, bool escribiendo) {
    _socket?.emit('escribiendo', {
      'conversacionId': conversacionId,
      'escribiendo': escribiendo,
    });
  }

  void solicitarPresencia(List<String> userIds) {
    _socket?.emit('presencia:get', {'userIds': userIds});
  }
}
