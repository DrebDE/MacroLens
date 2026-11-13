import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../ui/common.dart';
import 'legal_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.profile,
    required this.onSaved,
    required this.onSignOut,
    required this.onClearHistory,
    required this.hasHistory,
  });

  final HealthProfile profile;
  final Future<void> Function() onSaved;
  final VoidCallback onSignOut;
  final Future<void> Function() onClearHistory;
  final bool hasHistory;

  Future<void> _edit(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileEditorPage(
          profile: profile,
          onSave: onSaved,
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear meal history?'),
        content: const Text(
          'This deletes every meal entry saved on this device. Your profile and demo sign-in stay. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete history'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onClearHistory();
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out of this device?'),
        content: const Text(
          'Your profile and meal history stay on this device. You will return to the demo sign-in screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final initial = profile.name.trim().isEmpty
        ? '?'
        : profile.name.trim()[0].toUpperCase();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
      children: [
        const AppBrand(),
        const SizedBox(height: 16),
        const Text(
          'Profile & goals',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Your details and daily nutrition targets.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 13),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.lime,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: AppColors.deepGreen,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name.trim().isEmpty
                              ? 'Your profile'
                              : profile.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _Pill(text: profile.goal),
                            if (profile.goalWeight != null)
                              _Pill(
                                text:
                                    'Goal ${profile.goalWeight!.toStringAsFixed(1)} kg',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _edit(context),
                    tooltip: 'Edit profile',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.green,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.cake_outlined,
                label: 'Age',
                value: profile.age == 0 ? 'Not set' : '${profile.age} years',
              ),
              _InfoRow(
                icon: Icons.height_rounded,
                label: 'Height',
                value: profile.height == 0
                    ? 'Not set'
                    : '${profile.height.toStringAsFixed(0)} cm',
              ),
              _InfoRow(
                icon: Icons.monitor_weight_outlined,
                label: 'Current weight',
                value: profile.weight == 0
                    ? 'Not set'
                    : '${profile.weight.toStringAsFixed(1)} kg',
              ),
              _InfoRow(
                icon: Icons.directions_walk_outlined,
                label: 'Activity',
                value: profile.activityLabel,
              ),
              _InfoRow(
                icon: Icons.tune_rounded,
                label: 'Sex used for estimate',
                value: profile.formulaSetting,
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit profile'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        if (profile.canEstimateCalories) ...[
          SectionCard(
            color: AppColors.deepGreen,
            borderColor: AppColors.deepGreen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DAILY CALORIE GOAL',
                  style: TextStyle(
                    color: AppColors.lime,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatWhole(profile.calories),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 5, bottom: 3),
                      child: Text(
                        'kcal / day',
                        style: TextStyle(
                          color: AppColors.lime,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${profile.goal} · ${profile.activityLabel}',
                  style: const TextStyle(
                    color: AppColors.lime,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: _DarkMacro(
                        label: 'Protein',
                        grams: profile.proteinGoal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DarkMacro(
                        label: 'Carbs',
                        grams: profile.carbsGoal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DarkMacro(
                        label: 'Fat',
                        grams: profile.fatGoal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'A rough daily goal based on your profile. Update your details whenever things change.',
                  style: TextStyle(
                    color: AppColors.lime,
                    fontSize: 10,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: AppColors.paleGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.eco_outlined,
                        color: AppColors.green,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Daily goals aren’t available',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'We don’t set calorie or macro goals for users under 18. You can still track what you eat and review your totals in Today and Food log.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        const InfoNote(
          icon: Icons.medical_information_outlined,
          text:
              'Daily goals are rough estimates for adults, not medical advice. They are not intended for pregnancy, breastfeeding, eating-disorder treatment, or medical nutrition plans. Talk to a qualified professional for personal goals.',
        ),
        const SizedBox(height: 16),
        const SectionHeading(title: 'About MacroLens'),
        const SizedBox(height: 8),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.description_outlined,
                  color: AppColors.green,
                ),
                title: const Text('Terms of Service'),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.muted,
                ),
                onTap: () => showLegal(context, LegalKind.terms),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(
                  Icons.privacy_tip_outlined,
                  color: AppColors.green,
                ),
                title: const Text('Privacy Policy'),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.muted,
                ),
                onTap: () => showLegal(context, LegalKind.privacy),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionHeading(title: 'Your data'),
        const SizedBox(height: 8),
        SectionCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(
              Icons.delete_sweep_outlined,
              color: AppColors.green,
            ),
            title: const Text('Clear meal history'),
            subtitle: Text(
              hasHistory
                  ? 'Delete every locally saved meal entry'
                  : 'No meal history saved',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
            ),
            enabled: hasHistory,
            onTap: hasHistory ? () => _confirmClear(context) : null,
          ),
        ),
        const SizedBox(height: 13),
        OutlinedButton.icon(
          onPressed: () => _confirmSignOut(context),
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text('Sign out of this device'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Profile details and meal history are stored on this device only. A scan sends only the selected photo to Nouri’s hosted scanner.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 10.5,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.paleGreen,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.green,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: AppColors.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class _DarkMacro extends StatelessWidget {
  const _DarkMacro({
    required this.label,
    required this.grams,
  });

  final String label;
  final double grams;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.lime,
                fontSize: 9.5,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${formatWhole(grams)} g',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

class ProfileEditorPage extends StatefulWidget {
  const ProfileEditorPage({
    super.key,
    required this.profile,
    required this.onSave,
    this.isSetup = false,
  });

  final HealthProfile profile;
  final Future<void> Function() onSave;
  final bool isSetup;

  @override
  State<ProfileEditorPage> createState() => _ProfileEditorPageState();
}

class _ProfileEditorPageState extends State<ProfileEditorPage> {
  final formKey = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.profile.name);
  late final age = TextEditingController(
    text: widget.profile.age == 0 ? '' : '${widget.profile.age}',
  );
  late final height = TextEditingController(
    text: widget.profile.height == 0 ? '' : '${widget.profile.height}',
  );
  late final weight = TextEditingController(
    text: widget.profile.weight == 0 ? '' : '${widget.profile.weight}',
  );
  late final goalWeight = TextEditingController(
    text: widget.profile.goalWeight?.toString() ?? '',
  );
  late String formulaSetting = widget.profile.formulaSetting;
  late String goal = widget.profile.goal;
  late double activity = widget.profile.activity;
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    height.dispose();
    weight.dispose();
    goalWeight.dispose();
    super.dispose();
  }

  double? parseNumber(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  Future<void> submit() async {
    if (saving || !(formKey.currentState?.validate() ?? false)) return;
    final ageValue = int.parse(age.text.trim());
    final heightValue = parseNumber(height.text)!;
    final weightValue = parseNumber(weight.text)!;
    final targetValue =
        goal == 'Maintain weight' || goalWeight.text.trim().isEmpty
            ? null
            : parseNumber(goalWeight.text);

    widget.profile
      ..name = name.text.trim()
      ..age = ageValue
      ..height = heightValue
      ..weight = weightValue
      ..goal = goal
      ..goalWeight = targetValue
      ..formulaSetting = formulaSetting
      ..activity = activity;

    setState(() => saving = true);
    try {
      await widget.onSave();
      if (!mounted) return;
      if (!widget.isSetup) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your profile. Please try again.'),
        ),
      );
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.isSetup,
          title: Text(widget.isSetup ? 'Set up your profile' : 'Edit profile'),
        ),
        body: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
            children: [
              Text(
                widget.isSetup
                    ? 'A few details help MacroLens estimate your daily targets. Everything here stays on your device.'
                    : 'Update your details and nutrition goal. Everything here stays on your device.',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  counterText: '',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return 'Enter your name.';
                  if (text.length > 60) return 'Use 60 characters or fewer.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: age,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Age (years)',
                  prefixIcon: Icon(Icons.cake_outlined),
                ),
                validator: (value) {
                  final parsed = int.tryParse((value ?? '').trim());
                  if (parsed == null || parsed < 13 || parsed > 110) {
                    return 'Enter an age from 13 to 110.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: height,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Height',
                        suffixText: 'cm',
                      ),
                      validator: (value) {
                        final parsed = parseNumber(value ?? '');
                        if (parsed == null || parsed < 100 || parsed > 250) {
                          return 'Use 100–250 cm.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: weight,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Current weight',
                        suffixText: 'kg',
                      ),
                      validator: (value) {
                        final parsed = parseNumber(value ?? '');
                        if (parsed == null || parsed < 30 || parsed > 350) {
                          return 'Use 30–350 kg.';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: goal,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Your goal',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                items: HealthProfile.goals
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => goal = value ?? goal),
              ),
              if (goal != 'Maintain weight') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: goalWeight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Goal weight (optional)',
                    suffixText: 'kg',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return null;
                    final parsed = parseNumber(text);
                    final current = parseNumber(weight.text);
                    if (parsed == null || parsed < 30 || parsed > 350) {
                      return 'Use 30–350 kg.';
                    }
                    if (current != null &&
                        ((goal == 'Lose weight' && parsed >= current) ||
                            (goal == 'Gain weight' && parsed <= current))) {
                      return goal == 'Lose weight'
                          ? 'For this goal, enter a lower weight.'
                          : 'For this goal, enter a higher weight.';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<double>(
                initialValue: activity,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Usual activity level',
                  prefixIcon: Icon(Icons.directions_walk_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 1.2,
                    child: Text('Mostly sitting'),
                  ),
                  DropdownMenuItem(
                    value: 1.375,
                    child: Text('Light activity'),
                  ),
                  DropdownMenuItem(
                    value: 1.55,
                    child: Text('Moderate activity'),
                  ),
                  DropdownMenuItem(
                    value: 1.725,
                    child: Text('Very active'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => activity = value ?? activity),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: formulaSetting,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Sex used for estimate',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: HealthProfile.formulaSettings
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => formulaSetting = value ?? formulaSetting),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 5, left: 12, right: 12),
                child: Text(
                  'Used only to estimate your daily calorie goal. Choose “Average” if you prefer not to use a sex-specific estimate.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 10.5,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              const InfoNote(
                icon: Icons.medical_information_outlined,
                text:
                    'Daily goals are rough estimates for adults 18 and older. They are not intended for pregnancy, breastfeeding, eating-disorder treatment, or medical nutrition plans. Goals are not estimated for users under 18.',
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: saving ? null : submit,
              child: saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(widget.isSetup ? 'Save profile' : 'Save changes'),
            ),
          ),
        ),
      );
}
