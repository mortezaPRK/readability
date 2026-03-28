// JS interop entry point for browser/Node.js usage
// This file exposes the Readability library API to JavaScript

import 'dart:js_interop';

import 'package:html/parser.dart' as html_parser;

import '../reader_mode.dart' as lib;

/// JS-compatible Article object
extension type JSArticle._(JSObject _) implements JSObject {
  external factory JSArticle({
    required String title,
    required String content,
    required String textContent,
    required int length,
    String? excerpt,
    String? byline,
    String? dir,
    String? siteName,
    String? lang,
    String? publishedTime,
  });

  external String get title;
  external String get content;
  external String get textContent;
  external int get length;
  external String? get excerpt;
  external String? get byline;
  external String? get dir;
  external String? get siteName;
  external String? get lang;
  external String? get publishedTime;
}

/// JS-compatible parse options
extension type JSParseOptions._(JSObject _) implements JSObject {
  external String? get baseUri;
  external int? get charThreshold;
  external int? get maxElemsToParse;
  external bool? get keepClasses;
}

/// JS-compatible readerable options
extension type JSReaderableOptions._(JSObject _) implements JSObject {
  external int? get minContentLength;
  external int? get minScore;
}

/// Convert Dart Article to JS-compatible object
JSArticle? _toJSArticle(lib.Article? article) {
  if (article == null) return null;
  return JSArticle(
    title: article.title,
    content: article.content,
    textContent: article.textContent,
    length: article.length,
    excerpt: article.excerpt,
    byline: article.byline,
    dir: article.dir,
    siteName: article.siteName,
    lang: article.lang,
    publishedTime: article.publishedTime,
  );
}

/// Parse HTML content and extract the main article.
///
/// Returns a JS object with article properties, or null if no readable content.
@JS('parse')
external set _parse(JSFunction f);

JSArticle? _parseImpl(String html, [JSParseOptions? options]) {
  final baseUri = options?.baseUri;
  final charThreshold = options?.charThreshold ?? 500;
  final maxElemsToParse = options?.maxElemsToParse ?? 0;
  final keepClasses = options?.keepClasses ?? false;

  final article = lib.parse(
    html,
    baseUri: baseUri,
    charThreshold: charThreshold,
    maxElemsToParse: maxElemsToParse,
    keepClasses: keepClasses,
  );

  return _toJSArticle(article);
}

/// Check if HTML content is likely readable.
///
/// Returns true if the content appears to be an article worth parsing.
@JS('isProbablyReaderable')
external set _isProbablyReaderable(JSFunction f);

bool _isProbablyReaderableImpl(String html, [JSReaderableOptions? options]) {
  final doc = html_parser.parse(html);

  final readerableOptions = lib.ReaderableOptions(
    minContentLength: options?.minContentLength ?? 140,
    minScore: options?.minScore ?? 20,
  );

  return lib.isProbablyReaderable(doc, readerableOptions);
}

void main() {
  _parse = _parseImpl.toJS;
  _isProbablyReaderable = _isProbablyReaderableImpl.toJS;
}
