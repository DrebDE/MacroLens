import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

const _weekdayLetters = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _weekdayShort = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthShort = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _monthLong = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isToday(DateTime value) => sameDay(value, DateTime.now());

DateTime startOfWeek(DateTime value) {
  final day = dateOnly(value);
  return day.subtract(Duration(days: day.weekday - 1));
}

String dateLong(DateTime value, {bool includeYear = false}) {
  final year =
      includeYear || value.year != DateTime.now().year ? ', ${value.year}' : '';
  return '${_weekdayShort[value.weekday - 1]}, ${_monthShort[value.month - 1]} ${value.day}$year';
}

String monthDay(DateTime value) =>
    '${_monthShort[value.month - 1]} ${value.day}';

String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 17) return 'Good afternoon';
  return 'Good evening';
}

String formatWhole(num value) {
  final rounded = value.round();
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return rounded < 0 ? '-$buffer' : buffer.toString();
}

String formatDecimal(double value, {int digits = 1}) =>
    value.toStringAsFixed(digits);

String formatGrams(double grams) => '${PortionUnit.grams.formatGrams(grams)} g';

String formatPortionRange(double low, double high, PortionUnit unit) =>
    '${unit.formatGrams(low)}–${unit.formatGrams(high)} ${unit.symbol}';

Future<DateTime?> pickDay(BuildContext context, DateTime current) {
  final today = dateOnly(DateTime.now());
  final safeCurrent = current.isAfter(today) ? today : current;
  return showDatePicker(
    context: context,
    initialDate: safeCurrent,
    firstDate: DateTime(2020),
    lastDate: today,
    helpText: 'Select a day',
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: Material(
          color: color ?? Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(appCardRadius),
            side: BorderSide(color: borderColor ?? AppColors.border),
          ),
          child: Padding(padding: padding, child: child),
        ),
      );
}

class AppBrand extends StatelessWidget {
  const AppBrand({super.key, this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.center_focus_strong_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'MacroLens',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      );
}

class DateNavigator extends StatelessWidget {
  const DateNavigator({
    super.key,
    required this.day,
    required this.onChanged,
  });

  final DateTime day;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final selected = dateOnly(day);
    final canGoBack = !selected.isBefore(DateTime(2020, 1, 1));
    final canGoForward = selected.isBefore(today);
    final label = isToday(selected)
        ? 'Today · ${monthDay(selected)}'
        : dateLong(selected);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _DayArrow(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Previous day',
            onPressed: canGoBack
                ? () => onChanged(selected.subtract(const Duration(days: 1)))
                : null,
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: () async {
                final picked = await pickDay(context, selected);
                if (picked != null) onChanged(dateOnly(picked));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      size: 15,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _DayArrow(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Next day',
            onPressed: canGoForward
                ? () => onChanged(selected.add(const Duration(days: 1)))
                : null,
          ),
        ],
      ),
    );
  }
}

class _DayArrow extends StatelessWidget {
  const _DayArrow({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        padding: EdgeInsets.zero,
        icon: Icon(
          icon,
          size: 22,
          color: onPressed == null ? AppColors.border : AppColors.ink,
        ),
      );
}

class CalorieRing extends StatelessWidget {
  const CalorieRing({
    super.key,
    required this.consumed,
    required this.goal,
    this.size = 72,
  });

  final double consumed;
  final double goal;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ratio =
        goal <= 0 ? 0.0 : (consumed / goal).clamp(0.0, 1.0).toDouble();
    final percent = goal <= 0 ? 0 : (consumed / goal * 100).round();
    return Semantics(
      label: goal <= 0
          ? 'No daily calorie target'
          : '$percent percent of daily calorie target',
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: size,
              child: CircularProgressIndicator(
                value: ratio,
                strokeWidth: 7,
                backgroundColor: AppColors.lime,
                color: AppColors.green,
                strokeCap: StrokeCap.round,
              ),
            ),
            Text(
              '$percent%',
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MacroProgress extends StatelessWidget {
  const MacroProgress({
    super.key,
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
  });

  final String label;
  final double value;
  final double goal;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                goal > 0
                    ? '${formatWhole(value)} / ${formatWhole(goal)} g'
                    : '${formatWhole(value)} g',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value:
                  goal <= 0 ? 0.0 : (value / goal).clamp(0.0, 1.0).toDouble(),
              minHeight: 6,
              backgroundColor: AppColors.border,
              color: color,
            ),
          ),
        ],
      );
}

class NutritionTiles extends StatelessWidget {
  const NutritionTiles({super.key, required this.food, required this.grams});

  final Food food;
  final double grams;

  @override
  Widget build(BuildContext context) {
    final metrics = <(String, String, String)>[
      ('Calories', formatWhole(food.kcalFor(grams)), 'kcal'),
      ('Protein', formatDecimal(food.proteinFor(grams)), 'g'),
      ('Carbs', formatDecimal(food.carbsFor(grams)), 'g'),
      ('Fat', formatDecimal(food.fatFor(grams)), 'g'),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _NutritionTile(
              label: metrics[i].$1,
              value: metrics[i].$2,
              unit: metrics[i].$3,
            ),
          ),
        ],
      ],
    );
  }
}

class _NutritionTile extends StatelessWidget {
  const _NutritionTile({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.paleGreen,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: AppColors.deepGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              unit,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 8.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 8.5,
              ),
            ),
          ],
        ),
      );
}

class MacroStat extends StatelessWidget {
  const MacroStat({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${formatDecimal(value)} g',
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
}

class SourceTag extends StatelessWidget {
  const SourceTag(this.source, {super.key});

  final FoodSource source;

  @override
  Widget build(BuildContext context) {
    final label = switch (source) {
      FoodSource.aiEstimate => 'AI estimate',
      FoodSource.custom => 'Custom',
      FoodSource.catalog => 'Catalog',
    };
    final background = switch (source) {
      FoodSource.aiEstimate => AppColors.lime,
      FoodSource.custom => const Color(0xFFF0F1E9),
      FoodSource.catalog => AppColors.paleGreen,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class FoodRow extends StatelessWidget {
  const FoodRow({super.key, required this.entry, this.onRemove});

  final MealEntry entry;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          entry.food.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ),
                      if (entry.food.source != FoodSource.catalog) ...[
                        const SizedBox(width: 5),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: SourceTag(entry.food.source),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${formatGrams(entry.grams)} · P ${formatDecimal(entry.protein)} · C ${formatDecimal(entry.carbs)} · F ${formatDecimal(entry.fat)} g',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${formatWhole(entry.kcal)} kcal',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (onRemove != null)
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      onPressed: onRemove,
                      tooltip: 'Remove ${entry.food.name}',
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
}

class NutritionPreviewCard extends StatelessWidget {
  const NutritionPreviewCard({
    super.key,
    required this.food,
    required this.grams,
    this.title = 'Nutrition in this amount',
  });

  final Food food;
  final double grams;
  final String title;

  @override
  Widget build(BuildContext context) => SectionCard(
        color: AppColors.paleGreen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  formatGrams(grams),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatWhole(food.kcalFor(grams)),
                      style: const TextStyle(
                        color: AppColors.deepGreen,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 5, bottom: 3),
                  child: Text(
                    'kcal',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                if (food.source != FoodSource.catalog) SourceTag(food.source),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _PreviewMacro(
                  label: 'Protein',
                  value: food.proteinFor(grams),
                ),
                _PreviewMacro(label: 'Carbs', value: food.carbsFor(grams)),
                _PreviewMacro(label: 'Fat', value: food.fatFor(grams)),
              ],
            ),
          ],
        ),
      );
}

class _PreviewMacro extends StatelessWidget {
  const _PreviewMacro({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${formatDecimal(value)} g',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

class MealSection extends StatelessWidget {
  const MealSection({
    super.key,
    required this.name,
    required this.entries,
    required this.onAdd,
    required this.onRemove,
  });

  final String name;
  final List<MealEntry> entries;
  final VoidCallback onAdd;
  final ValueChanged<MealEntry> onRemove;

  @override
  Widget build(BuildContext context) {
    final kcal = entries.fold<double>(0, (sum, entry) => sum + entry.kcal);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${formatWhole(kcal)} kcal',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10.5,
                  ),
                ),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: IconButton(
                    onPressed: onAdd,
                    tooltip: 'Add food to $name',
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 21,
                      color: AppColors.green,
                    ),
                  ),
                ),
              ],
            ),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 7, top: 1),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Nothing logged yet',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ),
              )
            else
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                FoodRow(
                  entry: entries[i],
                  onRemove: () => onRemove(entries[i]),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.day,
    required this.entries,
    required this.goal,
    required this.onSelect,
  });

  final DateTime day;
  final List<MealEntry> entries;
  final double goal;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final weekStart = startOfWeek(day);
    final today = dateOnly(DateTime.now());
    final days = List.generate(
      7,
      (index) => weekStart.add(Duration(days: index)),
    );
    final totals = days.map((candidate) {
      return entries
          .where((entry) => sameDay(entry.date, candidate))
          .fold<double>(0, (sum, entry) => sum + entry.kcal);
    }).toList();
    final maxLogged =
        totals.fold<double>(0, (maximum, value) => math.max(maximum, value));

    return SizedBox(
      height: 126,
      child: Row(
        children: List.generate(7, (index) {
          final candidate = days[index];
          final selected = sameDay(candidate, day);
          final enabled = !dateOnly(candidate).isAfter(today);
          final ratio = goal > 0
              ? (totals[index] / goal).clamp(0.0, 1.0).toDouble()
              : (maxLogged > 0 ? totals[index] / maxLogged : 0.0);
          final barHeight =
              totals[index] <= 0 ? 0.0 : math.max(0.05, ratio).toDouble();
          return Expanded(
            child: Semantics(
              button: enabled,
              selected: selected,
              label:
                  '${dateLong(candidate)}, ${formatWhole(totals[index])} calories',
              child: InkWell(
                onTap: enabled ? () => onSelect(dateOnly(candidate)) : null,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: barHeight,
                            widthFactor: 0.56,
                            child: Container(
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.deepGreen
                                    : enabled
                                        ? AppColors.green.withValues(alpha: .35)
                                        : AppColors.border,
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 25,
                        height: 25,
                        alignment: Alignment.center,
                        decoration: selected
                            ? BoxDecoration(
                                color: AppColors.lime,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.green,
                                  width: 1.3,
                                ),
                              )
                            : null,
                        child: Text(
                          _weekdayLetters[index],
                          style: TextStyle(
                            color: selected
                                ? AppColors.deepGreen
                                : AppColors.muted,
                            fontSize: 9.5,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${candidate.day}',
                        style: TextStyle(
                          color: selected ? AppColors.ink : AppColors.muted,
                          fontSize: 9.5,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.entries,
    required this.onMonthChanged,
    required this.onDaySelected,
  });

  /// Any date in the month to display.
  final DateTime month;
  final DateTime selectedDay;
  final List<MealEntry> entries;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final today = dateOnly(DateTime.now());
    final currentMonth = DateTime(today.year, today.month, 1);
    final canGoBack = first.isAfter(DateTime(2020, 1, 1));
    final canGoForward = first.isBefore(currentMonth);
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    final leading = first.weekday - 1;
    final cells = <DateTime?>[
      ...List<DateTime?>.filled(leading, null),
      for (var day = 1; day <= daysInMonth; day++)
        DateTime(first.year, first.month, day),
    ];
    while (cells.length < 42) {
      cells.add(null);
    }
    final loggedDays = entries.map((entry) => dateOnly(entry.date)).toSet();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_monthLong[first.month - 1]} ${first.year}',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _CalendarArrow(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Previous month',
              onPressed: canGoBack
                  ? () =>
                      onMonthChanged(DateTime(first.year, first.month - 1, 1))
                  : null,
            ),
            _CalendarArrow(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Next month',
              onPressed: canGoForward
                  ? () =>
                      onMonthChanged(DateTime(first.year, first.month + 1, 1))
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            for (final label in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: 42,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, index) {
            final date = cells[index];
            if (date == null) return const SizedBox.shrink();
            final selected = sameDay(date, selectedDay);
            final isTodayDate = sameDay(date, today);
            final logged = loggedDays.contains(date);
            final enabled = !date.isAfter(today);
            return Semantics(
              button: enabled,
              selected: selected,
              label:
                  '${_monthShort[date.month - 1]} ${date.day}${logged ? ', food logged' : ''}',
              child: InkWell(
                onTap: enabled ? () => onDaySelected(date) : null,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.deepGreen : null,
                    borderRadius: BorderRadius.circular(10),
                    border: !selected && isTodayDate
                        ? Border.all(color: AppColors.green, width: 1.2)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : enabled
                                  ? AppColors.ink
                                  : AppColors.border,
                          fontSize: 10.5,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: logged
                              ? (selected ? AppColors.lime : AppColors.green)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CalendarArrow extends StatelessWidget {
  const _CalendarArrow({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 38,
        height: 38,
        child: IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          icon: Icon(
            icon,
            size: 21,
            color: onPressed == null ? AppColors.border : AppColors.ink,
          ),
        ),
      );
}

class InfoNote extends StatelessWidget {
  const InfoNote({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.color,
    this.textColor,
  });

  final String text;
  final IconData icon;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color ?? AppColors.paleGreen,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: textColor ?? AppColors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: textColor ?? AppColors.muted,
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const <Widget>[],
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => SectionCard(
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.lime,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.green, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: actions,
              ),
            ],
          ],
        ),
      );
}
