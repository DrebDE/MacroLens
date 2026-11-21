import 'package:flutter/material.dart';

import '../theme.dart';
import 'forgot_password_page.dart';
import 'legal_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onContinue});

  final Future<void> Function(String? displayName) onContinue;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool accepted = false;
  bool register = false;
  bool showPassword = false;
  bool submitting = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> enterDemo() async {
    if (register && !accepted) return;
    if (!(formKey.currentState?.validate() ?? false)) return;
    password.clear();
    setState(() => submitting = true);
    try {
      await widget.onContinue(register ? name.text.trim() : null);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save this device’s sign-in. Try again.'),
        ),
      );
      setState(() => submitting = false);
    }
  }

  Future<void> openForgotPassword() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ForgotPasswordPage(initialEmail: email.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.green,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.center_focus_strong_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'MacroLens',
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        register ? 'START YOUR JOURNEY' : 'WELCOME BACK',
                        style: const TextStyle(
                          color: AppColors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        register
                            ? 'Create your account'
                            : 'Sign in to MacroLens',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        register
                            ? 'Set up your profile and get a personalized daily goal.'
                            : 'Continue tracking your meals and daily progress.',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _AuthTabs(
                        register: register,
                        onChanged: (value) => setState(() {
                          register = value;
                          if (!register) accepted = false;
                        }),
                      ),
                      const SizedBox(height: 18),
                      if (register) ...[
                        TextFormField(
                          controller: name,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          maxLength: 60,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            hintText: 'Alex Smith',
                            counterText: '',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Enter your full name.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          hintText: 'you@example.com',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (!text.contains('@') ||
                              !text.contains('.') ||
                              text.startsWith('@') ||
                              text.endsWith('@')) {
                            return 'Enter a valid email address.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: password,
                        obscureText: !showPassword,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => enterDemo(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'At least 8 characters',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: showPassword
                                ? 'Hide password'
                                : 'Show password',
                            onPressed: () =>
                                setState(() => showPassword = !showPassword),
                            icon: Icon(
                              showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => (value ?? '').length >= 8
                            ? null
                            : 'Use at least 8 characters.',
                      ),
                      if (!register)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: openForgotPassword,
                            child: const Text('Forgot password?'),
                          ),
                        ),
                      if (register) ...[
                        const SizedBox(height: 6),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: accepted,
                          onChanged: (value) =>
                              setState(() => accepted = value ?? false),
                          title: _AgreementText(
                            onTerms: () => showLegal(context, LegalKind.terms),
                            onPrivacy: () =>
                                showLegal(context, LegalKind.privacy),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: submitting || (register && !accepted)
                              ? null
                              : enterDemo,
                          child: submitting
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  register ? 'Create my account' : 'Sign in',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(() {
                          register = !register;
                          if (!register) accepted = false;
                        }),
                        child: Text(
                          register
                              ? 'Already have an account? Sign in'
                              : 'New to MacroLens? Create an account',
                        ),
                      ),
                      if (!register) ...[
                        const SizedBox(height: 2),
                        _LegalFooter(
                          onTerms: () => showLegal(context, LegalKind.terms),
                          onPrivacy: () =>
                              showLegal(context, LegalKind.privacy),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: AppColors.lime.withValues(alpha: .65),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Demo sign-in: no account is created, and your email and password are not sent or saved. This device remembers that you entered the demo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _AuthTabs extends StatelessWidget {
  const _AuthTabs({required this.register, required this.onChanged});

  final bool register;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.paleGreen,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: _AuthTab(
                label: 'Sign in',
                selected: !register,
                onTap: () => onChanged(false),
              ),
            ),
            Expanded(
              child: _AuthTab(
                label: 'Create account',
                selected: register,
                onTap: () => onChanged(true),
              ),
            ),
          ],
        ),
      );
}

class _AuthTab extends StatelessWidget {
  const _AuthTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: selected ? Border.all(color: AppColors.border) : null,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? AppColors.ink : AppColors.muted,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
}

class _AgreementText extends StatelessWidget {
  const _AgreementText({
    required this.onTerms,
    required this.onPrivacy,
  });

  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) => Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'I agree to the ',
            style: TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
          _LegalLink(label: 'Terms of Service', onTap: onTerms),
          const Text(
            ' and ',
            style: TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
          _LegalLink(label: 'Privacy Policy', onTap: onPrivacy),
          const Text(
            '.',
            style: TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
        ],
      );
}

class _LegalFooter extends StatelessWidget {
  const _LegalFooter({required this.onTerms, required this.onPrivacy});

  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'By continuing, you agree to our ',
            style: TextStyle(fontSize: 10.5, color: AppColors.muted),
          ),
          _LegalLink(label: 'Terms', onTap: onTerms),
          const Text(
            ' and ',
            style: TextStyle(fontSize: 10.5, color: AppColors.muted),
          ),
          _LegalLink(label: 'Privacy Policy', onTap: onPrivacy),
          const Text(
            '.',
            style: TextStyle(fontSize: 10.5, color: AppColors.muted),
          ),
        ],
      );
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.green,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
          ),
        ),
      );
}
