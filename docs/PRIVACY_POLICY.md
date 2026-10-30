# MacroLens Privacy Policy

**Prototype draft — last updated October 31, 2026**

This draft describes the current MacroLens prototype. It is not a statement that production accounts, cloud storage, or a secure authentication system are connected.

## Account data

The app has no authentication backend or cloud database. Login fields are used only for local form validation; the entered email and password are not sent or saved. A simple sign-in flag is stored on this device so the demo stays signed in. Meal entries and profile settings exist in app memory and may be lost when the app closes. Uninstalling the app removes the locally stored sign-in flag.

## Food photos and AI scanning

When you tap **Identify food with AI**, the selected photo is sent over HTTPS to the hosted scanner service. The scanner forwards the image and a food-identification prompt to Google Gemini API and returns candidate food names. MacroLens does not ask the model to calculate nutrition values. Do not scan people, documents, or sensitive images.

The backend requests stateless Gemini interactions (`store=False`). Google’s handling of API prompts and images still depends on the API service tier and its terms. For unpaid Gemini API usage, Google may use submitted content to improve its products and services, and human reviewers may process inputs and outputs. Do not submit sensitive, confidential, or personal information to unpaid services. See the [Gemini API Additional Terms](https://ai.google.dev/gemini-api/terms) and [Google Privacy Policy](https://policies.google.com/privacy).

## Nutrition calculations

The app calculates nutrition locally from its small sample catalog and the portion you confirm. It does not send meal logs to Gemini. Estimates are informational and can be inaccurate.

## Retention and deletion

The prototype scanner does not intentionally save photos on its service. Google’s handling of a submitted image depends on the Gemini service tier and terms. Closing or reinstalling the app can clear in-memory meal entries. No account deletion feature exists because accounts are not connected.

## Network and security

Online scanner traffic uses HTTPS and a separate scanner access code. Keep that code private. The Gemini API key stays on the scanner service and must not be placed in the phone app or public source code. The local sign-in flag is not a verified account session. This prototype has not had a security review and is not a production authentication system.

## Contact and updates

No privacy contact channel is connected in this prototype. Before public release, identify the responsible operator, contact details, applicable jurisdiction, retention rules, and effective date, and have this notice reviewed for the intended markets.
