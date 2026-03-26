import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

/// Represents a test page loaded from the test-pages/ directory.
class TestPage {
  final String dir;
  final String source;
  final String expectedContent;
  final Map<String, dynamic> expectedMetadata;

  TestPage({
    required this.dir,
    required this.source,
    required this.expectedContent,
    required this.expectedMetadata,
  });
}

/// Reads a file as a UTF-8 string and trims whitespace.
String readFileAsString(String path) {
  return File(path).readAsStringSync().trim();
}

/// Reads a JSON file and returns the decoded map.
Map<String, dynamic> readJsonFile(String path) {
  return jsonDecode(readFileAsString(path)) as Map<String, dynamic>;
}

/// Returns the path to the test-pages/ directory relative to the dart/test/
/// directory.
String get testPageRoot {
  // Resolve relative to the script/working directory.
  // When running via `dart test` from dart/, the working directory is dart/.
  final dartRoot = _findDartRoot();
  final root = Directory('$dartRoot/readability/test/test-pages');
  if (!root.existsSync()) {
    throw StateError(
      'Could not find test-pages directory. '
      'Expected at: ${root.path}',
    );
  }
  return root.path;
}

/// Find the dart project root by looking for pubspec.yaml.
String _findDartRoot() {
  // Try current working directory first
  var dir = Directory.current;
  for (var i = 0; i < 5; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  // Fallback: assume we're in the dart directory
  return Directory.current.path;
}

/// Loads all test pages from the test-pages/ directory.
///
/// Each test page directory must contain:
/// - source.html
/// - expected.html
/// - expected-metadata.json
List<TestPage> getTestPages() {
  final root = testPageRoot;
  final dirs = Directory(root)
      .listSync()
      .whereType<Directory>()
      .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
      .toList()
    ..sort();

  return dirs.map((dir) {
    final dirPath = '$root/$dir';
    return TestPage(
      dir: dir,
      source: readFileAsString('$dirPath/source.html'),
      expectedContent: readFileAsString('$dirPath/expected.html'),
      expectedMetadata: readJsonFile('$dirPath/expected-metadata.json'),
    );
  }).toList();
}

/// Collapses subsequent whitespace like HTML rendering does.
/// Also trims leading/trailing whitespace to normalize differences between
/// parser serialization formats (JSDOMParser vs html package).
String htmlTransform(String str) {
  return str.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Pretty-prints HTML for comparison, matching js-beautify behavior.
///
/// Block-level elements get indentation on separate lines. Inline elements
/// and text stay on the same line. This matches how js-beautify formats the
/// expected.html files in the JS test suite.
String prettyPrint(String htmlString) {
  final doc = html_parser.parseFragment(htmlString);
  final buffer = StringBuffer();
  _writeNode(buffer, doc, 0, false);
  return buffer.toString();
}

const _blockElements = {
  'address',
  'article',
  'aside',
  'blockquote',
  'body',
  'dd',
  'details',
  'dialog',
  'div',
  'dl',
  'dt',
  'fieldset',
  'figcaption',
  'figure',
  'footer',
  'form',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'head',
  'header',
  'hgroup',
  'hr',
  'html',
  'li',
  'main',
  'meta',
  'nav',
  'ol',
  'p',
  'pre',
  'section',
  'summary',
  'table',
  'tbody',
  'td',
  'tfoot',
  'th',
  'thead',
  'tr',
  'ul',
};

void _writeNode(
    StringBuffer buffer, html_dom.Node node, int indent, bool needsIndent) {
  if (node is html_dom.Text) {
    final text = node.text;
    if (text.trim().isNotEmpty) {
      // Normalize whitespace to match HTML rendering (collapse whitespace
      // sequences to single spaces). This ensures consistent comparison
      // between the actual output and the expected.html files which were
      // formatted by js-beautify (which may add extra whitespace/newlines).
      var normalized = text.replaceAll(RegExp(r'\s+'), ' ');
      // If this text node is the last child of a block element (or followed
      // only by whitespace-only text nodes), trim its trailing whitespace.
      // This accounts for indentation added by js-beautify before closing
      // block tags in the expected.html files.
      final parent = node.parentNode;
      if (parent != null &&
          parent is html_dom.Element &&
          _blockElements.contains(parent.localName)) {
        final siblings = parent.nodes;
        final idx = siblings.indexOf(node);
        var isLastSignificant = true;
        for (var i = idx + 1; i < siblings.length; i++) {
          if (siblings[i] is html_dom.Text &&
              (siblings[i] as html_dom.Text).text.trim().isEmpty) {
            continue;
          }
          isLastSignificant = false;
          break;
        }
        if (isLastSignificant) {
          normalized = normalized.trimRight();
        }
      }
      if (normalized.isNotEmpty) {
        buffer.write(normalized);
      }
    }
  } else if (node is html_dom.Element) {
    final isBlock = _blockElements.contains(node.localName);
    if (isBlock && needsIndent) {
      buffer.write('\n${'    ' * indent}');
    }
    buffer.write('<${node.localName!}');
    final attrs = node.attributes.keys.toList()
      ..sort((a, b) => a.toString().compareTo(b.toString()));
    for (final key in attrs) {
      buffer.write(' $key="${node.attributes[key]}"');
    }
    if (_voidElements.contains(node.localName) && node.nodes.isEmpty) {
      buffer.write('>');
      return;
    }
    buffer.write('>');
    var childNeedsIndent = false;
    for (final child in node.nodes) {
      _writeNode(buffer, child, indent + 1, childNeedsIndent);
      childNeedsIndent = true;
    }
    // Add newline+indent before closing block tag (matches js-beautify)
    if (isBlock && node.nodes.isNotEmpty) {
      buffer.write('\n${'    ' * indent}');
    }
    buffer.write('</${node.localName!}>');
  } else if (node is html_dom.DocumentFragment) {
    var childNeedsIndent = false;
    for (final child in node.nodes) {
      _writeNode(buffer, child, indent, childNeedsIndent);
      childNeedsIndent = true;
    }
  }
}

const _voidElements = {
  'area',
  'base',
  'br',
  'col',
  'embed',
  'hr',
  'img',
  'input',
  'link',
  'meta',
  'param',
  'source',
  'track',
  'wbr',
};

/// In-order traversal: returns the first child if it exists, otherwise
/// walks up parent chain to find the next sibling.
html_dom.Node? inOrderTraverse(html_dom.Node? fromNode) {
  if (fromNode == null) return null;
  if (fromNode.nodes.isNotEmpty) {
    return fromNode.nodes.first;
  }
  while (fromNode != null) {
    final parent = fromNode.parentNode;
    if (parent == null) return null;
    final siblings = parent.nodes;
    final idx = siblings.indexOf(fromNode);
    if (idx >= 0 && idx < siblings.length - 1) {
      return siblings[idx + 1];
    }
    fromNode = parent;
  }
  return null;
}

/// In-order traversal that skips empty text nodes.
html_dom.Node? inOrderIgnoreEmptyTextNodes(html_dom.Node? fromNode) {
  do {
    fromNode = inOrderTraverse(fromNode);
  } while (fromNode != null &&
      fromNode is html_dom.Text &&
      fromNode.text.trim().isEmpty);
  return fromNode;
}

/// Traverses two DOM trees in parallel, calling [callback] for each pair
/// of nodes. Returns when callback returns false or both trees are exhausted.
void traverseDOM(
  bool Function(html_dom.Node? actual, html_dom.Node? expected) callback,
  html_dom.Node expectedDOM,
  html_dom.Node actualDOM,
) {
  html_dom.Node? actualNode = _getFirstElement(actualDOM);
  html_dom.Node? expectedNode = _getFirstElement(expectedDOM);

  while (actualNode != null || expectedNode != null) {
    if (!callback(actualNode, expectedNode)) {
      break;
    }
    actualNode = inOrderIgnoreEmptyTextNodes(actualNode);
    expectedNode = inOrderIgnoreEmptyTextNodes(expectedNode);
  }
}

html_dom.Node? _getFirstElement(html_dom.Node node) {
  if (node is html_dom.Document) {
    return node.documentElement;
  }
  if (node is html_dom.DocumentFragment && node.nodes.isNotEmpty) {
    return node.nodes.first;
  }
  if (node.nodes.isNotEmpty) {
    return node.nodes.first;
  }
  return null;
}

/// Returns a human-readable string for a DOM node, for test output.
String nodeStr(html_dom.Node? n) {
  if (n == null) return '(no node)';
  if (n is html_dom.Text) {
    return '#text(${htmlTransform(n.text)})';
  }
  if (n is html_dom.Element) {
    var rv = n.localName!;
    if (n.id.isNotEmpty) {
      rv += '#${n.id}';
    }
    final className = n.className;
    if (className.isNotEmpty) {
      rv += '.($className)';
    }
    return rv;
  }
  return 'node(type=${n.nodeType})';
}

/// Generates a CSS-like path to a node for debugging.
String genPath(html_dom.Node node) {
  if (node is html_dom.Element && node.id.isNotEmpty) {
    return '#${node.id}';
  }
  if (node is html_dom.Element && node.localName?.toUpperCase() == 'BODY') {
    return 'body';
  }
  final parent = node.parentNode;
  if (parent == null) return 'root';
  final parentPath = genPath(parent);
  final index = parent.nodes.indexOf(node) + 1;
  return '$parentPath > ${nodeStr(node)}:nth-child($index)';
}

/// Returns a description of a node that can be found in the DOM.
String findableNodeDesc(html_dom.Node node) {
  final parent = node.parentNode;
  final parentHtml = parent is html_dom.Element ? parent.innerHtml : '';
  return '${genPath(node)}(in: ``$parentHtml``)';
}

/// Returns sorted attribute key=value pairs for a node.
List<String> attributesForNode(html_dom.Element node) {
  return node.attributes.entries.map((e) => '${e.key}=${e.value}').toList()
    ..sort();
}

/// Removes comment nodes recursively from the DOM tree.
void removeCommentNodesRecursively(html_dom.Node node) {
  final toRemove = <html_dom.Node>[];
  for (final child in node.nodes) {
    if (child is html_dom.Comment) {
      toRemove.add(child);
    } else if (child is html_dom.Element) {
      removeCommentNodesRecursively(child);
    }
  }
  for (final child in toRemove) {
    child.remove();
  }
}
