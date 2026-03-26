// Copyright (c) 2024 Dart Readability contributors
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.

/// A specialized map for storing readability scores on DOM elements.
///
/// This map uses DOM attributes for storage, which allows it to work
/// with wrapped DOM elements where the underlying element identity needs
/// to be preserved across wrapper instances.
library;

import 'dom_adapter.dart';

/// Readability score attached to elements.
///
/// This class provides a mutable score object that automatically updates
/// the underlying DOM attribute when modified.
class ReadabilityScore {
  final DomElement _element;
  final ReadabilityScoreMap _map;
  double _contentScore;

  ReadabilityScore._({
    required DomElement element,
    required ReadabilityScoreMap map,
    double contentScore = 0,
  })  : _element = element,
        _map = map,
        _contentScore = contentScore;

  double get contentScore => _contentScore;

  set contentScore(double value) {
    _contentScore = value;
    _map._update(_element, value);
  }

  @override
  String toString() => contentScore.toString();
}

/// Identity-based map for storing readability scores on DOM elements.
///
/// This implementation stores scores as attributes on the elements themselves,
/// which ensures that the scores are preserved even when elements are wrapped
/// in adapter instances.
class ReadabilityScoreMap {
  final String _attributePrefix = '_readability-score-';
  static const String _scoreIdAttributeName = '_readability-score-id';
  int _nextId = 0;

  /// Stores a score value for the given element.
  void put(DomElement element, double contentScore) {
    final id = _getId(element);
    element.setAttribute('$_attributePrefix$id', contentScore.toString());
  }

  /// Updates a score value for the given element (internal method).
  void _update(DomElement element, double contentScore) {
    final id = _getId(element);
    element.setAttribute('$_attributePrefix$id', contentScore.toString());
  }

  /// Retrieves the score value for the given element, or null if not found.
  double? get(DomElement element) {
    for (final attr in element.attributes) {
      // Skip the ID attribute, only look for score attributes
      if (attr.name == _scoreIdAttributeName) continue;
      if (attr.name.startsWith(_attributePrefix)) {
        return double.tryParse(attr.value);
      }
    }
    return null;
  }

  /// Gets or creates a ReadabilityScore object for the given element.
  ///
  /// The returned score object is mutable and will automatically update
  /// the underlying DOM attribute when modified.
  ReadabilityScore getScoreObject(DomElement element) {
    final score = get(element) ?? 0;
    return ReadabilityScore._(
      element: element,
      map: this,
      contentScore: score,
    );
  }

  /// Returns true if this map contains a score for the given element.
  bool containsKey(DomElement element) {
    return get(element) != null;
  }

  /// Removes the score for the given element.
  void remove(DomElement element) {
    for (final attr in element.attributes) {
      if (attr.name.startsWith(_attributePrefix)) {
        element.removeAttribute(attr.name);
      }
    }
    // Also remove the ID attribute
    element.removeAttribute(_scoreIdAttributeName);
  }

  /// Gets or creates a unique ID for the element.
  String _getId(DomElement element) {
    final existing = element.getAttribute(_scoreIdAttributeName);
    if (existing != null) return existing;
    final id = '_rs_${++_nextId}';
    element.setAttribute(_scoreIdAttributeName, id);
    return id;
  }

  /// Cleans up all readability score attributes from the element.
  void cleanup(DomElement element) {
    remove(element);
  }
}
