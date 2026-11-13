import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../ui/common.dart';
import 'food_picker_page.dart';

enum _AddMode { catalog, custom }

class ManualAddPage extends StatefulWidget {
  const ManualAddPage({
    super.key,
    required this.day,
    this.initialMeal = 'Snacks',
    this.initialFood,
  });

  final DateTime day;
  final String initialMeal;
  final Food? initialFood;

  @override
  State<ManualAddPage> createState() => _ManualAddPageState();
}

class _ManualAddPageState extends State<ManualAddPage> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final servingAmount = TextEditingController(text: '100');
  final calories = TextEditingController();
  final protein = TextEditingController();
  final carbs = TextEditingController();
  final fat = TextEditingController();
  final amount = TextEditingController(text: '100');

  _AddMode mode = _AddMode.catalog;
  late Food? selectedFood = widget.initialFood;
  late String meal = mealCategories.contains(widget.initialMeal)
      ? widget.initialMeal
      : 'Snacks';
  PortionUnit servingUnit = PortionUnit.grams;
  PortionUnit unit = PortionUnit.grams;
  String? selectionError;

  @override
  void dispose() {
    name.dispose();
    servingAmount.dispose();
    calories.dispose();
    protein.dispose();
    carbs.dispose();
    fat.dispose();
    amount.dispose();
    super.dispose();
  }

  double? parseNumber(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  double? _servingGrams() {
    final value = parseNumber(servingAmount.text);
    if (value == null || value <= 0) return null;
    final grams = servingUnit.toGrams(value);
    if (!grams.isFinite || grams < 1 || grams > 5000) return null;
    return grams;
  }

  Food? previewFood() {
    if (mode == _AddMode.catalog) return selectedFood;
    final foodName = name.text.trim();
    final serving = _servingGrams();
    final kcalValue = parseNumber(calories.text);
    final proteinValue = parseNumber(protein.text);
    final carbsValue = parseNumber(carbs.text);
    final fatValue = parseNumber(fat.text);
    if (serving == null ||
        kcalValue == null ||
        proteinValue == null ||
        carbsValue == null ||
        fatValue == null) {
      return null;
    }
    return Food.fromServing(
      name: foodName,
      servingGrams: serving,
      calories: kcalValue,
      protein: proteinValue,
      carbs: carbsValue,
      fat: fatValue,
    );
  }

  double? previewGrams() {
    final value = parseNumber(amount.text);
    if (value == null || value <= 0) return null;
    final grams = unit.toGrams(value);
    if (!grams.isFinite || grams < 1 || grams > 5000) return null;
    return grams;
  }

  Future<void> chooseFood() async {
    final picked = await Navigator.of(context).push<Food>(
      MaterialPageRoute<Food>(
        fullscreenDialog: true,
        builder: (_) => FoodPickerPage(selected: selectedFood),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      selectedFood = picked;
      selectionError = null;
    });
  }

  void submit() {
    final valid = formKey.currentState?.validate() ?? false;
    if (mode == _AddMode.catalog && selectedFood == null) {
      setState(() => selectionError = 'Choose a food from the catalog.');
      return;
    }
    if (!valid) return;

    final food = previewFood();
    if (food == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Check the serving size and nutrition values for this food.',
          ),
        ),
      );
      return;
    }
    final grams = previewGrams();
    if (grams == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a portion from 1 to 5,000 g.')),
      );
      return;
    }

    final today = dateOnly(DateTime.now());
    final selectedDay = dateOnly(widget.day);
    final date = sameDay(today, selectedDay)
        ? DateTime.now()
        : DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 12);
    Navigator.of(context).pop(
      MealEntry(food: food, grams: grams, category: meal, date: date),
    );
  }

  @override
  Widget build(BuildContext context) {
    final food = previewFood();
    final grams = previewGrams();
    final dayText = isToday(widget.day) ? 'today' : dateLong(widget.day);
    return Scaffold(
      appBar: AppBar(title: const Text('Add food')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
          children: [
            Text(
              'Adding to $dayText. Nutrition updates as you type.',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<_AddMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _AddMode.catalog,
                  label: Text('Catalog'),
                  icon: Icon(Icons.restaurant_menu_rounded, size: 17),
                ),
                ButtonSegment(
                  value: _AddMode.custom,
                  label: Text('Custom food'),
                  icon: Icon(Icons.edit_note_rounded, size: 18),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (selection) =>
                  setState(() => mode = selection.first),
            ),
            const SizedBox(height: 16),
            if (mode == _AddMode.catalog)
              _CatalogChoice(
                food: selectedFood,
                error: selectionError,
                onTap: chooseFood,
              )
            else ...[
              TextFormField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Food name',
                  counterText: '',
                  prefixIcon: Icon(Icons.restaurant_rounded),
                ),
                validator: (value) => Food.validName(value ?? '')
                    ? null
                    : 'Enter a food name (120 characters or fewer).',
              ),
              const SizedBox(height: 14),
              const Text(
                'Serving size',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: servingAmount,
                      onChanged: (_) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: Icon(Icons.straighten_rounded),
                      ),
                      validator: (value) {
                        final parsed = parseNumber(value ?? '');
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a serving size.';
                        }
                        final converted = servingUnit.toGrams(parsed);
                        if (converted < 1 || converted > 5000) {
                          return 'Use 1–5,000 g.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 9),
                  SizedBox(
                    width: 126,
                    child: DropdownButtonFormField<PortionUnit>(
                      key: ValueKey(servingUnit),
                      initialValue: servingUnit,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 16,
                        ),
                      ),
                      items: PortionUnit.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null || value == servingUnit) return;
                        final parsed = parseNumber(servingAmount.text);
                        setState(() {
                          if (parsed != null && parsed > 0) {
                            servingAmount.text = value.formatGrams(
                              servingUnit.toGrams(parsed),
                            );
                          }
                          servingUnit = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Nutrition per serving',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: calories,
                      onChanged: (_) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Calories',
                        suffixText: 'kcal',
                      ),
                      validator: (value) {
                        final parsed = parseNumber(value ?? '');
                        if (parsed == null || parsed < 0 || parsed > 10000) {
                          return 'Use 0–10,000.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: TextFormField(
                      controller: protein,
                      onChanged: (_) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Protein',
                        suffixText: 'g',
                      ),
                      validator: (value) {
                        final parsed = parseNumber(value ?? '');
                        if (parsed == null || parsed < 0 || parsed > 1000) {
                          return 'Check value.';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: carbs,
                      onChanged: (_) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Carbs',
                        suffixText: 'g',
                      ),
                      validator: (value) {
                        final parsed = parseNumber(value ?? '');
                        if (parsed == null || parsed < 0 || parsed > 1000) {
                          return 'Check value.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: TextFormField(
                      controller: fat,
                      onChanged: (_) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Fat',
                        suffixText: 'g',
                      ),
                      validator: (value) {
                        final parsed = parseNumber(value ?? '');
                        if (parsed == null || parsed < 0 || parsed > 1000) {
                          return 'Check value.';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Use the values on the package for one serving.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10.5,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Portion to add',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: amount,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixIcon: Icon(Icons.scale_outlined),
                    ),
                    validator: (value) {
                      final parsed = parseNumber(value ?? '');
                      if (parsed == null || parsed <= 0) {
                        return 'Enter an amount.';
                      }
                      final grams = unit.toGrams(parsed);
                      if (grams < 1 || grams > 5000) {
                        return 'Use 1–5,000 g.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 9),
                SizedBox(
                  width: 126,
                  child: DropdownButtonFormField<PortionUnit>(
                    key: ValueKey(unit),
                    initialValue: unit,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 16,
                      ),
                    ),
                    items: PortionUnit.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null || value == unit) return;
                      final parsed = parseNumber(amount.text);
                      setState(() {
                        if (parsed != null && parsed > 0) {
                          amount.text = value.formatGrams(unit.toGrams(parsed));
                        }
                        unit = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: meal,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Meal',
                prefixIcon: Icon(Icons.schedule_rounded),
              ),
              items: mealCategories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => meal = value ?? meal),
            ),
            const SizedBox(height: 16),
            if (food != null && grams != null) ...[
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Nutrition',
                            style: TextStyle(
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
                    const SizedBox(height: 8),
                    NutritionTiles(food: food, grams: grams),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            const InfoNote(
              icon: Icons.info_outline_rounded,
              text:
                  'Nutrition values are estimates. You can adjust the portion before adding it.',
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 8, 18, 12),
        child: SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: submit,
            icon: const Icon(Icons.add_rounded),
            label: Text('Add to $meal'),
          ),
        ),
      ),
    );
  }
}

class _CatalogChoice extends StatelessWidget {
  const _CatalogChoice({
    required this.food,
    required this.error,
    required this.onTap,
  });

  final Food? food;
  final String? error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: food == null
                ? Colors.white
                : AppColors.lime.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: error == null ? AppColors.border : AppColors.danger,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.paleGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.restaurant_menu_rounded,
                        color: AppColors.green,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            food?.name ?? 'Choose a food',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            food == null
                                ? 'Search the food catalog'
                                : '${formatWhole(food!.kcal100)} kcal · P ${formatDecimal(food!.protein100)} · C ${formatDecimal(food!.carbs100)} · F ${formatDecimal(food!.fat100)} g per 100 g',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 11),
              ),
            ),
        ],
      );
}

/// Opens the full-screen manual-entry page and returns a confirmed entry.
Future<void> openManualAdd(
  BuildContext context, {
  required DateTime day,
  required ValueChanged<MealEntry> onAdd,
  String? meal,
  Food? initialFood,
}) async {
  final entry = await Navigator.of(context).push<MealEntry>(
    MaterialPageRoute<MealEntry>(
      fullscreenDialog: true,
      builder: (_) => ManualAddPage(
        day: day,
        initialMeal: meal ?? defaultMealForNow(),
        initialFood: initialFood,
      ),
    ),
  );
  if (entry != null && context.mounted) onAdd(entry);
}
