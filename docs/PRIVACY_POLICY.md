# MacroLens Privacy Policy

**Prototype draft — last updated November 6, 2026**

This notice describes the current MacroLens prototype. It is not a statement that production accounts, cloud storage, a secure authentication system, or regulatory compliance are in place. The in-app Privacy Policy mirrors this document.

## Scope

MacroLens is a Flutter nutrition-tracking prototype with a hosted photo scanner called Nouri, a FastAPI scanner service, and the DeepSeek API for image analysis. The app has no authentication backend, cloud profile database, analytics SDK, or advertising SDK.

## Demo account and sign-in

- Sign-in and registration screens are a local demonstration. Entered email addresses and passwords are validated only on the device. They are not transmitted, verified, or saved.
- A device-only flag remembers that the demo was signed in, so the app does not ask for email and password on every launch.
- Signing out removes that flag. The saved profile and meal history remain on the device unless you delete them.
- The forgot-password screen is a demo. It cannot send email or reset a password because no account service is connected.
- No account is created, and no account deletion process exists because no account service is connected.

## Data stored on the device

The app saves the following in local app preferences:

- the demo sign-in flag;
- profile details: name, age, height, current weight, goal, optional goal weight, activity level, and the calorie-estimate setting;
- meal entries: food name, per-100-gram nutrition values, portion grams, meal category, and date/time.

Profile details and meal entries are not uploaded to the scanner and are not included in a scan request. They stay on the device and are not synchronized across devices.

You can delete all locally saved meal entries with **Clear meal history** in Profile. Clearing the app's data or uninstalling the app removes the sign-in flag, profile, and meal history. The app does not intentionally export this local data. Android backup is disabled in the app manifest for this prototype.

## Food photos and AI scanning

A photo leaves the device only when you choose a photo and tap **Scan with Nouri**:

1. The app sends the selected image over HTTPS to the hosted MacroLens scanner.
2. The scanner forwards the image and a food-analysis prompt to the DeepSeek API.
3. DeepSeek returns one food or combined dish, a suggested edible-gram amount with a visual low/high range, an identification confidence, and approximate nutrition values per 100 grams.
4. The app displays the result for confirmation. A meal entry is created only after you confirm a food source, amount, and meal.

The image is held in app memory to show the preview and perform the scan. The app does not save scanner photos to the gallery or to its local profile/log storage. The device's image picker may keep a temporary cached copy until the operating system clears it. The scanner service does not intentionally save uploaded photos. DeepSeek's handling of a submitted image depends on its terms and privacy policy.

The backend requests DeepSeek Chat Completions with a base64 image and a JSON-output prompt. DeepSeek's privacy policy (last updated February 10, 2026) states that it collects user inputs, may use them to improve and train its technology, retains personal data as long as necessary for its services and legal obligations, and may process data outside your country, including in the People's Republic of China. MacroLens does not claim a zero-retention mode or that DeepSeek will not review submitted content. Do not submit sensitive, confidential, or personal images. See the [DeepSeek privacy policy](https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html) and [DeepSeek API documentation](https://api-docs.deepseek.com/).

Nouri is instructed to analyze edible food and drinks only and to reject non-food materials, people, animals, documents, non-edible plants, and unclear images. If food appears with objects, it is asked to analyze only the edible food. This guardrail can make mistakes. Text or instructions visible inside an image are treated as untrusted image content, not as commands.

## What is not sent with a scan

- Profile details, goals, and calculated targets are not sent to the scanner or DeepSeek.
- Meal entries and food logs are not sent to the scanner or DeepSeek.
- No account identifier is sent because there is no account service.
- The scanner access token identifies this private demo build, not the user or the user's profile.

## Nutrition estimates

- Catalog foods use typical per-100-gram values stored in the app. The app calculates the selected portion as `per-100-g value × grams / 100`. Ounces are converted to grams first.
- Unmatched foods use Nouri's generic per-100-gram values.
- A photo is not a scale measurement. Portion grams, the visual range, calories, and macros are approximate and may be wrong.
- Food-identification confidence is not confidence in the portion weight or macro values. The app never displays 100% confidence.
- Daily calorie and macro goals are rough adult estimates. They are not shown for users under 18 and are not intended for pregnancy, breastfeeding, eating-disorder treatment, or medical nutrition plans. They are not medical advice.

## Retention and deletion

- Local meal entries remain until you remove individual entries, use **Clear meal history**, clear app data, or uninstall the app.
- The local profile remains until you clear app data or uninstall the app. There is no separate profile-delete control in this prototype.
- The scanner does not intentionally store uploaded photos. DeepSeek may retain and process submitted content under its terms and privacy policy.
- Because no account is connected, there is no account-deletion request process.

## Network and security

- Hosted scanner traffic must use HTTPS; release builds of the app reject cleartext HTTP.
- A private scanner access token is compiled into this demo build so the user does not configure the scanner. A token embedded in an APK is not a production security boundary. Do not share the APK publicly, and rotate the token after an external demo.
- The DeepSeek API key stays on the scanner service and is not present in Flutter code, Dart defines, the APK, or committed files.
- The app does not log API keys, access tokens, or submitted image bytes. The backend logs only scan status and image type.
- This prototype has not had a production security review.

## Children and teens

MacroLens is intended for users aged 13 and older. Calorie and macro goals are not estimated for users under 18. The app does not knowingly collect information from children under 13; if you believe a child under 13 has used it, clear the app's local data or uninstall it.

## Third-party services

- **Render** hosts the scanner service. Render may process request metadata such as IP address and timestamps under its terms.
- **DeepSeek** processes the submitted image and prompt when you choose to scan. DeepSeek's terms and privacy policy apply, including possible use of inputs to improve or train its technology and retention as described in that policy.
- AI scanning requires internet access. Profile, catalog, custom food entry, and meal history remain usable without the scanner.

## Contact and updates

No privacy contact channel is connected in this prototype. Before public release, the operator should identify its legal name, contact address, applicable jurisdiction, retention rules, and effective date, and have this notice reviewed for the intended markets.
