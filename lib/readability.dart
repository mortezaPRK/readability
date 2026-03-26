/// A Dart port of Mozilla's Readability.js content extraction library.
///
/// This library extracts the main readable content from a web page,
/// stripping away navigation, ads, and other non-content elements.
///
/// ## Licensing
///
/// This library is licensed under the Apache License 2.0, except for
/// `jsdom_parser.dart` which is licensed under the Mozilla Public License v2.0.
/// See the LICENSE file for details.
///
/// ## Usage
///
/// ```dart
/// import 'package:readability/readability.dart';
///
/// // Simple usage with parse() function
/// final article = parse(htmlString, baseUri: 'https://example.com');
/// print(article?.title);
/// print(article?.content);
///
/// // With options
/// final article = parse(
///   htmlString,
///   parser: ParserType.html,  // Use html package instead of JSDOMParser
///   charThreshold: 1000,
///   keepClasses: true,
/// );
/// ```
///
/// ## Quick Readability Check
///
/// Before parsing, you can check if a page is likely readable:
///
/// ```dart
/// import 'package:html/parser.dart' as html;
/// import 'package:readability/readability.dart';
///
/// final document = html.parse(htmlString);
/// if (isProbablyReaderable(document)) {
///   final article = parse(htmlString);
/// }
/// ```
///
/// ## Dual Parser Support
///
/// This library supports two parsers via the [ParserType] enum:
/// - [ParserType.jsdom] (default): Port of Mozilla's JSDOM parser
/// - [ParserType.html]: Pure Dart html package
library;

// SPDX-License-Identifier: Apache-2.0
// SPDX-License-Identifier: MPL-2.0
// See LICENSE file for details on dual licensing

export 'src/jsdom_parser.dart' hide NodeType;
export 'src/readability.dart';
export 'src/readability_readerable.dart';
export 'src/dom_adapter.dart';
export 'src/adapters/jsdom_adapter.dart';
export 'src/adapters/html_adapter.dart';

// Import for use in convenience functions
import 'package:html/parser.dart' as html_parser;
import 'src/jsdom_parser.dart' show JSDOMParser;
import 'src/readability.dart'
    show Readability, ReadabilityOptions, ReadabilityLogger, Article;
import 'src/dom_adapter.dart' show DomElement;
import 'src/adapters/jsdom_adapter.dart' show JsdomDomDocument;
import 'src/adapters/html_adapter.dart' show HtmlDomDocument;

/// Parser type for HTML content extraction.
enum ParserType {
  /// JSDOMParser - a port of Mozilla's JSDOM parser.
  /// More accurate for complex HTML but slightly slower.
  jsdom,

  /// Dart html package - pure Dart implementation.
  /// Faster but may have minor differences in edge cases.
  html,
}

/// Parse HTML content and extract the main article.
///
/// This is the primary function for extracting readable content from HTML.
///
/// Example:
/// ```dart
/// // Basic usage with defaults (uses JSDOMParser)
/// final article = parse(htmlString);
/// print(article?.title);
/// print(article?.content);
///
/// // With options
/// final article = parse(
///   htmlString,
///   parser: ParserType.html,
///   baseUri: 'https://example.com',
///   charThreshold: 1000,
/// );
///
/// // With custom logger
/// final article = parse(
///   htmlString,
///   logger: (msg) => print('[Readability] $msg'),
/// );
/// ```
///
/// Parameters:
/// - [html]: The HTML content to parse
/// - [parser]: Which parser to use (default: [ParserType.jsdom])
/// - [baseUri]: Base URI for resolving relative URLs (only used with jsdom parser)
/// - [logger]: Custom callback for debug messages (overrides [debug] flag)
/// - All other parameters map to [ReadabilityOptions] fields
///
/// Returns the extracted [Article] or null if no readable content was found.
Article? parse(
  String html, {
  ParserType parser = ParserType.jsdom,
  String? baseUri,
  bool debug = false,
  ReadabilityLogger? logger,
  int maxElemsToParse = 0,
  int numTopCandidates = 5,
  int charThreshold = 500,
  List<String> classesToPreserve = const [],
  bool keepClasses = false,
  String Function(DomElement)? serializer,
  bool enableJSONLD = true,
  RegExp? allowedVideoRegex,
  double linkDensityModifier = 0,
}) {
  final options = ReadabilityOptions(
    debug: debug,
    logger: logger,
    maxElemsToParse: maxElemsToParse,
    numTopCandidates: numTopCandidates,
    charThreshold: charThreshold,
    classesToPreserve: classesToPreserve,
    keepClasses: keepClasses,
    serializer: serializer,
    enableJSONLD: enableJSONLD,
    allowedVideoRegex: allowedVideoRegex,
    linkDensityModifier: linkDensityModifier,
  );

  final Readability reader;
  switch (parser) {
    case ParserType.jsdom:
      final jsdomParser = JSDOMParser();
      final doc = jsdomParser.parse(html, baseUri);
      reader = Readability(JsdomDomDocument(doc), options);
    case ParserType.html:
      final htmlDoc = html_parser.parse(html);
      reader = Readability(HtmlDomDocument(htmlDoc), options);
  }

  return reader.parse();
}
