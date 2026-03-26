// Copyright (c) 2024 Dart Readability contributors
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.

/// Shared constants used across the Readability library.
///
/// This file contains regular expressions and other constants that are
/// referenced by multiple modules to avoid duplication.
library;

/// Regular expression matching class and id names that suggest content
/// is unlikely to be article content.
///
/// Used by both the readability check (isProbablyReaderable) and the
/// main article extraction algorithm.
final RegExp unlikelyCandidates = RegExp(
  r'-ad-|ai2html|banner|breadcrumbs|combx|comment|community|cover-wrap|disqus|extra|footer|gdpr|header|legends|menu|related|remark|replies|rss|shoutbox|sidebar|skyscraper|social|sponsor|supplemental|ad-break|agegate|pagination|pager|popup|yom-remote',
  caseSensitive: false,
);

/// Regular expression matching class and id names that suggest content
/// might still be article content despite matching unlikelyCandidates.
///
/// Used by both the readability check (isProbablyReaderable) and the
/// main article extraction algorithm.
final RegExp okMaybeItsACandidate = RegExp(
  r'and|article|body|column|content|main|mathjax|shadow',
  caseSensitive: false,
);
