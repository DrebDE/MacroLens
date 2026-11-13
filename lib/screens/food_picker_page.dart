import 'package:flutter/material.dart';

import '../catalog.dart';
import '../models.dart';
import '../theme.dart';
import '../ui/common.dart';

class FoodPickerPage extends StatefulWidget {
  const FoodPickerPage({super.key, this.aiEstimate, this.selected});

  final Food? aiEstimate;
  final Food? selected;

  @override
  State<FoodPickerPage> createState() => _FoodPickerPageState();
}

class _FoodPickerPageState extends State<FoodPickerPage> {
  final search = TextEditingController();
  String query = '';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void choose(Food food) => Navigator.of(context).pop(food);

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeFoodText(query);
    final matchesAi = widget.aiEstimate != null &&
        (normalized.isEmpty ||
            normalizeFoodText(widget.aiEstimate!.name).contains(normalized));
    final results = searchCatalog(query);

    return Scaffold(
      appBar: AppBar(title: const Text('Choose food')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
            child: TextField(
              controller: search,
              onChanged: (value) => setState(() => query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search the food catalog',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          search.clear();
                          setState(() => query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 24),
              children: [
                if (matchesAi) ...[
                  const _ListLabel('From this scan'),
                  _FoodTile(
                    food: widget.aiEstimate!,
                    selected: widget.aiEstimate == widget.selected,
                    onTap: () => choose(widget.aiEstimate!),
                  ),
                  const SizedBox(height: 14),
                ],
                const _ListLabel('Food catalog'),
                if (results.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 26),
                    child: Text(
                      'No catalog match. Clear the search to use Nouri’s estimate, go back and add a custom food, or try a different search.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  )
                else
                  ...results.map(
                    (food) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _FoodTile(
                        food: food,
                        selected: food == widget.selected,
                        onTap: () => choose(food),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                const InfoNote(
                  icon: Icons.straighten_rounded,
                  text:
                      'Catalog values are typical per-100-gram values. AI values are generic estimates. Either way, confirm the amount before logging.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListLabel extends StatelessWidget {
  const _ListLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7, top: 4),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
          ),
        ),
      );
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({
    required this.food,
    required this.selected,
    required this.onTap,
  });

  final Food food;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? AppColors.lime.withValues(alpha: .5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 11, 12, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.green : AppColors.border,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.paleGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    food.source == FoodSource.aiEstimate
                        ? Icons.auto_awesome_rounded
                        : Icons.restaurant_rounded,
                    color: AppColors.green,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 3,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SourceTag(food.source),
                          Text(
                            '${formatWhole(food.kcal100)} kcal / 100 g',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'P ${formatDecimal(food.protein100)} · C ${formatDecimal(food.carbs100)} · F ${formatDecimal(food.fat100)} g',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.chevron_right_rounded,
                    color: selected ? AppColors.green : AppColors.muted,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
