import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../scanner_service.dart';
import '../theme.dart';
import '../ui/common.dart';
import 'food_picker_page.dart';
import 'manual_add_page.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({
    super.key,
    required this.onAdd,
    @visibleForTesting this.initialEstimate,
    @visibleForTesting this.initialFood,
  });

  final ValueChanged<MealEntry> onAdd;
  final ScanEstimate? initialEstimate;
  final Food? initialFood;

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final picker = ImagePicker();
  late final ScannerService scanner;
  final grams = TextEditingController(text: '150');

  Uint8List? photoBytes;
  String? photoName;
  String? photoMime;
  bool busy = false;
  bool slow = false;
  Timer? slowTimer;
  String? error;
  bool errorRetryable = true;
  ScanEstimate? estimate;
  Food? aiEstimate;
  Food? selectedFood;
  double? portionLow;
  double? portionHigh;
  double? portionGuess;
  String meal = defaultMealForNow();
  PortionUnit unit = PortionUnit.grams;

  @override
  void initState() {
    super.initState();
    scanner = AppConfig.createScannerService();
    final initial = widget.initialEstimate;
    if (initial != null) {
      estimate = initial;
      aiEstimate = initial.aiFood;
      selectedFood = widget.initialFood ?? preferredScanFood(initial);
      portionLow = initial.portionLowG;
      portionHigh = initial.portionHighG;
      portionGuess = initial.portionGuessG;
      grams.text = initial.portionGuessG.round().toString();
    }
  }

  @override
  void dispose() {
    slowTimer?.cancel();
    grams.dispose();
    scanner.dispose();
    super.dispose();
  }

  void _setError(String message, {bool retryable = true}) {
    if (!mounted) return;
    setState(() {
      error = message;
      errorRetryable = retryable;
    });
  }

  void _clearResult() {
    estimate = null;
    aiEstimate = null;
    selectedFood = null;
    portionLow = null;
    portionHigh = null;
    portionGuess = null;
    error = null;
  }

  Future<void> pick(ImageSource source) async {
    if (busy) return;
    try {
      final file = await picker.pickImage(
        source: source,
        imageQuality: 84,
        maxWidth: 1600,
      );
      if (file == null) return;
      final mime = _imageMimeType(file);
      if (mime == null) {
        _setError(
          'This image format is not supported. Choose a JPEG, PNG, GIF, or WebP photo.',
          retryable: false,
        );
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > 15 * 1024 * 1024) {
        _setError(
          'That photo is larger than 15 MB. Choose a smaller photo or add the food manually.',
          retryable: false,
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        photoBytes = bytes;
        photoName = _safeFilename(file.name, mime);
        photoMime = mime;
        grams.text = '150';
        unit = PortionUnit.grams;
        _clearResult();
      });
    } catch (_) {
      _setError(
        'Could not open the camera or photo library. Check the app permission and try again, or add the food manually.',
      );
    }
  }

  void removePhoto() {
    if (busy) return;
    setState(() {
      photoBytes = null;
      photoName = null;
      photoMime = null;
      _clearResult();
    });
  }

  Future<void> analyze() async {
    final bytes = photoBytes;
    final mime = photoMime;
    if (bytes == null || mime == null || busy) return;
    setState(() {
      busy = true;
      slow = false;
      error = null;
      estimate = null;
      aiEstimate = null;
      selectedFood = null;
      portionLow = null;
      portionHigh = null;
      portionGuess = null;
    });
    slowTimer?.cancel();
    slowTimer = Timer(const Duration(seconds: 7), () {
      if (mounted && busy) setState(() => slow = true);
    });
    try {
      final result = await scanner.analyze(
        bytes: bytes,
        filename: photoName ?? 'food.jpg',
        mimeType: mime,
      );
      if (!mounted) return;
      setState(() {
        estimate = result;
        aiEstimate = result.aiFood;
        selectedFood = preferredScanFood(result);
        portionLow = result.portionLowG;
        portionHigh = result.portionHighG;
        portionGuess = result.portionGuessG;
        unit = PortionUnit.grams;
        grams.text = result.portionGuessG.round().toString();
        error = null;
      });
    } on ScannerException catch (exception) {
      _setError(exception.message, retryable: exception.retryable);
    } catch (_) {
      _setError(
        'Nouri could not complete the scan. Check your connection and try again, or add the food manually.',
      );
    } finally {
      slowTimer?.cancel();
      if (mounted) {
        setState(() {
          busy = false;
          slow = false;
        });
      }
    }
  }

  double? enteredGrams() {
    final value = double.tryParse(grams.text.trim().replaceAll(',', '.'));
    if (value == null || !value.isFinite || value <= 0) return null;
    final converted = unit.toGrams(value);
    if (!converted.isFinite || converted < 1 || converted > 5000) return null;
    return converted;
  }

  void setQuickAmount(double gramsValue) {
    setState(() => grams.text = unit.formatGrams(gramsValue));
  }

  Future<void> chooseFood() async {
    if (estimate == null) return;
    final picked = await Navigator.of(context).push<Food>(
      MaterialPageRoute<Food>(
        fullscreenDialog: true,
        builder: (_) => FoodPickerPage(
          aiEstimate: aiEstimate,
          selected: selectedFood,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => selectedFood = picked);
  }

  void addFood() {
    final food = selectedFood;
    final amountGrams = enteredGrams();
    if (food == null) {
      _snack('Choose a catalog food or Nouri’s estimate.');
      return;
    }
    if (amountGrams == null) {
      _snack('Enter an amount from 1 to 5,000 grams.');
      return;
    }
    final entry = MealEntry(
      food: food,
      grams: amountGrams,
      category: meal,
      date: DateTime.now(),
    );
    setState(() {
      photoBytes = null;
      photoName = null;
      photoMime = null;
      grams.text = '150';
      unit = PortionUnit.grams;
      _clearResult();
    });
    widget.onAdd(entry);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> openManualEntry() async {
    await openManualAdd(
      context,
      day: DateTime.now(),
      onAdd: widget.onAdd,
      meal: meal,
    );
  }

  @override
  Widget build(BuildContext context) {
    final configError = scanner.configurationError;
    final showConfirmation = estimate != null && selectedFood != null;
    final amountGrams = enteredGrams();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
      children: [
        const AppBrand(),
        const SizedBox(height: 16),
        const Text(
          'Scan food',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Take a photo or choose one. Nouri will estimate the food and portion.',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        const InfoNote(
          icon: Icons.restaurant_outlined,
          text: 'Nouri scans food and drinks only.',
        ),
        const SizedBox(height: 14),
        _PhotoPreview(bytes: photoBytes),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : () => pick(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined, size: 19),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : () => pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 19),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
        if (photoBytes != null)
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: busy ? null : removePhoto,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Remove photo'),
            ),
          ),
        const SizedBox(height: 4),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: photoBytes != null && !busy && configError == null
                ? analyze
                : null,
            icon: busy
                ? const SizedBox.square(
                    dimension: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome_rounded, size: 19),
            label: Text(busy ? 'Nouri is looking…' : 'Scan with Nouri'),
          ),
        ),
        if (busy) ...[
          const SizedBox(height: 10),
          SectionCard(
            color: AppColors.paleGreen,
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    slow
                        ? 'The free scanner can take up to a minute to wake. Nouri is still working on this photo.'
                        : 'Nouri is analyzing the photo. This can take a moment after the scanner has been idle.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (configError != null) ...[
          const SizedBox(height: 10),
          InfoNote(
            icon: Icons.cloud_off_outlined,
            text: configError,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: openManualEntry,
              icon: const Icon(Icons.edit_note_rounded, size: 19),
              label: const Text('Add food manually'),
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          SectionCard(
            color: const Color(0xFFFFF8F6),
            borderColor: const Color(0xFFEBCBC6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.danger,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (errorRetryable && photoBytes != null)
                      OutlinedButton.icon(
                        onPressed: analyze,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Try again'),
                      ),
                    OutlinedButton.icon(
                      onPressed: openManualEntry,
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('Add food manually'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (showConfirmation) ...[
          const SizedBox(height: 16),
          _buildConfirmation(context, amountGrams),
        ],
        const SizedBox(height: 10),
        if (!showConfirmation)
          Center(
            child: TextButton.icon(
              onPressed: openManualEntry,
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text('Add food manually'),
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildConfirmation(BuildContext context, double? amountGrams) {
    final selected = selectedFood!;
    final low = portionLow;
    final high = portionHigh;
    final guess = portionGuess;
    final amount = amountGrams ?? 0;
    final sourceText = switch (selected.source) {
      FoodSource.aiEstimate => 'Nutrition estimated by Nouri',
      FoodSource.custom => 'Your custom food',
      FoodSource.catalog => 'Using food catalog values',
    };
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Estimated food',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SourceTag(selected.source),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            selected.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sourceText,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 13),
          const Text(
            'Food',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Material(
            color: AppColors.paleGreen,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: chooseFood,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Change food',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            selected.source == FoodSource.aiEstimate
                                ? 'Use a catalog food or keep Nouri’s estimate.'
                                : 'Search the catalog or use Nouri’s estimate.',
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
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.green,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 13),
          const Text(
            'Estimated portion',
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
                child: TextField(
                  controller: grams,
                  onChanged: (_) => setState(() {}),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Portion',
                    prefixIcon: Icon(Icons.scale_outlined),
                  ),
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
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 16),
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
                    final parsed = double.tryParse(
                      grams.text.trim().replaceAll(',', '.'),
                    );
                    setState(() {
                      if (parsed != null && parsed > 0) {
                        grams.text = value.formatGrams(unit.toGrams(parsed));
                      }
                      unit = value;
                    });
                  },
                ),
              ),
            ],
          ),
          if (low != null && high != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.lime.withValues(alpha: .7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                guess == null
                    ? 'Visual range: ${formatPortionRange(low, high, unit)}. Adjust to match what you ate.'
                    : 'Suggested about ${unit.formatGrams(guess)} ${unit.symbol}. Visual range ${formatPortionRange(low, high, unit)}. Adjust to match what you ate.',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 10.5,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _PortionChip(
                  label: 'Low ${unit.formatGrams(low)} ${unit.symbol}',
                  onTap: () => setQuickAmount(low),
                ),
                if (guess != null)
                  _PortionChip(
                    label:
                        'Suggested ${unit.formatGrams(guess)} ${unit.symbol}',
                    onTap: () => setQuickAmount(guess),
                    emphasized: true,
                  ),
                _PortionChip(
                  label: 'High ${unit.formatGrams(high)} ${unit.symbol}',
                  onTap: () => setQuickAmount(high),
                ),
              ],
            ),
          ],
          const SizedBox(height: 13),
          DropdownButtonFormField<String>(
            key: ValueKey(meal),
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
          const SizedBox(height: 12),
          Text(
            amount > 0 ? 'Nutrition for ${formatGrams(amount)}' : 'Nutrition',
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          if (amount > 0 && amount <= 5000)
            NutritionTiles(food: selected, grams: amount)
          else
            const InfoNote(
              icon: Icons.straighten_rounded,
              text: 'Enter a portion to see calories and macros.',
            ),
          const SizedBox(height: 9),
          const Text(
            'Portions and nutrition are estimates. You can adjust the portion before adding.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 10.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            height: 49,
            child: FilledButton.icon(
              onPressed: addFood,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add food'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        height: 238,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFEEF5ED),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: bytes == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.camera_alt_rounded,
                        size: 44,
                        color: AppColors.green,
                      ),
                      SizedBox(height: 9),
                      Text(
                        'Take a photo or upload food',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'One food or one mixed dish per scan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(bytes!, fit: BoxFit.cover),
                  Positioned(
                    top: 9,
                    right: 9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Selected photo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      );
}

class _PortionChip extends StatelessWidget {
  const _PortionChip({
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => ActionChip(
        onPressed: onTap,
        label: Text(label),
        labelStyle: TextStyle(
          color: emphasized ? AppColors.deepGreen : AppColors.muted,
          fontSize: 10.5,
          fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
        ),
        backgroundColor: emphasized ? AppColors.lime : Colors.white,
        side: BorderSide(
          color: emphasized ? AppColors.green : AppColors.border,
        ),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      );
}

String? _imageMimeType(XFile file) {
  const supported = <String>{
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
  };
  final fromPicker = file.mimeType?.split(';').first.trim().toLowerCase();
  if (fromPicker != null &&
      supported
          .contains(fromPicker == 'image/jpg' ? 'image/jpeg' : fromPicker)) {
    return fromPicker == 'image/jpg' ? 'image/jpeg' : fromPicker;
  }
  final extension = file.name.split('.').last.toLowerCase();
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    _ => null,
  };
}

String _safeFilename(String name, String mimeType) {
  final cleaned = name.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_').trim();
  if (cleaned.isNotEmpty) {
    return cleaned.length > 80
        ? cleaned.substring(cleaned.length - 80)
        : cleaned;
  }
  return switch (mimeType) {
    'image/png' => 'food.png',
    'image/gif' => 'food.gif',
    'image/webp' => 'food.webp',
    _ => 'food.jpg',
  };
}
