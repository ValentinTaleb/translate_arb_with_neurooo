import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

/// Implementation for the Neurooo.com API
class NeuroooTranslator {
  final TranslationConfig config;
  static const String endpoint = 'https://neurooo.com/api/v1/';

  NeuroooTranslator(this.config);

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

    final result = <String, String>{};
    final entries = texts.entries.toList();

    int currentIndex = 0;

    while (currentIndex < entries.length) {
      final batch = <MapEntry<String, String>>[];
      int currentCharCount = 0;

      // Build a batch respecting both constraints
      while (currentIndex < entries.length && batch.length < maxItems) {
        final entry = entries[currentIndex];
        final entryLength = entry.value.length;

        // Check if adding this entry would exceed character limit
        if (currentCharCount + entryLength > maxChars && batch.isNotEmpty) {
          break;
        }

        batch.add(entry);
        currentCharCount += entryLength;
        currentIndex++;
      }

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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final targets = data['targets'] as List<dynamic>;

        // Add batch results to final result
        for (var i = 0; i < batchKeys.length; i++) {
          result[batchKeys[i]] = targets[i] as String;
        }
      } else {
        throw Exception('Batch translation API error: ${response.statusCode} - ${response.body}');
      }
    }

    return result;
  }
}
