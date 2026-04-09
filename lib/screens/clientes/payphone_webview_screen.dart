import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../ui/palette.dart';

class PayPhoneWebViewScreen extends StatefulWidget {
  final String formularioUrl;
  final String clientTransactionId;

  const PayPhoneWebViewScreen({
    super.key,
    required this.formularioUrl,
    required this.clientTransactionId,
  });

  @override
  State<PayPhoneWebViewScreen> createState() => _PayPhoneWebViewScreenState();
}

class _PayPhoneWebViewScreenState extends State<PayPhoneWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
        onNavigationRequest: (request) {
          final url = request.url;

          // PayPhone redirige a nuestro resultado → interceptar y cerrar
          if (url.contains('/pagos/payphone/resultado')) {
            // Dejar que el WebView cargue la página de resultado
            return NavigationDecision.navigate;
          }

          // La página de resultado redirige a enjoy:// → capturar y volver al app
          if (url.startsWith('enjoy://payphone-resultado')) {
            final uri = Uri.tryParse(url);
            final ok = uri?.queryParameters['status'] == 'ok';
            Navigator.of(context).pop(ok ? 'aprobado' : 'rechazado');
            return NavigationDecision.prevent;
          }

          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.formularioUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        backgroundColor: Palette.kPrimary,
        foregroundColor: Colors.white,
        title: const Text(
          'Pago seguro',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(null),
          tooltip: 'Cancelar pago',
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Palette.kAccent),
            ),
        ],
      ),
    );
  }
}
