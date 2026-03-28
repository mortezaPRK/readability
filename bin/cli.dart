// Readability CLI - Extract readable content from HTML
// Usage: readability [options] <input>

import 'dart:convert';
import 'dart:io';

import 'package:reader_mode/reader_mode.dart';

void main(List<String> args) {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    _printUsage();
    exit(args.isEmpty ? 1 : 0);
  }

  final jsonOutput = args.contains('--json') || args.contains('-j');
  final metadataOnly = args.contains('--metadata') || args.contains('-m');
  // "-" is stdin, not a flag
  final input = args.where((a) => a == '-' || !a.startsWith('-')).firstOrNull;

  if (input == null) {
    stderr.writeln('Error: No input specified');
    _printUsage();
    exit(1);
  }

  try {
    final html = _readInput(input);
    final article = _parseHtml(html, input);

    if (article == null) {
      stderr.writeln('Error: Could not extract readable content');
      exit(1);
    }

    _outputArticle(article, jsonOutput: jsonOutput, metadataOnly: metadataOnly);
  } on Exception catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}

void _printUsage() {
  stderr.writeln('''
Readability CLI - Extract readable content from HTML

Usage:
  readability [options] <file>
  readability [options] <url>
  cat file.html | readability [options] -

Options:
  -h, --help      Show this help message
  -j, --json      Output as JSON
  -m, --metadata  Output metadata only (no content)

Examples:
  readability article.html
  readability https://example.com/article
  curl -s https://example.com | readability -
  readability --json article.html > output.json
''');
}

String _readInput(String input) {
  if (input == '-') {
    // Read all of stdin
    final buffer = StringBuffer();
    String? line;
    while ((line = stdin.readLineSync(encoding: utf8)) != null) {
      buffer.writeln(line);
    }
    return buffer.toString();
  }

  if (input.startsWith('http://') || input.startsWith('https://')) {
    return _fetchUrl(input);
  }

  final file = File(input);
  if (!file.existsSync()) {
    throw Exception('File not found: $input');
  }
  return file.readAsStringSync();
}

String _fetchUrl(String url) {
  final client = HttpClient();
  try {
    final request = client.getUrl(Uri.parse(url));
    final response = request
        .then((req) => req.close())
        .then((res) => res.transform(utf8.decoder).join());
    // Run synchronously for simplicity
    final result = _runSync(() async => await response);
    return result;
  } finally {
    client.close();
  }
}

T _runSync<T>(Future<T> Function() fn) {
  late T result;
  var done = false;
  Exception? error;

  fn().then((value) {
    result = value;
    done = true;
  }).catchError((Object e) {
    error = e is Exception ? e : Exception(e.toString());
    done = true;
  });

  // Busy-wait for completion (not ideal but works for CLI)
  while (!done) {
    sleep(const Duration(milliseconds: 10));
  }

  if (error != null) throw error!;
  return result;
}

Article? _parseHtml(String html, String input) {
  final uri = input.startsWith('http') ? input : 'file://$input';
  final parser = JSDOMParser();
  final doc = parser.parse(html, uri);
  final reader = Readability(JsdomDomDocument(doc));
  return reader.parse();
}

void _outputArticle(Article article,
    {required bool jsonOutput, required bool metadataOnly}) {
  if (jsonOutput) {
    final map = <String, dynamic>{
      'title': article.title,
      'byline': article.byline,
      'excerpt': article.excerpt,
      'siteName': article.siteName,
      'length': article.length,
      'lang': article.lang,
      'dir': article.dir,
      'publishedTime': article.publishedTime,
    };
    if (!metadataOnly) {
      map['content'] = article.content;
      map['textContent'] = article.textContent;
    }
    print(const JsonEncoder.withIndent('  ').convert(map));
  } else {
    print('Title: ${article.title}');
    if (article.byline != null) print('Author: ${article.byline}');
    if (article.siteName != null) print('Site: ${article.siteName}');
    if (article.excerpt != null) print('Excerpt: ${article.excerpt}');
    if (article.publishedTime != null) {
      print('Published: ${article.publishedTime}');
    }
    print('Length: ${article.length} characters');

    if (!metadataOnly) {
      print('\n--- Content ---\n');
      print(article.textContent);
    }
  }
}
