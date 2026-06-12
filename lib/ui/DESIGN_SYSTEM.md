# Enjoy · Design System "Premium Dark + Glow" — Referencia de migración

Sistema visual nativo Flutter que replica la propuesta `propuesta_visual/`. Soporta
**tema oscuro y claro** con toggle (no hardcodear colores nunca).

Importar todo con una línea:
```dart
import 'package:enjoy/ui/enjoy.dart';
```

## Reglas de migración (OBLIGATORIAS)
1. **Solo cambia la capa visual.** Conserva intactos: controllers, servicios, llamadas API,
   validaciones, navegación (GoRouter `context.push/go`, `extra:`), estados, textos y acciones.
2. **Cero colores hardcodeados.** Todo color sale de `context.ec` (tokens) para que el
   toggle dark/light funcione. Prohibido `Palette.k*`, `Color(0x...)` salvo casos neutros
   justificados (negro del botón Apple, etc.).
3. **Tipografía:** títulos `EnjoyTheme.heading(...)` (Sora), cuerpo `EnjoyTheme.body(...)` (Inter).
4. Mantén nombres de clase/estado y firmas públicas (las rutas dependen de ellas).
5. Al terminar cada archivo: `flutter analyze <archivo>` debe salir **sin issues**.

## Tokens — `context.ec` (EnjoyColors)
Fondo/superficie: `bgGradient`, `surfaceGradient`, `bgTop/bgBottom`, `surfaceTop/Mid/Bottom`.
Vidrio/bordes: `glass`, `glassStrong`, `stroke`, `strokeStrong`.
Acento: `orange`, `orangeSoft`, `yellow`, `accentGradient`, `onAccent` (texto sobre naranja).
Estados: `green`, `red`, `blue`, `greenGradient`.
Texto: `text`, `textSoft`, `textMute`.
Tarjeta acento: `cardGradTop/Bottom`. Ícono glass: `iconGlassGradient`.
Flags: `ec.isDark`. Glow colors: `glowOrange`, `glowBlue`.

## Tipografía
```dart
EnjoyTheme.heading({size=16, weight=w700, color, height, letterSpacing=-.01}) // Sora
EnjoyTheme.body({size=14, weight=w400, color, height})                        // Inter
```

## Widgets (todos en enjoy.dart)

### Estructura
- `EnjoyScaffold({appBar, body, bottomBar, floatingActionButton, padding=fromLTRB(18,4,18,0), showGlow=true, safeTop/Bottom=true, extendBody=false})`
  Fondo con degradado + halos glow. Úsalo en TODA pantalla.
- `EnjoyAppBar({title, actions, showBack, onBack, leading})` — implementa PreferredSizeWidget.
  Chip back automático si hay back stack. `actions` = lista de widgets (usa `GlassIconButton`).
- `BackChip({onTap, icon})`, `GlassIconButton({icon, onTap, color, accent=false, size=42})`.

### Contenedores
- `GlassCard({child, padding=all(16), radius=20, accent=false, color, borderColor, borderStrong=false, onTap, blur=true, margin, leftAccent})`
  `accent:true` => degradado naranja sutil. `leftAccent: ec.orange` => barra vertical izquierda (estados).
- `ListRowTile({leading, title, subtitle, trailing, onTap, borderColor, titleColor})` — fila glass (.list-row).

### Acciones
- `EnjoyButton({label, onPressed, icon, trailingIcon, variant=orange, expand=true, dense=false, loading=false})`
  Variantes: `EnjoyButtonVariant.{orange, ghost, green, red, blueGlass}`. orange => glow + brillo animado.
- `Pill(label, {variant=glass, icon, dot=false, dense=false, onTap})`
  Variantes: `PillVariant.{orange, green, red, blue, glass}`. `dot:true` => punto parpadeante (estado activo).

### Átomos
- `IconBox(icon, {accent=false, size=44, radius=13, color, iconSize=20})` — caja de ícono (.ic-box).
- `EnjoyAvatar(label, {size=44, radius, imageUrl, accent=true})` — iniciales o foto.
- `EnjoyToggle({value, onChanged})` — switch (o usa `Switch` directo, ya tematizado).
- `Steps({count, current})` — barra de pasos del wizard/registro.
- `StatCard({value, label, accent=false, valueSize=26})` — KPI.
- `SectionTitle(title, {trailing, onTrailing})` — título + "ver todo".
- `FieldLabel(text)` — label uppercase. `EnjoyDivider({height=28})`.

### Inputs
Usa `TextField`/`TextFormField` normal: ya están tematizados por `inputDecorationTheme`
(fill glass, borde naranja al foco, prefixIconColor naranja). Para prefijo usa `prefixIcon`.

### Promo / media
- `PromoCard({title, subtitle, imageUrl, discount, topBadge, bottomPill, height=152, onTap, onFavorite, isFavorite=false, tint})`

### Efectos
- `ScanFrame({size=220})` — marco de escaneo QR animado (pantallas de cámara).
- `BlinkDot({color, size=7})`, `PulseGlow({child, color, radius})`, `GlowHalo({size, color})`,
  `RiseIn({child, delayMs, durationMs})`, `ShineSweep()`.

### Navegación inferior
- `EnjoyDock({items: List<DockItem>, currentIndex, onFab, fabIcon=Icons.add})`
  `DockItem({icon, label, onTap})`. El FAB central va en el medio si `onFab != null`.
  Pásalo como `bottomBar:` de EnjoyScaffold (con `extendBody:true`).

## Ejemplo canónico
`lib/screens/login_screen.dart` ya migrado. Pantallas de cámara (scan): ver mockups
`03_empresa.html` #2 y `02_cliente.html` #13 → usar `ScanFrame` sobre fondo oscuro.

## Mapa mockup ↔ pantalla
- Auth: `propuesta_visual/01_auth.html` (login, login empresa, registro, OTP, recuperar, solicitud empresa).
- Cliente: `propuesta_visual/02_cliente.html` (home, buscar, favoritos, membresías, comprar, pago, solicitudes, detalle membresía, mapa, detalle comercio, cupón/QR, escanear, perfil, editar perfil, notificaciones, privacidad).
- Empresa/Admin: `propuesta_visual/03_empresa.html` (panel, escanear cupón, resultado canje, cupones, asignados, establecimientos, form establecimiento, perfil local, empleados, form empleado, estadísticas, usuarios, solicitudes, nueva cuponera).
