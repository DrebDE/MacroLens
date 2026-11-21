import 'package:flutter/material.dart';

import '../theme.dart';

enum LegalKind { terms, privacy }

void showLegal(BuildContext context, LegalKind kind) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => LegalPage(kind: kind)),
  );
}

class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.kind});

  final LegalKind kind;

  @override
  Widget build(BuildContext context) {
    final terms = kind == LegalKind.terms;
    final sections = terms ? _termsSections : _privacySections;
    return Scaffold(
      appBar: AppBar(
        title: Text(terms ? 'Terms of Service' : 'Privacy Policy'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Text(
            terms ? 'MacroLens Terms of Service' : 'MacroLens Privacy Policy',
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Prototype draft · Last updated November 6, 2026',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Text(
            terms
                ? 'These terms describe use of the MacroLens nutrition-tracking prototype. By continuing, you agree to use it for personal, informational tracking.'
                : 'This draft explains what the current MacroLens prototype processes. It is not a statement that a production account, cloud database, or secure authentication system is connected.',
            style: const TextStyle(color: AppColors.ink, height: 1.55),
          ),
          const SizedBox(height: 14),
          ...sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.$1,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    section.$2,
                    style: const TextStyle(
                      color: AppColors.muted,
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!terms)
            const SelectableText(
              'DeepSeek privacy policy: https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html\nDeepSeek Open Platform Terms: https://cdn.deepseek.com/policies/en-US/deepseek-open-platform-terms-of-service.html\nDeepSeek API docs: https://api-docs.deepseek.com/',
              style:
                  TextStyle(color: AppColors.green, fontSize: 12, height: 1.5),
            ),
        ],
      ),
    );
  }
}

const _termsSections = <(String, String)>[
  (
    'Prototype access',
    'MacroLens currently provides a local demonstration. Sign-in and account creation are prototype flows only. Credentials are not verified, transmitted, or stored, and no account is created. The forgot-password screen explains that this demo cannot send reset emails.'
  ),
  (
    'Estimates, not measurements',
    'Food recognition, portion estimates, calorie totals, and macronutrient values are approximate and may be incomplete or wrong. A photo is not a scale reading. Confirm the food, review the suggested range, and adjust the amount before logging.'
  ),
  (
    'Not medical advice',
    'MacroLens is for general informational tracking only. It does not diagnose, treat, or prevent any condition and is not a substitute for medical or dietetic advice. Daily calorie and macro goals are rough estimates for adults. They are not shown for users under 18 and are not intended for pregnancy, breastfeeding, eating-disorder treatment, or medical nutrition plans. Consult a qualified professional for personal health decisions.'
  ),
  (
    'Acceptable use',
    'Use only photos you have permission to use. Do not use the prototype for emergencies, clinical decisions, or to process information about another person without their permission. If a photo contains text or instructions, Nouri treats them as image content, not as commands.'
  ),
  (
    'Availability and changes',
    'This prototype is provided for testing and may be changed or unavailable at any time. AI scanning requires internet access and a hosted scanner. The free scanner may take time to wake after inactivity and may be unavailable.'
  ),
  (
    'Local data',
    'Profile details and meal entries are saved locally on this device so the app can restore them. They are not sent to Nouri with a photo. You can delete meal history in Profile, and uninstalling the app clears its local data. The demo sign-in flag is not a verified account session.'
  ),
  (
    'AI-generated information',
    'Nouri’s answer is generated by an AI model and may contain errors or omissions. Only log a food after reviewing it. The hosted scanner uses DeepSeek to process the submitted photo and prompt; by using the scanner, you acknowledge that processing is subject to DeepSeek’s terms and privacy policy.'
  ),
  (
    'Contact and release readiness',
    'This prototype has no connected support or account service. Before public release, the operator should add its legal name and contact address, set an effective date, and have these terms reviewed for the intended markets.'
  ),
];

const _privacySections = <(String, String)>[
  (
    'Prototype and demo account',
    'The app has no authentication backend or cloud database. Login fields are used only for local form validation; the entered email and password are not sent or saved. A device-only sign-in flag remembers the demo until you sign out or remove the app. The forgot-password screen is a demo and does not send email.'
  ),
  (
    'Data saved on this device',
    'Profile details (name, age, height, weight, goal, goal weight, activity, and calorie-estimate setting) and your meal entries are saved in local app preferences on this device. Profile details are not uploaded to the scanner. Meal history stays on the device until you use Clear meal history in Profile, clear app data, or uninstall the app.'
  ),
  (
    'Food photos and AI scanning',
    'Only when you tap Scan with Nouri is the selected photo sent over HTTPS to the hosted MacroLens scanner. The scanner forwards the image and a food-analysis prompt to DeepSeek and returns one food match, a visual portion estimate with a low/high range, and approximate nutrition values per 100 grams. The app does not save scanner photos to the gallery or meal log; the device image picker may keep a temporary cached copy until the operating system clears it. Nouri is instructed to scan edible food and drinks only and to reject non-food, unclear, or sensitive images; this guardrail can still make mistakes. Do not scan people, documents, or sensitive images.'
  ),
  (
    'DeepSeek processing',
    'The DeepSeek API receives the photo and prompt for the requested scan. DeepSeek’s privacy policy (last updated February 10, 2026) says it collects user inputs, may use them to improve and train its technology, retains personal data as long as necessary for its services and legal obligations, and may process data outside your country, including in the People’s Republic of China. We do not claim a zero-retention mode or that DeepSeek will not review submitted content. Read DeepSeek’s privacy policy before scanning sensitive material.'
  ),
  (
    'Nutrition calculations',
    'For catalog foods, the app calculates nutrition locally from catalog values and the portion you confirm. For unmatched foods, Nouri supplies approximate generic values per 100 grams and the app scales them to your confirmed portion. Meal logs and profile details are not sent with a scan. Estimates are informational and can be inaccurate.'
  ),
  (
    'Retention and deletion',
    'The prototype scanner does not intentionally save uploaded photos. DeepSeek’s handling of a submitted image depends on its terms and privacy policy. In Profile, Clear meal history deletes locally saved meal entries. Clearing app data or uninstalling removes the demo sign-in, profile, and meal history from the device. There is no account deletion because no account is connected.'
  ),
  (
    'Network and security',
    'Hosted scanner traffic uses HTTPS. A private scanner access token is compiled into this demo build only; a token embedded in an APK is not a production security boundary. The DeepSeek API key stays on the scanner service and must not be placed in the phone app or public source code. This prototype has not had a security review and is not a production authentication system.'
  ),
  (
    'Contact and changes',
    'No privacy contact channel is connected in this prototype. Before public release, identify the responsible operator, contact details, applicable jurisdiction, retention rules, and an effective date, and have this notice reviewed for the intended markets.'
  ),
];
