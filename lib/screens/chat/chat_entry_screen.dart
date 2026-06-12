import 'package:enjoy/screens/chat/chat_bandeja_screen.dart';
import 'package:enjoy/screens/chat/chat_conversacion_screen.dart';
import 'package:enjoy/services/chat_service.dart';
import 'package:enjoy/services/permissions_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';

/// Decide qué mostrar al tocar "Chats":
/// - Soporte (con `chat.ver` / `chat.responder`) → bandeja de hilos.
/// - Resto → directo a su hilo único con Soporte.
///
/// Cuando se navega como ruta independiente (`Navigator.push`) hace replace;
/// cuando se embebe dentro de otro layout, renderiza la pantalla resuelta
/// in-place.
class ChatEntryScreen extends StatefulWidget {
  final bool embedded;
  const ChatEntryScreen({super.key, this.embedded = true});

  @override
  State<ChatEntryScreen> createState() => _ChatEntryScreenState();
}

class _ChatEntryScreenState extends State<ChatEntryScreen> {
  Widget? _resolved;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _decidir();
  }

  Future<void> _decidir() async {
    final perms = PermissionsService();
    final esSoporte =
        await perms.hasAnyPermission(['chat.ver', 'chat.responder']);
    if (!mounted) return;

    if (esSoporte) {
      _abrir(ChatBandejaScreen(embedded: widget.embedded));
      return;
    }

    try {
      final hilo = await ChatService().miHilo();
      if (!mounted) return;
      _abrir(
        ChatConversacionScreen(
          hiloId: hilo['_id'].toString(),
          esSoporte: false,
          embedded: widget.embedded,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      if (!widget.embedded) Navigator.pop(context);
      setState(() => _loading = false);
    }
  }

  void _abrir(Widget pantalla) {
    if (widget.embedded) {
      setState(() {
        _resolved = pantalla;
        _loading = false;
      });
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => pantalla),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    if (_resolved != null) return _resolved!;
    if (_loading) {
      return EnjoyScaffold(
        body: Center(child: CircularProgressIndicator(color: ec.orange)),
      );
    }
    return EnjoyScaffold(
      body: Center(
        child: Text(
          'No se pudo abrir el chat',
          style: EnjoyTheme.body(color: ec.textMute),
        ),
      ),
    );
  }
}
