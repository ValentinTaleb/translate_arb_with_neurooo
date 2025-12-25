import 'dart:convert';
import 'dart:io';

class ArbParser {
  /// Parses an .arb file and returns a Map
  static Map<String, dynamic> parse(File file) {
    if (!file.existsSync()) {
      throw FileSystemException('File not found', file.path);
    }

    final content = file.readAsStringSync();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// Extracts only translation keys (ignores metadata)
  static Map<String, String> extractTranslations(Map<String, dynamic> arb) {
    final translations = <String, String>{};

    for (final entry in arb.entries) {
      // Ignore metadata (keys starting with @)
      if (!entry.key.startsWith('@') && entry.value is String) {
        translations[entry.key] = entry.value as String;
      }
    }

    return translations;
  }

  /// Saves an .arb file
  static void save(File file, Map<String, dynamic> content) {
    final encoder = JsonEncoder.withIndent('  ');
    file.writeAsStringSync(encoder.convert(content));
  }

  /// Creates a new .arb file with translations
  static void createTranslatedArb(
    File sourceFile,
    String targetLocale,
    Map<String, String> translations,
    Map<String, dynamic> originalArb,
  ) {
    final newArb = <String, dynamic>{};

    // Iterate through keys in original order
    for (final key in originalArb.keys) {
      if (key.startsWith('@')) {
        // It's metadata, copy it as is
        if (key == '@@locale') {
          // Update the locale
          newArb[key] = targetLocale;
        } else {
          newArb[key] = originalArb[key];
        }
      } else {
        // It's a translation, use the translated version
        newArb[key] = translations[key] ?? originalArb[key];
      }
    }

    // Create the output file
    final directory = sourceFile.parent;
    final fileName = sourceFile.uri.pathSegments.last;
    final baseName = fileName.replaceAll(RegExp(r'_[a-z]{2}\.arb$'), '');
    final newFileName = '${baseName}_$targetLocale.arb';
    final outputFile = File('${directory.path}/$newFileName');

    save(outputFile, newArb);
  }
}
