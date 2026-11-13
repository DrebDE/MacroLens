import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../ui/common.dart';
import 'manual_add_page.dart';

class FoodLogPage extends StatefulWidget {
  const FoodLogPage({
    super.key,
    required this.day,
    required this.entries,
    required this.profile,
    required this.onDay,
    required this.onScan,
    required this.onAdd,
    required this.onRemove,
  });

  final DateTime day;
  final List<MealEntry> entries;
  final HealthProfile profile;
  final ValueChanged<DateTime> onDay;
  final VoidCallback onScan;
  final ValueChanged<MealEntry> onAdd;
  final ValueChanged<MealEntry> onRemove;

  @override
  State<FoodLogPage> createState() => _FoodLogPageState();
}

class _FoodLogPageState extends State<FoodLogPage> {
  late DateTime month = DateTime(widget.day.year, widget.day.month, 1);

  @override
  void didUpdateWidget(covariant FoodLogPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!sameDay(widget.day, oldWidget.day) &&
        (widget.day.year != month.year || widget.day.month != month.month)) {
      month = DateTime(widget.day.year, widget.day.month, 1);
    }
  }

  void _changeMonth(DateTime newMonth) {
    final first = DateTime(newMonth.year, newMonth.month, 1);
    final today = dateOnly(DateTime.now());
    final selected =
        first.year == today.year && first.month == today.month ? today : first;
    setState(() => month = first);
    widget.onDay(selected);
  }

  void _selectDay(DateTime day) {
    setState(() => month = DateTime(day.year, day.month, 1));
    widget.onDay(day);
  }

  @override
  Widget build(BuildContext context) {
    final dayEntries = widget.entries
        .where((entry) => sameDay(entry.date, widget.day))
        .toList();
    final kcal = dayEntries.fold<double>(0, (sum, entry) => sum + entry.kcal);
    final protein =
        dayEntries.fold<double>(0, (sum, entry) => sum + entry.protein);
    final carbs = dayEntries.fold<double>(0, (sum, entry) => sum + entry.carbs);
    final fat = dayEntries.fold<double>(0, (sum, entry) => sum + entry.fat);
    final adultTargets = widget.profile.canEstimateCalories;

    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    final monthEntries = widget.entries.where(
      (entry) =>
          !dateOnly(entry.date).isBefore(monthStart) &&
          !dateOnly(entry.date).isAfter(monthEnd),
    );
    final monthDays = monthEntries.map((entry) => dateOnly(entry.date)).toSet();
    final monthKcal =
        monthEntries.fold<double>(0, (sum, entry) => sum + entry.kcal);
    final dailyAverage = monthDays.isEmpty ? 0.0 : monthKcal / monthDays.length;
    final today = dateOnly(DateTime.now());
    final elapsedDays = month.year == today.year && month.month == today.month
        ? today.day
        : monthEnd.day;
    final loggedPercent =
        elapsedDays == 0 ? 0.0 : monthDays.length / elapsedDays;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
      children: [
        const AppBrand(),
        const SizedBox(height: 16),
        const Text(
          'Food log',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Review meals or add food to your day.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        SectionCard(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: MonthCalendar(
            month: month,
            selectedDay: widget.day,
            entries: widget.entries,
            onMonthChanged: _changeMonth,
            onDaySelected: _selectDay,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isToday(widget.day) ? 'Today' : dateLong(widget.day),
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${dayEntries.length} ${dayEntries.length == 1 ? 'item' : 'items'} logged',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.paleGreen,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '${formatWhole(kcal)} kcal',
                style: const TextStyle(
                  color: AppColors.deepGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          adultTargets
              ? 'of ${formatWhole(widget.profile.calories)} kcal goal · P ${formatWhole(protein)} g · C ${formatWhole(carbs)} g · F ${formatWhole(fat)} g'
              : 'P ${formatWhole(protein)} g · C ${formatWhole(carbs)} g · F ${formatWhole(fat)} g',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        if (dayEntries.isEmpty)
          EmptyState(
            icon: Icons.restaurant_outlined,
            title: 'Nothing logged for this day',
            message:
                'Scan a meal or enter food manually to add it to your log.',
            actions: [
              OutlinedButton.icon(
                onPressed: widget.onScan,
                icon: const Icon(Icons.document_scanner_outlined, size: 18),
                label: const Text('Add food'),
              ),
            ],
          )
        else
          for (final category in mealCategories)
            MealSection(
              name: category,
              entries: dayEntries
                  .where((entry) => entry.category == category)
                  .toList(),
              onAdd: () => openManualAdd(
                context,
                day: widget.day,
                onAdd: widget.onAdd,
                meal: category,
              ),
              onRemove: widget.onRemove,
            ),
        const SizedBox(height: 4),
        if (dayEntries.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: widget.onScan,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add food'),
            ),
          ),
        ],
        const SizedBox(height: 6),
        SizedBox(
          height: 46,
          child: TextButton.icon(
            onPressed: () => openManualAdd(
              context,
              day: widget.day,
              onAdd: widget.onAdd,
              meal: defaultMealForNow(),
            ),
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Add food manually'),
          ),
        ),
        const SizedBox(height: 16),
        const SectionHeading(title: 'Monthly snapshot'),
        const SizedBox(height: 8),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Daily average',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${formatWhole(dailyAverage)} kcal',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                monthDays.isEmpty
                    ? 'No meals logged this month yet.'
                    : 'Across ${monthDays.length} logged ${monthDays.length == 1 ? 'day' : 'days'}',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                ),
              ),
              if (adultTargets) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: widget.profile.calories <= 0
                        ? 0
                        : (dailyAverage / widget.profile.calories)
                            .clamp(0.0, 1.0)
                            .toDouble(),
                    minHeight: 7,
                    backgroundColor: AppColors.border,
                    color: AppColors.green,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${(dailyAverage / widget.profile.calories * 100).round()}% of your daily goal',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Days logged',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${monthDays.length}',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 5, bottom: 1),
                    child: Text(
                      'of $elapsedDays days',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: loggedPercent.clamp(0.0, 1.0).toDouble(),
                  minHeight: 7,
                  backgroundColor: AppColors.border,
                  color: AppColors.deepGreen,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Meal entries are saved on this device. Remove an entry with × or clear all history in Profile.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
