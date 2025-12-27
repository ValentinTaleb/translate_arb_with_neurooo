import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

/// Implementation for the Neurooo.com API
class NeuroooTranslator {
  final TranslationConfig config;
  static const String endpoint = 'https://neurooo.com/api/v1/';
  final bool verbose;

  NeuroooTranslator({required this.config, this.verbose = false});

  /// Translates a text from the source language to the target language
  Future<String> translate(String text, String sourceLocale, String targetLocale) async {
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
  Future<Map<String, String>> translateBatch(
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
}
