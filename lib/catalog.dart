import 'models.dart';

/// Small on-device reference catalog. Values are typical per-100-gram values,
/// not brand-specific label data. Users confirm the amount before logging.
const catalog = <Food>[
  Food('Cooked white rice', 130, 2.7, 28.2, .3,
      ['rice', 'white rice', 'steamed rice']),
  Food('Grilled chicken breast', 165, 31, 0, 3.6,
      ['chicken', 'chicken breast', 'grilled chicken']),
  Food('Cooked egg', 155, 13, 1.1, 11,
      ['egg', 'eggs', 'boiled egg', 'fried egg', 'scrambled egg']),
  Food('Banana', 89, 1.1, 22.8, .3, ['banana', 'bananas']),
  Food('Cooked salmon', 206, 22.1, 0, 12.4, ['salmon', 'fish']),
  Food('Cooked oatmeal', 71, 2.5, 12, 1.5,
      ['oatmeal', 'porridge', 'rolled oats', 'oats']),
  Food('Baked potato', 93, 2.5, 21, .1, ['potato', 'potatoes', 'baked potato']),
  Food('Cooked broccoli', 35, 2.4, 7.2, .4, ['broccoli']),
  Food('Whole wheat bread', 247, 13, 41, 4.2,
      ['bread', 'toast', 'whole wheat bread', 'wheat bread']),
  Food('Avocado', 160, 2, 8.5, 14.7, ['avocado', 'avocados', 'avocado slices']),
  Food('Greek yogurt, plain', 97, 9, 3.9, 5,
      ['greek yogurt', 'yogurt', 'yoghurt']),
  Food('Tomato', 18, .9, 3.9, .2, ['tomato', 'tomatoes']),
  Food('Lettuce', 15, 1.4, 2.9, .2, ['lettuce', 'salad greens']),
  Food('Pork adobo', 210, 20, 4, 12, ['adobo', 'pork adobo']),
  Food('Apple', 52, .3, 13.8, .2, ['apple', 'apples']),
  Food('Milk, 2%', 50, 3.3, 4.8, 1.9,
      ['milk', 'low fat milk', 'low-fat milk', '2% milk']),
  Food('Cheddar cheese', 403, 24.9, 1.3, 33.1,
      ['cheddar', 'cheddar cheese', 'cheese']),
  Food('Cooked pasta', 131, 5, 25, 1.1,
      ['pasta', 'spaghetti', 'noodles', 'cooked pasta']),
  Food('Firm tofu', 144, 17.3, 2.8, 8.7, ['tofu', 'firm tofu', 'bean curd']),
  Food('Cooked black beans', 132, 8.9, 23.7, .5,
      ['black beans', 'beans', 'cooked beans']),
  Food('Almonds', 579, 21.2, 21.6, 49.9, ['almond', 'almonds']),
  Food('Olive oil', 884, 0, 0, 100, ['olive oil', 'oil']),
  Food('Orange', 47, .9, 11.8, .1, ['orange', 'oranges']),
  Food('Carrot', 41, .9, 9.6, .2, ['carrot', 'carrots']),
  Food('Baked sweet potato', 90, 2, 20.7, .2,
      ['sweet potato', 'sweet potatoes', 'kamote']),
  Food('Cooked shrimp', 99, 24, .2, .3, ['shrimp', 'prawns']),
  Food('Cooked beef steak', 250, 26, 0, 15, ['beef', 'steak', 'beef steak']),
  Food(
      'Black coffee', 2, .3, 0, 0, ['coffee', 'black coffee', 'brewed coffee']),
  Food('Fried chicken', 246, 24, 5.5, 14,
      ['fried chicken', 'chicken thigh', 'chicken leg']),
];

String normalizeFoodText(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[^a-z0-9\\s]'), ' ')
    .replaceAll(RegExp('\\s+'), ' ')
    .trim();

String _stem(String token) {
  if (token.length > 3 &&
      token.endsWith('s') &&
      !token.endsWith('ss') &&
      !token.endsWith('ies')) {
    return token.substring(0, token.length - 1);
  }
  if (token.endsWith('ies') && token.length > 4) {
    return '${token.substring(0, token.length - 3)}y';
  }
  return token;
}

List<String> _tokens(String value) => normalizeFoodText(value)
    .split(' ')
    .where((token) => token.isNotEmpty)
    .map(_stem)
    .toList();

/// Matches a model food label to a catalog item using whole-word overlap.
///
/// This avoids unsafe substring matches such as "cheeseburger" -> "cheese".
Food? matchFood(String text) {
  final query = _tokens(text);
  if (query.isEmpty) return null;
  final querySet = query.toSet();

  Food? best;
  var bestScore = -1;
  for (final food in catalog) {
    for (final name in <String>[food.name, ...food.aliases]) {
      final alias = _tokens(name);
      if (alias.isEmpty) continue;
      final aliasSet = alias.toSet();
      int? score;
      if (alias.length == query.length && alias.every(querySet.contains)) {
        score = 1000 + alias.length;
      } else if (querySet.containsAll(aliasSet)) {
        score = 500 + aliasSet.length * 10 - alias.length;
      } else if (aliasSet.containsAll(querySet)) {
        score = 400 + querySet.length * 10 - aliasSet.length;
      }
      if (score != null && score > bestScore) {
        bestScore = score;
        best = food;
      }
    }
  }
  return best;
}

/// Catalog search used by the food picker. Empty query returns the catalog.
List<Food> searchCatalog(String query) {
  final q = normalizeFoodText(query);
  if (q.isEmpty) return catalog;
  final querySet = _tokens(q).toSet();
  return catalog.where((food) {
    for (final name in <String>[food.name, ...food.aliases]) {
      final normalized = normalizeFoodText(name);
      if (normalized.contains(q)) return true;
      final tokens = _tokens(name).toSet();
      if (querySet.isNotEmpty && tokens.containsAll(querySet)) return true;
    }
    return false;
  }).toList();
}
