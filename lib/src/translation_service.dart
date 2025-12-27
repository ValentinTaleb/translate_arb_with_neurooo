import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'arb_parser.dart';
import 'config.dart';

class TranslationService {
  final TranslationConfig config;
  final bool verbose;
  static const String endpoint = 'https://neurooo.com/api/v1/';

  TranslationService({required this.config, this.verbose = false});

  factory TranslationService.fromConfig(TranslationConfig config, {bool verbose = false}) {
    return TranslationService(
      config: config,
      verbose: verbose,
    );
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
        translatedTexts = await _translateBatch(translationsToProcess, sourceLocale, targetLocale);
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
            final translated = await _translate(entry.value, sourceLocale, targetLocale);
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

  /// Translates a text from the source language to the target language
  Future<String> _translate(String text, String sourceLocale, String targetLocale) async {
    final body = {
      'source': text,
      'target_language_code': targetLocale,
      'source_language_code': sourceLocale,
      ...?config.additionalParams,
    };

    final response = await http.post(
      Uri.parse('${endpoint}translate'),
      headers: {'Content-Type': 'application/json', 'x-api-key': config.apiKey},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['target'] as String? ?? text;
    } else {
      throw Exception('Translation API error: ${response.statusCode} - ${response.body}');
    }
  }

  /// Translates multiple texts in a single request (batch translation)
  /// Handles API constraints: max 12500 characters and max 100 items per batch
  Future<Map<String, String>> _translateBatch(
    Map<String, String> texts,
    String sourceLocale,
    String targetLocale,
  ) async {
    const int maxChars = 12500;
    const int maxItems = 100;

    _log('Starting batch translation: ${texts.length} total items');

    final result = <String, String>{};
    final entries = texts.entries.toList();

    int currentIndex = 0;
    int batchNumber = 0;

    while (currentIndex < entries.length) {
      final batch = <MapEntry<String, String>>[];
      int currentCharCount = 0;

      // Build a batch respecting both constraints
      while (currentIndex < entries.length && batch.length < maxItems) {
        final entry = entries[currentIndex];
        final entryLength = entry.value.length;

        // Check if adding this entry would exceed character limit
        if (currentCharCount + entryLength > maxChars && batch.isNotEmpty) {
          _log('Batch ${batchNumber + 1}: Character limit would be exceeded, splitting batch');
          break;
        }

        batch.add(entry);
        currentCharCount += entryLength;
        currentIndex++;
      }

      batchNumber++;
      _log('Batch $batchNumber: Translating ${batch.length} items (${currentCharCount} characters)');

      // Translate current batch
      final batchKeys = batch.map((e) => e.key).toList();
      final batchSources = batch.map((e) => e.value).toList();

      final body = {
        'sources': batchSources,
        'target_language_code': targetLocale,
        'source_language_code': sourceLocale,
        ...?config.additionalParams,
      };

      final response = await http.post(
        Uri.parse('${endpoint}batch_translate'),
        headers: {'Content-Type': 'application/json', 'x-api-key': config.apiKey},
        body: jsonEncode(body),
      );

      _log('Batch $batchNumber: API response status ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final targets = data['targets'] as List<dynamic>;

        _log('Batch $batchNumber: Received ${targets.length} translations');

        // Add batch results to final result
        for (var i = 0; i < batchKeys.length; i++) {
          result[batchKeys[i]] = targets[i] as String;
        }
      } else {
        _log('Batch $batchNumber: Error - ${response.body}');
        throw Exception('Batch translation API error: ${response.statusCode} - ${response.body}');
      }
    }

    _log('Batch translation complete: ${result.length} items translated in $batchNumber batches');
    return result;
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
