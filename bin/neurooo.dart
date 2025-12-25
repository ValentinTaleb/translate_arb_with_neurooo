import 'dart:io';
import 'package:args/args.dart';
import 'package:neurooo/src/config.dart';
import 'package:neurooo/src/translation_service.dart';

const String version = '0.0.1';

ArgParser buildParser() {
  return ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Print this usage information.')
    ..addFlag('verbose', abbr: 'v', negatable: false, help: 'Show additional command output.')
    ..addFlag('version', negatable: false, help: 'Print the tool version.')
    ..addOption('source', abbr: 's', help: 'Path to the source .arb file (e.g., app_en.arb)', mandatory: false)
    ..addOption('from', abbr: 'f', help: 'Source locale code (e.g., en)', defaultsTo: 'en')
    ..addOption('to', abbr: 't', help: 'Target locale codes, comma-separated (e.g., fr,es,de)')
    ..addOption('config', abbr: 'c', help: 'Path to configuration file', defaultsTo: 'neurooo.yaml')
    ..addFlag(
      'only-missing',
      abbr: 'm',
      negatable: false,
      help: 'Only translate missing keys (preserve existing translations)',
    );
}

void printUsage(ArgParser argParser) {
  print('🌍 translate_arb_with_neurooo - Automatic ARB Translation Tool for Flutter');
  print('');
  print('Usage: dart run neurooo [options]');
  print('');
  print(argParser.usage);
  print('');
  print('Examples:');
  print('  dart run neurooo -s lib/l10n/app_en.arb -t fr,es,de');
  print('  dart run neurooo --source app_en.arb --from en --to ja --verbose');
  print('  dart run neurooo -s app_en.arb -t fr --only-missing');
  print('');
  print('Configuration:');
  print('  Create a neurooo.yaml file in your project root:');
  print('');
  print('  api_key: your_api_key_here');
  print('  params:');
  print('    engine: your_model_name');
}

Future<void> main(List<String> arguments) async {
  final ArgParser argParser = buildParser();

  try {
    final ArgResults results = argParser.parse(arguments);

    // Base flags
    if (results.flag('help')) {
      printUsage(argParser);
      return;
    }

    if (results.flag('version')) {
      print('translate_arb_with_neurooo version: $version');
      return;
    }

    final bool verbose = results.flag('verbose');
    final bool onlyMissing = results.flag('only-missing');
    final String? sourceFile = results.option('source');
    final String sourceLocale = results.option('from')!;
    final String? targetLocalesStr = results.option('to');

    // Argument validation
    if (sourceFile == null || sourceFile.isEmpty) {
      print('❌ Error: Source file is required');
      print('');
      printUsage(argParser);
      exit(1);
    }

    if (targetLocalesStr == null || targetLocalesStr.isEmpty) {
      print('❌ Error: Target locale(s) required');
      print('');
      printUsage(argParser);
      exit(1);
    }

    final targetLocales = targetLocalesStr.split(',').map((e) => e.trim()).toList();

    // Load configuration
    final configPath = results.option('config')!;
    final TranslationConfig config;

    try {
      config = TranslationConfig.fromYaml(File(configPath));
    } catch (e) {
      print('❌ Error loading configuration: $e');
      print('');
      print('Create a neurooo.yaml file with your API configuration.');
      exit(1);
    }

    // Create translation service
    final service = TranslationService.fromConfig(config, verbose: verbose);

    // Start translation
    if (verbose) {
      print('🚀 Starting translation...');
      print('   Source: $sourceFile ($sourceLocale)');
      print('   Targets: ${targetLocales.join(", ")}');
      print('   Mode: ${onlyMissing ? "Only missing keys" : "All keys"}');
      print('');
    }

    await service.translateArbFile(sourceFile, targetLocales, sourceLocale, onlyMissing: onlyMissing);
  } on FormatException catch (e) {
    print('❌ ${e.message}');
    print('');
    printUsage(argParser);
    exit(1);
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}
