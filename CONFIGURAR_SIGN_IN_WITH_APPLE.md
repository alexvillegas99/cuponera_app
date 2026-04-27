# Configurar Sign in with Apple

Requisito para Apple App Review — Guideline 4.8

---

## 1. Xcode — Agregar Capability

1. Abrir `ios/Runner.xcworkspace` en Xcode
2. Click en **Runner** en el panel izquierdo
3. Seleccionar target **Runner**
4. Ir a la pestaña **Signing & Capabilities**
5. Click en **+ Capability**
6. Buscar y agregar **Sign in with Apple**

---

## 2. App Store Connect — Activar en el App ID

1. Ir a https://developer.apple.com → Certificates, IDs & Profiles
2. Seleccionar **Identifiers** → buscar por Bundle ID
3. Activar **Sign in with Apple** en la lista de capabilities
4. Guardar — Xcode descarga el provisioning profile actualizado automáticamente

---

## 3. Firebase Console — Activar proveedor Apple

1. Ir al proyecto en Firebase Console
2. **Authentication** → **Sign-in method**
3. Activar **Apple**
4. Ingresar:
   - **Services ID**: se crea en developer.apple.com → Identifiers → + → Services IDs
   - **Team ID**: esquina superior derecha en developer.apple.com (10 caracteres)
5. Guardar

---

## 4. Compilar y probar

- Compilar desde Xcode hacia iPhone físico
- Verificar que el botón "Continuar con Apple" aparece en la pantalla de login
- Probar el flujo completo: login cliente y login empresa

---

## Notas

- El botón solo aparece en iOS (correcto por diseño)
- El codigo ya esta implementado en el app — solo falta esta configuracion
- Archivo: `lib/services/auth_service.dart` metodos `loginClienteWithApple()` y `loginUsuarioWithApple()`
