// Copyright (c) 2024 Dart Readability contributors
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.

/// JSDOMParser adapter that wraps JSDOMParser types to implement the DOM adapter interfaces.
library;

import '../dom_adapter.dart';
import '../jsdom_parser.dart' as jsdom;

/// Maps JSDOMParser node type to NodeType enum.
NodeType _mapNodeType(jsdom.Node node) {
  return switch (node.nodeType) {
    jsdom.Node.ELEMENT_NODE => NodeType.element,
    jsdom.Node.TEXT_NODE => NodeType.text,
    jsdom.Node.COMMENT_NODE => NodeType.comment,
    jsdom.Node.DOCUMENT_NODE => NodeType.document,
    jsdom.Node.DOCUMENT_FRAGMENT_NODE => NodeType.documentFragment,
    _ => NodeType.unknown,
  };
}

/// Adapter for JSDOMParser Node.
class JsdomDomNode implements DomNode {
  final jsdom.Node _node;

  JsdomDomNode(this._node);

  @override
  List<DomNode> get childNodes =>
      _node.childNodes.map((n) => _wrapNode(n)).toList();

  @override
  DomNode? get firstChild =>
      _node.firstChild != null ? _wrapNode(_node.firstChild!) : null;

  @override
  DomNode? get lastChild =>
      _node.lastChild != null ? _wrapNode(_node.lastChild!) : null;

  @override
  String? get nodeName => _node.nodeName;

  @override
  NodeType get nodeType => _mapNodeType(_node);

  @override
  DomNode? get parentNode =>
      _node.parentNode != null ? _wrapNode(_node.parentNode!) : null;

  @override
  DomElement? get parentElement {
    final parent = _node.parentNode;
    if (parent is jsdom.Element) {
      return JsdomDomElement(parent);
    }
    return null;
  }

  @override
  String? get textContent => _node.textContent;

  @override
  set textContent(String? value) {
    _node.textContent = value ?? '';
  }

  @override
  String get innerHTML => _node.innerHTML;

  @override
  set innerHTML(String value) {
    _node.innerHTML = value;
  }

  @override
  DomNode? get nextSibling =>
      _node.nextSibling != null ? _wrapNode(_node.nextSibling!) : null;

  @override
  DomNode? get previousSibling =>
      _node.previousSibling != null ? _wrapNode(_node.previousSibling!) : null;

  @override
  List<DomElement> get children =>
      _node.children.map((e) => JsdomDomElement(e)).toList();

  @override
  DomElement? get firstElementChild {
    final first = _node.firstElementChild;
    return first != null ? JsdomDomElement(first) : null;
  }

  @override
  DomElement? get lastElementChild {
    final last = _node.lastElementChild;
    return last != null ? JsdomDomElement(last) : null;
  }

  @override
  DomNode appendChild(DomNode child) {
    final unwrapped = _unwrapNode(child);
    _node.appendChild(unwrapped);
    return child;
  }

  @override
  DomNode insertBefore(DomNode newNode, DomNode? referenceNode) {
    final unwrappedNew = _unwrapNode(newNode);
    final unwrappedRef =
        referenceNode != null ? _unwrapNode(referenceNode) : null;
    _node.insertBefore(unwrappedNew, unwrappedRef);
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
    _node.removeChild(unwrapped);
    return child;
  }

  @override
  DomNode replaceChild(DomNode newNode, DomNode oldNode) {
    final unwrappedNew = _unwrapNode(newNode);
    final unwrappedOld = _unwrapNode(oldNode);
    _node.replaceChild(unwrappedNew, unwrappedOld);
    return oldNode;
  }

  @override
  List<DomElement> getElementsByTagName(String tag) {
    if (_node case jsdom.Element element) {
      return element
          .getElementsByTagName(tag)
          .map((e) => JsdomDomElement(e))
          .toList();
    } else if (_node case jsdom.Document document) {
      return document
          .getElementsByTagName(tag)
          .map((e) => JsdomDomElement(e))
          .toList();
    }
    return [];
  }

  @override
  DomElement? querySelector(String selectors) {
    if (_node case jsdom.Element element) {
      final result = element.querySelector(selectors);
      return result != null ? JsdomDomElement(result) : null;
    } else if (_node case jsdom.Document document) {
      final result = document.querySelector(selectors);
      return result != null ? JsdomDomElement(result) : null;
    }
    return null;
  }

  @override
  List<DomElement> querySelectorAll(String selectors) {
    if (_node case jsdom.Element element) {
      return element
          .querySelectorAll(selectors)
          .map((e) => JsdomDomElement(e))
          .toList();
    } else if (_node case jsdom.Document document) {
      return document
          .querySelectorAll(selectors)
          .map((e) => JsdomDomElement(e))
          .toList();
    }
    return [];
  }

  /// Wraps a JSDOMParser Node in the appropriate adapter.
  static DomNode _wrapNode(jsdom.Node node) {
    if (node is jsdom.Element) {
      return JsdomDomElement(node);
    }
    return JsdomDomNode(node);
  }

  /// Unwraps an adapter to get the underlying JSDOMParser Node.
  static jsdom.Node _unwrapNode(DomNode node) {
    if (node is JsdomDomNode) {
      return node._node;
    }
    throw ArgumentError('Node is not a JSDOMParser adapter: $node');
  }

  /// Gets the underlying JSDOMParser node.
  jsdom.Node get unwrap => _node;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JsdomDomNode && identical(_node, other._node);
  }

  @override
  int get hashCode => identityHashCode(_node);
}

/// Adapter for JSDOMParser Element.
class JsdomDomElement extends JsdomDomNode implements DomElement {
  jsdom.Element get _element => _node as jsdom.Element;

  JsdomDomElement(super.element);

  @override
  String get tagName => _element.tagName;

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
  String? getAttribute(String name) => _element.getAttribute(name);

  @override
  void setAttribute(String name, String value) {
    _element.setAttribute(name, value);
  }

  @override
  void removeAttribute(String name) {
    _element.removeAttribute(name);
  }

  @override
  bool hasAttribute(String name) => _element.hasAttribute(name);

  @override
  List<DomAttribute> get attributes =>
      _element.attributes.map((a) => JsdomDomAttribute(a)).toList();

  @override
  DomElement? get nextElementSibling {
    final next = _element.nextElementSibling;
    return next != null ? JsdomDomElement(next) : null;
  }

  @override
  DomElement? get previousElementSibling {
    final prev = _element.previousElementSibling;
    return prev != null ? JsdomDomElement(prev) : null;
  }
}

/// Adapter for JSDOMParser Document.
class JsdomDomDocument extends JsdomDomNode implements DomDocument {
  jsdom.Document get _doc => _node as jsdom.Document;

  JsdomDomDocument(super.document);

  /// Gets the underlying JSDOMParser document.
  @override
  jsdom.Document get unwrap => _doc;

  @override
  bool get isJSDOMParser => true;

  @override
  String? get title => _doc.title;

  @override
  set title(String? value) {
    _doc.title = value ?? '';
  }

  @override
  String get baseURI => _doc.baseURI;

  @override
  String? get documentURI => _doc.documentURI;

  @override
  DomElement? get body {
    final body = _doc.body;
    return body != null ? JsdomDomElement(body) : null;
  }

  @override
  set body(DomElement? value) {
    if (value == null) {
      _doc.body = null;
    } else if (value is JsdomDomElement) {
      _doc.body = value._element;
    } else {
      throw ArgumentError('Element is not a JSDOMParser adapter');
    }
  }

  @override
  DomElement? get head {
    final head = _doc.head;
    return head != null ? JsdomDomElement(head) : null;
  }

  @override
  set head(DomElement? value) {
    if (value == null) {
      _doc.head = null;
    } else if (value is JsdomDomElement) {
      _doc.head = value._element;
    } else {
      throw ArgumentError('Element is not a JSDOMParser adapter');
    }
  }

  @override
  DomElement? get documentElement {
    final root = _doc.documentElement;
    return root != null ? JsdomDomElement(root) : null;
  }

  @override
  DomElement createElement(String tagName) {
    return JsdomDomElement(_doc.createElement(tagName));
  }

  @override
  DomNode createTextNode(String text) {
    return JsdomDomNode(_doc.createTextNode(text));
  }

  @override
  DomDocumentFragment createDocumentFragment() {
    return JsdomDomDocumentFragment(_doc.createDocumentFragment());
  }

  @override
  DomElement? getElementById(String id) {
    final element = _doc.getElementById(id);
    return element != null ? JsdomDomElement(element) : null;
  }
}

/// Adapter for JSDOMParser DocumentFragment.
class JsdomDomDocumentFragment extends JsdomDomNode
    implements DomDocumentFragment {
  JsdomDomDocumentFragment(super.fragment);
}

/// Adapter for JSDOMParser Attribute.
class JsdomDomAttribute implements DomAttribute {
  final jsdom.Attribute _attribute;

  JsdomDomAttribute(this._attribute);

  @override
  String get name => _attribute.name;

  @override
  String get value => _attribute.value;

  @override
  set value(String newValue) {
    _attribute.setValue(newValue);
  }
}
