import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:enjoy/services/server_health_service.dart';

class ServerHealthStore extends ChangeNotifier {
  final ServerHealthService _svc;
  Timer? _timer;
  bool _isOk = true;
  bool _isMaintenance = false;
  String? _message;
  int _failCount = 0;

  bool get isOk => _isOk;
  bool get isMaintenance => _isMaintenance;
  String? get message => _message;

  ServerHealthStore(this._svc);

  void start() {
    _tick(); // primer chequeo inmediato
  }

  Future<void> checkNow() => _tick(manual: true);

  Duration _nextDelay() {
    // backoff exponencial suave: 3s, 6s, 10s, 15s...
    final seconds = [3, 6, 10, 15, 20, 30];
    final idx = _failCount.clamp(0, seconds.length - 1);
    return Duration(seconds: seconds[idx]);
  }

  Future<void> _tick({bool manual = false}) async {
    _timer?.cancel();

    final (status, msg) = await _svc.checkOnce();

    switch (status) {
      case 'ok':
        _isOk = true;
        _isMaintenance = false;
        _message = null;
        _failCount = 0;
        break;
      case 'maintenance':
        _isOk = false;
        _isMaintenance = true;
        _message = msg;
        _failCount = 0; // mantenimiento no cuenta como “fallo”
        break;
      default: // 'down'
        _isOk = false;
        _isMaintenance = false;
        _message = msg;
        _failCount++;
    }

    notifyListeners();

    // programa siguiente chequeo (a menos que haya sido manual y esté OK)
    final delay = _nextDelay();
    if (!(manual && _isOk)) {
      _timer = Timer(delay, _tick);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
