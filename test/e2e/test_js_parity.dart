/// Test file that compares Dart Readability output directly with JS Readability output.
///
/// This test runs both the JavaScript and Dart implementations on the same
/// source HTML and compares their outputs, ignoring insignificant differences.
/// Both implementations use JSDOMParser for HTML parsing to ensure identical
/// DOM structures.
///
/// The comparison normalizes:
/// - Whitespace between tags
/// - Self-closing tag syntax (br/ vs br)
/// - HTML entity encoding (apos vs ')
/// - tbody tags (implicit in HTML)
/// - SVG attribute/element case (viewbox vs viewBox)
/// - HTML comments
///
/// Requirements:
/// - Node.js must be installed
library;

import 'dart:convert';
import 'dart:io';

import 'package:readability/readability.dart';
import 'package:test/test.dart';

import '../utils.dart';

/// Runs the JS Readability on the given source HTML and returns the result.
Future<Map<String, dynamic>?> runJsReadability(
    String source, String url) async {
  // Create a temporary JS script that runs Readability
  final repoRoot = _getRepoRoot();
  final script = '''
const Readability = require('./Readability');
const JSDOMParser = require('./JSDOMParser');

const source = ${jsonEncode(source)};
const url = ${jsonEncode(url)};

// Use JSDOMParser (same as Dart implementation) instead of JSDOM
// This ensures both implementations parse HTML the same way
const parser = new JSDOMParser();
const doc = parser.parse(source, url);
const reader = new Readability(doc, {
  classesToPreserve: ['caption']
});
const article = reader.parse();

if (article) {
  console.log(JSON.stringify({
    title: article.title,
    byline: article.byline,
    dir: article.dir,
    lang: article.lang,
    content: article.content,
    textContent: article.textContent,
    length: article.length,
    excerpt: article.excerpt,
    siteName: article.siteName,
    publishedTime: article.publishedTime
  }));
} else {
  console.log('null');
}
''';

  // Write temp file in repo root so relative requires work
  final tempFile = File(
      '$repoRoot/readability_test_${DateTime.now().millisecondsSinceEpoch}.js');
  await tempFile.writeAsString(script);

  try {
    final result = await Process.run(
      'node',
      [tempFile.path],
      workingDirectory: repoRoot,
    );

    if (result.exitCode != 0) {
      print('JS Readability error: ${result.stderr}');
      return null;
    }

    final output = (result.stdout as String).trim();
    if (output == 'null') {
      return null;
    }

    return jsonDecode(output) as Map<String, dynamic>;
  } finally {
    await tempFile.delete();
  }
}

/// Runs the Dart Readability on the given source HTML and returns the result.
Map<String, dynamic>? runDartReadability(String source, String url) {
  final parser = JSDOMParser();
  final doc = parser.parse(source, url);
  final reader = Readability(
    JsdomDomDocument(doc),
    ReadabilityOptions(classesToPreserve: ['caption']),
  );
  final article = reader.parse();
  return article?.toJson();
}

/// Normalizes HTML content for XML comparison.
/// - Removes whitespace between tags
/// - Normalizes whitespace within text content
/// - Normalizes self-closing tags (br/, hr/, img/, etc.)
/// - Normalizes HTML entity encoding
/// - Removes HTML comments
/// - Removes tbody tags (implicit in HTML)
/// - Returns normalized string
String? normalizeHtmlForComparison(String? html) {
  if (html == null || html.isEmpty) return null;

  // Remove HTML comments
  var normalized = html.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

  // Remove whitespace between tags (> followed by whitespace followed by <)
  normalized = normalized.replaceAll(RegExp(r'>\s+<'), '><');

  // Normalize whitespace within text (collapse multiple spaces to one)
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');

  // Remove leading/trailing whitespace from text content between tags
  // This regex finds text between > and < and trims it
  normalized = normalized.replaceAllMapped(
    RegExp(r'>([^<]+)<'),
    (match) {
      final text = match.group(1)!.trim();
      return text.isEmpty ? '><' : '>$text<';
    },
  );

  // Normalize self-closing tags: <br/> -> <br>, <hr/> -> <hr>, etc.
  // This handles void elements that may be serialized differently
  normalized = normalized.replaceAllMapped(
    RegExp(
        r'<(br|hr|img|input|meta|link|area|base|col|embed|param|source|track|wbr)([^>]*?)\s*/>'),
    (match) => '<${match.group(1)}${match.group(2)}>',
  );

  // Remove tbody tags (they're implicit in HTML tables)
  normalized = normalized.replaceAll(RegExp(r'</?tbody>'), '');

  // Normalize SVG attribute case (HTML parsers lowercase, but SVG uses camelCase)
  // viewbox -> viewBox, clippath -> clipPath, etc.
  final svgCamelCaseAttrs = {
    'viewbox': 'viewBox',
    'preserveaspectratio': 'preserveAspectRatio',
    'clippath': 'clipPath',
    'clippathunits': 'clipPathUnits',
    'basefrequency': 'baseFrequency',
    'numoctaves': 'numOctaves',
    'stddeviation': 'stdDeviation',
    'stitchtiles': 'stitchTiles',
    'patterncontentunits': 'patternContentUnits',
    'patterntransform': 'patternTransform',
    'patternunits': 'patternUnits',
    'spreadmethod': 'spreadMethod',
    'gradientunits': 'gradientUnits',
    'gradienttransform': 'gradientTransform',
    'filterunits': 'filterUnits',
    'primitiveunits': 'primitiveUnits',
    'maskcontentunits': 'maskContentUnits',
    'maskunits': 'maskUnits',
    'textlength': 'textLength',
    'lengthadjust': 'lengthAdjust',
    'startoffset': 'startOffset',
    'glyphref': 'glyphRef',
    'requiredfeatures': 'requiredFeatures',
    'requiredextensions': 'requiredExtensions',
    'systemlanguage': 'systemLanguage',
    'refx': 'refX',
    'refy': 'refY',
    'markerheight': 'markerHeight',
    'markerwidth': 'markerWidth',
    'markerunits': 'markerUnits',
  };
  for (final entry in svgCamelCaseAttrs.entries) {
    normalized = normalized.replaceAll(' ${entry.key}=', ' ${entry.value}=');
  }

  // Also normalize SVG element names that use camelCase
  final svgCamelCaseElems = {
    'clippath': 'clipPath',
    'lineargradient': 'linearGradient',
    'radialgradient': 'radialGradient',
    'textpath': 'textPath',
    'foreignobject': 'foreignObject',
  };
  for (final entry in svgCamelCaseElems.entries) {
    normalized = normalized.replaceAll('<${entry.key}', '<${entry.value}');
    normalized = normalized.replaceAll('</${entry.key}>', '</${entry.value}>');
  }

  // Normalize HTML entities to characters where safe
  // &apos; -> '
  normalized = normalized.replaceAll('&apos;', "'");
  // &#160; and &nbsp; -> single space (for comparison purposes)
  normalized = normalized.replaceAll(RegExp(r'&#160;|&nbsp;'), ' ');

  // Normalize &lt; and &gt; in text content to actual < and > characters.
  // This handles differences in how parsers serialize text containing < or >.
  // We do this by matching text between tags and decoding entities there.
  normalized = normalized.replaceAllMapped(
    RegExp(r'>([^<]*)<'),
    (match) {
      var text = match.group(1)!;
      text = text.replaceAll('&lt;', '<').replaceAll('&gt;', '>');
      return '>$text<';
    },
  );

  // Collapse multiple spaces again after entity replacement
  normalized = normalized.replaceAll(RegExp(r' +'), ' ');

  // Final trim
  return normalized.trim();
}

/// Gets the repository root directory.
String _getRepoRoot() {
  final dartRoot = _findDartRoot();
  // In this project, mozilla/readability is in the readability/ subdirectory
  // of the dart project, not a sibling directory
  return Directory('$dartRoot/readability').path;
}

/// Find the dart project root by looking for pubspec.yaml.
String _findDartRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 5; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  return Directory.current.path;
}

/// Compares two HTML strings as XML, ignoring whitespace differences.
/// Returns null if they match, or an error message if they differ.
String? compareHtmlAsXml(String? dartHtml, String? jsHtml, String context) {
  final normalizedDart = normalizeHtmlForComparison(dartHtml);
  final normalizedJs = normalizeHtmlForComparison(jsHtml);

  if (normalizedDart == normalizedJs) {
    return null; // Match
  }

  if (normalizedDart == null && normalizedJs == null) {
    return null; // Both null, match
  }

  if (normalizedDart == null || normalizedJs == null) {
    return '$context: One is null (Dart: ${normalizedDart != null}, JS: ${normalizedJs != null})';
  }

  // Find first difference
  final dartChars = normalizedDart.split('');
  final jsChars = normalizedJs.split('');
  final minLen =
      dartChars.length < jsChars.length ? dartChars.length : jsChars.length;

  for (var i = 0; i < minLen; i++) {
    if (dartChars[i] != jsChars[i]) {
      final start = i > 20 ? i - 20 : 0;
      final dartSnippet = normalizedDart.substring(
          start, (i + 30).clamp(0, normalizedDart.length));
      final jsSnippet =
          normalizedJs.substring(start, (i + 30).clamp(0, normalizedJs.length));
      return '$context: Difference at position $i\n'
          '  Dart: ...$dartSnippet...\n'
          '  JS:   ...$jsSnippet...';
    }
  }

  if (dartChars.length != jsChars.length) {
    return '$context: Length difference (Dart: ${dartChars.length}, JS: ${jsChars.length})';
  }

  return '$context: Unknown difference';
}

void main() {
  final testPages = getTestPages();

  // Check if Node.js is available
  setUpAll(() async {
    try {
      final result = await Process.run('node', ['--version']);
      if (result.exitCode != 0) {
        fail('Node.js is required but not available');
      }
    } catch (e) {
      fail('Node.js is required but not available: $e');
    }

    // Check if jsdom is installed
    try {
      final result = await Process.run(
        'node',
        ['-e', "require('jsdom')"],
        workingDirectory: _getRepoRoot(),
      );
      if (result.exitCode != 0) {
        fail('jsdom is required. Run: npm install jsdom');
      }
    } catch (e) {
      fail('jsdom is required. Run: npm install jsdom');
    }
  });

  group('JS Parity', () {
    for (final testPage in testPages) {
      test('${testPage.dir} - content should match JS output', () async {
        final url = 'http://fakehost/test/page.html';

        // Run both implementations
        final jsResult = await runJsReadability(testPage.source, url);
        final dartResult = runDartReadability(testPage.source, url);

        // Both should return same null/non-null status
        if (jsResult == null && dartResult == null) {
          return; // Both null, pass
        }

        expect(
          dartResult != null,
          equals(jsResult != null),
          reason: 'Dart and JS should both return article or both return null',
        );

        if (jsResult == null || dartResult == null) return;

        // Compare content as XML
        final contentDiff = compareHtmlAsXml(
          dartResult['content'] as String?,
          jsResult['content'] as String?,
          'content',
        );
        expect(contentDiff, isNull, reason: contentDiff ?? '');

        // Compare metadata
        expect(
          dartResult['title'],
          equals(jsResult['title']),
          reason: 'title should match',
        );
        expect(
          dartResult['byline'],
          equals(jsResult['byline']),
          reason: 'byline should match',
        );
        expect(
          dartResult['excerpt'],
          equals(jsResult['excerpt']),
          reason: 'excerpt should match',
        );
        expect(
          dartResult['siteName'],
          equals(jsResult['siteName']),
          reason: 'siteName should match',
        );
        expect(
          dartResult['dir'],
          equals(jsResult['dir']),
          reason: 'dir should match',
        );
        expect(
          dartResult['lang'],
          equals(jsResult['lang']),
          reason: 'lang should match',
        );
        expect(
          dartResult['publishedTime'],
          equals(jsResult['publishedTime']),
          reason: 'publishedTime should match',
        );
      });
    }
  });
}
