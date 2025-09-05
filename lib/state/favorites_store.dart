import 'package:enjoy/services/favorites_service.dart';
import 'package:flutter/material.dart';

class FavoritesStore extends ChangeNotifier {
  final FavoritosService api;
  FavoritesStore(this.api);

  final Set<String> _ids = {};
  bool _loaded = false;
  String? _clienteId;

  Set<String> get ids => _ids;
  bool get loaded => _loaded;

  Future<void> init(String clienteId) async {
    if (_loaded && _clienteId == clienteId) return;
    _clienteId = clienteId;
    _ids
      ..clear()
      ..addAll(await api.getIds(clienteId));
    _loaded = true;
    notifyListeners();
  }

  bool isFav(String negocioId) => _ids.contains(negocioId);

  /// Alterna y sincroniza. Retorna el estado final (true si terminó como favorito).
  Future<bool> toggle(String negocioId) async {
    assert(_clienteId != null, 'FavoritesStore.init(clienteId) no llamado');
    final wasFav = _ids.contains(negocioId);

    // UI optimista
    if (wasFav) _ids.remove(negocioId); else _ids.add(negocioId);
    notifyListeners();

    try {
      final nowFav = await api.toggle(_clienteId!, negocioId);
      if (nowFav) _ids.add(negocioId); else _ids.remove(negocioId);
      notifyListeners();
      return nowFav;
    } catch (e) {
      // rollback
      if (wasFav) _ids.add(negocioId); else _ids.remove(negocioId);
      notifyListeners();
      rethrow;
    }
  }
}
