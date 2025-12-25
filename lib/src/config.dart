import 'dart:io';
import 'package:yaml/yaml.dart';

class TranslationConfig {
  final String apiKey;
  final Map<String, dynamic>? additionalParams;

  TranslationConfig({required this.apiKey, this.additionalParams});

  /// Loads the configuration from a YAML file
  static TranslationConfig fromYaml(File file) {
    if (!file.existsSync()) {
      throw FileSystemException(
        'Configuration file not found. Create a translate_arb_with_neurooo.yaml file with your API credentials.',
        file.path,
      );
    }

    final content = file.readAsStringSync();
    final yaml = loadYaml(content);

    // Converts YamlMap params to Map<String, dynamic> if present
    Map<String, dynamic>? params;
    if (yaml['params'] != null) {
      final yamlParams = yaml['params'];
      params = Map<String, dynamic>.from(yamlParams as Map);
    }

    return TranslationConfig(apiKey: yaml['api_key'] as String? ?? '', additionalParams: params);
  }

  /// Loads the configuration from the current directory
  static TranslationConfig load() {
    final file = File('translate_arb_with_neurooo.yaml');
    return fromYaml(file);
  }
}
