# Readability

A Dart port of [Mozilla's Readability.js](https://github.com/mozilla/readability) - extract readable content from any web page.

## Installation

### As a Dart Package

Add to your `pubspec.yaml`:

```yaml
dependencies:
  readability: ^0.1.0
```

### As a CLI Tool

Download pre-built binaries from [Releases](https://github.com/mortezaPRK/readability/releases), or build from source:

```bash
make build-cli
./build/readability --help
```

### As a JavaScript Library

Compile to JavaScript for use in browsers or Node.js:

```bash
make build-js
# Output: build/readability.js
```

## Usage

### Dart Package

```dart
import 'package:readability/readability.dart';

void main() {
  final html = '<html>...</html>';

  // Parse with default JSDOMParser
  final article = parse(html, baseUri: 'https://example.com');

  if (article != null) {
    print('Title: ${article.title}');
    print('Author: ${article.byline}');
    print('Content: ${article.textContent}');
  }
}
```

#### Check if a Page is Readable

```dart
import 'package:html/parser.dart' as html_parser;

final doc = html_parser.parse(html);
if (isProbablyReaderable(doc)) {
  final article = parse(html);
  // ...
}
```

#### Configuration Options

```dart
// All options are named parameters on parse()
final article = parse(
  html,
  parser: ParserType.jsdom,  // or ParserType.html
  baseUri: 'https://example.com',
  debug: false,              // Enable debug logging
  charThreshold: 500,        // Minimum content length
  maxElemsToParse: 0,        // Element limit (0 = unlimited)
  keepClasses: false,        // Preserve CSS classes
);
```

#### Article Properties

| Property | Type | Description |
|----------|------|-------------|
| `title` | `String` | Article title |
| `content` | `String` | HTML content |
| `textContent` | `String` | Plain text content |
| `excerpt` | `String` | Short description |
| `byline` | `String?` | Author name |
| `siteName` | `String?` | Site name |
| `lang` | `String?` | Language code |
| `publishedTime` | `String?` | Publication date |

### Command Line

```bash
# Extract from file
readability article.html

# Extract from URL
readability https://example.com/article

# Read from stdin
curl -s https://example.com | readability -

# Output as JSON
readability --json article.html

# Metadata only
readability --metadata article.html
```

### JavaScript (Browser/Node.js)

After compiling with `make build-js`:

```html
<script src="readability.js"></script>
<script>
  // The compiled JS exposes the Dart main function
  // For library usage, create a wrapper entry point
</script>
```

For library usage, create a custom entry point that exports the API you need.

## Alternative Parsers

The library supports two HTML parsers via the `parser` parameter:

```dart
// JSDOMParser (default, recommended)
final article = parse(html, parser: ParserType.jsdom);

// html package parser (pure Dart)
final article = parse(html, parser: ParserType.html);
```

| Parser | Accuracy | Speed | Use Case |
|--------|----------|-------|----------|
| JSDOMParser | Highest | Fast | Production, compatibility |
| html package | High | Moderate | Pure Dart preference |

## Todo

- [ ] Provide a way to pass a logger
- [ ] Publish to pub.dev
- [ ] Best practices on having dependencies pinned for covering most users
- [ ] Check if js can be replaced with a Mozilla's implementation without any manual work
- [ ] Publish js to npmjs
- [ ] Cleanup CI
- [ ] Build for Darwin x86

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## License

This project uses **dual licensing**:

- **[Apache License 2.0](LICENSE)** - Main library code
- **[Mozilla Public License 2.0](LICENSE)** - JSDOMParser (ported from Mozilla)

Both licenses are open source and commercial-friendly. The dual licensing ensures compatibility with Mozilla's original codebase while providing flexibility for most use cases.

### What This Means

- You can use this library in commercial and open source projects
- Modifications to MPL-licensed files (JSDOMParser) must be shared under MPL
- The rest of the library can be used under Apache 2.0 terms

See the [LICENSE](LICENSE) file for full details.

---

Based on [Mozilla Readability.js](https://github.com/mozilla/readability) by Arc90 Inc and Mozilla.
