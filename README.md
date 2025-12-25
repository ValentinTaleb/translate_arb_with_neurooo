# 🌍 ARB Translator

A CLI tool to automatically translate Flutter `.arb` files using Neurooo translation API.

## 📦 Installation

```bash
dart pub get
```

## ⚙️ Configuration

1. Get your API key from [neurooo.com](https://neurooo.com)

2. Create the configuration file `neurooo.yaml` and set your API key:

```yaml
api_key: your_neurooo_api_key

# Optional: customize parameters
params:
  engine: openai-4omini-eu  # Check available engines at https://neurooo.com/fr/docs/api 
  tone: auto # informal, auto or formal
  context: "Mobile app interface"
```

## 🚀 Usage

### Basic Command

```bash
dart run neurooo -s lib/l10n/app_en.arb -t fr,es,de
```

### Options

- `-s, --source`: Path to the source `.arb` file (e.g., `app_en.arb`)
- `-f, --from`: Source language code (default: `en`)
- `-t, --to`: Target language codes, comma-separated (e.g., `fr,es,de`)
- `-c, --config`: Path to the configuration file (default: `neurooo.yaml`)
- `-m, --only-missing`: Translate only missing keys (preserves existing translations)
- `-v, --verbose`: Display translation details
- `-h, --help`: Display help
- `--version`: Display version

### Examples

Translate to French, Spanish, and German:
```bash
dart run neurooo -s lib/l10n/app_en.arb -t fr,es,de
```

Translate to Japanese with verbose mode:
```bash
dart run neurooo --source app_en.arb --from en --to ja --verbose
```

Translate only missing keys (preserves existing translations):
```bash
dart run neurooo -s lib/l10n/app_en.arb -t fr --only-missing
```

Use cases for `--only-missing` mode:
- You've added new keys to your source file
- You want to avoid retranslating the entire file
- You've manually refined certain translations and don't want to overwrite them


## ⚡ Features

- ✅ **Integrated Neurooo.com API**: High-quality translations with multiple AI engines
- ✅ **Batch translation**: Translates all texts in a single request (fast)
- ✅ **100+ language support**: All languages supported by Neurooo
- ✅ **Customizable engines**: OpenAI, Claude, DeepSeek and others
- ✅ **Metadata preservation**: Keeps descriptions and formats
- ✅ **Incremental mode**: `--only-missing` option to translate only new keys


## 📝 .arb File Format

`.arb` files follow the standard Flutter format:

```json
{
  "@@locale": "en",
  "hello": "Hello",
  "@hello": {
    "description": "Greeting message"
  },
  "welcome": "Welcome to the app"
}
```

**neurooo** does the following:
- ✅ Translates text
- ✅ Preserves metadata (keys starting with `@`)
- ✅ Creates files with the correct locale suffix (`app_fr.arb`, `app_es.arb`)

## 🤝 Contribution

Contributions are welcome!
