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
    try {
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
    } catch (e) {
      throw Exception('Failed to translate: $e');
    }
  }

  /// Translates multiple texts in a single request (batch translation)
  Future<Map<String, String>> translateBatch(
    Map<String, String> texts,
    String sourceLocale,
    String targetLocale,
  ) async {
    try {
      // Prepare texts for batch processing
      final sources = texts.values.toList();
      final keys = texts.keys.toList();

      final body = {
        'source': sources,
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
        final targets = data['target'] as List<dynamic>;

        // Reconstruct the map with original keys
        final result = <String, String>{};
        for (var i = 0; i < keys.length; i++) {
          result[keys[i]] = targets[i] as String;
        }
        return result;
      } else {
        throw Exception('Batch translation API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // Fallback to one-by-one translation if batch fails
      final translations = <String, String>{};
      for (final entry in texts.entries) {
        translations[entry.key] = await translate(entry.value, sourceLocale, targetLocale);
      }
      return translations;
    }
  }
}
