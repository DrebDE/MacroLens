import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../ui/common.dart';
import 'manual_add_page.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    required this.day,
    required this.entries,
    required this.profile,
    required this.onDay,
    required this.onAdd,
    required this.onRemove,
    required this.onScan,
    required this.onShowLog,
  });

  final DateTime day;
  final List<MealEntry> entries;
  final HealthProfile profile;
  final ValueChanged<DateTime> onDay;
  final ValueChanged<MealEntry> onAdd;
  final ValueChanged<MealEntry> onRemove;
  final VoidCallback onScan;
  final VoidCallback onShowLog;

  @override
  Widget build(BuildContext context) {
    final dayEntries =
        entries.where((entry) => sameDay(entry.date, day)).toList();
    final kcal = dayEntries.fold<double>(0, (sum, entry) => sum + entry.kcal);
    final protein =
        dayEntries.fold<double>(0, (sum, entry) => sum + entry.protein);
    final carbs = dayEntries.fold<double>(0, (sum, entry) => sum + entry.carbs);
    final fat = dayEntries.fold<double>(0, (sum, entry) => sum + entry.fat);
    final displayName =
        profile.name.trim().isEmpty ? 'there' : profile.name.trim();
    final adultTargets = profile.canEstimateCalories;

    final weekStart = startOfWeek(day);
    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekEntries = entries.where(
      (entry) =>
          !dateOnly(entry.date).isBefore(weekStart) &&
          !dateOnly(entry.date).isAfter(weekEnd),
    );
    final weekTotal =
        weekEntries.fold<double>(0, (sum, entry) => sum + entry.kcal);
    final loggedWeekDays = entries
        .where(
          (entry) =>
              !dateOnly(entry.date).isBefore(weekStart) &&
              !dateOnly(entry.date).isAfter(weekEnd),
        )
        .map((entry) => dateOnly(entry.date))
        .toSet();
    final weekAverage =
        loggedWeekDays.isEmpty ? 0.0 : weekTotal / loggedWeekDays.length;
    final remaining = profile.calories - kcal;

    final energyTitle = !adultTargets
        ? 'Today’s energy'
        : remaining < 0
            ? 'A little over today'
            : profile.calories > 0 && kcal >= profile.calories * .8
                ? 'Almost at your goal'
                : 'You’re on track';
    final energySubtitle = adultTargets
        ? '${formatWhole(kcal)} of ${formatWhole(profile.calories)} kcal · ${remaining >= 0 ? '${formatWhole(remaining)} left' : '${formatWhole(-remaining)} over'}'
        : '${formatWhole(kcal)} kcal logged today';

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
      children: [
        const AppBrand(),
        const SizedBox(height: 14),
        DateNavigator(day: day, onChanged: onDay),
        const SizedBox(height: 14),
        Text(
          '${greetingFor(DateTime.now())}, $displayName',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          isToday(day)
              ? 'Here’s your nutrition for today.'
              : 'Reviewing what you logged.',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        SectionCard(
          color: AppColors.paleGreen,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DAILY ENERGY',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      energyTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      energySubtitle,
                      style: TextStyle(
                        color: remaining < 0 && adultTargets
                            ? AppColors.amber
                            : AppColors.muted,
                        fontSize: 10.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 38,
                      child: FilledButton.icon(
                        onPressed: onScan,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add food'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          textStyle: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (adultTargets) ...[
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: CalorieRing(
                    consumed: kcal,
                    goal: profile.calories,
                    size: 84,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Macronutrients',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    adultTargets ? 'Your balance today' : 'Logged today',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (adultTargets) ...[
                MacroProgress(
                  label: 'Protein',
                  value: protein,
                  goal: profile.proteinGoal,
                  color: AppColors.deepGreen,
                ),
                const SizedBox(height: 12),
                MacroProgress(
                  label: 'Carbs',
                  value: carbs,
                  goal: profile.carbsGoal,
                  color: AppColors.green,
                ),
                const SizedBox(height: 12),
                MacroProgress(
                  label: 'Fat',
                  value: fat,
                  goal: profile.fatGoal,
                  color: const Color(0xFF00695C),
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: MacroStat(
                        label: 'Protein',
                        value: protein,
                        color: AppColors.deepGreen,
                      ),
                    ),
                    Expanded(
                      child: MacroStat(
                        label: 'Carbs',
                        value: carbs,
                        color: AppColors.green,
                      ),
                    ),
                    Expanded(
                      child: MacroStat(
                        label: 'Fat',
                        value: fat,
                        color: const Color(0xFF00695C),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionHeading(
          title: 'Today’s meals',
          subtitle:
              '${dayEntries.length} ${dayEntries.length == 1 ? 'item' : 'items'} logged',
          trailing: IconButton(
            onPressed: () => openManualAdd(
              context,
              day: day,
              onAdd: onAdd,
              meal: defaultMealForNow(),
            ),
            tooltip: 'Add food',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.paleGreen,
              foregroundColor: AppColors.green,
            ),
            icon: const Icon(Icons.add_rounded),
          ),
        ),
        const SizedBox(height: 8),
        for (final category in mealCategories)
          MealSection(
            name: category,
            entries: dayEntries
                .where((entry) => entry.category == category)
                .toList(),
            onAdd: () => openManualAdd(
              context,
              day: day,
              onAdd: onAdd,
              meal: category,
            ),
            onRemove: onRemove,
          ),
        const SizedBox(height: 4),
        _SmartScanCard(onTap: onScan),
        const SizedBox(height: 18),
        SectionHeading(
          title: 'This week',
          subtitle: '${monthDay(weekStart)} – ${monthDay(weekEnd)}',
          trailing: TextButton(
            onPressed: onShowLog,
            child: const Text('History'),
          ),
        ),
        const SizedBox(height: 8),
        SectionCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Average calories',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 10.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${formatWhole(weekAverage)} kcal',
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (adultTargets)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        'Goal ${formatWhole(profile.calories)}/day',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                loggedWeekDays.isEmpty
                    ? 'No meals logged this week yet.'
                    : 'Across ${loggedWeekDays.length} logged ${loggedWeekDays.length == 1 ? 'day' : 'days'}',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 9.5,
                ),
              ),
              const SizedBox(height: 4),
              WeekStrip(
                day: day,
                entries: entries,
                goal: profile.calories,
                onSelect: onDay,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Portions and nutrition are estimates.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 10),
        ),
      ],
    );
  }
}

class _SmartScanCard extends StatelessWidget {
  const _SmartScanCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.paleGreen,
        borderRadius: BorderRadius.circular(appCardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(appCardRadius),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(appCardRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.green,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SMART SCAN',
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .8,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'What’s on your plate?',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Scan a meal',
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.green,
                ),
              ],
            ),
          ),
        ),
      );
}
