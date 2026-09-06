# Running SUMPAY on your Android phone

This project now includes the full `android/` folder, so it builds and installs
onto a real device. Follow either method below.

---

## One-time phone setup

1. On your phone, open **Settings → About phone** and tap **Build number**
   seven times to unlock **Developer options**.
2. Go to **Settings → System → Developer options** and turn on
   **USB debugging**.
3. Connect the phone to your computer with a USB cable. When the phone asks
   *"Allow USB debugging?"*, tap **Allow**.

Confirm your computer sees the phone:

```bash
flutter devices
```

Your phone should appear in the list.

---

## Method A — run it directly (recommended)

From the project folder:

```bash
flutter pub get
flutter run
```

If more than one device is connected, pick your phone:

```bash
flutter run -d <device-id-from-flutter-devices>
```

The first build downloads Gradle and dependencies and can take several minutes.
Later builds are much faster, and hot reload (press `r` in the terminal) is
instant.

---

## Method B — build an APK and copy it over

```bash
flutter pub get
flutter build apk --release
```

The installable file is created at:

```
build/app/outputs/flutter-apk/app-release.apk
```

Transfer that file to your phone (USB, email, cloud, etc.), open it on the
phone, allow *"install from unknown sources"* if prompted, and install.

For a smaller download you can split per CPU architecture:

```bash
flutter build apk --split-per-abi
```

which produces `app-armeabi-v7a-release.apk`, `app-arm64-v8a-release.apk`
(most modern phones), and `app-x86_64-release.apk`.

---

## If the `android/` folder ever gets out of date

If you hit a Gradle or embedding error after upgrading Flutter, you can let
Flutter regenerate the native folders while keeping all of this app's code:

```bash
flutter create --platforms=android .
```

Run it inside the project folder. It only rewrites platform scaffolding and
leaves everything in `lib/` untouched.

---

## Notes

- `applicationId` / package name: **com.sumpay.app**
- `minSdk` 21 (Android 5.0), so it runs on virtually any phone from 2015 on.
- The release build is signed with debug keys so `flutter build apk --release`
  works immediately. Generate a proper keystore before any real distribution.
- No runtime permissions are requested — this is a UI prototype. The manifest
  pre-declares network/Wi-Fi/vibrate permissions for the future LoRa and mesh
  integration so it won't need editing later.
