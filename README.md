# MacroLens prototype

A Flutter prototype for photo-assisted macronutrient tracking. The scanner uses a camera or gallery image and asks Gemini 3.5 Flash-Lite to identify visible food, suggest a serving size, and estimate typical macros per 100 g. Known foods can use the app's local catalog; unmatched foods use clearly labeled AI estimates. The app scales the selected per-100-g values to the serving size the user confirms.

## Run the Flutter app

```sh
flutter pub get
flutter run -d chrome --dart-define=MACROS_API_URL=http://localhost:8000/api/analyze
```

For online scanning, deploy the scanner service described below and build the app with a private config file. The phone needs internet access, but it does not need to share Wi-Fi with or connect to your laptop. The scanner access code is not shown in the app.

## Open and run on an Android phone in VS Code (Windows)

1. In VS Code, choose **File → Open Folder** and open this `macrotrack_app` folder.
2. Install the recommended **Flutter** extension if VS Code asks. The Dart extension is installed alongside it.
3. On the phone, enable **Developer options → USB debugging**, connect it with a data-capable USB cable, and accept the debugging prompt.
4. Open **Terminal → New Terminal** in VS Code and run:

```powershell
flutter pub get
flutter devices
flutter run --dart-define-from-file=private_config.json
```

Choose the phone when Flutter asks for a device. `flutter run` builds, installs, and launches the app; keep the terminal open for hot reload. The same steps work with an Android emulator.

If PowerShell does not recognize `flutter`, add your Flutter SDK's `bin` folder to your user `PATH` first. Flutter uses the Android SDK installed with Android Studio.

To build an APK for manual installation instead, run `flutter build apk --debug`. The APK is written to `build/app/outputs/flutter-apk/app-debug.apk`. Install it over USB with:

```powershell
adb install -r 'build\app\outputs\flutter-apk\app-debug.apk'
```

## Deploy the scanner online for phone testing

This repository includes a Render Blueprint for the FastAPI scanner. It creates a free Python web service from `backend/`, exposes `/health`, and asks you to enter secrets in Render rather than committing them to GitHub.

1. Create a Render account, choose **New → Blueprint**, and connect the `DrebDE/MacroLens` GitHub repository on the `main` branch.
2. When Render prompts for `GEMINI_API_KEY`, enter your Gemini API key in the dashboard. Do not put it in this repository or the phone app.
3. Generate a separate scanner access code in PowerShell and copy it to the Render prompt for `SCANNER_ACCESS_TOKEN`:

   ```powershell
   $bytes = New-Object byte[] 32
   $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
   $rng.GetBytes($bytes)
   $scannerCode = -join ($bytes | ForEach-Object { $_.ToString('x2') })
   $rng.Dispose()
   $scannerCode
   ```

4. Choose the **Free** plan and create the Blueprint. After deployment, open `https://YOUR-SERVICE.onrender.com/health`; it should return `{"status":"ok"}`.
5. Copy `private_config.example.json` to `private_config.json`. Replace the URL with your Render service URL plus `/api/analyze`, and replace the placeholder access code with the same `SCANNER_ACCESS_TOKEN` value you set in Render. Keep `private_config.json` private; it is ignored by Git.

6. Connect the phone by USB once, then install the app using:

   ```powershell
   flutter run --dart-define-from-file=private_config.json
   ```

   The scanner access code is compiled into this private demo build, so it is not displayed during the presentation. Do not share the APK publicly; rotate the scanner access code after the demo if you distribute the app. Never put your Gemini API key in the phone app. After installation, the phone can scan without USB or the laptop; it only needs internet access.

Render's free web services spin down after 15 minutes without traffic and can take about a minute to wake on the next request. This is suitable for testing, though the first scan after idle may take longer. See [Render's free service limits](https://render.com/docs/free).

For local backend development instead, follow the steps below; local mode can omit `SCANNER_ACCESS_TOKEN`.

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
- Camera/gallery food scan, candidate correction, AI macro estimates for unmatched foods, grams/ounces input, and meal category.
- Local nutrient catalog with editable food/portion confirmation, manual add, and remove.
- Profile-based calorie target using the Mifflin-St Jeor BMR formula and an activity factor.
- Green MacroLens sign-in and registration prototype with in-app Terms of Service and Privacy Policy drafts. Authentication is not connected; email/password are not verified, transmitted, or stored. A device-only flag remembers the demo sign-in until the user signs out or removes the app.
- Data is in memory for this prototype; cloud persistence and a comprehensive nutrition database are not connected yet.

Photo portion estimates are approximate. Always confirm the serving size and database match.
