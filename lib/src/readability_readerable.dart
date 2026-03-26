/*
 * Copyright (c) 2010 Arc90 Inc
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Copyright (c) 2024 Dart Readability contributors
 * This is a Dart port of Mozilla's Readability.js from the Readability project
 */

/*
 * This code is heavily based on Arc90's readability.js (1.7.1) script
 * available at: http://code.google.com/p/arc90labs-readability
 */

import 'dart:math' as math;

import 'package:html/dom.dart';
// ignore: implementation_imports
import 'package:html/src/query_selector.dart' as query;

import 'constants.dart';

/// Checks whether a node is visible based on its style and attributes.
///
/// This is the default visibility checker used by [isProbablyReaderable].
bool isNodeVisible(Element node) {
  // Have to null-check node.style and node.className.includes to deal
  // with SVG and MathML nodes.
  // In the html package, there's no parsed style object, so we check the
  // raw style attribute string for "display:none" or "display: none".
  final style = node.attributes['style'];
  if (style != null && _displayNonePattern.hasMatch(style)) {
    return false;
  }
  if (node.attributes.containsKey('hidden')) {
    return false;
  }
  // Check for "fallback-image" so that wikimedia math images are displayed.
  if (node.attributes.containsKey('aria-hidden') &&
      node.attributes['aria-hidden'] == 'true' &&
      !node.className.contains('fallback-image')) {
    return false;
  }
  return true;
}

final _displayNonePattern = RegExp(r'display\s*:\s*none', caseSensitive: false);

/// Options for [isProbablyReaderable].
class ReaderableOptions {
  /// The minimum node content length used to decide if the document is
  /// readerable. Defaults to 140.
  final int minContentLength;

  /// The minimum cumulated 'score' used to determine if the document is
  /// readerable. Defaults to 20.
  final int minScore;

  /// The function used to determine if a node is visible.
  /// Defaults to [isNodeVisible].
  final bool Function(Element) visibilityChecker;

  const ReaderableOptions({
    this.minContentLength = 140,
    this.minScore = 20,
    this.visibilityChecker = isNodeVisible,
  });
}

/// Determines whether a document is likely to contain readable article content.
///
/// This is a fast check that analyzes the document without doing a full parse.
/// It's useful for deciding whether to attempt full article extraction.
///
/// The function looks for:
/// - Sufficient content length (paragraphs, pre blocks, articles)
/// - Positive class/id names (article, content, main, etc.)
/// - Negative class/id names (ad, banner, sidebar, etc.)
/// - Visible content (not hidden via CSS)
///
/// Example:
/// ```dart
/// final document = html.parse(htmlString);
/// if (isProbablyReaderable(document)) {
///   final reader = Readability(document);
///   final article = reader.parse();
/// }
/// ```
///
/// Returns `true` if the document is likely readable, `false` otherwise.
bool isProbablyReaderable(Document doc, [ReaderableOptions? options]) {
  options ??= const ReaderableOptions();

  var nodes = doc.querySelectorAll('p, pre, article');

  // Get <div> nodes which have <br> node(s) and append them into the
  // `nodes` variable. Some articles' DOM structures might look like:
  // <div>
  //   Sentences<br>
  //   <br>
  //   Sentences<br>
  // </div>
  var brNodes = doc.querySelectorAll('div > br');
  if (brNodes.isNotEmpty) {
    var set = <Element>{...nodes};
    for (var node in brNodes) {
      final parent = node.parent;
      if (parent != null) {
        set.add(parent);
      }
    }
    nodes = set.toList();
  }

  var score = 0.0;
  // This is a little cheeky, we use the accumulator 'score' to decide what
  // to return from this callback:
  return nodes.any((node) {
    if (!options!.visibilityChecker(node)) {
      return false;
    }

    var matchString = '${node.className} ${node.id}';
    if (unlikelyCandidates.hasMatch(matchString) &&
        !okMaybeItsACandidate.hasMatch(matchString)) {
      return false;
    }

    if (query.matches(node, 'li p')) {
      return false;
    }

    var textContentLength = node.text.trim().length;
    if (textContentLength < options.minContentLength) {
      return false;
    }

    score += math.sqrt(textContentLength - options.minContentLength);

    if (score > options.minScore) {
      return true;
    }
    return false;
  });
}
