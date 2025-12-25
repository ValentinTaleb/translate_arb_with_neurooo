import 'dart:io';
import 'arb_parser.dart';
import 'config.dart';
import 'neurooo_translator.dart';

class TranslationService {
  final NeuroooTranslator translator;
  final bool verbose;

  TranslationService({required this.translator, this.verbose = false});

  factory TranslationService.fromConfig(TranslationConfig config, {bool verbose = false}) {
    return TranslationService(translator: NeuroooTranslator(config), verbose: verbose);
  }

  /// Translates an .arb file to one or more target languages
  Future<void> translateArbFile(
    String sourceFilePath,
    List<String> targetLocales,
    String sourceLocale, {
    bool onlyMissing = false,
  }) async {
    final sourceFile = File(sourceFilePath);

    if (!sourceFile.existsSync()) {
      throw FileSystemException('Source file not found', sourceFilePath);
    }

    _log('📖 Reading source file: $sourceFilePath');

    // Parse the source file
    final arbContent = ArbParser.parse(sourceFile);
    final translations = ArbParser.extractTranslations(arbContent);

    _log('✨ Found ${translations.length} translations to process');

    // Translate to each target language
    for (final targetLocale in targetLocales) {
      _log('\n🌍 Translating to: $targetLocale');

      // If onlyMissing is enabled, read the existing target file
      Map<String, String> translationsToProcess = translations;
      Map<String, String>? existingTranslations;

      if (onlyMissing) {
        final targetFile = _getTargetFile(sourceFile, targetLocale);
        if (targetFile.existsSync()) {
          _log('  📖 Reading existing translations from ${targetFile.path}');
          final existingArb = ArbParser.parse(targetFile);
          existingTranslations = ArbParser.extractTranslations(existingArb);

          // Filter to keep only missing keys
          translationsToProcess = Map.fromEntries(
            translations.entries.where((entry) => !existingTranslations!.containsKey(entry.key)),
          );

          _log('  ℹ️  Found ${existingTranslations.length} existing translations');
          _log('  ℹ️  ${translationsToProcess.length} keys to translate');

          if (translationsToProcess.isEmpty) {
            _log('  ✅ All translations already exist, skipping');
            continue;
          }
        } else {
          _log('  ℹ️  Target file does not exist, will translate all keys');
        }
      }

      Map<String, String> translatedTexts;

      try {
        // Use batch translation (faster)
        _log('  🚀 Using batch translation (${translationsToProcess.length} texts)');
        translatedTexts = await translator.translateBatch(translationsToProcess, sourceLocale, targetLocale);
        _log('  ✅ Batch translation complete');
      } catch (e) {
        // Fallback to individual translation if batch fails
        print('  ⚠️  Batch translation failed, using individual translation: $e');
        translatedTexts = <String, String>{};
        int count = 0;

        for (final entry in translationsToProcess.entries) {
          count++;
          _log('  [$count/${translationsToProcess.length}] Translating: ${entry.key}');

          try {
            final translated = await translator.translate(entry.value, sourceLocale, targetLocale);
            translatedTexts[entry.key] = translated;
          } catch (e) {
            print('  ⚠️  Error translating "${entry.key}": $e');
            translatedTexts[entry.key] = entry.value;
          }
        }
      }

      // If onlyMissing, merge with existing translations
      if (onlyMissing && existingTranslations != null) {
        translatedTexts = {...existingTranslations, ...translatedTexts};
      }

      // Create the translated file
      ArbParser.createTranslatedArb(sourceFile, targetLocale, translatedTexts, arbContent);

      final directory = sourceFile.parent;
      final fileName = sourceFile.uri.pathSegments.last;
      final baseName = fileName.replaceAll(RegExp(r'_[a-z]{2}\.arb$'), '');
      final newFileName = '${baseName}_$targetLocale.arb';

      _log('✅ Created: ${directory.path}/$newFileName');
    }

    _log('\n🎉 Translation complete!');
  }

  void _log(String message) {
    if (verbose) {
      print(message);
    }
  }

  /// Returns the target file for a given locale
  File _getTargetFile(File sourceFile, String targetLocale) {
    final directory = sourceFile.parent;
    final fileName = sourceFile.uri.pathSegments.last;
    final baseName = fileName.replaceAll(RegExp(r'_[a-z]{2}\.arb$'), '');
    final newFileName = '${baseName}_$targetLocale.arb';
    return File('${directory.path}/$newFileName');
  }
}
