import 'package:shortzz/model/general/settings_model.dart';

/// Resolves a flag emoji for an app language. The admin panel stores
/// non-standard codes (sp, ch, ge, kr ...), so we match on both the code and
/// the English title.
class LanguageFlags {
  LanguageFlags._();

  static const Map<String, String> _byCode = {
    'en': '🇬🇧',
    'en-us': '🇺🇸',
    'es': '🇪🇸',
    'sp': '🇪🇸',
    'fr': '🇫🇷',
    'de': '🇩🇪',
    'ge': '🇩🇪',
    'it': '🇮🇹',
    'pt': '🇵🇹',
    'pr': '🇵🇹',
    'pt-br': '🇧🇷',
    'ru': '🇷🇺',
    'zh': '🇨🇳',
    'ch': '🇨🇳',
    'ja': '🇯🇵',
    'jp': '🇯🇵',
    'ko': '🇰🇷',
    'kr': '🇰🇷',
    'ar': '🇸🇦',
    'hi': '🇮🇳',
    'bn': '🇧🇩',
    'ta': '🇮🇳',
    'te': '🇮🇳',
    'ml': '🇮🇳',
    'kn': '🇮🇳',
    'mr': '🇮🇳',
    'gu': '🇮🇳',
    'pa': '🇮🇳',
    'ur': '🇵🇰',
    'tr': '🇹🇷',
    'da': '🇩🇰',
    'nb': '🇳🇴',
    'no': '🇳🇴',
    'sv': '🇸🇪',
    'fi': '🇫🇮',
    'nl': '🇳🇱',
    'pl': '🇵🇱',
    'po': '🇵🇱',
    'el': '🇬🇷',
    'gr': '🇬🇷',
    'id': '🇮🇩',
    'in': '🇮🇩',
    'ms': '🇲🇾',
    'th': '🇹🇭',
    'vi': '🇻🇳',
    'tl': '🇵🇭',
    'fa': '🇮🇷',
    'he': '🇮🇱',
    'uk': '🇺🇦',
    'ro': '🇷🇴',
    'hu': '🇭🇺',
    'cs': '🇨🇿',
    'sk': '🇸🇰',
    'bg': '🇧🇬',
    'hr': '🇭🇷',
    'sr': '🇷🇸',
    'sw': '🇰🇪',
    'af': '🇿🇦',
    'ne': '🇳🇵',
    'si': '🇱🇰',
    'my': '🇲🇲',
    'km': '🇰🇭',
  };

  static const Map<String, String> _byTitle = {
    'english': '🇬🇧',
    'spanish': '🇪🇸',
    'french': '🇫🇷',
    'german': '🇩🇪',
    'italian': '🇮🇹',
    'portuguese': '🇵🇹',
    'russian': '🇷🇺',
    'chinese': '🇨🇳',
    'simplified chinese': '🇨🇳',
    'traditional chinese': '🇹🇼',
    'japanese': '🇯🇵',
    'korean': '🇰🇷',
    'arabic': '🇸🇦',
    'hindi': '🇮🇳',
    'bengali': '🇧🇩',
    'tamil': '🇮🇳',
    'telugu': '🇮🇳',
    'malayalam': '🇮🇳',
    'kannada': '🇮🇳',
    'marathi': '🇮🇳',
    'gujarati': '🇮🇳',
    'punjabi': '🇮🇳',
    'urdu': '🇵🇰',
    'turkish': '🇹🇷',
    'danish': '🇩🇰',
    'norwegian': '🇳🇴',
    'norwegian bokmal': '🇳🇴',
    'swedish': '🇸🇪',
    'finnish': '🇫🇮',
    'dutch': '🇳🇱',
    'polish': '🇵🇱',
    'greek': '🇬🇷',
    'indonesian': '🇮🇩',
    'malay': '🇲🇾',
    'thai': '🇹🇭',
    'vietnamese': '🇻🇳',
    'filipino': '🇵🇭',
    'tagalog': '🇵🇭',
    'persian': '🇮🇷',
    'hebrew': '🇮🇱',
    'ukrainian': '🇺🇦',
    'romanian': '🇷🇴',
    'hungarian': '🇭🇺',
    'czech': '🇨🇿',
    'swahili': '🇰🇪',
    'nepali': '🇳🇵',
    'sinhala': '🇱🇰',
    'burmese': '🇲🇲',
    'khmer': '🇰🇭',
  };

  static String flagFor(Language? language) {
    if (language == null) return '🌐';
    final code = (language.code ?? '').trim().toLowerCase();
    if (code.isNotEmpty && _byCode.containsKey(code)) return _byCode[code]!;
    final title = (language.title ?? '').trim().toLowerCase();
    if (title.isNotEmpty && _byTitle.containsKey(title)) {
      return _byTitle[title]!;
    }
    final localized = (language.localizedTitle ?? '').trim().toLowerCase();
    if (localized.isNotEmpty && _byTitle.containsKey(localized)) {
      return _byTitle[localized]!;
    }
    // Last resort: derive a regional indicator pair from a 2-letter code.
    if (code.length == 2 && RegExp(r'^[a-z]{2}$').hasMatch(code)) {
      return String.fromCharCodes(
        code.codeUnits.map((c) => 0x1F1E6 + (c - 0x61)),
      );
    }
    return '🌐';
  }
}
