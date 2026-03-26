// Copyright (c) 2010 Arc90 Inc
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Copyright (c) 2024 Dart Readability contributors
// This is a Dart port of Mozilla's Readability.js from the Readability project

import 'dart:convert';
import 'jsdom_parser.dart' hide NodeType;
import 'dom_adapter.dart';
import 'adapters/jsdom_adapter.dart';
import 'readability_score_map.dart';
import 'constants.dart';

/// Article result from Readability parsing.
///
/// Contains the extracted article content and metadata from a web page.
class Article {
  /// The article title.
  final String title;

  /// The article content as HTML.
  final String content;

  /// The article content as plain text (no HTML tags).
  final String textContent;

  /// The length of the text content in characters.
  final int length;

  /// A short excerpt or summary of the article.
  final String? excerpt;

  /// The article author/byline.
  final String? byline;

  /// The text direction (e.g., "ltr" or "rtl").
  final String? dir;

  /// The site name where the article was published.
  final String? siteName;

  /// The article language code (e.g., "en").
  final String? lang;

  /// The publication time as an ISO 8601 string.
  final String? publishedTime;

  /// Creates a new Article with the given properties.
  Article({
    required this.title,
    required this.content,
    required this.textContent,
    required this.length,
    this.excerpt,
    this.byline,
    this.dir,
    this.siteName,
    this.lang,
    this.publishedTime,
  });

  /// Converts this Article to a JSON map.
  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'textContent': textContent,
        'length': length,
        'excerpt': excerpt,
        'byline': byline,
        'dir': dir,
        'siteName': siteName,
        'lang': lang,
        'publishedTime': publishedTime,
      };
}

/// Configuration options for the Readability parser.
class ReadabilityOptions {
  /// Enable debug logging.
  final bool debug;

  /// Maximum number of elements to parse (0 = no limit).
  final int maxElemsToParse;

  /// Number of top candidates to consider during content extraction.
  final int numTopCandidates;

  /// Minimum character threshold for article content.
  final int charThreshold;

  /// List of CSS class names to preserve during cleaning.
  final List<String> classesToPreserve;

  /// Whether to preserve all classes in the output.
  final bool keepClasses;

  /// Custom serializer function for converting elements to strings.
  final String Function(DomElement)? serializer;

  /// Enable JSON-LD metadata extraction (for byline, published time, etc.).
  final bool enableJSONLD;

  /// Regular expression for matching allowed video URLs.
  final RegExp? allowedVideoRegex;

  /// Modifier for link density scoring.
  final double linkDensityModifier;

  const ReadabilityOptions({
    this.debug = false,
    this.maxElemsToParse = 0,
    this.numTopCandidates = 5,
    this.charThreshold = 500,
    this.classesToPreserve = const [],
    this.keepClasses = false,
    this.serializer,
    this.enableJSONLD = true,
    this.allowedVideoRegex,
    this.linkDensityModifier = 0,
  });
}

/// Main Readability parser class.
///
/// Extracts the main article content from a web page by analyzing
/// the document structure, content density, and various heuristics.
///
/// Example:
/// ```dart
/// final parser = JSDOMParser();
/// final document = parser.parse(htmlString);
/// final reader = Readability(document);
/// final article = reader.parse();
/// ```
class Readability {
  // Constants
  static const int flagStripUnlikelys = 0x1;
  static const int flagWeightClasses = 0x2;
  static const int flagCleanConditionally = 0x4;

  static const int defaultMaxElemsToParse = 0;
  static const int defaultNTopCandidates = 5;
  static const int defaultCharThreshold = 500;

  static const List<String> defaultTagsToScore = [
    'SECTION',
    'H2',
    'H3',
    'H4',
    'H5',
    'H6',
    'P',
    'TD',
    'PRE'
  ];

  static const List<String> classesToPreserveDefault = ['page'];

  static final RegExp _positive = RegExp(
    r'article|body|content|entry|hentry|h-entry|main|page|pagination|post|text|blog|story',
    caseSensitive: false,
  );

  static final RegExp _negative = RegExp(
    r'-ad-|hidden|^hid$| hid$| hid |^hid |banner|combx|comment|com-|contact|footer|gdpr|masthead|media|meta|outbrain|promo|related|scroll|share|shoutbox|sidebar|skyscraper|sponsor|shopping|tags|widget',
    caseSensitive: false,
  );

  static final RegExp _byline = RegExp(
    r'byline|author|dateline|writtenby|p-author',
    caseSensitive: false,
  );

  static final RegExp _normalize = RegExp(r'\s{2,}');

  static final RegExp _videos = RegExp(
    r'//(www\.)?((dailymotion|youtube|youtube-nocookie|player\.vimeo|v\.qq|bilibili|live.bilibili)\.com|(archive|upload\.wikimedia)\.org|player\.twitch\.tv)',
    caseSensitive: false,
  );

  static final RegExp _shareElements = RegExp(
    r'(\b|_)(share|sharedaddy)(\b|_)',
    caseSensitive: false,
  );

  static final RegExp _tokenize = RegExp(r'\W+');
  static final RegExp _whitespace = RegExp(r'^\s*$');
  static final RegExp _hasContent = RegExp(r'\S$');
  static final RegExp _hashUrl = RegExp(r'^#.+');
  static final RegExp _srcsetUrl = RegExp(r'(\S+)(\s+[\d.]+[xw])?(\s*(?:,|$))');
  static final RegExp _b64DataUrl = RegExp(
    r'^data:\s*([^\s;,]+)\s*;\s*base64\s*,',
    caseSensitive: false,
  );

  static final RegExp _commas = RegExp(
    r'[\u002C\u060C\uFE50\uFE10\uFE11\u2E41\u2E34\u2E32\uFF0C]',
  );

  static final RegExp _jsonLdArticleTypes = RegExp(
    r'^(Article|AdvertiserContentArticle|NewsArticle|AnalysisNewsArticle|AskPublicNewsArticle|BackgroundNewsArticle|OpinionNewsArticle|ReportageNewsArticle|ReviewNewsArticle|Report|SatiricalArticle|ScholarlyArticle|MedicalScholarlyArticle|SocialMediaPosting|BlogPosting|LiveBlogPosting|DiscussionForumPosting|TechArticle|APIReference)$',
  );

  static final RegExp _adWords = RegExp(
    r'^(ad(vertising|vertisement)?|pub(licité)?|werb(ung)?|广告|Реклама|Anuncio)$',
    caseSensitive: false,
    unicode: true,
  );

  static final RegExp _loadingWords = RegExp(
    r'^((loading|正在加载|Загрузка|chargement|cargando)(…|\.\.\.)?)$',
    caseSensitive: false,
    unicode: true,
  );

  static const List<String> unlikelyRoles = [
    'menu',
    'menubar',
    'complementary',
    'navigation',
    'alert',
    'alertdialog',
    'dialog',
  ];

  static const Set<String> divToPElems = {
    'BLOCKQUOTE',
    'DL',
    'DIV',
    'IMG',
    'OL',
    'P',
    'PRE',
    'TABLE',
    'UL',
  };

  static const List<String> alterToDivExceptions = [
    'DIV',
    'ARTICLE',
    'SECTION',
    'P',
    'OL',
    'UL',
  ];

  static const List<String> presentationalAttributes = [
    'align',
    'background',
    'bgcolor',
    'border',
    'cellpadding',
    'cellspacing',
    'frame',
    'hspace',
    'rules',
    'style',
    'valign',
    'vspace',
  ];

  static const List<String> deprecatedSizeAttributeElems = [
    'TABLE',
    'TH',
    'TD',
    'HR',
    'PRE',
  ];

  static const List<String> phrasingElems = [
    'ABBR',
    'AUDIO',
    'B',
    'BDO',
    'BR',
    'BUTTON',
    'CITE',
    'CODE',
    'DATA',
    'DATALIST',
    'DFN',
    'EM',
    'EMBED',
    'I',
    'IMG',
    'INPUT',
    'KBD',
    'LABEL',
    'MARK',
    'MATH',
    'METER',
    'NOSCRIPT',
    'OBJECT',
    'OUTPUT',
    'PROGRESS',
    'Q',
    'RUBY',
    'SAMP',
    'SCRIPT',
    'SELECT',
    'SMALL',
    'SPAN',
    'STRONG',
    'SUB',
    'SUP',
    'TEXTAREA',
    'TIME',
    'VAR',
    'WBR',
  ];

  static const Map<String, String> htmlEscapeMap = {
    'lt': '<',
    'gt': '>',
    'amp': '&',
    'quot': '"',
    'apos': "'",
  };

  /// Unescape HTML entities in a string.
  String? _unescapeHtmlEntities(String? str) {
    if (str == null || str.isEmpty) {
      return str;
    }

    return str.replaceAllMapped(RegExp(r'&(quot|amp|apos|lt|gt);'), (m) {
      return htmlEscapeMap[m.group(1)] ?? m.group(0)!;
    }).replaceAllMapped(RegExp(r'&#(?:x([0-9a-fA-F]+)|([0-9]+));'), (m) {
      final hex = m.group(1);
      final numStr = m.group(2);
      var num = int.parse(hex ?? numStr!, radix: hex != null ? 16 : 10);

      // Character references replaced by conforming HTML parser
      if (num == 0 || num > 0x10ffff || (num >= 0xd800 && num <= 0xdfff)) {
        num = 0xfffd;
      }
      return String.fromCharCode(num);
    });
  }

  // Instance fields
  final DomDocument _doc;
  final Document?
      _legacyDoc; // Keep raw doc for JSDOMParser-specific operations
  final bool _docJSDOMParser;
  String? _articleTitle;
  String? _articleByline;
  String? _articleDir;
  String? _articleSiteName;
  final List<_Attempt> _attempts = [];
  Map<String, dynamic> _metadata = {};

  final bool _debug;
  final int _maxElemsToParse;
  final int _numTopCandidates;
  final int _charThreshold;
  final List<String> _classesToPreserve;
  final bool _keepClasses;
  final String Function(DomElement) _serializer;
  final bool _enableJSONLD;
  final RegExp _allowedVideoRegex;
  final double _linkDensityModifier;

  int _flags;

  // Map to store readability scores on elements
  final ReadabilityScoreMap _readabilityScores = ReadabilityScoreMap();

  /// Safe cast of parentNode to Element, returns null if not an Element.
  DomElement? _parentElement(DomNode? node) {
    final parent = node?.parentNode;
    return parent is DomElement ? parent : null;
  }

  // Public getters for options (for testing)
  bool get debug => _debug;
  int get maxElemsToParse => _maxElemsToParse;
  int get numTopCandidates => _numTopCandidates;
  int get charThreshold => _charThreshold;
  bool get keepClasses => _keepClasses;
  bool get enableJSONLD => _enableJSONLD;
  RegExp get allowedVideoRegex => _allowedVideoRegex;

  /// Internal constructor that accepts a DomDocument adapter.
  Readability._internal(this._doc, this._legacyDoc,
      [ReadabilityOptions? options])
      : _docJSDOMParser = _doc.isJSDOMParser,
        _debug = options?.debug ?? false,
        _maxElemsToParse = options?.maxElemsToParse ?? defaultMaxElemsToParse,
        _numTopCandidates = options?.numTopCandidates ?? defaultNTopCandidates,
        _charThreshold = options?.charThreshold ?? defaultCharThreshold,
        _classesToPreserve = [
          ...classesToPreserveDefault,
          ...(options?.classesToPreserve ?? [])
        ],
        _keepClasses = options?.keepClasses ?? false,
        _serializer = options?.serializer ?? ((DomElement el) => el.innerHTML),
        _enableJSONLD = options?.enableJSONLD ?? true,
        _allowedVideoRegex = options?.allowedVideoRegex ?? _videos,
        _linkDensityModifier = options?.linkDensityModifier ?? 0,
        _flags =
            flagStripUnlikelys | flagWeightClasses | flagCleanConditionally;

  /// Creates a new Readability parser for the given document.
  ///
  /// The [doc] parameter is a DomDocument adapter that wraps either a
  /// JSDOMParser document or an html package document.
  ///
  /// Example:
  /// ```dart
  /// // Using the parse() convenience function is recommended:
  /// final article = parse(htmlString);
  ///
  /// // Or create manually with adapters:
  /// final parser = JSDOMParser();
  /// final jsdomDoc = parser.parse(htmlString, baseUri);
  /// final reader = Readability(JsdomDomDocument(jsdomDoc), options);
  /// final article = reader.parse();
  /// ```
  Readability(DomDocument doc, [ReadabilityOptions? options])
      : this._internal(
            doc, doc is JsdomDomDocument ? doc.unwrap : null, options);

  void _log(List<dynamic> args) {
    if (_debug) {
      print('Reader: (Readability) ${args.join(' ')}');
    }
  }

  ReadabilityScore _getReadability(DomElement node) {
    return _readabilityScores.getScoreObject(node);
  }

  void _setReadability(DomElement node, ReadabilityScore score) {
    _readabilityScores.put(node, score.contentScore);
  }

  bool _hasReadability(DomElement node) {
    return _readabilityScores.containsKey(node);
  }

  /// Run any post-process modifications to article content.
  void _postProcessContent(DomElement articleContent) {
    _fixRelativeUris(articleContent);
    _simplifyNestedElements(articleContent);
    if (!_keepClasses) {
      _cleanClasses(articleContent);
    }
    // Remove internal readability attributes that were used during processing
    // but should not appear in the final output. In the JS version these are
    // JS object properties, not DOM attributes, so they never leak into
    // innerHTML. In Dart we store them as DOM attributes and must clean them up.
    for (final table in _getAllNodesWithTag(articleContent, ['table'])) {
      table.removeAttribute('_readabilityDataTable');
    }

    // Clean up score attributes from all elements (before serialization)
    _cleanupScoreAttributes(articleContent);
  }

  /// Clean up score attributes from all elements in the given subtree.
  void _cleanupScoreAttributes(DomElement root) {
    final stack = <DomElement>[root];
    while (stack.isNotEmpty) {
      final elem = stack.removeLast();
      // Remove all _readability- attributes
      for (final attr in elem.attributes.toList()) {
        if (attr.name.startsWith('_readability-')) {
          elem.removeAttribute(attr.name);
        }
      }
      // Process children
      stack.addAll(elem.children);
    }
  }

  /// Check if this node is or contains a single image.
  /// Returns true if the node is an IMG, or if it has exactly one element child
  /// (with no non-whitespace text) and that child is or contains a single image.
  bool _isSingleImage(DomElement node) {
    DomElement? current = node;
    while (current != null) {
      if (current.tagName == 'IMG') {
        return true;
      }
      if (current.children.length != 1 ||
          (current.textContent ?? '').trim().isNotEmpty) {
        return false;
      }
      current = current.children.isNotEmpty ? current.children[0] : null;
    }
    return false;
  }

  /// Find all <noscript> that are located after <img> nodes, and which contain
  /// only one <img> element. Replace the first image with the image from inside
  /// the <noscript> tag, and remove the <noscript> tag. This improves the
  /// quality of the images we use on some sites (e.g. Medium).
  void _unwrapNoscriptImages(DomDocument doc) {
    // Find img without source or attributes that might contain image, and remove it.
    // This is done to prevent a placeholder img being replaced by img from noscript in next step.
    final imgs = List<DomElement>.from(doc.getElementsByTagName('img'));
    for (final img in imgs) {
      var hasImageAttr = false;
      for (final attr in img.attributes) {
        switch (attr.name) {
          case 'src':
          case 'srcset':
          case 'data-src':
          case 'data-srcset':
            hasImageAttr = true;
            break;
        }
        if (hasImageAttr) break;
        if (RegExp(r'\.(jpg|jpeg|png|webp)', caseSensitive: false)
            .hasMatch(attr.value)) {
          hasImageAttr = true;
          break;
        }
      }
      if (!hasImageAttr) {
        img.remove();
      }
    }

    // Next find noscript and try to extract its image
    final noscripts =
        List<DomElement>.from(doc.getElementsByTagName('noscript'));
    for (final noscript in noscripts) {
      // Parse content of noscript and make sure it only contains image
      if (!_isSingleImage(noscript)) {
        continue;
      }

      // Create a temp element and parse the noscript content into it
      final tmp = _doc.createElement('div')..innerHTML = noscript.innerHTML;

      // If noscript has previous sibling and it only contains image,
      // replace it with noscript content. However we also keep old
      // attributes that might contain image.
      final prevElement = noscript.previousElementSibling;
      if (prevElement != null && _isSingleImage(prevElement)) {
        var prevImg = prevElement;
        if (prevImg.tagName != 'IMG') {
          final imgs = prevImg.getElementsByTagName('img');
          if (imgs.isNotEmpty) {
            prevImg = imgs[0];
          }
        }

        final newImgs = tmp.getElementsByTagName('img');
        if (newImgs.isEmpty) continue;
        final newImg = newImgs[0];

        for (final attr in prevImg.attributes) {
          if (attr.value.isEmpty) {
            continue;
          }
          if (attr.name == 'src' ||
              attr.name == 'srcset' ||
              RegExp(r'\.(jpg|jpeg|png|webp)', caseSensitive: false)
                  .hasMatch(attr.value)) {
            if (newImg.getAttribute(attr.name) == attr.value) {
              continue;
            }
            var attrName = attr.name;
            if (newImg.hasAttribute(attrName)) {
              attrName = 'data-old-$attrName';
            }
            newImg.setAttribute(attrName, attr.value);
          }
        }

        final firstChild = tmp.firstElementChild;
        if (firstChild != null) {
          noscript.parentNode?.replaceChild(firstChild, prevElement);
        }
      }
    }
  }

  /// Remove script and noscript tags from the document.
  void _removeScripts(DomDocument doc) {
    _removeNodes(
        _getAllNodesWithTag(doc, ['script', 'noscript']).cast<DomNode>());
  }

  /// Remove nodes matching filter function.
  void _removeNodes(List<DomNode> nodeList,
      [bool Function(DomNode, int, List<DomNode>)? filterFn]) {
    final entries = nodeList.toList().asMap().entries.toList();
    for (final entry in entries.reversed) {
      final i = entry.key;
      final node = entry.value;
      final parentNode = node.parentNode;
      if (parentNode != null) {
        if (filterFn == null || filterFn(node, i, nodeList)) {
          parentNode.removeChild(node);
        }
      }
    }
  }

  /// Replace node tags.
  void _replaceNodeTags(List<DomElement> nodeList, String newTagName) {
    for (final node in nodeList) {
      _setNodeTag(node, newTagName);
    }
  }

  /// Check if any node matches predicate.
  bool _someNode<T extends DomNode>(List<T> nodeList, bool Function(T) fn) {
    return nodeList.any(fn);
  }

  /// Check if all nodes match predicate.
  bool _everyNode<T extends DomNode>(List<T> nodeList, bool Function(T) fn) {
    return nodeList.every(fn);
  }

  /// Get all nodes with specified tag names.
  List<DomElement> _getAllNodesWithTag(DomNode node, List<String> tagNames) {
    if (node is DomElement) {
      return tagNames.expand((tag) => node.getElementsByTagName(tag)).toList();
    } else if (node is DomDocument) {
      return tagNames.expand((tag) => node.getElementsByTagName(tag)).toList();
    }
    return [];
  }

  /// Clean class attributes from elements.
  void _cleanClasses(DomElement node) {
    final className = (node.getAttribute('class') ?? '')
        .split(RegExp(r'\s+'))
        .where((cls) => _classesToPreserve.contains(cls))
        .join(' ');

    if (className.isNotEmpty) {
      node.setAttribute('class', className);
    } else {
      node.removeAttribute('class');
    }

    for (var child = node.firstElementChild;
        child != null;
        child = child.nextElementSibling) {
      _cleanClasses(child);
    }
  }

  /// Check if string is a valid URL.
  bool _isUrl(String str) {
    try {
      Uri.parse(str);
      return str.startsWith('http://') ||
          str.startsWith('https://') ||
          str.startsWith('//');
    } catch (_) {
      return false;
    }
  }

  /// Fix relative URIs to absolute.
  void _fixRelativeUris(DomElement articleContent) {
    final baseURI = _doc.baseURI;
    final documentURI = _doc.documentURI ?? '';

    String toAbsoluteURI(String uri) {
      // JS URL() strips leading/trailing C0 control chars and spaces
      uri = uri.trim();
      if (baseURI == documentURI && uri.startsWith('#')) {
        return uri;
      }
      // Leave non-http(s) absolute URIs (data:, mailto:, blob:, tel:, etc.)
      // unchanged. Check if the URI starts with a valid scheme followed by ":".
      final colonIndex = uri.indexOf(':');
      if (colonIndex > 0) {
        final possibleScheme = uri.substring(0, colonIndex);
        if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+\-.]*$').hasMatch(possibleScheme) &&
            possibleScheme != 'http' &&
            possibleScheme != 'https') {
          // Normalize file:///C|/ to file:///C:/ to match JS URL() behavior
          if (possibleScheme == 'file') {
            uri = uri.replaceFirstMapped(
              RegExp(r'^file:///([a-zA-Z])\|'),
              (m) => 'file:///${m.group(1)!}:',
            );
          }
          return uri;
        }
      }
      // If the URI is already absolute http(s), normalize minimally
      // to match JS URL behavior:
      // - lowercase the hostname
      // - add trailing slash for host-only URLs
      // but preserve percent-encoding (Dart Uri normalizes %7E -> ~ etc.)
      if (uri.startsWith('http://') || uri.startsWith('https://')) {
        try {
          final parsed = Uri.parse(uri);
          if (parsed.host.isNotEmpty) {
            final lowerHost = parsed.host.toLowerCase();
            // Reconstruct with lowercase host, preserving everything else
            final scheme = parsed.scheme;
            final userInfo =
                parsed.userInfo.isNotEmpty ? '${parsed.userInfo}@' : '';
            final port = parsed.hasPort ? ':${parsed.port}' : '';
            final authority = '$userInfo$lowerHost$port';
            final schemeAndAuth = '$scheme://$authority';
            // Find where the path starts in the original URI
            final origSchemeAndAuth = '$scheme://${parsed.authority}';
            var rest = uri.substring(origSchemeAndAuth.length);
            if (parsed.path.isEmpty && rest.isEmpty) {
              rest = '/';
            } else if (parsed.path.isEmpty && rest.startsWith('?')) {
              rest = '/$rest';
            } else if (parsed.path.isEmpty && rest.startsWith('#')) {
              rest = '/$rest';
            }
            return '$schemeAndAuth$rest';
          }
        } catch (_) {
          // If parsing fails, return as-is
        }
        return uri;
      }
      try {
        final base = Uri.parse(baseURI);
        final resolved = base.resolve(uri);
        // Normalize to match JS URL behavior: add trailing slash when
        // host is present but path is empty (e.g. https://example.com
        // becomes https://example.com/)
        var result = resolved.toString();
        if (resolved.host.isNotEmpty && resolved.path.isEmpty) {
          // Insert / before any query or fragment
          final authority = resolved.authority;
          final scheme = resolved.scheme;
          final afterAuthority =
              result.substring('$scheme://$authority'.length);
          result = '$scheme://$authority/$afterAuthority';
        }
        return result;
      } catch (_) {
        // If resolve() fails (e.g. URI has invalid scheme-like prefix),
        // try resolving as a relative path reference
        try {
          final base = Uri.parse(baseURI);
          return base.resolveUri(Uri(path: uri)).toString();
        } catch (_) {
          return uri;
        }
      }
    }

    final links = _getAllNodesWithTag(articleContent, ['a']);
    for (final link in links) {
      final href = link.getAttribute('href');
      if (href != null) {
        if (href.startsWith('javascript:')) {
          if (link.childNodes.length == 1 &&
              link.childNodes[0].nodeType == NodeType.text) {
            final text = _doc.createTextNode(link.textContent ?? '');
            link.parentNode?.replaceChild(text, link);
          } else {
            final container = _doc.createElement('span');
            while (link.firstChild != null) {
              container.appendChild(link.firstChild!);
            }
            link.parentNode?.replaceChild(container, link);
          }
        } else {
          link.setAttribute('href', toAbsoluteURI(href));
        }
      }
    }

    final medias = _getAllNodesWithTag(articleContent,
        ['img', 'picture', 'figure', 'video', 'audio', 'source']);
    for (final media in medias) {
      final src = media.getAttribute('src');
      final poster = media.getAttribute('poster');
      final srcset = media.getAttribute('srcset');

      if (src != null) {
        media.setAttribute('src', toAbsoluteURI(src));
      }
      if (poster != null) {
        media.setAttribute('poster', toAbsoluteURI(poster));
      }
      if (srcset != null) {
        final newSrcset = srcset.replaceAllMapped(_srcsetUrl, (m) {
          return toAbsoluteURI(m.group(1)!) + (m.group(2) ?? '') + m.group(3)!;
        });
        media.setAttribute('srcset', newSrcset);
      }
    }
  }

  /// Simplify nested elements.
  void _simplifyNestedElements(DomElement articleContent) {
    DomNode? node = articleContent;

    while (node != null) {
      if (node.parentNode != null &&
          node is DomElement &&
          ['DIV', 'SECTION'].contains(node.tagName) &&
          !node.id.startsWith('readability')) {
        if (_isElementWithoutContent(node)) {
          node = _removeAndGetNext(node);
          continue;
        } else if (_hasSingleTagInsideElement(node, 'DIV') ||
            _hasSingleTagInsideElement(node, 'SECTION')) {
          final child = node.children.first;
          for (final attr in node.attributes) {
            child.setAttribute(attr.name, attr.value);
          }
          node.parentNode!.replaceChild(child, node);
          node = child;
          continue;
        }
      }
      node = _getNextNode(node as DomElement?);
    }
  }

  /// Get article title.
  String _getArticleTitle() {
    var curTitle = '';
    var origTitle = '';

    try {
      curTitle = origTitle = (_doc.title ?? '').trim();
      if (curTitle.isEmpty) {
        final titleElements = _doc.getElementsByTagName('title');
        if (titleElements.isNotEmpty) {
          curTitle = origTitle = _getInnerText(titleElements.first);
        }
      }
    } catch (_) {}

    var titleHadHierarchicalSeparators = false;

    int wordCount(String str) => str.split(RegExp(r'\s+')).length;

    const titleSeparators = r'\|\-–—\\/>»';
    if (RegExp('\\s[$titleSeparators]\\s').hasMatch(curTitle)) {
      titleHadHierarchicalSeparators =
          RegExp(r'\s[\\/\>»]\s').hasMatch(curTitle);
      final allSeparators =
          RegExp('\\s[$titleSeparators]\\s', caseSensitive: false)
              .allMatches(origTitle)
              .toList();
      if (allSeparators.isNotEmpty) {
        curTitle = origTitle.substring(0, allSeparators.last.start);
      }

      if (wordCount(curTitle) < 3) {
        curTitle = origTitle.replaceFirst(
            RegExp('^[^$titleSeparators]*[$titleSeparators]',
                caseSensitive: false),
            '');
      }
    } else if (curTitle.contains(': ')) {
      final headings = _getAllNodesWithTag(_doc, ['h1', 'h2']);
      final trimmedTitle = curTitle.trim();
      final match = _someNode(
          headings, (h) => (h.textContent ?? '').trim() == trimmedTitle);

      if (!match) {
        curTitle = origTitle.substring(origTitle.lastIndexOf(':') + 1);

        if (wordCount(curTitle) < 3) {
          curTitle = origTitle.substring(origTitle.indexOf(':') + 1);
        } else if (wordCount(origTitle.substring(0, origTitle.indexOf(':'))) >
            5) {
          curTitle = origTitle;
        }
      }
    } else if (curTitle.length > 150 || curTitle.length < 15) {
      final hOnes = _doc.getElementsByTagName('h1');
      if (hOnes.length == 1) {
        curTitle = _getInnerText(hOnes.first);
      }
    }

    curTitle = curTitle.trim().replaceAll(_normalize, ' ');

    final curTitleWordCount = wordCount(curTitle);
    if (curTitleWordCount <= 4 &&
        (!titleHadHierarchicalSeparators ||
            curTitleWordCount !=
                wordCount(origTitle.replaceAll(
                        RegExp('\\s[$titleSeparators]\\s'), '')) -
                    1)) {
      curTitle = origTitle;
    }

    return curTitle;
  }

  /// Prepare document for parsing.
  void _prepDocument() {
    _removeNodes(_getAllNodesWithTag(_doc, ['style']).cast<DomNode>());

    if (_doc.body != null) {
      _replaceBrs(_doc.body!);
    }

    _replaceNodeTags(_getAllNodesWithTag(_doc, ['font']), 'SPAN');
  }

  /// Find next element node.
  DomNode? _nextNode(DomNode? node) {
    var next = node;
    while (next != null &&
        next.nodeType != NodeType.element &&
        _whitespace.hasMatch(next.textContent ?? '')) {
      next = next.nextSibling;
    }
    return next;
  }

  /// Replace consecutive BRs with paragraphs.
  void _replaceBrs(DomElement elem) {
    final brs = _getAllNodesWithTag(elem, ['br']);
    for (final br in brs) {
      var next = br.nextSibling;
      var replaced = false;

      while ((next = _nextNode(next)) != null &&
          next is DomElement &&
          next.tagName == 'BR') {
        replaced = true;
        final brSibling = next.nextSibling;
        next.remove();
        next = brSibling;
      }

      if (replaced) {
        final p = _doc.createElement('p');
        br.parentNode?.replaceChild(p, br);

        next = p.nextSibling;
        while (next != null) {
          if (next is DomElement && next.tagName == 'BR') {
            final nextElem = _nextNode(next.nextSibling);
            if (nextElem is DomElement && nextElem.tagName == 'BR') {
              break;
            }
          }

          if (!_isPhrasingContent(next)) {
            break;
          }

          final sibling = next.nextSibling;
          p.appendChild(next);
          next = sibling;
        }

        while (p.lastChild != null && _isWhitespace(p.lastChild!)) {
          p.lastChild!.remove();
        }

        final pParent = _parentElement(p);
        if (pParent != null && pParent.tagName == 'P') {
          _setNodeTag(pParent, 'DIV');
        }
      }
    }
  }

  /// Change element tag name.
  DomElement _setNodeTag(DomElement node, String tag) {
    _log(['_setNodeTag', node.tagName, tag]);

    if (_docJSDOMParser && _legacyDoc != null) {
      // For JSDOMParser, unwrap and mutate the raw element directly
      if (node case JsdomDomElement jsdomNode) {
        final rawElement = jsdomNode.unwrap as Element;
        rawElement.localName = tag.toLowerCase();
        rawElement.tagName = tag.toUpperCase();
        return node;
      }
    }

    final replacement = _doc.createElement(tag);
    while (node.firstChild != null) {
      replacement.appendChild(node.firstChild!);
    }
    node.parentNode?.replaceChild(replacement, node);

    // Copy attributes first (excluding internal readability attributes)
    for (final attr in node.attributes) {
      if (!attr.name.startsWith('_readability-')) {
        replacement.setAttribute(attr.name, attr.value);
      }
    }

    // Then set readability score (which will create new score attributes)
    if (_hasReadability(node)) {
      _setReadability(replacement, _getReadability(node));
    }

    return replacement;
  }

  /// Prepare article content for display.
  void _prepArticle(DomElement articleContent) {
    _cleanStyles(articleContent);
    _markDataTables(articleContent);
    _fixLazyImages(articleContent);

    _cleanConditionally(articleContent, 'form');
    _cleanConditionally(articleContent, 'fieldset');
    _clean(articleContent, 'object');
    _clean(articleContent, 'embed');
    _clean(articleContent, 'footer');
    _clean(articleContent, 'link');
    _clean(articleContent, 'aside');

    final shareElementThreshold = defaultCharThreshold;
    for (final topCandidate in articleContent.children) {
      _cleanMatchedNodes(topCandidate, (node, matchString) {
        return _shareElements.hasMatch(matchString) &&
            (node.textContent ?? '').length < shareElementThreshold;
      });
    }

    _clean(articleContent, 'iframe');
    _clean(articleContent, 'input');
    _clean(articleContent, 'textarea');
    _clean(articleContent, 'select');
    _clean(articleContent, 'button');
    _cleanHeaders(articleContent);

    _cleanConditionally(articleContent, 'table');
    _cleanConditionally(articleContent, 'ul');
    _cleanConditionally(articleContent, 'div');

    _replaceNodeTags(_getAllNodesWithTag(articleContent, ['h1']), 'h2');

    _removeNodes(
      _getAllNodesWithTag(articleContent, ['p']).cast<DomNode>(),
      (p, _, __) {
        final contentElementCount = _getAllNodesWithTag(
            p as DomElement, ['img', 'embed', 'object', 'iframe']).length;
        return contentElementCount == 0 && _getInnerText(p, false).isEmpty;
      },
    );

    for (final br in _getAllNodesWithTag(articleContent, ['br'])) {
      final next = _nextNode(br.nextSibling);
      if (next is DomElement && next.tagName == 'P') {
        br.remove();
      }
    }

    for (final table in _getAllNodesWithTag(articleContent, ['table'])) {
      final tbody = _hasSingleTagInsideElement(table, 'TBODY')
          ? table.firstElementChild!
          : table;
      if (_hasSingleTagInsideElement(tbody, 'TR')) {
        final row = tbody.firstElementChild!;
        if (_hasSingleTagInsideElement(row, 'TD')) {
          var cell = row.firstElementChild!;
          cell = _setNodeTag(
            cell,
            _everyNode(cell.childNodes, _isPhrasingContent) ? 'P' : 'DIV',
          );
          table.parentNode?.replaceChild(cell, table);
        }
      }
    }
  }

  /// Initialize readability score for a node.
  void _initializeNode(DomElement node) {
    _readabilityScores.put(node, 0);

    switch (node.tagName) {
      case 'DIV':
        _getReadability(node).contentScore += 5;
        break;
      case 'PRE':
      case 'TD':
      case 'BLOCKQUOTE':
        _getReadability(node).contentScore += 3;
        break;
      case 'ADDRESS':
      case 'OL':
      case 'UL':
      case 'DL':
      case 'DD':
      case 'DT':
      case 'LI':
      case 'FORM':
        _getReadability(node).contentScore -= 3;
        break;
      case 'H1':
      case 'H2':
      case 'H3':
      case 'H4':
      case 'H5':
      case 'H6':
      case 'TH':
        _getReadability(node).contentScore -= 5;
        break;
    }

    _getReadability(node).contentScore += _getClassWeight(node);
  }

  /// Remove node and return next node.
  DomNode? _removeAndGetNext(DomNode node) {
    final nextNode = _getNextNode(node as DomElement?, true);
    node.remove();
    return nextNode;
  }

  /// Traverse DOM depth-first.
  DomElement? _getNextNode(DomElement? node, [bool ignoreSelfAndKids = false]) {
    if (node == null) return null;

    if (!ignoreSelfAndKids && node.firstElementChild != null) {
      return node.firstElementChild;
    }

    if (node.nextElementSibling != null) {
      return node.nextElementSibling;
    }

    DomElement? current = node;
    while (current != null && current.nextElementSibling == null) {
      final parent = current.parentNode;
      if (parent is DomElement) {
        current = parent;
      } else {
        // Parent is DomDocument or null, stop traversing up
        current = null;
      }
    }

    return current?.nextElementSibling;
  }

  /// Calculate text similarity between two strings.
  double _textSimilarity(String textA, String textB) {
    final tokensA = textA
        .toLowerCase()
        .split(_tokenize)
        .where((t) => t.isNotEmpty)
        .toList();
    final tokensB = textB
        .toLowerCase()
        .split(_tokenize)
        .where((t) => t.isNotEmpty)
        .toList();

    if (tokensA.isEmpty || tokensB.isEmpty) {
      return 0;
    }

    final uniqTokensB = tokensB.where((t) => !tokensA.contains(t)).toList();
    final distanceB = uniqTokensB.join(' ').length / tokensB.join(' ').length;
    return 1 - distanceB;
  }

  /// Check if element is a valid byline.
  bool _checkByline(DomElement node, String matchString) {
    if (_articleByline != null) {
      return false;
    }

    final rel = node.getAttribute('rel');
    final itemprop = node.getAttribute('itemprop');
    final bylineLength = (node.textContent ?? '').trim().length;

    if ((rel == 'author' ||
            (itemprop != null && itemprop.contains('author')) ||
            _byline.hasMatch(matchString)) &&
        bylineLength > 0 &&
        bylineLength < 100) {
      // Find child node matching [itemprop="name"] for more accurate byline
      final endOfSearchMarker = _getNextNode(node, true);
      var next = _getNextNode(node);
      DomElement? itemPropNameNode;

      while (next != null && next != endOfSearchMarker) {
        final nextItemprop = next.getAttribute('itemprop');
        if (nextItemprop != null && nextItemprop.contains('name')) {
          itemPropNameNode = next;
          break;
        }
        next = _getNextNode(next);
      }

      _articleByline = ((itemPropNameNode ?? node).textContent ?? '').trim();
      return true;
    }

    return false;
  }

  /// Get inner text of element.
  String _getInnerText(DomElement e, [bool normalizeSpaces = true]) {
    final textContent = (e.textContent ?? '').trim();
    if (normalizeSpaces) {
      return textContent.replaceAll(_normalize, ' ');
    }
    return textContent;
  }

  /// Get character count (commas as proxy).
  int _getCharCount(DomElement e, [String separator = ',']) {
    return _getInnerText(e).split(separator).length - 1;
  }

  /// Clean inline styles from elements.
  void _cleanStyles(DomElement e) {
    if (e.tagName == 'SVG') {
      return;
    }

    for (final attr in presentationalAttributes) {
      e.removeAttribute(attr);
    }

    if (deprecatedSizeAttributeElems.contains(e.tagName)) {
      e.removeAttribute('width');
      e.removeAttribute('height');
    }

    for (var child = e.firstElementChild;
        child != null;
        child = child.nextElementSibling) {
      _cleanStyles(child);
    }
  }

  /// Calculate link density for element.
  double _getLinkDensity(DomElement element) {
    final textLength = _getInnerText(element).length;
    if (textLength == 0) {
      return 0;
    }

    var linkLength = 0.0;
    for (final link in _getAllNodesWithTag(element, ['a'])) {
      final href = link.getAttribute('href');
      final coefficient = (href != null && _hashUrl.hasMatch(href)) ? 0.3 : 1.0;
      linkLength += _getInnerText(link).length * coefficient;
    }

    return linkLength / textLength;
  }

  /// Get class weight for scoring.
  double _getClassWeight(DomElement e) {
    if ((_flags & flagWeightClasses) == 0) {
      return 0;
    }

    var weight = 0.0;
    final className = e.className;
    final id = e.id;

    if (className.isNotEmpty) {
      if (_negative.hasMatch(className)) {
        weight -= 25;
      }
      if (_positive.hasMatch(className)) {
        weight += 25;
      }
    }

    if (id.isNotEmpty) {
      if (_negative.hasMatch(id)) {
        weight -= 25;
      }
      if (_positive.hasMatch(id)) {
        weight += 25;
      }
    }

    return weight;
  }

  /// Clean elements matching tag name.
  void _clean(DomElement e, String tag) {
    final isEmbed = ['object', 'embed', 'iframe'].contains(tag);

    _removeNodes(
      _getAllNodesWithTag(e, [tag]).cast<DomNode>(),
      (element, _, __) {
        if (isEmbed) {
          if ((element as DomElement)
              .attributes
              .any((attr) => _allowedVideoRegex.hasMatch(attr.value))) {
            return false;
          }

          if (element.tagName == 'OBJECT' &&
              _allowedVideoRegex.hasMatch(element.innerHTML)) {
            return false;
          }
        }
        return true;
      },
    );
  }

  /// Check if element has single child with specified tag.
  bool _hasSingleTagInsideElement(DomElement element, String tag) {
    if (element.children.length != 1 || element.children.first.tagName != tag) {
      return false;
    }

    return !_someNode(
      element.childNodes,
      (node) =>
          node.nodeType == NodeType.text &&
          _hasContent.hasMatch(node.textContent ?? ''),
    );
  }

  /// Check if element is without content.
  bool _isElementWithoutContent(DomElement node) {
    return node.nodeType == NodeType.element &&
        (node.textContent ?? '').trim().isEmpty &&
        (node.children.isEmpty ||
            node.children.length ==
                _getAllNodesWithTag(node, ['br', 'hr']).length);
  }

  /// Check if node has ancestor with specified tag.
  bool _hasAncestorTag(
    DomElement node,
    String tagName, [
    int maxDepth = 3,
    bool Function(DomElement)? filterFn,
  ]) {
    var depth = 0;
    DomNode? current = node;

    while (current?.parentNode != null) {
      if (maxDepth > 0 && depth > maxDepth) {
        return false;
      }

      final parent = current!.parentNode;
      if (parent is DomElement &&
          parent.tagName == tagName &&
          (filterFn == null || filterFn(parent))) {
        return true;
      }

      depth++;
      current = parent;
    }

    return false;
  }

  /// Get table row and column count.
  Map<String, int> _getRowAndCellCount(DomElement table) {
    var rows = 0;
    var columns = 0;

    for (final tr in _getAllNodesWithTag(table, ['tr'])) {
      final rowspan = int.tryParse(tr.getAttribute('rowspan') ?? '1') ?? 1;
      rows += rowspan;

      var columnsInThisRow = 0;
      for (final cell in _getAllNodesWithTag(tr, ['td'])) {
        final colspan = int.tryParse(cell.getAttribute('colspan') ?? '1') ?? 1;
        columnsInThisRow += colspan;
      }

      columns = columnsInThisRow > columns ? columnsInThisRow : columns;
    }

    return {'rows': rows, 'columns': columns};
  }

  /// Mark data tables.
  void _markDataTables(DomElement root) {
    for (final table in _getAllNodesWithTag(root, ['table'])) {
      final role = table.getAttribute('role');
      if (role == 'presentation') {
        table.setAttribute('_readabilityDataTable', 'false');
        continue;
      }

      final datatable = table.getAttribute('datatable');
      if (datatable == '0') {
        table.setAttribute('_readabilityDataTable', 'false');
        continue;
      }

      if (table.getAttribute('summary') != null) {
        table.setAttribute('_readabilityDataTable', 'true');
        continue;
      }

      final caption = _getAllNodesWithTag(table, ['caption']);
      if (caption.isNotEmpty && caption.first.childNodes.isNotEmpty) {
        table.setAttribute('_readabilityDataTable', 'true');
        continue;
      }

      final dataTableDescendants = ['col', 'colgroup', 'tfoot', 'thead', 'th'];
      bool hasDescendant(String tag) =>
          _getAllNodesWithTag(table, [tag]).isNotEmpty;

      if (dataTableDescendants.any(hasDescendant)) {
        _log(['Data table because of descendant']);
        table.setAttribute('_readabilityDataTable', 'true');
        continue;
      }

      if (_getAllNodesWithTag(table, ['table']).isNotEmpty) {
        table.setAttribute('_readabilityDataTable', 'false');
        continue;
      }

      final size = _getRowAndCellCount(table);

      if (size['columns']! == 1 || size['rows']! == 1) {
        table.setAttribute('_readabilityDataTable', 'false');
        continue;
      }

      if (size['rows']! >= 10 || size['columns']! > 4) {
        table.setAttribute('_readabilityDataTable', 'true');
        continue;
      }

      if (size['rows']! * size['columns']! > 10) {
        table.setAttribute('_readabilityDataTable', 'true');
      }
    }
  }

  static final RegExp _lazyImageSrcPattern =
      RegExp(r'\.(jpg|jpeg|png|webp)', caseSensitive: false);
  static final RegExp _lazySrcsetPattern =
      RegExp(r'\.(jpg|jpeg|png|webp)\s+\d', caseSensitive: false);
  static final RegExp _lazySrcPattern =
      RegExp(r'^\s*\S+\.(jpg|jpeg|png|webp)\S*\s*$', caseSensitive: false);

  /// Fix lazy-loaded images.
  void _fixLazyImages(DomElement root) {
    for (final elem
        in _getAllNodesWithTag(root, ['img', 'picture', 'figure'])) {
      // In some sites, they put 1px square image as base64 data uri in the src attribute.
      // So, here we check if the data uri is too short, just might as well remove it.
      final src = elem.getAttribute('src');
      if (src != null && _b64DataUrl.hasMatch(src)) {
        final parts = _b64DataUrl.firstMatch(src);
        if (parts != null && parts.group(1) == 'image/svg+xml') {
          continue;
        }

        // Make sure this element has other attributes which contain image.
        var srcCouldBeRemoved = false;
        for (final attr in elem.attributes) {
          if (attr.name == 'src') continue;
          if (_lazyImageSrcPattern.hasMatch(attr.value)) {
            srcCouldBeRemoved = true;
            break;
          }
        }

        // If image is less than 100 bytes (or 133 after encoded to base64)
        // it will be too small, therefore it might be placeholder image.
        if (srcCouldBeRemoved && parts != null) {
          final b64starts = parts.group(0)!.length;
          final b64length = src.length - b64starts;
          if (b64length < 133) {
            elem.removeAttribute('src');
          }
        }
      }

      // If element already has src or srcset and is not lazy, skip it
      final currentSrc = elem.getAttribute('src');
      final currentSrcset = elem.getAttribute('srcset');
      if ((currentSrc != null ||
              (currentSrcset != null && currentSrcset != 'null')) &&
          !(elem.className.toLowerCase().contains('lazy'))) {
        continue;
      }

      for (final attr in List.from(elem.attributes)) {
        if (attr.name == 'src' || attr.name == 'srcset' || attr.name == 'alt') {
          continue;
        }

        String? copyTo;
        if (_lazySrcsetPattern.hasMatch(attr.value)) {
          copyTo = 'srcset';
        } else if (_lazySrcPattern.hasMatch(attr.value)) {
          copyTo = 'src';
        }

        if (copyTo != null) {
          if (elem.tagName == 'IMG' || elem.tagName == 'PICTURE') {
            elem.setAttribute(copyTo, attr.value);
          } else if (elem.tagName == 'FIGURE' &&
              _getAllNodesWithTag(elem, ['img', 'picture']).isEmpty) {
            final img = _doc.createElement('img');
            img.setAttribute(copyTo, attr.value);
            elem.appendChild(img);
          }
        }
      }
    }
  }

  /// Get node ancestors.
  List<DomElement> _getNodeAncestors(DomElement node, [int maxDepth = 0]) {
    var i = 0;
    final ancestors = <DomElement>[];
    DomNode? current = node.parentNode;

    while (current != null) {
      if (current is DomElement) {
        ancestors.add(current);
        if (maxDepth > 0 && ++i == maxDepth) {
          break;
        }
      }
      current = current.parentNode;
    }

    return ancestors;
  }

  /// Clean headers from article.
  void _cleanHeaders(DomElement e) {
    final headingTags = ['h1', 'h2'];
    _removeNodes(
      _getAllNodesWithTag(e, headingTags).cast<DomNode>(),
      (header, _, __) => _getClassWeight(header as DomElement) < 0,
    );
  }

  /// Check if header duplicates title.
  bool _headerDuplicatesTitle(DomElement node) {
    if (node.tagName != 'H1' && node.tagName != 'H2') {
      return false;
    }

    final heading = _getInnerText(node, false);
    _log(['Evaluating header for title duplication: $heading']);
    return _textSimilarity(_articleTitle ?? '', heading) > 0.75;
  }

  /// Clean conditionally based on content quality.
  void _cleanConditionally(DomElement e, String tag) {
    if ((_flags & flagCleanConditionally) == 0) {
      return;
    }

    _removeNodes(
      _getAllNodesWithTag(e, [tag]).cast<DomNode>(),
      (node, _, __) {
        final element = node as DomElement;

        // First check if this node IS data table, in which case don't remove it.
        bool isDataTable(ancestor) =>
            ancestor is DomElement &&
            ancestor.getAttribute('_readabilityDataTable') == 'true';

        var isList = tag == 'ul' || tag == 'ol';
        if (!isList) {
          var listLength = 0;
          final listNodes = _getAllNodesWithTag(element, ['ul', 'ol']);
          for (final list in listNodes) {
            listLength += _getInnerText(list).length;
          }
          final innerTextLength = _getInnerText(element).length;
          isList = innerTextLength > 0 && listLength / innerTextLength > 0.9;
        }

        if (tag == 'table' && isDataTable(element)) {
          return false;
        }

        // Next check if we're inside a data table, in which case don't remove it as well.
        if (_hasAncestorTag(element, 'TABLE', -1, isDataTable)) {
          return false;
        }

        if (_hasAncestorTag(element, 'CODE')) {
          return false;
        }

        // Keep element if it has data tables.
        if (_getAllNodesWithTag(element, ['table']).any(
            (tbl) => tbl.getAttribute('_readabilityDataTable') == 'true')) {
          return false;
        }

        final weight = _getClassWeight(element);
        _log([
          'Cleaning conditionally ${element.tagName}#${element.id}.${element.className}'
        ]);

        var contentScore = 0;

        if (weight + contentScore < 0) {
          return true;
        }

        if (_getCharCount(element, ',') < 10) {
          final p = _getAllNodesWithTag(element, ['p']).length;
          final img = _getAllNodesWithTag(element, ['img']).length;
          final li = _getAllNodesWithTag(element, ['li']).length - 100;
          final input = _getAllNodesWithTag(element, ['input']).length;
          final headingDensity =
              _getTextDensity(element, ['h1', 'h2', 'h3', 'h4', 'h5', 'h6']);

          var embedCount = 0;
          for (final embed
              in _getAllNodesWithTag(element, ['object', 'embed', 'iframe'])) {
            for (final attr in embed.attributes) {
              if (_allowedVideoRegex.hasMatch(attr.value)) {
                return false;
              }
            }

            if (embed.tagName == 'OBJECT' &&
                _allowedVideoRegex.hasMatch(embed.innerHTML)) {
              return false;
            }

            embedCount++;
          }

          final innerText = _getInnerText(element);

          // Toss any node whose inner text contains nothing but suspicious words.
          if (_adWords.hasMatch(innerText) ||
              _loadingWords.hasMatch(innerText)) {
            return true;
          }

          final contentLength = innerText.length;
          final linkDensity = _getLinkDensity(element);
          final textishTags = ['SPAN', 'LI', 'TD', ...divToPElems];
          final textDensity = _getTextDensity(element, textishTags);
          final isFigureChild = _hasAncestorTag(element, 'FIGURE');

          bool shouldRemoveNode() {
            if (!isFigureChild && img > 1 && p / img < 0.5) {
              return true;
            }
            if (!isList && li > p) {
              return true;
            }
            if (input > (p / 3).floor()) {
              return true;
            }
            if (!isList &&
                !isFigureChild &&
                headingDensity < 0.9 &&
                contentLength < 25 &&
                (img == 0 || img > 2) &&
                linkDensity > 0) {
              return true;
            }
            if (!isList &&
                weight < 25 &&
                linkDensity > 0.2 + _linkDensityModifier) {
              return true;
            }
            if (weight >= 25 && linkDensity > 0.5 + _linkDensityModifier) {
              return true;
            }
            if ((embedCount == 1 && contentLength < 75) || embedCount > 1) {
              return true;
            }
            if (img == 0 && textDensity == 0) {
              return true;
            }
            return false;
          }

          var haveToRemove = shouldRemoveNode();

          // Allow simple lists of images to remain in pages
          if (isList && haveToRemove) {
            for (final child in element.children) {
              if (child.children.length > 1) {
                return haveToRemove;
              }
            }

            final liCount = _getAllNodesWithTag(element, ['li']).length;
            // Only allow the list to remain if every li contains an image
            if (img == liCount) {
              return false;
            }
          }

          return haveToRemove;
        }

        return false;
      },
    );
  }

  /// Calculate text density for specific tags.
  double _getTextDensity(DomElement e, List<String> tags) {
    final textLength = _getInnerText(e).length;
    if (textLength == 0) {
      return 0;
    }

    var childrenLength = 0;
    for (final child in _getAllNodesWithTag(e, tags)) {
      childrenLength += _getInnerText(child).length;
    }

    return childrenLength / textLength;
  }

  /// Clean matched nodes using predicate.
  void _cleanMatchedNodes(
      DomElement e, bool Function(DomElement, String) filter) {
    final endOfSearchMarker = _getNextNode(e, true);
    var next = _getNextNode(e);

    while (next != null && next != endOfSearchMarker) {
      if (filter(next, '${next.className} ${next.id}')) {
        next = _removeAndGetNext(next) as DomElement?;
      } else {
        next = _getNextNode(next);
      }
    }
  }

  /// Check if element is probably visible.
  bool _isProbablyVisible(DomElement node) {
    final style = node.getAttribute('style');
    final hasHidden = node.getAttribute('hidden') != null;
    final ariaHidden = node.getAttribute('aria-hidden') == 'true';
    final fallbackImage = node.className.contains('fallback-image');

    final isInvisibleStyle = style != null &&
        (style.contains('display:none') ||
            style.contains('display: none') ||
            style.contains('visibility:hidden') ||
            style.contains('visibility: hidden'));

    return !isInvisibleStyle && !hasHidden && (!ariaHidden || fallbackImage);
  }

  /// Check if node is whitespace.
  bool _isWhitespace(DomNode node) {
    return (node.nodeType == NodeType.text &&
            (node.textContent ?? '').trim().isEmpty) ||
        (node is DomElement && node.tagName == 'BR');
  }

  /// Check if node is phrasing content.
  bool _isPhrasingContent(DomNode node) {
    return node.nodeType == NodeType.text ||
        (node is DomElement && phrasingElems.contains(node.tagName)) ||
        (node is DomElement &&
            ['A', 'DEL', 'INS'].contains(node.tagName) &&
            _everyNode(node.childNodes, _isPhrasingContent));
  }

  /// Get article metadata from document.
  Map<String, dynamic> _getArticleMetadata(Map<String, dynamic>? jsonld) {
    final metadata = <String, dynamic>{};
    final values = <String, String>{};

    final metaElements = _doc.getElementsByTagName('meta');

    // property is a space-separated list of values
    final propertyPattern = RegExp(
      r'\s*(article|dc|dcterm|og|twitter)\s*:\s*(author|creator|description|published_time|title|site_name)\s*',
      caseSensitive: false,
    );

    // name is a single value
    final namePattern = RegExp(
      r'^\s*(?:(dc|dcterm|og|twitter|parsely|weibo:(article|webpage))\s*[-.:]\s*)?(author|creator|pub-date|description|title|site_name)\s*$',
      caseSensitive: false,
    );

    for (final element in metaElements) {
      final elementName = element.getAttribute('name');
      final elementProperty = element.getAttribute('property');
      final content = element.getAttribute('content');

      if (content == null || content.isEmpty) continue;

      RegExpMatch? matches;
      String? name;

      if (elementProperty != null) {
        matches = propertyPattern.firstMatch(elementProperty);
        if (matches != null) {
          // Convert to lowercase and remove whitespace so we can match below
          name = matches.group(0)!.toLowerCase().replaceAll(RegExp(r'\s'), '');
          values[name] = content.trim();
        }
      }

      if (matches == null &&
          elementName != null &&
          namePattern.hasMatch(elementName)) {
        name = elementName;
        // Convert to lowercase, remove whitespace, and convert dots to colons
        name = name
            .toLowerCase()
            .replaceAll(RegExp(r'\s'), '')
            .replaceAll('.', ':');
        values[name] = content.trim();
      }
    }

    // Get title with proper priority
    metadata['title'] = jsonld?['title'] ??
        values['dc:title'] ??
        values['dcterm:title'] ??
        values['og:title'] ??
        values['weibo:article:title'] ??
        values['weibo:webpage:title'] ??
        values['title'] ??
        values['twitter:title'] ??
        values['parsely-title'];

    if (metadata['title'] == null) {
      metadata['title'] = _getArticleTitle();
    }

    // Get byline with proper priority
    final articleAuthor = values['article:author'];
    final validArticleAuthor =
        articleAuthor != null && !_isUrl(articleAuthor) ? articleAuthor : null;

    metadata['byline'] = jsonld?['byline'] ??
        values['dc:creator'] ??
        values['dcterm:creator'] ??
        values['author'] ??
        values['parsely-author'] ??
        validArticleAuthor;

    // Get excerpt with proper priority
    metadata['excerpt'] = jsonld?['excerpt'] ??
        values['dc:description'] ??
        values['dcterm:description'] ??
        values['og:description'] ??
        values['weibo:article:description'] ??
        values['weibo:webpage:description'] ??
        values['description'] ??
        values['twitter:description'];

    // Get site name
    metadata['siteName'] = jsonld?['siteName'] ?? values['og:site_name'];

    // Get published time
    metadata['publishedTime'] = jsonld?['datePublished'] ??
        values['article:published_time'] ??
        values['parsely-pub-date'];

    // Unescape HTML entities in metadata
    metadata['title'] = _unescapeHtmlEntities(metadata['title'] as String?);
    metadata['byline'] = _unescapeHtmlEntities(metadata['byline'] as String?);
    metadata['excerpt'] = _unescapeHtmlEntities(metadata['excerpt'] as String?);
    metadata['siteName'] =
        _unescapeHtmlEntities(metadata['siteName'] as String?);
    metadata['publishedTime'] =
        _unescapeHtmlEntities(metadata['publishedTime'] as String?);

    return metadata;
  }

  /// Get JSON-LD metadata.
  Map<String, dynamic>? _getJSONLD() {
    final scripts = _doc.getElementsByTagName('script');
    final schemaDotOrgRegex = RegExp(r'^https?:\/\/schema\.org\/?$');

    for (final script in scripts) {
      if (script.getAttribute('type') != 'application/ld+json') {
        continue;
      }

      try {
        // Strip CDATA markers if present
        var content = (script.textContent ?? '').trim();
        content = content.replaceAll(RegExp(r'^\s*<!\[CDATA\[|\]\]>\s*$'), '');
        if (content.isEmpty) continue;

        var parsed = jsonDecode(content);

        // Handle top-level arrays
        if (parsed is List) {
          parsed = parsed.firstWhere(
            (it) =>
                it is Map &&
                it['@type'] != null &&
                _jsonLdArticleTypes.hasMatch(it['@type'].toString()),
            orElse: () => null,
          );
          if (parsed == null) continue;
        }

        if (parsed is! Map) {
          continue;
        }

        Map<String, dynamic>? data = parsed as Map<String, dynamic>;

        // Validate @context matches schema.org
        final context = data['@context'];
        bool matches = false;
        if (context is String) {
          matches = schemaDotOrgRegex.hasMatch(context);
        } else if (context is Map && context['@vocab'] is String) {
          matches = schemaDotOrgRegex.hasMatch(context['@vocab'] as String);
        }

        if (!matches) {
          continue;
        }

        // Handle @graph structure
        if (data['@type'] == null && data['@graph'] is List) {
          final graph = data['@graph'] as List;
          data = graph.firstWhere(
            (item) =>
                item is Map &&
                _jsonLdArticleTypes.hasMatch((item['@type'] ?? '').toString()),
            orElse: () => null,
          ) as Map<String, dynamic>?;
        }

        if (data == null) continue;

        final type = data['@type'];
        if (type == null || !_jsonLdArticleTypes.hasMatch(type.toString())) {
          continue;
        }

        final result = <String, dynamic>{};

        // Handle name vs headline - check which better matches the article title
        if (data['name'] is String &&
            data['headline'] is String &&
            data['name'] != data['headline']) {
          final title = _getArticleTitle();
          final nameMatches =
              _textSimilarity(data['name'] as String, title) > 0.75;
          final headlineMatches =
              _textSimilarity(data['headline'] as String, title) > 0.75;

          if (headlineMatches && !nameMatches) {
            result['title'] = (data['headline'] as String).trim();
          } else {
            result['title'] = (data['name'] as String).trim();
          }
        } else if (data['name'] is String) {
          result['title'] = (data['name'] as String).trim();
        } else if (data['headline'] is String) {
          result['title'] = (data['headline'] as String).trim();
        }

        if (data['author'] != null) {
          final author = data['author'];
          if (author is Map && author['name'] is String) {
            result['byline'] = (author['name'] as String).trim();
          } else if (author is List && author.isNotEmpty) {
            result['byline'] = author
                .where((a) => a is Map && a['name'] is String)
                .map((a) => (a['name'] as String).trim())
                .join(', ');
          }
        }

        if (data['description'] is String) {
          result['excerpt'] = (data['description'] as String).trim();
        }

        if (data['publisher'] is Map) {
          final publisher = data['publisher'] as Map;
          if (publisher['name'] is String) {
            result['siteName'] = (publisher['name'] as String).trim();
          }
        }

        if (data['datePublished'] is String) {
          result['datePublished'] = data['datePublished'];
        }

        return result;
      } catch (e) {
        _log(['Error parsing JSON-LD: $e']);
      }
    }

    return null;
  }

  /// Main article extraction method.
  DomElement? _grabArticle([DomElement? page]) {
    _log(['**** grabArticle ****']);

    final doc = _doc;

    page ??= doc.body;
    if (page == null) {
      _log(['No body found in document']);
      return null;
    }

    final pageCacheHtml = page.innerHTML;

    while (true) {
      _log(['Starting parse loop']);
      final stripUnlikelyCandidates = (_flags & flagStripUnlikelys) != 0;
      var shouldRemoveTitleHeader = true;

      final elementsToScore = <DomElement>[];

      // First pass: node prepping - remove cruddy nodes and turn divs into P tags
      DomNode? node = doc.documentElement;
      while (node != null) {
        if (node is! DomElement) {
          node = _getNextNode(node as DomElement?, true);
          continue;
        }

        final matchString = '${node.className} ${node.id}';

        // Check visibility - always done
        if (!_isProbablyVisible(node)) {
          _log(['Removing hidden node: $matchString']);
          node = _removeAndGetNext(node) as DomElement?;
          continue;
        }

        // Remove elements with aria-modal and role=dialog
        if (node.getAttribute('aria-modal') == 'true' &&
            node.getAttribute('role') == 'dialog') {
          node = _removeAndGetNext(node) as DomElement?;
          continue;
        }

        // Check byline - always done (not just when stripping unlikelys)
        final metadataByline = _metadata['byline'];
        final hasMetadataByline = metadataByline != null &&
            metadataByline is String &&
            metadataByline.isNotEmpty;
        if (_articleByline == null && !hasMetadataByline) {
          if (_checkByline(node, matchString)) {
            node = _removeAndGetNext(node) as DomElement?;
            continue;
          }
        }

        // Remove header if it duplicates the title - always done
        if (shouldRemoveTitleHeader && _headerDuplicatesTitle(node)) {
          _log([
            'Removing header: ${(node.textContent ?? '').trim()} $_articleTitle'
          ]);
          shouldRemoveTitleHeader = false;
          node = _removeAndGetNext(node) as DomElement?;
          continue;
        }

        // Only strip unlikely candidates when flag is set
        if (stripUnlikelyCandidates) {
          final role = node.getAttribute('role');

          if (unlikelyCandidates.hasMatch(matchString) &&
              !okMaybeItsACandidate.hasMatch(matchString) &&
              !_hasAncestorTag(node, 'TABLE') &&
              !_hasAncestorTag(node, 'CODE') &&
              node.tagName != 'BODY' &&
              node.tagName != 'A') {
            _log(['Removing unlikely candidate: $matchString']);
            node = _removeAndGetNext(node) as DomElement?;
            continue;
          }

          if (unlikelyRoles.contains(role)) {
            _log(['Removing node with unlikely role: $role']);
            node = _removeAndGetNext(node) as DomElement?;
            continue;
          }
        }

        // Remove DIV, SECTION, and HEADER nodes without any content
        // (e.g. text, image, video, or iframe).
        if (['DIV', 'SECTION', 'HEADER', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6']
                .contains(node.tagName) &&
            _isElementWithoutContent(node)) {
          node = _removeAndGetNext(node) as DomElement?;
          continue;
        }

        // Add elements to scoring list
        if (defaultTagsToScore.contains(node.tagName)) {
          elementsToScore.add(node);
        }

        // Turn all divs that don't have children block level elements into p's
        if (node.tagName == 'DIV') {
          // Put phrasing content into paragraphs.
          DomNode? childNode = node.firstChild;
          while (childNode != null) {
            var nextSibling = childNode.nextSibling;
            if (_isPhrasingContent(childNode)) {
              final fragment = _doc.createDocumentFragment();
              // Collect all consecutive phrasing content into a fragment.
              do {
                nextSibling = childNode!.nextSibling;
                fragment.appendChild(childNode);
                childNode = nextSibling;
              } while (childNode != null && _isPhrasingContent(childNode));

              // Trim leading and trailing whitespace from the fragment.
              while (fragment.firstChild != null &&
                  _isWhitespace(fragment.firstChild!)) {
                fragment.firstChild!.remove();
              }
              while (fragment.lastChild != null &&
                  _isWhitespace(fragment.lastChild!)) {
                fragment.lastChild!.remove();
              }

              // If the fragment contains anything, wrap it in a paragraph and
              // insert it before the next non-phrasing node.
              if (fragment.firstChild != null) {
                final p = _doc.createElement('p');
                p.appendChild(fragment);
                node.insertBefore(p, nextSibling);
              }
            }
            childNode = nextSibling;
          }

          if (_hasSingleTagInsideElement(node, 'P') &&
              _getLinkDensity(node) < 0.25) {
            final newNode = node.children.first;
            node.parentNode?.replaceChild(newNode, node);
            node = newNode;
            elementsToScore.add(node);
          } else if (!_hasChildBlockElement(node)) {
            node = _setNodeTag(node, 'P');
            elementsToScore.add(node);
          }
        }

        node = _getNextNode(node);
      }

      // Score candidates
      final candidates = <DomElement>[];

      for (final elementToScore in elementsToScore) {
        if (elementToScore.parentNode == null) {
          continue;
        }

        final innerText = _getInnerText(elementToScore);
        if (innerText.length < 25) {
          continue;
        }

        final ancestors = _getNodeAncestors(elementToScore, 5);
        if (ancestors.isEmpty) {
          continue;
        }

        var contentScore = 0.0;

        // Add points for paragraph
        contentScore += 1;

        // Add points for any commas within this paragraph.
        contentScore += innerText.split(_commas).length;

        // Add points for content length (max 3)
        contentScore += [((innerText.length / 100).floor()).toDouble(), 3.0]
            .reduce((a, b) => a < b ? a : b);

        // Score ancestors
        for (var level = 0; level < ancestors.length; level++) {
          final ancestor = ancestors[level];

          if (ancestor.parentNode == null ||
              ancestor.parentNode?.nodeName == null) {
            continue;
          }

          if (!_hasReadability(ancestor)) {
            _initializeNode(ancestor);
            candidates.add(ancestor);
          }

          double scoreDivider;
          if (level == 0) {
            scoreDivider = 1;
          } else if (level == 1) {
            scoreDivider = 2;
          } else {
            scoreDivider = level * 3.0;
          }

          _getReadability(ancestor).contentScore += contentScore / scoreDivider;
        }
      }

      // Find top candidate(s)
      final topCandidates = <DomElement>[];

      for (final candidate in candidates) {
        final candidateScore = _getReadability(candidate).contentScore *
            (1 - _getLinkDensity(candidate));
        _getReadability(candidate).contentScore = candidateScore;

        _log([
          'Candidate: ${candidate.tagName} (${candidate.className}) with score $candidateScore'
        ]);

        for (var t = 0; t < _numTopCandidates; t++) {
          final aTopCandidate =
              t < topCandidates.length ? topCandidates[t] : null;
          if (aTopCandidate == null ||
              candidateScore > _getReadability(aTopCandidate).contentScore) {
            topCandidates.insert(t, candidate);
            if (topCandidates.length > _numTopCandidates) {
              topCandidates.removeLast();
            }
            break;
          }
        }
      }

      var topCandidate = topCandidates.isNotEmpty ? topCandidates.first : null;
      var neededToCreateTopCandidate = false;

      // If no top candidate, create one from body
      if (topCandidate == null || topCandidate.tagName == 'BODY') {
        topCandidate = doc.createElement('DIV');
        neededToCreateTopCandidate = true;

        final body = page;
        while (body.firstChild != null) {
          _log(['Moving child out']);
          topCandidate.appendChild(body.firstChild!);
        }

        page.appendChild(topCandidate);
        _initializeNode(topCandidate);
      } else {
        // Check sibling content
        final alternativeCandidateAncestors = <List<DomElement>>[];

        for (final candidate in topCandidates.skip(1)) {
          if (_getReadability(candidate).contentScore /
                  _getReadability(topCandidate).contentScore >=
              0.75) {
            alternativeCandidateAncestors.add(_getNodeAncestors(candidate));
          }
        }

        const minTopCandidates = 3;
        if (alternativeCandidateAncestors.length >= minTopCandidates) {
          var parentOfTopCandidate = _parentElement(topCandidate);

          while (parentOfTopCandidate != null &&
              parentOfTopCandidate.tagName != 'BODY') {
            var listsContainingThisAncestor = 0;

            for (var i = 0;
                i < alternativeCandidateAncestors.length &&
                    listsContainingThisAncestor < minTopCandidates;
                i++) {
              if (alternativeCandidateAncestors[i]
                  .contains(parentOfTopCandidate)) {
                listsContainingThisAncestor++;
              }
            }

            if (listsContainingThisAncestor >= minTopCandidates) {
              topCandidate = parentOfTopCandidate;
              break;
            }

            parentOfTopCandidate = _parentElement(parentOfTopCandidate);
          }
        }

        if (topCandidate != null && !_hasReadability(topCandidate)) {
          _initializeNode(topCandidate);
        }

        var parentOfTopCandidate = topCandidate?.parentNode as DomElement?;
        var lastScore = topCandidate != null
            ? _getReadability(topCandidate).contentScore
            : 0.0;
        final scoreThreshold = lastScore / 3;

        while (parentOfTopCandidate != null &&
            parentOfTopCandidate.tagName != 'BODY') {
          if (!_hasReadability(parentOfTopCandidate)) {
            parentOfTopCandidate = _parentElement(parentOfTopCandidate);
            continue;
          }

          final parentScore =
              _getReadability(parentOfTopCandidate).contentScore;
          if (parentScore < scoreThreshold) {
            break;
          }

          if (parentScore > lastScore) {
            topCandidate = parentOfTopCandidate;
            break;
          }

          lastScore = parentScore;
          parentOfTopCandidate = _parentElement(parentOfTopCandidate);
        }

        // Walk up and get siblings
        // If the top candidate is the only child, use parent instead to help sibling joining.
        parentOfTopCandidate = topCandidate?.parentNode as DomElement?;
        while (parentOfTopCandidate != null &&
            parentOfTopCandidate.tagName != 'BODY' &&
            parentOfTopCandidate.children.length == 1) {
          topCandidate = parentOfTopCandidate;
          parentOfTopCandidate = topCandidate.parentNode as DomElement?;
        }

        if (topCandidate != null && !_hasReadability(topCandidate)) {
          _initializeNode(topCandidate);
        }
      }

      // Create article content
      var articleContent = doc.createElement('DIV');
      articleContent.id = 'readability-content';

      final topCandidateScore = topCandidate != null
          ? _getReadability(topCandidate).contentScore
          : 0.0;
      final siblingScoreThreshold =
          [10.0, topCandidateScore * 0.2].reduce((a, b) => a > b ? a : b);

      final parentOfTopCandidate = _parentElement(topCandidate);
      // Make a copy of siblings to avoid concurrent modification
      final siblings =
          List<DomElement>.from(parentOfTopCandidate?.children ?? []);
      final topCandidateClassName = topCandidate?.className ?? '';

      for (final sibling in siblings) {
        var append = false;

        _log([
          'Looking at sibling node: ${sibling.tagName}#${sibling.id}.${sibling.className}'
        ]);

        if (sibling == topCandidate) {
          append = true;
        } else {
          var contentBonus = 0.0;

          if (_getReadability(sibling).contentScore != 0 &&
              sibling.className == topCandidateClassName &&
              topCandidateClassName.isNotEmpty) {
            contentBonus = topCandidateScore * 0.2;
          }

          if (_hasReadability(sibling) &&
              (_getReadability(sibling).contentScore + contentBonus) >=
                  siblingScoreThreshold) {
            append = true;
          } else if (sibling.tagName == 'P') {
            final linkDensity = _getLinkDensity(sibling);
            final nodeContent = _getInnerText(sibling);
            final nodeLength = nodeContent.length;

            if (nodeLength > 80 && linkDensity < 0.25) {
              append = true;
            } else if (nodeLength < 80 &&
                nodeLength > 0 &&
                linkDensity == 0 &&
                RegExp(r'\.( |$)').hasMatch(nodeContent)) {
              append = true;
            }
          }
        }

        if (append) {
          _log(['Appending node: ${sibling.tagName}']);

          var nodeToAppend = sibling;
          if (!alterToDivExceptions.contains(sibling.tagName)) {
            _log(['Altering sibling tag to div']);
            nodeToAppend = _setNodeTag(sibling, 'DIV');
          }

          articleContent.appendChild(nodeToAppend);
        }
      }

      _log(['Article content pre-prep: ${articleContent.innerHTML}']);

      _prepArticle(articleContent);

      _log(['Article content post-prep: ${articleContent.innerHTML}']);

      if (neededToCreateTopCandidate && topCandidate != null) {
        topCandidate.id = 'readability-page-1';
        topCandidate.className = 'page';
      } else {
        final div = doc.createElement('DIV');
        div.id = 'readability-page-1';
        div.className = 'page';

        while (articleContent.firstChild != null) {
          div.appendChild(articleContent.firstChild!);
        }
        articleContent.appendChild(div);
      }

      _log(['Article content after paging: ${articleContent.innerHTML}']);

      var parseSuccessful = true;

      final textLength = _getInnerText(articleContent, true).length;
      if (textLength < _charThreshold) {
        parseSuccessful = false;

        // Restore the page content before retrying
        page.innerHTML = pageCacheHtml;

        _attempts.add(
            _Attempt(articleContent: articleContent, textLength: textLength));

        if ((_flags & flagStripUnlikelys) != 0) {
          _flags = _flags & ~flagStripUnlikelys;
        } else if ((_flags & flagWeightClasses) != 0) {
          _flags = _flags & ~flagWeightClasses;
        } else if ((_flags & flagCleanConditionally) != 0) {
          _flags = _flags & ~flagCleanConditionally;
        } else {
          // Return best attempt
          _attempts.sort((a, b) => b.textLength.compareTo(a.textLength));

          if (_attempts.isEmpty) {
            return null;
          }

          articleContent = _attempts.first.articleContent;
          parseSuccessful = true;
        }
      }

      if (parseSuccessful) {
        // Find out text direction from ancestors of final top candidate.
        // Check both parentOfTopCandidate and topCandidate, plus ancestors of parentOfTopCandidate.
        final candidates = <DomElement?>[parentOfTopCandidate, topCandidate];
        if (parentOfTopCandidate != null) {
          candidates.addAll(_getNodeAncestors(parentOfTopCandidate));
        }
        for (final ancestor in candidates) {
          if (ancestor == null || ancestor.tagName.isEmpty) {
            continue;
          }
          final dir = ancestor.getAttribute('dir');
          if (dir != null) {
            _articleDir = dir;
            break;
          }
        }

        return articleContent;
      }
    }
  }

  /// Check if element has child block elements.
  bool _hasChildBlockElement(DomElement element) {
    for (final child in element.children) {
      if (divToPElems.contains(child.tagName) || _hasChildBlockElement(child)) {
        return true;
      }
    }
    return false;
  }

  /// Extracts the main readable article content from the document.
  ///
  /// This is the main entry point for the Readability parser. It analyzes
  /// the document structure, identifies the main article content, extracts
  /// metadata (title, author, excerpt, etc.), and returns an [Article] object.
  ///
  /// Returns `null` if no article content could be found.
  ///
  /// Throws [Exception] if the document has more than [maxElemsToParse] elements.
  Article? parse() {
    // Check for max elements
    if (_maxElemsToParse > 0) {
      final numTags = _doc.getElementsByTagName('*').length;
      if (numTags > _maxElemsToParse) {
        throw Exception(
            'Aborting parsing: too many elements ($numTags > $_maxElemsToParse)');
      }
    }

    // Get JSON-LD metadata if enabled
    Map<String, dynamic>? jsonLd;
    if (_enableJSONLD) {
      jsonLd = _getJSONLD();
    }

    // Unwrap image from noscript
    _unwrapNoscriptImages(_doc);

    // Remove script tags from the document
    _removeScripts(_doc);

    // Get metadata from meta tags (JSON-LD takes priority)
    _metadata = _getArticleMetadata(jsonLd);

    _articleTitle = _metadata['title'] as String? ?? _getArticleTitle();

    // Prepare the document
    _prepDocument();

    // Grab the article
    final articleContent = _grabArticle();
    if (articleContent == null) {
      return null;
    }

    _log(['Grabbed article: ${articleContent.innerHTML}']);

    // Post-process content
    _postProcessContent(articleContent);

    // Get text direction if not already set
    _articleDir ??= _doc.documentElement?.getAttribute('dir');

    // Get language
    final lang = _doc.documentElement?.getAttribute('lang');

    final textContent = (articleContent.textContent ?? '').trim();

    // Compute excerpt if not present
    var excerpt = _metadata['excerpt'] as String?;
    if (excerpt == null || excerpt.isEmpty) {
      final paragraphs = articleContent.getElementsByTagName('p');
      if (paragraphs.isNotEmpty) {
        excerpt = (paragraphs.first.textContent ?? '').trim();
      }
    }

    return Article(
      title: _articleTitle ?? '',
      content: _serializer(articleContent),
      textContent: textContent,
      length: textContent.length,
      excerpt: excerpt,
      byline: (_metadata['byline'] as String?)?.isNotEmpty == true
          ? _metadata['byline'] as String?
          : _articleByline,
      dir: _articleDir,
      siteName: _metadata['siteName'] as String? ?? _articleSiteName,
      lang: lang,
      publishedTime: _metadata['publishedTime'] as String?,
    );
  }
}

/// Internal class to track parsing attempts.
class _Attempt {
  final DomElement articleContent;
  final int textLength;

  _Attempt({required this.articleContent, required this.textLength});
}
