flutter pub run flutter_native_splash:create
flutter pub run flutter_launcher_icons:main
# Ejemplo: 1.0.2 (3)
flutter clean
flutter build appbundle --release --build-name=1.0.2 --build-number=3
bundletool dump manifest --bundle build/app/outputs/bundle/release/app-release.aab \
  --xpath '/manifest/@android:versionName | /manifest/@android:versionCode'



naVmx3Pto5