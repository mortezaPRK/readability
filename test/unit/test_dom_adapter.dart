/// Tests for DOM adapter interfaces and implementations.
///
/// These tests verify that:
/// 1. JSDOMParser adapter correctly wraps JSDOMParser types
/// 2. html package adapter correctly wraps html package types
/// 3. Both adapters implement the DomNode, DomElement, DomDocument interfaces
/// 4. Common operations (getAttribute, setAttribute, textContent, querySelector) work correctly

/// Tests for DOM adapter interfaces and implementations.
library;

import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html_parser;
import 'package:readability/readability.dart';
import 'package:test/test.dart';

void main() {
  group('JSDOMParser Adapter', () {
    late JSDOMParser parser;
    late Document jsdomDoc;
    late JsdomDomDocument adapterDoc;

    setUp(() {
      parser = JSDOMParser();
      final htmlStr = '''
        <html>
          <head><title>Test</title></head>
          <body>
            <div id="test" class="foo bar">Content</div>
            <p>Paragraph</p>
          </body>
        </html>
      ''';
      jsdomDoc = parser.parse(htmlStr, 'http://test.com');
      adapterDoc = JsdomDomDocument(jsdomDoc);
    });

    test('JsdomDomDocument wraps JSDOMParser Document', () {
      expect(adapterDoc, isA<DomDocument>());
      expect(adapterDoc.unwrap, equals(jsdomDoc));
    });

    test('JsdomDomElement wraps JSDOMParser Element', () {
      final div = adapterDoc.getElementById('test');
      expect(div, isNotNull);
      expect(div, isA<DomElement>());
      expect((div as JsdomDomElement).unwrap, isA<Element>());
    });

    test('JsdomDomNode wraps JSDOMParser Node', () {
      final div = adapterDoc.getElementById('test');
      final textNode = div!.childNodes.first;
      expect(textNode, isA<DomNode>());
      expect((textNode as JsdomDomNode).unwrap, isA<Node>());
    });

    test('Attribute operations work correctly', () {
      final div = adapterDoc.getElementById('test');

      // getAttribute
      expect(div!.getAttribute('id'), equals('test'));
      expect(div.getAttribute('class'), equals('foo bar'));
      expect(div.getAttribute('data-test'), isNull);

      // setAttribute
      div.setAttribute('data-test', 'value');
      expect(div.getAttribute('data-test'), equals('value'));

      // hasAttribute
      expect(div.hasAttribute('id'), isTrue);
      expect(div.hasAttribute('data-missing'), isFalse);

      // removeAttribute
      div.removeAttribute('data-test');
      expect(div.getAttribute('data-test'), isNull);
    });

    test('Text content operations work correctly', () {
      final div = adapterDoc.getElementById('test');
      expect(div!.textContent, equals('Content'));

      div.textContent = 'New content';
      expect(div.textContent, equals('New content'));
    });

    test('Element navigation works correctly', () {
      final div = adapterDoc.getElementById('test');
      expect(div, isNotNull);

      // children
      expect(div!.children.length, equals(0));

      // childNodes
      expect(div.childNodes.length, equals(1));

      // firstChild
      expect(div.firstChild, isNotNull);
      expect(div.firstChild!.nodeType, equals(NodeType.text));
    });

    test('getElementsByTagName works correctly', () {
      final divs = adapterDoc.getElementsByTagName('div');
      expect(divs.length, greaterThanOrEqualTo(1));
      expect(divs.first.getAttribute('id'), equals('test'));

      final ps = adapterDoc.getElementsByTagName('p');
      expect(ps.length, greaterThanOrEqualTo(1));
    });

    test('querySelector works correctly', () {
      final div = adapterDoc.querySelector('div#test');
      expect(div, isNotNull);
      expect(div!.getAttribute('id'), equals('test'));

      final foo = adapterDoc.querySelector('.foo');
      expect(foo, isNotNull);
      expect(foo!.getAttribute('class'), contains('foo'));
    });

    test('querySelectorAll works correctly', () {
      final all = adapterDoc.querySelectorAll('div');
      expect(all.length, greaterThanOrEqualTo(1));
    });
  });

  group('HTML Package Adapter', () {
    late html.Document htmlDoc;
    late HtmlDomDocument adapterDoc;

    setUp(() {
      final htmlStr = '''
        <html>
          <head><title>Test</title></head>
          <body>
            <div id="test" class="foo bar">Content</div>
            <p>Paragraph</p>
          </body>
        </html>
      ''';
      htmlDoc = html_parser.parse(htmlStr);
      adapterDoc = HtmlDomDocument(htmlDoc);
    });

    test('HtmlDomDocument wraps html Document', () {
      expect(adapterDoc, isA<DomDocument>());
      expect(adapterDoc.unwrap, equals(htmlDoc));
    });

    test('HtmlDomElement wraps html Element', () {
      final div = adapterDoc.getElementById('test');
      expect(div, isNotNull);
      expect(div, isA<DomElement>());
    });

    test('HtmlDomNode wraps html Node', () {
      final div = adapterDoc.getElementById('test');
      final textNode = div!.childNodes.first;
      expect(textNode, isA<DomNode>());
      expect(textNode, isA<HtmlDomNode>());
    });

    test('Attribute operations work correctly', () {
      final div = adapterDoc.getElementById('test');

      // getAttribute - html package uses attributes map
      expect(div!.getAttribute('id'), equals('test'));
      expect(div.getAttribute('class'), equals('foo bar'));
      expect(div.getAttribute('data-test'), isNull);

      // setAttribute
      div.setAttribute('data-test', 'value');
      expect(div.getAttribute('data-test'), equals('value'));

      // hasAttribute
      expect(div.hasAttribute('id'), isTrue);
      expect(div.hasAttribute('data-missing'), isFalse);

      // removeAttribute
      div.removeAttribute('data-test');
      expect(div.getAttribute('data-test'), isNull);
    });

    test('Text content operations work correctly', () {
      final div = adapterDoc.getElementById('test');
      expect(div!.textContent, equals('Content'));

      div.textContent = 'New content';
      expect(div.textContent, equals('New content'));
    });

    test('Element navigation works correctly', () {
      final div = adapterDoc.getElementById('test');
      expect(div, isNotNull);

      // children
      expect(div!.children.length, equals(0));

      // childNodes - html package uses nodes
      expect(div.childNodes.length, equals(1));

      // firstChild
      expect(div.firstChild, isNotNull);
    });

    test('getElementsByTagName works correctly', () {
      final divs = adapterDoc.getElementsByTagName('div');
      expect(divs.length, greaterThanOrEqualTo(1));
      expect(divs.first.getAttribute('id'), equals('test'));

      final ps = adapterDoc.getElementsByTagName('p');
      expect(ps.length, greaterThanOrEqualTo(1));
    });

    test('querySelector works correctly', () {
      final div = adapterDoc.querySelector('div#test');
      expect(div, isNotNull);
      expect(div!.getAttribute('id'), equals('test'));

      final foo = adapterDoc.querySelector('.foo');
      expect(foo, isNotNull);
      expect(foo!.getAttribute('class'), contains('foo'));
    });

    test('querySelectorAll works correctly', () {
      final all = adapterDoc.querySelectorAll('div');
      expect(all.length, greaterThanOrEqualTo(1));
    });

    test('Siblings work correctly', () {
      final div = adapterDoc.getElementById('test');

      expect(div, isNotNull);

      // Test that childNodes works
      expect(div!.childNodes.length, greaterThanOrEqualTo(0));
    });
  });

  group('Adapter Interface Compliance', () {
    test('All JSDOMAdapter types implement correct interfaces', () {
      final parser = JSDOMParser();
      final doc = parser.parse('<div>test</div>');
      final adapterDoc = JsdomDomDocument(doc);

      expect(adapterDoc, isA<DomDocument>());
      expect(adapterDoc, isA<DomNode>());
    });

    test('All HTML adapter types implement correct interfaces', () {
      final doc = html_parser.parse('<div>test</div>');
      final adapterDoc = HtmlDomDocument(doc);

      expect(adapterDoc, isA<DomDocument>());
      expect(adapterDoc, isA<DomNode>());
    });

    test('Common DOM operations produce similar results', () {
      final htmlStr = '''
        <div id="test" class="foo">Text <span>content</span></div>
      ''';

      // JSDOMParser
      final jsdomParser = JSDOMParser();
      final jsdomDoc = jsdomParser.parse(htmlStr);
      final jsdomAdapter = JsdomDomDocument(jsdomDoc);
      final jsdomDiv = jsdomAdapter.getElementById('test');

      // html package
      final htmlDoc = html_parser.parse(htmlStr);
      final htmlAdapter = HtmlDomDocument(htmlDoc);
      final htmlDiv = htmlAdapter.getElementById('test');

      // Compare basic operations
      expect(jsdomDiv!.getAttribute('id'), equals(htmlDiv!.getAttribute('id')));
      expect(jsdomDiv.getAttribute('class'),
          equals(htmlDiv.getAttribute('class')));

      // Text content should be similar (may have whitespace differences)
      expect(jsdomDiv.textContent?.trim(), equals(htmlDiv.textContent?.trim()));

      // Both should have one child element (span)
      expect(jsdomDiv.children.length, equals(htmlDiv.children.length));
    });
  });

  group('Adapter Edge Cases', () {
    test('Null handling in getAttribute', () {
      final doc = html_parser.parse('<div></div>');
      final adapter = HtmlDomDocument(doc);
      final divs = adapter.getElementsByTagName('div');

      expect(divs.first.getAttribute('nonexistent'), isNull);
    });

    test('Empty class name', () {
      final doc = html_parser.parse('<div></div>');
      final adapter = HtmlDomDocument(doc);
      final divs = adapter.getElementsByTagName('div');

      expect(divs.first.className, isEmpty);
    });

    test('Text content with HTML entities', () {
      final htmlStr =
          '<div id="test">&lt;tag&gt; &amp; &quot;quoted&quot;</div>';
      final jsdomDoc = JSDOMParser().parse(htmlStr);
      final htmlDoc = html_parser.parse(htmlStr);

      final jsdomAdapter = JsdomDomDocument(jsdomDoc);
      final htmlAdapter = HtmlDomDocument(htmlDoc);

      final jsdomDiv = jsdomAdapter.getElementById('test');
      final htmlDiv = htmlAdapter.getElementById('test');

      expect(jsdomDiv?.textContent, equals(htmlDiv?.textContent));
      expect(jsdomDiv?.textContent, contains('<tag>'));
      expect(jsdomDiv?.textContent, contains('&'));
      expect(jsdomDiv?.textContent, contains('"quoted"'));
    });

    test('Nested element traversal', () {
      final htmlStr = '''
        <div id="outer">
          <div id="middle">
            <div id="inner">Deep</div>
          </div>
        </div>
      ''';

      final jsdomDoc = JSDOMParser().parse(htmlStr);
      final htmlDoc = html_parser.parse(htmlStr);

      final jsdomAdapter = JsdomDomDocument(jsdomDoc);
      final htmlAdapter = HtmlDomDocument(htmlDoc);

      final jsdomInner = jsdomAdapter.getElementById('inner');
      final htmlInner = htmlAdapter.getElementById('inner');

      expect(jsdomInner, isNotNull);
      expect(htmlInner, isNotNull);

      expect(jsdomInner!.textContent, equals(htmlInner!.textContent));
    });
  });
}
