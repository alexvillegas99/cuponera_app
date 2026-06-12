package com.pixelsmart.cuponera_app

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity es requerido por local_auth para mostrar el
// prompt biométrico (huella / Face ID) en Android. Si extendieras
// FlutterActivity la huella no se muestra.
class MainActivity : FlutterFragmentActivity()
