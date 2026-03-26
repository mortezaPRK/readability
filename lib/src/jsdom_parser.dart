// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2024 Dart Readability contributors
// This is a Dart port of Mozilla's JSDOMParser from the Readability project
// Original JSDOMParser: Copyright (c) Mozilla Foundation and contributors

/// A relatively lightweight DOMParser that is safe to use in isolates.
/// This is far from a complete DOM implementation; however, it should contain
/// the minimal set of functionality necessary for Readability.
///
/// Aside from not implementing the full DOM API, there are other quirks to be
/// aware of when using the JSDOMParser:
///
///   1) Properly formed HTML/XML must be used.
///   2) Live NodeLists are not supported. DOM methods and properties such as
///      getElementsByTagName() and childNodes return standard lists.
library;

// XML only defines these and the numeric ones:
const Map<String, String> _entityTable = {
  'lt': '<',
  'gt': '>',
  'amp': '&',
  'quot': '"',
  'apos': "'",
};

const Map<String, String> _reverseEntityTable = {
  '<': '&lt;',
  '>': '&gt;',
  '&': '&amp;',
  '"': '&quot;',
  "'": '&apos;',
};

String _encodeTextContentHTML(String s) {
  return s.replaceAllMapped(RegExp(r'[&<>]'), (match) {
    return _reverseEntityTable[match[0]]!;
  });
}

/// Encodes a string for use in an HTML attribute value.
/// Encodes &, <, >, ', and " to match JS JSDOMParser behavior.
String _encodeAttrValue(String s) {
  return s.replaceAllMapped(RegExp(r"""[&<>'"]"""), (match) {
    return _reverseEntityTable[match[0]]!;
  });
}

String _decodeHTML(String str) {
  return str
      .replaceAllMapped(
    RegExp(r'&(quot|amp|apos|lt|gt);'),
    (match) => _entityTable[match[1]]!,
  )
      .replaceAllMapped(
    RegExp(r'&#(?:x([0-9a-fA-F]+)|([0-9]+));'),
    (match) {
      final hex = match[1];
      final numStr = match[2];
      var num = int.parse(hex ?? numStr!, radix: hex != null ? 16 : 10);

      // These character references are replaced by a conforming HTML parser
      if (num == 0 || num > 0x10ffff || (num >= 0xd800 && num <= 0xdfff)) {
        num = 0xfffd;
      }

      return String.fromCharCode(num);
    },
  );
}

// When a style is set in JS, map it to the corresponding CSS attribute
const Map<String, String> _styleMap = {
  'alignmentBaseline': 'alignment-baseline',
  'background': 'background',
  'backgroundAttachment': 'background-attachment',
  'backgroundClip': 'background-clip',
  'backgroundColor': 'background-color',
  'backgroundImage': 'background-image',
  'backgroundOrigin': 'background-origin',
  'backgroundPosition': 'background-position',
  'backgroundPositionX': 'background-position-x',
  'backgroundPositionY': 'background-position-y',
  'backgroundRepeat': 'background-repeat',
  'backgroundRepeatX': 'background-repeat-x',
  'backgroundRepeatY': 'background-repeat-y',
  'backgroundSize': 'background-size',
  'baselineShift': 'baseline-shift',
  'border': 'border',
  'borderBottom': 'border-bottom',
  'borderBottomColor': 'border-bottom-color',
  'borderBottomLeftRadius': 'border-bottom-left-radius',
  'borderBottomRightRadius': 'border-bottom-right-radius',
  'borderBottomStyle': 'border-bottom-style',
  'borderBottomWidth': 'border-bottom-width',
  'borderCollapse': 'border-collapse',
  'borderColor': 'border-color',
  'borderImage': 'border-image',
  'borderImageOutset': 'border-image-outset',
  'borderImageRepeat': 'border-image-repeat',
  'borderImageSlice': 'border-image-slice',
  'borderImageSource': 'border-image-source',
  'borderImageWidth': 'border-image-width',
  'borderLeft': 'border-left',
  'borderLeftColor': 'border-left-color',
  'borderLeftStyle': 'border-left-style',
  'borderLeftWidth': 'border-left-width',
  'borderRadius': 'border-radius',
  'borderRight': 'border-right',
  'borderRightColor': 'border-right-color',
  'borderRightStyle': 'border-right-style',
  'borderRightWidth': 'border-right-width',
  'borderSpacing': 'border-spacing',
  'borderStyle': 'border-style',
  'borderTop': 'border-top',
  'borderTopColor': 'border-top-color',
  'borderTopLeftRadius': 'border-top-left-radius',
  'borderTopRightRadius': 'border-top-right-radius',
  'borderTopStyle': 'border-top-style',
  'borderTopWidth': 'border-top-width',
  'borderWidth': 'border-width',
  'bottom': 'bottom',
  'boxShadow': 'box-shadow',
  'boxSizing': 'box-sizing',
  'captionSide': 'caption-side',
  'clear': 'clear',
  'clip': 'clip',
  'clipPath': 'clip-path',
  'clipRule': 'clip-rule',
  'color': 'color',
  'colorInterpolation': 'color-interpolation',
  'colorInterpolationFilters': 'color-interpolation-filters',
  'colorProfile': 'color-profile',
  'colorRendering': 'color-rendering',
  'content': 'content',
  'counterIncrement': 'counter-increment',
  'counterReset': 'counter-reset',
  'cursor': 'cursor',
  'direction': 'direction',
  'display': 'display',
  'dominantBaseline': 'dominant-baseline',
  'emptyCells': 'empty-cells',
  'enableBackground': 'enable-background',
  'fill': 'fill',
  'fillOpacity': 'fill-opacity',
  'fillRule': 'fill-rule',
  'filter': 'filter',
  'cssFloat': 'float',
  'floodColor': 'flood-color',
  'floodOpacity': 'flood-opacity',
  'font': 'font',
  'fontFamily': 'font-family',
  'fontSize': 'font-size',
  'fontStretch': 'font-stretch',
  'fontStyle': 'font-style',
  'fontVariant': 'font-variant',
  'fontWeight': 'font-weight',
  'glyphOrientationHorizontal': 'glyph-orientation-horizontal',
  'glyphOrientationVertical': 'glyph-orientation-vertical',
  'height': 'height',
  'imageRendering': 'image-rendering',
  'kerning': 'kerning',
  'left': 'left',
  'letterSpacing': 'letter-spacing',
  'lightingColor': 'lighting-color',
  'lineHeight': 'line-height',
  'listStyle': 'list-style',
  'listStyleImage': 'list-style-image',
  'listStylePosition': 'list-style-position',
  'listStyleType': 'list-style-type',
  'margin': 'margin',
  'marginBottom': 'margin-bottom',
  'marginLeft': 'margin-left',
  'marginRight': 'margin-right',
  'marginTop': 'margin-top',
  'marker': 'marker',
  'markerEnd': 'marker-end',
  'markerMid': 'marker-mid',
  'markerStart': 'marker-start',
  'mask': 'mask',
  'maxHeight': 'max-height',
  'maxWidth': 'max-width',
  'minHeight': 'min-height',
  'minWidth': 'min-width',
  'opacity': 'opacity',
  'orphans': 'orphans',
  'outline': 'outline',
  'outlineColor': 'outline-color',
  'outlineOffset': 'outline-offset',
  'outlineStyle': 'outline-style',
  'outlineWidth': 'outline-width',
  'overflow': 'overflow',
  'overflowX': 'overflow-x',
  'overflowY': 'overflow-y',
  'padding': 'padding',
  'paddingBottom': 'padding-bottom',
  'paddingLeft': 'padding-left',
  'paddingRight': 'padding-right',
  'paddingTop': 'padding-top',
  'page': 'page',
  'pageBreakAfter': 'page-break-after',
  'pageBreakBefore': 'page-break-before',
  'pageBreakInside': 'page-break-inside',
  'pointerEvents': 'pointer-events',
  'position': 'position',
  'quotes': 'quotes',
  'resize': 'resize',
  'right': 'right',
  'shapeRendering': 'shape-rendering',
  'size': 'size',
  'speak': 'speak',
  'src': 'src',
  'stopColor': 'stop-color',
  'stopOpacity': 'stop-opacity',
  'stroke': 'stroke',
  'strokeDasharray': 'stroke-dasharray',
  'strokeDashoffset': 'stroke-dashoffset',
  'strokeLinecap': 'stroke-linecap',
  'strokeLinejoin': 'stroke-linejoin',
  'strokeMiterlimit': 'stroke-miterlimit',
  'strokeOpacity': 'stroke-opacity',
  'strokeWidth': 'stroke-width',
  'tableLayout': 'table-layout',
  'textAlign': 'text-align',
  'textAnchor': 'text-anchor',
  'textDecoration': 'text-decoration',
  'textIndent': 'text-indent',
  'textLineThrough': 'text-line-through',
  'textLineThroughColor': 'text-line-through-color',
  'textLineThroughMode': 'text-line-through-mode',
  'textLineThroughStyle': 'text-line-through-style',
  'textLineThroughWidth': 'text-line-through-width',
  'textOverflow': 'text-overflow',
  'textOverline': 'text-overline',
  'textOverlineColor': 'text-overline-color',
  'textOverlineMode': 'text-overline-mode',
  'textOverlineStyle': 'text-overline-style',
  'textOverlineWidth': 'text-overline-width',
  'textRendering': 'text-rendering',
  'textShadow': 'text-shadow',
  'textTransform': 'text-transform',
  'textUnderline': 'text-underline',
  'textUnderlineColor': 'text-underline-color',
  'textUnderlineMode': 'text-underline-mode',
  'textUnderlineStyle': 'text-underline-style',
  'textUnderlineWidth': 'text-underline-width',
  'top': 'top',
  'unicodeBidi': 'unicode-bidi',
  'unicodeRange': 'unicode-range',
  'vectorEffect': 'vector-effect',
  'verticalAlign': 'vertical-align',
  'visibility': 'visibility',
  'whiteSpace': 'white-space',
  'widows': 'widows',
  'width': 'width',
  'wordBreak': 'word-break',
  'wordSpacing': 'word-spacing',
  'wordWrap': 'word-wrap',
  'writingMode': 'writing-mode',
  'zIndex': 'z-index',
  'zoom': 'zoom',
};

// Elements that can be self-closing
const Set<String> _voidElems = {
  'area',
  'base',
  'br',
  'col',
  'command',
  'embed',
  'hr',
  'img',
  'input',
  'link',
  'meta',
  'param',
  'source',
  'wbr',
};

const List<String> _whitespace = [' ', '\t', '\n', '\r'];

// See https://developer.mozilla.org/en-US/docs/Web/API/Node/nodeType
abstract class NodeType {
  static const int elementNode = 1;
  static const int attributeNode = 2;
  static const int textNode = 3;
  static const int cdataSectionNode = 4;
  static const int entityReferenceNode = 5;
  static const int entityNode = 6;
  static const int processingInstructionNode = 7;
  static const int commentNode = 8;
  static const int documentNode = 9;
  static const int documentTypeNode = 10;
  static const int documentFragmentNode = 11;
  static const int notationNode = 12;
}

/// Base class for all DOM nodes.
abstract class Node {
  // Node type constants matching the JS implementation
  // ignore: constant_identifier_names
  static const int ELEMENT_NODE = 1;
  // ignore: constant_identifier_names
  static const int ATTRIBUTE_NODE = 2;
  // ignore: constant_identifier_names
  static const int TEXT_NODE = 3;
  // ignore: constant_identifier_names
  static const int CDATA_SECTION_NODE = 4;
  // ignore: constant_identifier_names
  static const int ENTITY_REFERENCE_NODE = 5;
  // ignore: constant_identifier_names
  static const int ENTITY_NODE = 6;
  // ignore: constant_identifier_names
  static const int PROCESSING_INSTRUCTION_NODE = 7;
  // ignore: constant_identifier_names
  static const int COMMENT_NODE = 8;
  // ignore: constant_identifier_names
  static const int DOCUMENT_NODE = 9;
  // ignore: constant_identifier_names
  static const int DOCUMENT_TYPE_NODE = 10;
  // ignore: constant_identifier_names
  static const int DOCUMENT_FRAGMENT_NODE = 11;
  // ignore: constant_identifier_names
  static const int NOTATION_NODE = 12;

  List<Attribute> attributes = [];
  List<Node> childNodes = [];
  String? localName;
  String? nodeName;
  Node? parentNode;
  Node? nextSibling;
  Node? previousSibling;

  int get nodeType;

  Node? get firstChild => childNodes.isNotEmpty ? childNodes[0] : null;

  Element? get firstElementChild => children.isNotEmpty ? children[0] : null;

  Node? get lastChild =>
      childNodes.isNotEmpty ? childNodes[childNodes.length - 1] : null;

  Element? get lastElementChild =>
      children.isNotEmpty ? children[children.length - 1] : null;

  /// The element children of this node.
  List<Element> get children => _children;
  List<Element> _children = [];

  String get textContent;
  set textContent(String value);

  String get innerHTML;
  set innerHTML(String value);

  /// The workhorse for all node insertion operations.
  void _insertNodesAtIndex(List<Node> nodes, int index) {
    if (nodes.isEmpty) {
      return;
    }

    // Detach nodes from their previous parents.
    for (final node in nodes) {
      if (node.parentNode != null) {
        node.remove();
      }
    }

    final afterSibling = index == -1 ? null : childNodes[index];

    // Store the previous sibling before we modify the DOM.
    Node? prevSibling;
    if (afterSibling != null) {
      prevSibling = afterSibling.previousSibling;
    } else {
      prevSibling = lastChild;
    }

    // Insert nodes into childNodes.
    final insertionPoint = index == -1 ? childNodes.length : index;
    childNodes.insertAll(insertionPoint, nodes);

    // Update parentNode and sibling pointers for the new nodes.
    for (final node in nodes) {
      node.parentNode = this;
      node.previousSibling = prevSibling;
      if (prevSibling != null) {
        prevSibling.nextSibling = node;
      }
      prevSibling = node;
    }
    final lastInsertedNode = nodes.last;
    lastInsertedNode.nextSibling = afterSibling;
    if (afterSibling != null) {
      afterSibling.previousSibling = lastInsertedNode;
    }

    // Filter for element nodes and update children array and pointers.
    final elementsToInsert = nodes.whereType<Element>().toList();

    if (elementsToInsert.isNotEmpty) {
      // Find the next element sibling to use as an insertion reference.
      Node? afterElem = afterSibling;
      while (afterElem != null && afterElem.nodeType != Node.ELEMENT_NODE) {
        afterElem = afterElem.nextSibling;
      }

      // Store the previous element sibling before more DOM modifications.
      Element? prevElem;
      if (afterElem != null && afterElem is Element) {
        prevElem = afterElem.previousElementSibling;
      } else {
        prevElem = lastElementChild;
      }

      final afterElemIndex =
          afterElem != null ? _children.indexOf(afterElem as Element) : -1;
      final elemInsertionPoint =
          afterElemIndex == -1 ? _children.length : afterElemIndex;
      _children.insertAll(elemInsertionPoint, elementsToInsert);

      for (final elem in elementsToInsert) {
        elem.previousElementSibling = prevElem;
        if (prevElem != null) {
          prevElem.nextElementSibling = elem;
        }
        prevElem = elem;
      }
      final lastInsertedElem = elementsToInsert.last;
      lastInsertedElem.nextElementSibling =
          afterElem != null ? afterElem as Element : null;
      if (afterElem != null) {
        (afterElem as Element).previousElementSibling = lastInsertedElem;
      }
    }
  }

  Node appendChild(Node child) {
    final nodes = child.nodeType == Node.DOCUMENT_FRAGMENT_NODE
        ? List<Node>.from(child.childNodes)
        : [child];
    _insertNodesAtIndex(nodes, -1);
    return child;
  }

  Node insertBefore(Node newNode, Node? referenceNode) {
    if (identical(newNode, referenceNode)) {
      return newNode;
    }
    final nodes = newNode.nodeType == Node.DOCUMENT_FRAGMENT_NODE
        ? List<Node>.from(newNode.childNodes)
        : [newNode];
    int index;
    if (referenceNode != null) {
      index = childNodes.indexOf(referenceNode);
    } else {
      index = -1;
    }
    if (referenceNode != null && index == -1) {
      throw StateError('insertBefore: reference node not found');
    }
    _insertNodesAtIndex(nodes, index);
    return newNode;
  }

  Node remove() {
    final parent = parentNode;
    if (parent == null) {
      // Already detached.
      return this;
    }
    final parentChildNodes = parent.childNodes;
    final childIndex = parentChildNodes.indexOf(this);
    if (childIndex == -1) {
      throw StateError('removeChild: node not found');
    }
    parentNode = null;
    final prev = previousSibling;
    final next = nextSibling;
    if (prev != null) {
      prev.nextSibling = next;
    }
    if (next != null) {
      next.previousSibling = prev;
    }
    parentChildNodes.removeAt(childIndex);

    if (nodeType == Node.ELEMENT_NODE) {
      final self = this as Element;
      final prevElem = self.previousElementSibling;
      final nextElem = self.nextElementSibling;
      if (prevElem != null) {
        prevElem.nextElementSibling = nextElem;
      }
      if (nextElem != null) {
        nextElem.previousElementSibling = prevElem;
      }
      parent._children.remove(self);
      self.previousElementSibling = null;
      self.nextElementSibling = null;
    }

    previousSibling = null;
    nextSibling = null;

    return this;
  }

  Node removeChild(Node child) {
    return child.remove();
  }

  Node replaceChild(Node newNode, Node oldNode) {
    if (identical(newNode, oldNode)) {
      return oldNode;
    }
    if (!identical(oldNode.parentNode, this)) {
      throw StateError(
          'replaceChild: node to be replaced is not a child of this node');
    }
    // Insert the new node(s) before the node to be replaced.
    insertBefore(newNode, oldNode);
    // Now, remove the old node.
    oldNode.remove();
    return oldNode;
  }

  List<Element> getElementsByTagName(String tag) {
    tag = tag.toUpperCase();
    final elems = <Element>[];
    final allTags = tag == '*';
    void getElems(Node node) {
      final length = node.children.length;
      for (var i = 0; i < length; i++) {
        final child = node.children[i];
        if (allTags || child.tagName == tag) {
          elems.add(child);
        }
        getElems(child);
      }
    }

    getElems(this);
    return elems;
  }

  // Marker property used by Readability to detect JSDOMParser nodes.
  // ignore: non_constant_identifier_names, unused_element
  bool get __JSDOMParser__ => true;
}

/// Represents an HTML/XML attribute.
class Attribute {
  final String name;
  String _value;

  Attribute(this.name, this._value);

  String get value => _value;

  void setValue(String newValue) {
    _value = newValue;
  }

  String getEncodedValue() {
    return _encodeAttrValue(_value);
  }

  /// Cheat horribly. This is fine for our usecases.
  Attribute cloneNode() {
    return this;
  }
}

/// Represents an HTML comment node.
class Comment extends Node {
  /// The comment's data (content between <!-- and -->).
  String data;

  Comment([this.data = '']) {
    childNodes = [];
  }

  @override
  String? get nodeName => '#comment';

  @override
  int get nodeType => Node.COMMENT_NODE;

  @override
  String get textContent => '';

  @override
  set textContent(String value) {}

  @override
  String get innerHTML => '<!--$data-->';

  @override
  set innerHTML(String value) {}
}

/// Represents a document fragment.
class DocumentFragment extends Node {
  DocumentFragment() {
    childNodes = [];
    _children = [];
  }

  @override
  String? get nodeName => '#document-fragment';

  @override
  int get nodeType => Node.DOCUMENT_FRAGMENT_NODE;

  @override
  String get textContent => '';

  @override
  set textContent(String value) {}

  @override
  String get innerHTML => '';

  @override
  set innerHTML(String value) {}
}

/// Represents a text node.
class TextNode extends Node {
  String? _textContent;
  String? _innerHTML;

  TextNode() {
    childNodes = [];
  }

  @override
  String? get nodeName => '#text';

  @override
  int get nodeType => Node.TEXT_NODE;

  @override
  String get textContent {
    _textContent ??= _decodeHTML(_innerHTML ?? '');
    return _textContent!;
  }

  @override
  set textContent(String value) {
    _textContent = value;
    _innerHTML = null;
  }

  @override
  String get innerHTML {
    _innerHTML ??= _encodeTextContentHTML(_textContent ?? '');
    return _innerHTML!;
  }

  @override
  set innerHTML(String value) {
    _innerHTML = value;
    _textContent = null;
  }

  /// Sets raw text content that will be returned as-is by both
  /// textContent and innerHTML, without any encoding/decoding.
  /// Used for script/style element content.
  void setRawContent(String value) {
    _textContent = value;
    _innerHTML = value;
  }
}

/// Represents an HTML document.
class Document extends Node {
  final String? documentURI;
  final List<dynamic> styleSheets = [];
  String title = '';
  Element? head;
  Element? body;
  Element? documentElement;
  String? _baseURI;

  Document([this.documentURI]) {
    childNodes = [];
    _children = [];
  }

  @override
  String? get nodeName => '#document';

  @override
  int get nodeType => Node.DOCUMENT_NODE;

  @override
  String get textContent => '';

  @override
  set textContent(String value) {}

  @override
  String get innerHTML => '';

  @override
  set innerHTML(String value) {}

  Element? getElementById(String id) {
    Element? getElem(Node node) {
      final length = node.children.length;
      if (node is Element && node.id == id) {
        return node;
      }
      for (var i = 0; i < length; i++) {
        final el = getElem(node.children[i]);
        if (el != null) {
          return el;
        }
      }
      return null;
    }

    return getElem(this);
  }

  /// Returns the first element within the document that matches the specified selector.
  ///
  /// Supports basic CSS selectors:
  /// - ID selector: `#id`
  /// - Class selector: `.class`
  /// - Tag selector: `tag`
  /// - Combined selectors: `tag.class`, `tag#id`
  ///
  /// Does NOT support complex selectors like:
  /// - Descendant selectors (`div p`)
  /// - Attribute selectors (`[attr=value]`)
  /// - Pseudo-classes (`:hover`, `:nth-child`)
  Element? querySelector(String selectors) {
    final results = querySelectorAll(selectors);
    return results.isNotEmpty ? results.first : null;
  }

  /// Returns all elements within the document that match the specified selector.
  ///
  /// Supports basic CSS selectors:
  /// - ID selector: `#id`
  /// - Class selector: `.class`
  /// - Tag selector: `tag`
  /// - Combined selectors: `tag.class`, `tag#id`
  List<Element> querySelectorAll(String selectors) {
    final results = <Element>[];

    // Parse the selector
    final parts = _parseSelector(selectors);
    if (parts == null) return results;

    void search(Node node) {
      final length = node.children.length;
      for (var i = 0; i < length; i++) {
        final child = node.children[i];
        if (_matchesSelector(child, parts)) {
          results.add(child);
        }
        search(child);
      }
    }

    search(this);
    return results;
  }

  /// Parse a simple CSS selector into its components.
  /// Returns null for unsupported selectors.
  _SelectorParts? _parseSelector(String selector) {
    return _parseSimpleSelector(selector);
  }

  /// Check if an element matches the parsed selector parts.
  bool _matchesSelector(Element element, _SelectorParts parts) {
    if (parts.tag != null && element.tagName != parts.tag!.toUpperCase()) {
      return false;
    }
    if (parts.id != null && element.id != parts.id) {
      return false;
    }
    if (parts.className != null && !element.hasClass(parts.className!)) {
      return false;
    }
    return true;
  }

  Element createElement(String tag) {
    return Element(tag);
  }

  TextNode createTextNode(String text) {
    final node = TextNode();
    node.textContent = text;
    return node;
  }

  DocumentFragment createDocumentFragment() {
    return DocumentFragment();
  }

  String get baseURI {
    if (_baseURI == null) {
      _baseURI = documentURI ?? '';
      final baseElements = getElementsByTagName('base');
      final href =
          baseElements.isNotEmpty ? baseElements[0].getAttribute('href') : null;
      if (href != null) {
        try {
          _baseURI = Uri.parse(href).resolve(href).toString();
          // Try to resolve against documentURI
          if (documentURI != null) {
            _baseURI = Uri.parse(documentURI!).resolve(href).toString();
          }
        } catch (_) {
          // Just fall back to documentURI
        }
      }
    }
    return _baseURI!;
  }
}

/// Represents an HTML element node.
class Element extends Node {
  /// The original tag used for matching the closing tag.
  final String _matchingTag;
  late final Style style;
  Element? nextElementSibling;
  Element? previousElementSibling;

  String tagName;

  Element(String tag)
      : _matchingTag = tag,
        tagName = _normalizeTagName(tag) {
    // We're explicitly a non-namespace aware parser, we just pretend it's all
    // HTML.
    final lastColonIndex = tag.lastIndexOf(':');
    final localTag =
        lastColonIndex != -1 ? tag.substring(lastColonIndex + 1) : tag;
    localName = localTag.toLowerCase();
    attributes = [];
    childNodes = [];
    _children = [];
    style = Style(this);
  }

  static String _normalizeTagName(String tag) {
    final lastColonIndex = tag.lastIndexOf(':');
    if (lastColonIndex != -1) {
      tag = tag.substring(lastColonIndex + 1);
    }
    return tag.toUpperCase();
  }

  @override
  int get nodeType => Node.ELEMENT_NODE;

  @override
  String get nodeName => tagName;

  String get className => getAttribute('class') ?? '';
  set className(String str) => setAttribute('class', str);

  String get id => getAttribute('id') ?? '';
  set id(String str) => setAttribute('id', str);

  String get href => getAttribute('href') ?? '';
  set href(String str) => setAttribute('href', str);

  String get src => getAttribute('src') ?? '';
  set src(String str) => setAttribute('src', str);

  String get srcset => getAttribute('srcset') ?? '';
  set srcset(String str) => setAttribute('srcset', str);

  @override
  String get innerHTML {
    final arr = <String>[];

    void getHTML(Node node) {
      for (var i = 0; i < node.childNodes.length; i++) {
        final child = node.childNodes[i];
        if (child.localName != null) {
          arr.add('<${child.localName}');

          // serialize attribute list
          for (var j = 0; j < child.attributes.length; j++) {
            final attr = child.attributes[j];
            // the attribute value will be HTML escaped.
            final val = attr.getEncodedValue();
            final quote = !val.contains('"') ? '"' : "'";
            arr.add(' ${attr.name}=$quote$val$quote');
          }

          if (_voidElems.contains(child.localName) &&
              child.childNodes.isEmpty) {
            // Void elements don't need closing tags in HTML5
            // Use > instead of /> to match browser behavior (JSDOM)
            arr.add('>');
          } else {
            // otherwise, add its children
            arr.add('>');
            getHTML(child);
            arr.add('</${child.localName}>');
          }
        } else {
          // This is a text node, so asking for innerHTML won't recurse.
          arr.add(child.innerHTML);
        }
      }
    }

    getHTML(this);
    return arr.join('');
  }

  @override
  set innerHTML(String html) {
    final parser = JSDOMParser();
    final node = parser.parse(html);
    for (var i = childNodes.length - 1; i >= 0; i--) {
      childNodes[i].parentNode = null;
    }
    childNodes = node.childNodes;
    _children = List<Element>.from(node.children);
    for (var i = childNodes.length - 1; i >= 0; i--) {
      childNodes[i].parentNode = this;
    }
  }

  @override
  set textContent(String text) {
    // clear parentNodes for existing children
    for (var i = childNodes.length - 1; i >= 0; i--) {
      childNodes[i].parentNode = null;
    }

    final node = TextNode();
    childNodes = [node];
    _children = [];
    node.textContent = text;
    node.parentNode = this;
  }

  @override
  String get textContent {
    final text = <String>[];

    void getText(Node node) {
      final nodes = node.childNodes;
      for (final child in nodes) {
        if (child.nodeType == Node.TEXT_NODE) {
          text.add(child.textContent);
        } else {
          getText(child);
        }
      }
    }

    getText(this);
    return text.join('');
  }

  String? getAttribute(String name) {
    for (final attr in attributes.reversed) {
      if (attr.name == name) {
        return attr.value;
      }
    }
    return null;
  }

  void setAttribute(String name, String value) {
    for (final attr in attributes.reversed) {
      if (attr.name == name) {
        attr.setValue(value);
        return;
      }
    }
    attributes.add(Attribute(name, value));
  }

  void setAttributeNode(Attribute node) {
    setAttribute(node.name, node.value);
  }

  void removeAttribute(String name) {
    for (var i = attributes.length - 1; i >= 0; i--) {
      final attr = attributes[i];
      if (attr.name == name) {
        attributes.removeAt(i);
        break;
      }
    }
  }

  bool hasAttribute(String name) {
    return attributes.any((attr) => attr.name == name);
  }

  /// Returns the first descendant element that matches the specified selector.
  ///
  /// Supports basic CSS selectors:
  /// - ID selector: `#id`
  /// - Class selector: `.class`
  /// - Tag selector: `tag`
  /// - Combined selectors: `tag.class`, `tag#id`
  Element? querySelector(String selectors) {
    final results = querySelectorAll(selectors);
    return results.isNotEmpty ? results.first : null;
  }

  /// Returns all descendant elements that match the specified selector.
  ///
  /// Supports basic CSS selectors:
  /// - ID selector: `#id`
  /// - Class selector: `.class`
  /// - Tag selector: `tag`
  /// - Combined selectors: `tag.class`, `tag#id`
  List<Element> querySelectorAll(String selectors) {
    final results = <Element>[];

    // Parse the selector
    final parts = _parseSelector(selectors);
    if (parts == null) return results;

    void search(Node node) {
      final length = node.children.length;
      for (var i = 0; i < length; i++) {
        final child = node.children[i];
        if (_matchesSelector(child, parts)) {
          results.add(child);
        }
        search(child);
      }
    }

    search(this);
    return results;
  }

  /// Parse a simple CSS selector into its components.
  _SelectorParts? _parseSelector(String selector) {
    return _parseSimpleSelector(selector);
  }

  /// Check if an element matches the parsed selector parts.
  bool _matchesSelector(Element element, _SelectorParts parts) {
    if (parts.tag != null && element.tagName != parts.tag!.toUpperCase()) {
      return false;
    }
    if (parts.id != null && element.id != parts.id) {
      return false;
    }
    if (parts.className != null && !element.hasClass(parts.className!)) {
      return false;
    }
    return true;
  }
}

/// Represents the style property of an element, backed by the style attribute.
///
/// getStyle() and setStyle() use the style attribute string directly. This
/// won't be very efficient if there are a lot of style manipulations, but
/// it's the easiest way to make sure the style attribute string and the JS
/// style property stay in sync.
class Style {
  final Element node;

  Style(this.node);

  String? getStyle(String styleName) {
    final attr = node.getAttribute('style');
    if (attr == null) {
      return null;
    }

    final styles = attr.split(';');
    for (var i = 0; i < styles.length; i++) {
      final parts = styles[i].split(':');
      final name = parts[0].trim();
      if (name == styleName) {
        return parts[1].trim();
      }
    }

    return null;
  }

  void setStyle(String styleName, String styleValue) {
    var value = node.getAttribute('style') ?? '';
    var index = 0;
    do {
      var next = value.indexOf(';', index) + 1;
      final length = next - index - 1;
      final style = length > 0
          ? value.substring(index, index + length)
          : value.substring(index);
      if (style
              .substring(0, style.indexOf(':').clamp(0, style.length))
              .trim() ==
          styleName) {
        value = value.substring(0, index).trim() +
            (next > 0 ? ' ${value.substring(next).trim()}' : '');
        break;
      }
      index = next;
    } while (index > 0);

    value += ' $styleName: $styleValue;';
    node.setAttribute('style', value.trim());
  }

  /// Dynamic style property access using camelCase JS names.
  String? operator [](String jsName) {
    final cssName = _styleMap[jsName];
    if (cssName == null) return null;
    return getStyle(cssName);
  }

  /// Dynamic style property setter using camelCase JS names.
  void operator []=(String jsName, String value) {
    final cssName = _styleMap[jsName];
    if (cssName == null) return;
    setStyle(cssName, value);
  }

  // Commonly used style properties as direct getters/setters:
  String? get display => getStyle('display');
  set display(String? value) {
    if (value != null) setStyle('display', value);
  }

  String? get fontSize => getStyle('font-size');
  set fontSize(String? value) {
    if (value != null) setStyle('font-size', value);
  }

  String? get fontWeight => getStyle('font-weight');
  set fontWeight(String? value) {
    if (value != null) setStyle('font-weight', value);
  }

  String? get width => getStyle('width');
  set width(String? value) {
    if (value != null) setStyle('width', value);
  }

  String? get height => getStyle('height');
  set height(String? value) {
    if (value != null) setStyle('height', value);
  }

  String? get cssFloat => getStyle('float');
  set cssFloat(String? value) {
    if (value != null) setStyle('float', value);
  }
}

/// A lightweight DOM parser that converts HTML strings to a DOM tree.
///
/// This parser is designed to be safe to use in isolates and provides
/// a minimal DOM implementation sufficient for Readability's needs.
///
/// Note: This is not a fully compliant HTML5 parser. Properly formed
/// HTML/XML should be used as input.
///
/// Example:
/// ```dart
/// final parser = JSDOMParser();
/// final document = parser.parse(htmlString, 'https://example.com');
/// ```

/// Internal class to hold parsed CSS selector components.
/// Parse a simple CSS selector into its components.
/// Returns null for unsupported selectors.
///
/// Supports simple selectors like:
/// - `div` (tag only)
/// - `#myId` (id only)
/// - `.myClass` (class only)
/// - `div#myId` (tag + id)
/// - `div.myClass` (tag + class)
/// - `div#myId.myClass` (tag + id + class)
///
/// Does not support:
/// - Descendant selectors (`div p`)
/// - Child selectors (`div > p`)
/// - Attribute selectors (`[type="text"]`)
/// - Pseudo-selectors (`:hover`, `::before`)
_SelectorParts? _parseSimpleSelector(String selector) {
  selector = selector.trim();

  // Empty selector is invalid
  if (selector.isEmpty) {
    return null;
  }

  // Check for unsupported selectors (spaces, brackets, colons)
  if (selector.contains(' ') ||
      selector.contains('>') ||
      selector.contains('[') ||
      selector.contains(':')) {
    return null;
  }

  String? tag;
  String? id;
  String? className;

  // Extract ID
  final idMatch = RegExp(r'#([A-Za-z0-9_-]+)').firstMatch(selector);
  if (idMatch != null) {
    id = idMatch.group(1);
    selector = selector.replaceFirst('#${idMatch.group(1)}', '');
  }

  // Extract class (only first class is supported)
  final classMatch = RegExp(r'\.([A-Za-z0-9_-]+)').firstMatch(selector);
  if (classMatch != null) {
    className = classMatch.group(1);
    selector = selector.replaceFirst('.${classMatch.group(1)}', '');
  }

  // Remove any remaining class or id patterns (for multi-class selectors like .foo.bar)
  selector = selector.replaceAll(RegExp(r'[.#][A-Za-z0-9_-]+'), '');

  // Remaining text (if any) is the tag name
  tag = selector.trim();
  if (tag.isEmpty) tag = null;

  // Must have at least one selector part
  if (tag == null && id == null && className == null) {
    return null;
  }

  return _SelectorParts(tag: tag, id: id, className: className);
}

class _SelectorParts {
  final String? tag;
  final String? id;
  final String? className;

  const _SelectorParts({this.tag, this.id, this.className});
}

class JSDOMParser {
  int _currentChar = 0;
  late String _html;
  late Document doc;
  String errorState = '';
  // Reusable buffer for building strings one char at a time.
  final List<String> _strBuf = [];
  // Reusable pair for returning from makeElementNode.
  final List<dynamic> _retPair = [null, false];

  void error(String m) {
    // ignore: avoid_print
    print('JSDOMParser error: $m\n');
    errorState += '$m\n';
  }

  /// Look at the next character without advancing the index.
  String? _peekNext() {
    if (_currentChar >= _html.length) return null;
    return _html[_currentChar];
  }

  /// Get the next character and advance the index.
  String? _nextChar() {
    if (_currentChar >= _html.length) return null;
    return _html[_currentChar++];
  }

  /// Called after a quote character is read. This finds the next quote
  /// character and returns the text string in between.
  String? _readString(String quote) {
    final n = _html.indexOf(quote, _currentChar);
    if (n == -1) {
      _currentChar = _html.length;
      return null;
    }
    final str = _html.substring(_currentChar, n);
    _currentChar = n + 1;
    return str;
  }

  /// Called when parsing a node. This finds the next name/value attribute
  /// pair and adds the result to the attributes list.
  void _readAttribute(Element node) {
    var name = '';

    final n = _html.indexOf('=', _currentChar);
    if (n == -1) {
      _currentChar = _html.length;
    } else {
      // Read until a '=' character is hit; this will be the attribute key
      name = _html.substring(_currentChar, n);
      _currentChar = n + 1;
    }

    if (name.isEmpty) {
      return;
    }

    // After a '=', we should see a '"' for the attribute value
    final c = _nextChar();
    if (c != '"' && c != "'") {
      error("Error reading attribute $name, expecting '\"'");
      return;
    }

    // Read the attribute value (and consume the matching quote)
    final value = _readString(c!);

    node.attributes.add(Attribute(name, _decodeHTML(value ?? '')));
  }

  /// Parses and returns an Element node. This is called after a '<' has been
  /// read.
  ///
  /// Returns true on success, storing the node and closed flag in [retPair].
  bool _makeElementNode(List<dynamic> retPair) {
    var c = _nextChar();

    // Read the Element tag name
    _strBuf.clear();
    while (c != null && !_whitespace.contains(c) && c != '>' && c != '/') {
      _strBuf.add(c);
      c = _nextChar();
    }
    final tag = _strBuf.join('');

    if (tag.isEmpty) {
      return false;
    }

    final node = Element(tag);

    // Read Element attributes
    while (c != '/' && c != '>') {
      if (c == null) {
        return false;
      }
      while (_currentChar < _html.length &&
          _whitespace.contains(_html[_currentChar])) {
        _currentChar++;
      }
      c = _nextChar();
      if (c != '/' && c != '>') {
        _currentChar--;
        _readAttribute(node);
      }
    }

    // If this is a self-closing tag, read '/>'
    var closed = false;
    if (c == '/') {
      closed = true;
      c = _nextChar();
      if (c != '>') {
        error("expected '>' to close $tag");
        return false;
      }
    }

    retPair[0] = node;
    retPair[1] = closed;
    return true;
  }

  /// If the current input matches this string, advance the input index;
  /// otherwise, do nothing.
  bool _match(String str) {
    final strlen = str.length;
    if (_currentChar + strlen > _html.length) return false;
    if (_html.substring(_currentChar, _currentChar + strlen).toLowerCase() ==
        str.toLowerCase()) {
      _currentChar += strlen;
      return true;
    }
    return false;
  }

  /// Skips whitespace characters at the current position.
  void _skipWhitespace() {
    while (_currentChar < _html.length &&
        _whitespace.contains(_html[_currentChar])) {
      _currentChar++;
    }
  }

  /// Reads a tag name from the current position.
  /// Returns null if not a valid tag name.
  String? _readTagName() {
    final start = _currentChar;
    while (_currentChar < _html.length) {
      final c = _html[_currentChar];
      if (_whitespace.contains(c) || c == '>' || c == '/') {
        break;
      }
      _currentChar++;
    }
    if (_currentChar == start) return null;
    return _html.substring(start, _currentChar);
  }

  /// Reads child nodes for the given node.
  void _readChildren(Node node) {
    Node? child;
    while ((child = _readNode()) != null) {
      // Don't keep Comment nodes (matches JS behavior)
      if (child!.nodeType != Node.COMMENT_NODE) {
        node.appendChild(child);
      }
    }
  }

  Comment? _readComment() {
    if (_match('--')) {
      // Standard HTML comment: <!-- ... -->
      final startPos = _currentChar;
      final endPos = _html.indexOf('-->', _currentChar);
      if (endPos == -1) {
        // Unclosed comment, read to end
        final data = _html.substring(startPos);
        _currentChar = _html.length;
        return Comment(data);
      }
      final data = _html.substring(startPos, endPos);
      _currentChar = endPos + 3; // Skip past -->
      return Comment(data);
    } else {
      // Other declaration (like <!DOCTYPE>), discard it
      var c = _nextChar();
      while (c != '>') {
        if (c == null) {
          return null;
        }
        if (c == '"' || c == "'") {
          _readString(c);
        }
        c = _nextChar();
      }
      return null; // Don't create a node for non-comment declarations
    }
  }

  /// Reads the next child node from the input. If we're reading a closing
  /// tag, or if we've reached the end of input, return null.
  Node? _readNode() {
    var c = _nextChar();

    if (c == null) {
      return null;
    }

    // Read any text as Text node
    if (c != '<') {
      _currentChar--;
      final textNode = TextNode();
      final n = _html.indexOf('<', _currentChar);
      if (n == -1) {
        textNode.innerHTML = _html.substring(_currentChar, _html.length);
        _currentChar = _html.length;
      } else {
        textNode.innerHTML = _html.substring(_currentChar, n);
        _currentChar = n;
      }
      return textNode;
    }

    if (_match('![CDATA[')) {
      final endChar = _html.indexOf(']]>', _currentChar);
      if (endChar == -1) {
        error('unclosed CDATA section');
        return null;
      }
      final textNode = TextNode();
      textNode.textContent = _html.substring(_currentChar, endChar);
      _currentChar = endChar + ']]>'.length;
      return textNode;
    }

    c = _peekNext();

    // Read Comment or declaration node.
    if (c == '!' || c == '?') {
      _currentChar++;
      final comment = _readComment();
      if (comment != null) {
        return comment;
      }
      // For non-comment declarations (like DOCTYPE), continue reading next node
      return _readNode();
    }

    // If we're reading a closing tag, check if it should be skipped
    if (c == '/') {
      // Save position (currently pointing at '/')
      final closeTagStart = _currentChar;
      _currentChar++; // Skip past '/'
      final tagName = _readTagName();
      if (tagName != null) {
        final lowerTagName = tagName.toLowerCase();
        // Skip closing tags for void elements (like </meta>) and
        // orphaned script/style closing tags (from malformed nested tags)
        if (_voidElems.contains(lowerTagName) ||
            lowerTagName == 'script' ||
            lowerTagName == 'style') {
          _skipWhitespace();
          if (_peekNext() == '>') {
            _nextChar(); // consume '>'
            return _readNode();
          }
        }
      }
      // Not a skippable closing tag, restore position and return null
      _currentChar = closeTagStart - 1; // -1 because we already consumed '<'
      return null;
    }

    // Otherwise, we're looking at an Element node
    final result = _makeElementNode(_retPair);
    if (!result) {
      return null;
    }

    final node = _retPair[0] as Element;
    final closed = _retPair[1] as bool;
    final elLocalName = node.localName;

    // If this isn't a void Element and wasn't self-closed, read its child nodes
    if (!closed && !_voidElems.contains(elLocalName)) {
      // Script and style elements have raw text content (not parsed as HTML)
      if (elLocalName == 'script' || elLocalName == 'style') {
        final closingTag = '</${node._matchingTag}>';
        // Per HTML5, </script> inside <!-- --> comments doesn't close the tag
        var searchPos = _currentChar;
        var endIdx = -1;
        while (searchPos < _html.length) {
          final idx = _html.indexOf(closingTag, searchPos);
          if (idx == -1) break;
          // Check if this closing tag is inside an HTML comment
          final contentBefore = _html.substring(_currentChar, idx);
          final lastCommentStart = contentBefore.lastIndexOf('<!--');
          final lastCommentEnd = contentBefore.lastIndexOf('-->');
          // If there's an unclosed comment before this closing tag, skip it
          if (lastCommentStart != -1 && lastCommentStart > lastCommentEnd) {
            // Find the end of this comment and continue searching after it
            final commentEnd = _html.indexOf('-->', idx);
            if (commentEnd != -1) {
              searchPos = commentEnd + 3;
              continue;
            }
          }
          endIdx = idx;
          break;
        }
        if (endIdx != -1) {
          final rawText = _html.substring(_currentChar, endIdx);
          _currentChar = endIdx + closingTag.length;
          // Only add text node if there's actual content
          if (rawText.isNotEmpty) {
            final textNode = TextNode();
            // Use setRawContent to preserve text exactly as-is
            // (no entity encoding/decoding for script/style content)
            textNode.setRawContent(rawText);
            node.appendChild(textNode);
          }
        } else {
          error("expected '$closingTag'");
          return null;
        }
      } else {
        _readChildren(node);
        final closingTag = '</${node._matchingTag}>';
        if (!_match(closingTag)) {
          final remaining = _html.length - _currentChar >= closingTag.length
              ? _html.substring(_currentChar, _currentChar + closingTag.length)
              : _html.substring(_currentChar);
          error("expected '$closingTag' and got $remaining");
          return null;
        }
      }
    }

    // Only use the first title, because SVG might have other
    // title elements which we don't care about.
    if (elLocalName == 'title' && doc.title.isEmpty) {
      doc.title = node.textContent.trim();
    } else if (elLocalName == 'head') {
      doc.head = node;
    } else if (elLocalName == 'body') {
      doc.body = node;
    } else if (elLocalName == 'html') {
      doc.documentElement = node;
    }

    return node;
  }

  /// Parses an HTML string and returns a Document object.
  ///
  /// The [html] parameter should be a well-formed HTML string.
  /// The optional [url] parameter sets the document's base URL for resolving relative links.
  ///
  /// Returns a [Document] object representing the parsed HTML tree.
  Document parse(String html, [String? url]) {
    _html = html;
    _currentChar = 0;
    errorState = '';
    doc = Document(url);
    _readChildren(doc);

    // If this is an HTML document, remove root-level children except for the
    // <html> node
    if (doc.documentElement != null) {
      for (final child in doc.childNodes.toList().reversed) {
        if (!identical(child, doc.documentElement)) {
          child.remove();
        }
      }
    }

    return doc;
  }
}

/// Extension methods for Element to provide common DOM operations.
extension ElementExtensions on Element {
  /// Returns true if the element is visible (has no display:none style).
  bool get isVisible {
    final style = getAttribute('style');
    return style == null || !style.contains('display:none');
  }

  /// Returns only Element children (filters out text nodes, etc).
  List<Element> get childrenElements =>
      childNodes.whereType<Element>().toList();

  /// Returns the text content trimmed of whitespace.
  String get trimmedText => textContent.trim();

  /// Returns true if the element has the given class name.
  bool hasClass(String className) {
    final classes = getAttribute('class')?.split(' ') ?? [];
    return className.split(' ').any((cls) => classes.contains(cls));
  }

  /// Returns true if any of the given class names are present.
  bool hasAnyClass(List<String> classNames) {
    return classNames.any((name) => hasClass(name));
  }
}
