import 'package:enjoy/services/auth_service.dart';

/// Equivalente al PermissionsService de Angular.
/// Lee los permisos del usuario en storage y valida acceso a módulos.
class PermissionsService {
  final AuthService _auth;

  PermissionsService([AuthService? auth]) : _auth = auth ?? AuthService();

  /// Array de permisos del usuario actual (ej: ['cupones.ver', 'reportes.ver'])
  Future<List<String>> getPermisos() async {
    final user = await _auth.getUser();
    final perms = user?['permisos'];
    if (perms is List) return List<String>.from(perms);
    return [];
  }

  /// Rol del usuario empresa (staff, admin-local, admin, vendedor, etc.)
  Future<String> getRol() async {
    final user = await _auth.getUser();
    return (user?['rol'] ?? '').toString().toLowerCase();
  }

  Future<bool> hasPermission(String permission) async {
    return (await getPermisos()).contains(permission);
  }

  Future<bool> hasAnyPermission(List<String> permissions) async {
    final perms = await getPermisos();
    return permissions.any((p) => perms.contains(p));
  }

  /// Determina si el usuario puede acceder a un módulo.
  ///
  /// Lógica:
  /// - Sin restricción (permission == null) → siempre true
  /// - Usuario con permisos dinámicos → usa el array de permisos (cualquier rol)
  /// - Usuario sin permisos → fallback estático por rol (para staff/admin-local)
  Future<bool> canAccess({
    String? permission,
    List<String>? fallbackRoles,
  }) async {
    if (permission == null) return true;

    final perms = await getPermisos();

    if (perms.isNotEmpty) {
      // Sistema dinámico: válido para cualquier rol personalizado (vendedor, etc.)
      return perms.contains(permission);
    }

    // Fallback estático: solo roles conocidos del sistema
    if (fallbackRoles == null || fallbackRoles.isEmpty) return false;
    final rol = await getRol();
    return fallbackRoles.contains(rol);
  }
}
