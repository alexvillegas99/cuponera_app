import 'package:flutter/material.dart';

/// Definición de un ítem del menú lateral de usuarios empresa.
class EmpresaNavItem {
  final String id;
  final String label;
  final IconData icon;

  /// Permiso requerido. null = siempre visible.
  final String? permission;

  /// Roles con acceso cuando el usuario no tiene permisos dinámicos.
  /// Fallback estático para staff y admin-local.
  final List<String>? fallbackRoles;

  /// Roles que NUNCA pueden ver este módulo, aunque tengan el permiso
  /// en su array dinámico. Tiene precedencia absoluta.
  final List<String>? excludeRoles;

  const EmpresaNavItem({
    required this.id,
    required this.label,
    required this.icon,
    this.permission,
    this.fallbackRoles,
    this.excludeRoles,
  });
}

/// Lista maestra de módulos — equivalente a SIDEBAR_MENU_FULL en Angular.
/// El sistema filtra esta lista según los permisos del usuario en tiempo real.
const List<EmpresaNavItem> kEmpresaNavItems = [
  // ─── Staff + Admin-Local (operación diaria) ──────────────────────────
  EmpresaNavItem(
    id: 'cupones',
    label: 'Cupones',
    icon: Icons.confirmation_num_rounded,
    permission: 'cupones.ver',
    fallbackRoles: ['staff', 'admin-local'],
    excludeRoles: ['admin'],
  ),
  EmpresaNavItem(
    id: 'estadisticas',
    label: 'Estadísticas',
    icon: Icons.bar_chart_rounded,
    permission: 'reportes.ver',
    fallbackRoles: ['admin-local'],
    excludeRoles: ['admin'],
  ),

  // ─── Admin-Local (gestión del local) ─────────────────────────────────
  EmpresaNavItem(
    id: 'empleados',
    label: 'Empleados',
    icon: Icons.people_rounded,
    permission: 'usuarios-local.ver',
    fallbackRoles: ['admin-local'],
  ),
  EmpresaNavItem(
    id: 'perfil_local',
    label: 'Perfil del Local',
    icon: Icons.store_rounded,
    permission: 'perfil-local.ver',
    fallbackRoles: ['admin-local'],
  ),

  // ─── Solo Admin (gestión global) ─────────────────────────────────────
  EmpresaNavItem(
    id: 'establecimientos',
    label: 'Establecimientos',
    icon: Icons.location_city_rounded,
    permission: 'establecimientos.ver',
    fallbackRoles: ['admin'],
  ),
  EmpresaNavItem(
    id: 'usuarios',
    label: 'Usuarios',
    icon: Icons.manage_accounts_rounded,
    permission: 'usuarios.ver',
    fallbackRoles: ['admin'],
  ),
  EmpresaNavItem(
    id: 'solicitudes',
    label: 'Solicitudes',
    icon: Icons.receipt_long_rounded,
    permission: 'solicitudes.ver',
    fallbackRoles: ['admin'],
  ),
  EmpresaNavItem(
    id: 'nueva_cuponera',
    label: 'Nueva Cuponera',
    icon: Icons.add_circle_rounded,
    permission: 'cupones.crear',
    fallbackRoles: ['admin'],
  ),
  EmpresaNavItem(
    id: 'cupones_asignados',
    label: 'Cupones Asignados',
    icon: Icons.confirmation_num_rounded,
    permission: 'cupones.ver',
    fallbackRoles: ['admin'],
  ),
];
