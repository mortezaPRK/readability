// Copyright (c) 2024 Dart Readability contributors
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.

/// DOM adapter interfaces that normalize APIs between different DOM parsers.
///
/// This allows Readability to work with both JSDOMParser and the html package.
///
/// ## Why Mutating Methods?
///
/// The DOM API is inherently mutable - Readability.js modifies the DOM tree
/// during parsing to clean up content, remove clutter, and restructure
/// elements. These setters and methods mirror the JavaScript DOM API:
///
/// - `textContent` setter: Replace node content with text
/// - `innerHTML` setter: Replace node content with parsed HTML
/// - `appendChild`, `insertBefore`, `removeChild`, `replaceChild`: Tree manipulation
/// - `setAttribute`, `removeAttribute`: Attribute modification
/// - `id`, `className` setters: Common attribute shortcuts
///
/// This mutability is required for Readability's content extraction algorithm.
library;

/// Node type constants matching the DOM specification.
enum NodeType {
  unknown(-1),
  element(1),
  attribute(2),
  text(3),
  cdataSection(4),
  entityReference(5),
  entity(6),
  processingInstruction(7),
  comment(8),
  document(9),
  documentType(10),
  documentFragment(11),
  notation(12);

  const NodeType(this.value);
  final int value;

  static NodeType fromInt(int value) {
    return NodeType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NodeType.unknown,
    );
  }
}

/// Special node names for non-element nodes.
enum SpecialNodeName {
  unknown('#unknown'),
  text('#text'),
  comment('#comment'),
  document('#document'),
  documentFragment('#document-fragment');

  const SpecialNodeName(this.value);
  final String value;
}

/// Base interface for all DOM nodes.
abstract class DomNode {
  /// The type of node (element, text, comment, etc.).
  NodeType get nodeType;

  /// The name of the node.
  ///
  /// For elements, returns the uppercase tag name (e.g., 'DIV', 'P').
  /// For text nodes, returns '#text'.
  /// For comments, returns '#comment'.
  /// For documents, returns '#document'.
  String? get nodeName;

  /// The parent node of this node.
  DomNode? get parentNode;

  /// The parent element of this node, or null if parent is not an element.
  DomElement? get parentElement;

  /// The text content of this node and its descendants.
  String? get textContent;

  /// Sets the text content, replacing all children with a single text node.
  set textContent(String? value);

  /// The HTML content of this node's children.
  String get innerHTML;

  /// Sets the HTML content, parsing the string and replacing all children.
  set innerHTML(String value);

  /// The child nodes of this node.
  List<DomNode> get childNodes;

  /// The first child node, or null if no children.
  DomNode? get firstChild;

  /// The last child node, or null if no children.
  DomNode? get lastChild;

  /// The next sibling node.
  DomNode? get nextSibling;

  /// The previous sibling node.
  DomNode? get previousSibling;

  /// The element children of this node (excludes text nodes, etc.).
  List<DomElement> get children;

  /// The first element child, or null if no element children.
  DomElement? get firstElementChild;

  /// The last element child, or null if no element children.
  DomElement? get lastElementChild;

  /// Appends a child node to this node's children.
  DomNode appendChild(DomNode child);

  /// Inserts a node before a reference node in the children list.
  DomNode insertBefore(DomNode newNode, DomNode? referenceNode);

  /// Removes this node from its parent.
  DomNode remove();

  /// Removes a child node from this node's children.
  DomNode removeChild(DomNode child);

  /// Replaces a child node with a new node.
  DomNode replaceChild(DomNode newNode, DomNode oldNode);

  /// Gets all descendant elements with the specified tag name.
  List<DomElement> getElementsByTagName(String tag);

  /// Returns the first descendant element matching the selector.
  DomElement? querySelector(String selectors);

  /// Returns all descendant elements matching the selector.
  List<DomElement> querySelectorAll(String selectors);
}

/// Interface for an HTML element node.
abstract class DomElement extends DomNode {
  /// The tag name of the element in uppercase (e.g., 'DIV', 'P').
  String get tagName;

  /// The local name of the element (lowercase).
  String? get localName;

  /// The ID attribute value.
  String get id;

  /// Sets the ID attribute value.
  set id(String value);

  /// The class attribute value (space-separated class names).
  String get className;

  /// Sets the class attribute value.
  set className(String value);

  /// Gets an attribute value by name.
  String? getAttribute(String name);

  /// Sets an attribute value.
  void setAttribute(String name, String value);

  /// Removes an attribute.
  void removeAttribute(String name);

  /// Checks if an attribute exists.
  bool hasAttribute(String name);

  /// The list of attributes.
  List<DomAttribute> get attributes;

  /// The next element sibling.
  DomElement? get nextElementSibling;

  /// The previous element sibling.
  DomElement? get previousElementSibling;
}

/// Interface for a document node.
abstract class DomDocument extends DomNode {
  /// Returns true if this document is backed by JSDOMParser.
  bool get isJSDOMParser;

  /// The document title (from the title element).
  String? get title;

  /// Sets the document title.
  set title(String? value);

  /// The base URI for resolving relative URLs.
  String get baseURI;

  /// The document URI (if available).
  String? get documentURI;

  /// The body element.
  DomElement? get body;

  /// Sets the body element, replacing the existing one.
  set body(DomElement? value);

  /// The head element.
  DomElement? get head;

  /// Sets the head element, replacing the existing one.
  set head(DomElement? value);

  /// The document element (root element, typically `html` element).
  DomElement? get documentElement;

  /// Creates a new element with the specified tag name.
  DomElement createElement(String tagName);

  /// Creates a new text node with the specified text.
  DomNode createTextNode(String text);

  /// Creates a new document fragment.
  DomDocumentFragment createDocumentFragment();

  /// Gets an element by its ID.
  DomElement? getElementById(String id);
}

/// Interface for a document fragment node.
abstract class DomDocumentFragment extends DomNode {}

/// Interface for an attribute.
abstract class DomAttribute {
  /// The attribute name.
  String get name;

  /// The attribute value.
  String get value;

  /// Sets the attribute value.
  set value(String newValue);
}

/// CSS style interface for element styles.
abstract class DomStyle {
  /// Gets a style property value.
  String? getStyle(String styleName);

  /// Sets a style property value.
  void setStyle(String styleName, String styleValue);

  /// Dynamic style property access using camelCase JS names.
  String? operator [](String jsName);

  /// Dynamic style property setter using camelCase JS names.
  void operator []=(String jsName, String value);
}
