# MacroLens prototype

A Flutter prototype for photo-assisted macronutrient tracking. The scanner uses a camera or gallery image, asks Gemini 3.8 Flash to identify visible food items, maps the selected result to the app's built-in food catalog, and calculates calories/protein/carbohydrates/fat from the confirmed portion weight. The model does not invent the displayed macro totals.

## Run the Flutter app

```sh
flutter pub get
flutter run -d chrome --dart-define=MACROS_API_URL=http://localhost:8000/api/analyze
```

For an Android emulator, set the endpoint to `http://10.0.2.2:8000/api/analyze`. For a physical phone, use the laptop's current Wi-Fi address. The scanner screen lets you edit this address; the phone and laptop must be on the same Wi-Fi network.

## Open and run on an Android phone in VS Code (Windows)

1. In VS Code, choose **File → Open Folder** and open this `macrotrack_app` folder.
2. Install the recommended **Flutter** extension if VS Code asks. The Dart extension is installed alongside it.
3. On the phone, enable **Developer options → USB debugging**, connect it with a data-capable USB cable, and accept the debugging prompt.
4. Open **Terminal → New Terminal** in VS Code and run:

```powershell
flutter pub get
flutter devices
flutter run
```

Choose the phone when Flutter asks for a device. `flutter run` builds, installs, and launches the app; keep the terminal open for hot reload. The same steps work with an Android emulator.

If PowerShell does not recognize `flutter`, add your Flutter SDK's `bin` folder to your user `PATH` first. Flutter uses the Android SDK installed with Android Studio.

To build an APK for manual installation instead, run `flutter build apk --debug`. The APK is written to `build/app/outputs/flutter-apk/app-debug.apk`. Install it over USB with:

```powershell
adb install -r 'build\app\outputs\flutter-apk\app-debug.apk'
```

For live Gemini scanning on a physical phone, start the backend below. The phone and PC need to be on the same Wi-Fi network. Use the laptop's LAN IP in the Scanner connection field, for example:

```powershell
flutter run --dart-define=MACROS_API_URL=http://192.168.1.20:8000/api/analyze
```

Replace `192.168.1.20` with the PC's current LAN IP. The backend requires `GEMINI_API_KEY`; the phone app does not contain the key. The scanner cannot identify food until that service is running and configured.

## Start the scanner service

From `backend/`, install the requirements and set a Gemini API key in the environment. Keep this key on the server; do not place it in Flutter source or `--dart-define`.

```sh
python -m venv .venv
.venv\\Scripts\\activate
pip install -r requirements.txt
$env:GEMINI_API_KEY="your-key"
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The Gemini endpoint returns food names, visual confidence, and a rough portion suggestion. The interaction is configured with `store=False`; unpaid Gemini API usage may still be used by Google to improve its services and may be reviewed under Google's terms. See the in-app Privacy Policy and [Gemini API terms](https://ai.google.dev/gemini-api/terms). The app asks the user to confirm a food catalog match and serving weight, then computes nutrition from per-100-gram entries. Use the manual entry flow if the scanner service is unavailable or the food is missing from the sample catalog.

## Prototype scope

- Daily calories and macro dashboard, with a 7-day chart and date history.
- Camera/gallery food scan, candidate correction, grams/ounces input, and meal category.
- Local nutrient catalog with editable food/portion confirmation, manual add, and remove.
- Profile-based calorie target using the Mifflin-St Jeor BMR formula and an activity factor.
- Orange MacroLens sign-in and registration prototype with in-app Terms of Service and Privacy Policy drafts. Authentication is not connected; credentials are not verified, transmitted, or stored.
- Data is in memory for this prototype; cloud persistence and a comprehensive nutrition database are not connected yet.

Photo portion estimates are approximate. Always confirm the serving size and database match.
