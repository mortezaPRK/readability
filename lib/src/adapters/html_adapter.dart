// Copyright (c) 2024 Dart Readability contributors
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.

/// HTML package adapter that wraps html package types to implement the DOM adapter interfaces.
library;

import 'package:html/dom.dart' as html;
import '../dom_adapter.dart';

/// Maps html package node type to NodeType enum.
NodeType _mapNodeType(html.Node node) {
  return switch (node.nodeType) {
    html.Node.ELEMENT_NODE => NodeType.element,
    html.Node.TEXT_NODE => NodeType.text,
    html.Node.COMMENT_NODE => NodeType.comment,
    html.Node.DOCUMENT_NODE => NodeType.document,
    html.Node.DOCUMENT_FRAGMENT_NODE => NodeType.documentFragment,
    html.Node.DOCUMENT_TYPE_NODE => NodeType.documentType,
    _ => NodeType.unknown,
  };
}

/// Maps html package node to a node name string.
String? _mapNodeName(html.Node node) {
  return switch (node) {
    html.Text() => SpecialNodeName.text.value,
    html.Comment() => SpecialNodeName.comment.value,
    html.Document() => SpecialNodeName.document.value,
    html.DocumentFragment() => SpecialNodeName.documentFragment.value,
    html.Element() => node.localName?.toUpperCase(),
    _ => SpecialNodeName.unknown.value,
  };
}

/// Adapter for html package Node.
class HtmlDomNode implements DomNode {
  final html.Node _node;

  HtmlDomNode(this._node);

  @override
  List<DomNode> get childNodes => _node.nodes.map((n) => _wrapNode(n)).toList();

  @override
  DomNode? get firstChild =>
      _node.nodes.isNotEmpty ? _wrapNode(_node.nodes.first) : null;

  @override
  DomNode? get lastChild =>
      _node.nodes.isNotEmpty ? _wrapNode(_node.nodes.last) : null;

  @override
  String? get nodeName => _mapNodeName(_node);

  @override
  NodeType get nodeType => _mapNodeType(_node);

  @override
  DomNode? get parentNode =>
      _node.parent != null ? _wrapNode(_node.parent!) : null;

  @override
  DomElement? get parentElement {
    final parent = _node.parent;
    if (parent is html.Element) {
      return HtmlDomElement(parent);
    }
    return null;
  }

  @override
  String? get textContent {
    if (_node case html.Text text) {
      return text.text;
    } else if (_node case html.Element element) {
      return element.text;
    }
    return null;
  }

  @override
  set textContent(String? value) {
    if (_node case html.Element element) {
      element.text = value ?? '';
    }
  }

  @override
  String get innerHTML {
    if (_node case html.Element element) {
      return element.innerHtml;
    }
    return '';
  }

  @override
  set innerHTML(String value) {
    if (_node case html.Element element) {
      element.innerHtml = value;
    }
  }

  @override
  DomNode? get nextSibling {
    if (_node.parent == null) return null;
    final siblings = _node.parent!.nodes;
    final index = siblings.indexOf(_node);
    if (index >= 0 && index < siblings.length - 1) {
      return _wrapNode(siblings[index + 1]);
    }
    return null;
  }

  @override
  DomNode? get previousSibling {
    if (_node.parent == null) return null;
    final siblings = _node.parent!.nodes;
    final index = siblings.indexOf(_node);
    if (index > 0) {
      return _wrapNode(siblings[index - 1]);
    }
    return null;
  }

  @override
  List<DomElement> get children {
    if (_node case html.Element element) {
      return element.children.map((e) => HtmlDomElement(e)).toList();
    }
    return [];
  }

  @override
  DomElement? get firstElementChild {
    if (_node case html.Element element) {
      final first = element.children.firstOrNull;
      return first != null ? HtmlDomElement(first) : null;
    }
    return null;
  }

  @override
  DomElement? get lastElementChild {
    if (_node case html.Element element) {
      final last = element.children.lastOrNull;
      return last != null ? HtmlDomElement(last) : null;
    }
    return null;
  }

  @override
  DomNode appendChild(DomNode child) {
    final unwrapped = _unwrapNode(child);
    _node.append(unwrapped);
    return child;
  }

  @override
  DomNode insertBefore(DomNode newNode, DomNode? referenceNode) {
    final unwrappedNew = _unwrapNode(newNode);
    if (referenceNode != null) {
      final unwrappedRef = _unwrapNode(referenceNode);
      _node.insertBefore(unwrappedNew, unwrappedRef);
    } else {
      _node.append(unwrappedNew);
    }
    return newNode;
  }

  @override
  DomNode remove() {
    _node.remove();
    return this;
  }

  @override
  DomNode removeChild(DomNode child) {
    final unwrapped = _unwrapNode(child);
    unwrapped.remove();
    return child;
  }

  @override
  DomNode replaceChild(DomNode newNode, DomNode oldNode) {
    final unwrappedNew = _unwrapNode(newNode);
    final unwrappedOld = _unwrapNode(oldNode);
    unwrappedOld.replaceWith(unwrappedNew);
    return oldNode;
  }

  @override
  List<DomElement> getElementsByTagName(String tag) {
    if (_node case html.Element element) {
      return element
          .getElementsByTagName(tag)
          .map((e) => HtmlDomElement(e))
          .toList();
    } else if (_node case html.Document document) {
      return document
          .getElementsByTagName(tag)
          .map((e) => HtmlDomElement(e))
          .toList();
    }
    return [];
  }

  @override
  DomElement? querySelector(String selectors) {
    if (_node case html.Element element) {
      final result = element.querySelector(selectors);
      return result != null ? HtmlDomElement(result) : null;
    } else if (_node case html.Document document) {
      final result = document.querySelector(selectors);
      return result != null ? HtmlDomElement(result) : null;
    }
    return null;
  }

  @override
  List<DomElement> querySelectorAll(String selectors) {
    if (_node case html.Element element) {
      return element
          .querySelectorAll(selectors)
          .map((e) => HtmlDomElement(e))
          .toList();
    } else if (_node case html.Document document) {
      return document
          .querySelectorAll(selectors)
          .map((e) => HtmlDomElement(e))
          .toList();
    }
    return [];
  }

  /// Wraps an html package Node in the appropriate adapter.
  static DomNode _wrapNode(html.Node node) {
    if (node is html.Element) {
      return HtmlDomElement(node);
    }
    return HtmlDomNode(node);
  }

  /// Unwraps an adapter to get the underlying html package Node.
  static html.Node _unwrapNode(DomNode node) {
    if (node is HtmlDomNode) {
      return node._node;
    }
    throw ArgumentError('Node is not an html package adapter: $node');
  }

  /// Gets the underlying html package node.
  html.Node get unwrap => _node;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HtmlDomNode && identical(_node, other._node);
  }

  @override
  int get hashCode => identityHashCode(_node);
}

/// Adapter for html package Element.
class HtmlDomElement extends HtmlDomNode implements DomElement {
  html.Element get _element => _node as html.Element;

  HtmlDomElement(super.element);

  @override
  String get tagName => _element.localName?.toUpperCase() ?? '';

  @override
  String? get localName => _element.localName;

  @override
  String get id => _element.id;

  @override
  set id(String value) {
    _element.id = value;
  }

  @override
  String get className => _element.className;

  @override
  set className(String value) {
    _element.className = value;
  }

  @override
  String? getAttribute(String name) => _element.attributes[name];

  @override
  void setAttribute(String name, String value) {
    _element.attributes[name] = value;
  }

  @override
  void removeAttribute(String name) {
    _element.attributes.remove(name);
  }

  @override
  bool hasAttribute(String name) => _element.attributes.containsKey(name);

  @override
  List<DomAttribute> get attributes => _element.attributes.entries
      .map((e) => HtmlDomAttribute(e.key.toString(), e.value))
      .toList();

  @override
  DomElement? get nextElementSibling {
    final next = _element.nextElementSibling;
    return next != null ? HtmlDomElement(next) : null;
  }

  @override
  DomElement? get previousElementSibling {
    final prev = _element.previousElementSibling;
    return prev != null ? HtmlDomElement(prev) : null;
  }
}

/// Adapter for html package Document.
class HtmlDomDocument extends HtmlDomNode implements DomDocument {
  html.Document get _doc => _node as html.Document;

  HtmlDomDocument(super.document);

  /// Gets the underlying html package document.
  @override
  html.Document get unwrap => _doc;

  @override
  bool get isJSDOMParser => false;

  @override
  String? get title {
    final titleEl = _doc.querySelector('title');
    return titleEl?.text;
  }

  @override
  set title(String? value) {
    html.Element titleEl =
        _doc.querySelector('title') ?? _doc.createElement('title');
    if (titleEl.parent == null) {
      final head = _doc.head;
      if (head != null) {
        head.append(titleEl);
      }
    }
    titleEl.text = value ?? '';
  }

  @override
  String get baseURI => ''; // html package doesn't have baseUri

  @override
  String? get documentURI => null; // html package doesn't have documentURI

  @override
  DomElement? get body {
    final body = _doc.body;
    return body != null ? HtmlDomElement(body) : null;
  }

  /// **Note**: Setting body is not supported by the html package adapter.
  ///
  /// The html package doesn't provide a way to replace the body element.
  /// If you need to modify document structure, use JSDOMParser instead.
  ///
  /// This setter is a no-op and will silently ignore the value.
  @override
  set body(DomElement? value) {
    // html package doesn't allow setting body directly.
    // This is a known limitation - no-op for compatibility.
  }

  @override
  DomElement? get head {
    final head = _doc.head;
    return head != null ? HtmlDomElement(head) : null;
  }

  /// **Note**: Setting head is not supported by the html package adapter.
  ///
  /// The html package doesn't provide a way to replace the head element.
  /// If you need to modify document structure, use JSDOMParser instead.
  ///
  /// This setter is a no-op and will silently ignore the value.
  @override
  set head(DomElement? value) {
    // html package doesn't allow setting head directly.
    // This is a known limitation - no-op for compatibility.
  }

  @override
  DomElement? get documentElement {
    final html = _doc.documentElement;
    return html != null ? HtmlDomElement(html) : null;
  }

  @override
  DomElement createElement(String tagName) {
    return HtmlDomElement(_doc.createElement(tagName));
  }

  @override
  DomNode createTextNode(String text) {
    return HtmlDomNode(html.Text(text));
  }

  @override
  DomDocumentFragment createDocumentFragment() {
    return HtmlDomDocumentFragment(_doc.createDocumentFragment());
  }

  @override
  DomElement? getElementById(String id) {
    final element = _doc.getElementById(id);
    return element != null ? HtmlDomElement(element) : null;
  }
}

/// Adapter for html package DocumentFragment.
class HtmlDomDocumentFragment extends HtmlDomNode
    implements DomDocumentFragment {
  HtmlDomDocumentFragment(super.fragment);
}

/// Adapter for html package attributes.
class HtmlDomAttribute implements DomAttribute {
  final String _name;
  String _value;

  HtmlDomAttribute(this._name, this._value);

  @override
  String get name => _name;

  @override
  String get value => _value;

  @override
  set value(String newValue) {
    _value = newValue;
  }
}
