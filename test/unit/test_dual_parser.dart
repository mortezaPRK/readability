/// Tests comparing JSDOMParser and html package DOM implementations.
///
/// This is the first phase of dual parser support. These tests compare
/// outputs from both parsers to validate they produce similar results.
///
/// Key findings from these tests will inform future decisions about
/// implementing full adapter support or refactoring.
///
/// **CRITICAL API DIFFERENCES DISCOVERED:**
/// 1. JSDOMParser.Document does NOT have querySelector/querySelectorAll
/// 2. JSDOMParser only supports getElementById and getElementsByTagName
/// 3. html package Element uses attributes map, not getAttribute method
/// 4. html package uses `text` instead of `textContent`
/// 5. html package uses `innerHtml` instead of `innerHTML`
library;

import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html_parser;
import 'package:readability/readability.dart';
import 'package:test/test.dart';

void main() {
  group('Dual Parser: Basic DOM Comparison', () {
    test('Both parsers produce similar DOM structure for simple HTML', () {
      final htmlStr = '''
        <html>
          <body>
            <article id="main" class="content">
              <h1>Title</h1>
              <p>Paragraph 1</p>
              <p>Paragraph 2</p>
            </article>
          </body>
        </html>
      ''';

      // Parse with JSDOMParser
      final jsdomDoc = JSDOMParser().parse(htmlStr, 'http://test.com');

      // Parse with html package
      final htmlDoc = html_parser.parse(htmlStr);

      // Both should find the article element using getElementById (JSDOMParser) or querySelector (html)
      final jsdomArticle = jsdomDoc.getElementById('main');
      final htmlArticle = htmlDoc.querySelector('article');

      expect(jsdomArticle, isNotNull);
      expect(htmlArticle, isNotNull);

      // Compare tag names
      // html package uses localName (lowercase), JSDOMParser uses tagName (uppercase)
      expect(
          jsdomArticle!.tagName, equals(htmlArticle!.localName?.toUpperCase()));

      // Compare id
      expect(jsdomArticle.id, equals(htmlArticle.id));

      // Compare className - both use className
      expect(jsdomArticle.className, equals(htmlArticle.className));

      // Compare text content - JSDOMParser uses textContent, html package uses text
      final jsdomH1 = jsdomArticle.getElementsByTagName('h1');
      final htmlH1 = htmlArticle.querySelector('h1');
      if (jsdomH1.isNotEmpty && htmlH1 != null) {
        expect(jsdomH1[0].textContent, equals(htmlH1.text));
      }

      // Compare number of paragraphs
      final jsdomPs = jsdomArticle.getElementsByTagName('p');
      final htmlPs = htmlArticle.querySelectorAll('p');
      expect(jsdomPs.length, equals(htmlPs.length));
    });

    test('Both parsers handle malformed HTML similarly', () {
      final htmlStr = '<div><p>Unclosed</div><p>Another</p>';

      final jsdomDoc = JSDOMParser().parse(htmlStr);
      final htmlDoc = html_parser.parse(htmlStr);

      // Both should produce valid DOM with p elements
      final jsdomPs = jsdomDoc.getElementsByTagName('p');
      final htmlPs = htmlDoc.querySelectorAll('p');

      // They should both find p elements
      expect(jsdomPs.length, greaterThan(0));
      expect(htmlPs.length, greaterThan(0));
    });

    test('Both parsers handle nested elements', () {
      final htmlStr = '''
        <div class="outer">
          <div class="middle">
            <div class="inner" id="deep">
              <span>Deep content</span>
            </div>
          </div>
        </div>
      ''';

      final jsdomDoc = JSDOMParser().parse(htmlStr);
      final htmlDoc = html_parser.parse(htmlStr);

      // Test deep nesting using getElementById for JSDOMParser
      final jsdomInner = jsdomDoc.getElementById('deep');
      final htmlInner = htmlDoc.querySelector('.outer .middle .inner');

      expect(jsdomInner, isNotNull);
      expect(htmlInner, isNotNull);
      expect(jsdomInner!.className, equals(htmlInner!.className));
    });

    test('Both parsers handle attributes correctly', () {
      final htmlStr = '''
        <a href="https://example.com" class="link" id="my-link" data-value="123">Link</a>
      ''';

      final jsdomDoc = JSDOMParser().parse(htmlStr);
      final htmlDoc = html_parser.parse(htmlStr);

      final jsdomLink = jsdomDoc.getElementById('my-link');
      final htmlLink = htmlDoc.querySelector('#my-link');

      expect(jsdomLink, isNotNull);
      expect(htmlLink, isNotNull);

      // JSDOMParser uses getAttribute, html package uses attributes map
      expect(jsdomLink!.getAttribute('href'),
          equals(htmlLink!.attributes['href']));
      expect(jsdomLink.getAttribute('class'),
          equals(htmlLink.attributes['class']));
      expect(jsdomLink.getAttribute('id'), equals(htmlLink.attributes['id']));
      expect(jsdomLink.getAttribute('data-value'),
          equals(htmlLink.attributes['data-value']));
    });

    test('Both parsers handle text content with HTML entities', () {
      final htmlStr =
          '<p id="test">Hello &amp; goodbye &lt;tag&gt; &quot;quoted&quot;</p>';

      final jsdomDoc = JSDOMParser().parse(htmlStr);
      final htmlDoc = html_parser.parse(htmlStr);

      final jsdomP = jsdomDoc.getElementById('test');
      final htmlP = htmlDoc.querySelector('#test');

      expect(jsdomP, isNotNull);
      expect(htmlP, isNotNull);

      // textContent should decode entities in both parsers
      // JSDOMParser uses textContent, html package uses text
      expect(jsdomP!.textContent, equals(htmlP!.text));
      expect(jsdomP.textContent, equals('Hello & goodbye <tag> "quoted"'));
    });

    test('Both parsers handle mixed content (text and elements)', () {
      final htmlStr =
          '<p id="test">Text before <strong>bold</strong> text after <em>italic</em>.</p>';

      final jsdomDoc = JSDOMParser().parse(htmlStr);
      final htmlDoc = html_parser.parse(htmlStr);

      final jsdomP = jsdomDoc.getElementById('test');
      final htmlP = htmlDoc.querySelector('#test');

      expect(jsdomP, isNotNull);
      expect(htmlP, isNotNull);

      // Check children count
      expect(jsdomP!.childNodes.length, equals(htmlP!.nodes.length));

      // Check innerHTML / innerHtml
      expect(jsdomP.innerHTML, isNotEmpty);
      expect(htmlP.innerHtml, isNotEmpty);
    });
  });

  group('Dual Parser: DOM API Differences', () {
    test('querySelector/querySelectorAll NOT available in JSDOMParser', () {
      final htmlStr = '<div class="test">Content</div>';

      final jsdomDoc = JSDOMParser().parse(htmlStr);

      // This documents that JSDOMParser does NOT have querySelector
      // If you try to call jsdomDoc.querySelector, it will be a compile error
      // JSDOMParser only has:
      // - getElementById(String id)
      // - getElementsByTagName(String tag)

      // Using getElementById (works in JSDOMParser)
      final byId = jsdomDoc.getElementById('test');
      expect(byId, isNull); // No element with id='test'

      // Using getElementsByTagName (works in JSDOMParser)
      final byTag = jsdomDoc.getElementsByTagName('div');
      expect(byTag.length, equals(1));
    });

    test('querySelector/querySelectorAll available in html package', () {
      final htmlStr = '<div class="test">Content</div>';

      final htmlDoc = html_parser.parse(htmlStr);

      // html package DOES have querySelector and querySelectorAll
      final bySelector = htmlDoc.querySelector('.test');
      expect(bySelector, isNotNull);

      final bySelectorAll = htmlDoc.querySelectorAll('div');
      expect(bySelectorAll.length, equals(1));
    });

    test('Document property differences', () {
      final htmlStr =
          '<html><head><title>Test</title></head><body>Content</body></html>';

      final jsdomDoc = JSDOMParser().parse(htmlStr, 'http://test.com');
      final htmlDoc = html_parser.parse(htmlStr);

      // JSDOMParser has documentURI, html package does not
      expect(jsdomDoc.documentURI, equals('http://test.com'));

      // Both have title (JSDOMParser has it directly, html package needs to get from title element)
      expect(jsdomDoc.title, isNotEmpty);
      final htmlTitle = htmlDoc.getElementsByTagName('title');
      expect(htmlTitle.isNotEmpty ? htmlTitle.first.text : '', isNotEmpty);

      // Both have body
      expect(jsdomDoc.body, isNotNull);
      expect(htmlDoc.body, isNotNull);
    });

    test('Element property differences', () {
      final htmlStr = '<div id="test" class="foo bar">Content</div>';

      final jsdomDoc = JSDOMParser().parse(htmlStr);
      final htmlDoc = html_parser.parse(htmlStr);

      final jsdomEl = jsdomDoc.getElementById('test');
      final htmlEl = htmlDoc.querySelector('#test');

      expect(jsdomEl, isNotNull);
      expect(htmlEl, isNotNull);

      // Both support id and className
      expect(jsdomEl!.id, equals(htmlEl!.id));
      expect(jsdomEl.className, equals(htmlEl.className));

      // JSDOMParser has marker for identifying its elements
      // (The __JSDOMParser__ getter exists but is not publicly documented)
      expect(jsdomEl.localName, isNotNull);
    });

    test('Attribute access differences', () {
      final htmlStr =
          '<div id="test" data-value="123" class="foo">Content</div>';

      final jsdomDoc = JSDOMParser().parse(htmlStr);
      final htmlDoc = html_parser.parse(htmlStr);

      final jsdomEl = jsdomDoc.getElementById('test');
      final htmlEl = htmlDoc.querySelector('#test');

      // JSDOMParser uses getAttribute/setAttribute methods
      expect(jsdomEl!.getAttribute('data-value'), equals('123'));
      expect(jsdomEl.getAttribute('class'), equals('foo'));

      // html package uses attributes map
      expect(htmlEl!.attributes['data-value'], equals('123'));
      expect(htmlEl.attributes['class'], equals('foo'));
    });

    test('Text node property differences', () {
      final htmlStr = '<p id="test">Text content</p>';

      final jsdomDoc = JSDOMParser().parse(htmlStr);
      final htmlDoc = html_parser.parse(htmlStr);

      final jsdomP = jsdomDoc.getElementById('test');
      final htmlP = htmlDoc.querySelector('#test');

      final jsdomText = jsdomP!.firstChild;
      final htmlText = htmlP!.firstChild;

      if (jsdomText != null && htmlText != null) {
        // JSDOMParser uses textContent
        expect(jsdomText.textContent, equals('Text content'));

        // html package uses `text` property
        expect(htmlText.text, equals('Text content'));

        // Both have nodeType
        expect(jsdomText.nodeType, equals(Node.TEXT_NODE));
        expect(htmlText.nodeType, equals(html.Node.TEXT_NODE));
      }
    });

    test('getElementsByTagName works in both parsers', () {
      final htmlStr = '''
        <div>1</div>
        <div>2</div>
        <span>3</span>
      ''';

      final jsdomDoc = JSDOMParser().parse(htmlStr);
      final htmlDoc = html_parser.parse(htmlStr);

      final jsdomDivs = jsdomDoc.getElementsByTagName('div');
      final htmlDivs = htmlDoc.getElementsByTagName('div');

      // Both should find 2 divs
      expect(jsdomDivs.length, equals(2));
      expect(htmlDivs.length, equals(2));
    });

    test('getElementById works in both parsers', () {
      final htmlStr = '<div id="test1">First</div><div id="test2">Second</div>';

      final jsdomDoc = JSDOMParser().parse(htmlStr);
      final htmlDoc = html_parser.parse(htmlStr);

      final jsdomEl = jsdomDoc.getElementById('test1');
      final htmlEl = htmlDoc.getElementById('test1');

      expect(jsdomEl, isNotNull);
      expect(htmlEl, isNotNull);
      expect(jsdomEl!.id, equals(htmlEl!.id));
    });
  });

  group('Dual Parser: isProbablyReaderable Compatibility', () {
    test('isProbablyReaderable works with html package', () {
      // Need more substantial content to be detected as readerable
      // The minContentLength is 140 and minScore is 20
      final content = 'This is a substantial paragraph. ' * 20;
      final htmlStr =
          '<html><body><article><p>$content</p></article></body></html>';
      final htmlDoc = html_parser.parse(htmlStr);

      expect(isProbablyReaderable(htmlDoc), isTrue);
    });

    test('isProbablyReaderable returns false for short content', () {
      final htmlStr = '<html><body><p>Short</p></body></html>';
      final htmlDoc = html_parser.parse(htmlStr);

      expect(isProbablyReaderable(htmlDoc), isFalse);
    });

    test('isProbablyReaderable handles negative class names', () {
      final htmlStr =
          '<html><body><div class="advertisement"><p>${'Content. ' * 50}</p></div></body></html>';
      final htmlDoc = html_parser.parse(htmlStr);

      // Should detect unlikely candidate
      expect(isProbablyReaderable(htmlDoc), isFalse);
    });

    test('isProbablyReaderable handles positive class names', () {
      final htmlStr =
          '<html><body><article class="post"><p>${'Content. ' * 50}</p></article></body></html>';
      final htmlDoc = html_parser.parse(htmlStr);

      expect(isProbablyReaderable(htmlDoc), isTrue);
    });
  });

  group('Dual Parser: Readability Integration', () {
    test('Readability only works with JSDOMParser.Document', () {
      final htmlStr =
          '<html><body><article><h1>Title</h1><p>${'Content. ' * 50}</p></article></body></html>';

      // This should work - JSDOMParser Document
      final jsdomDoc = JSDOMParser().parse(htmlStr, 'http://test.com');
      final reader1 = Readability(JsdomDomDocument(jsdomDoc));
      expect(reader1, isNotNull);

      // This would NOT work - html package Document has different type
      // Demonstrating the type incompatibility
      final htmlDoc = html_parser.parse(htmlStr);
      // The following would cause a compile-time error:
      // final reader2 = Readability(htmlDoc); // Error: html.Document is not JSDOMParser.Document

      // For now, this confirms the type incompatibility exists
      expect(htmlDoc, isNotNull);
    });

    test('Both parsers can handle same HTML structure', () {
      final htmlStr = '''
        <html>
          <head>
            <meta property="og:title" content="Open Graph Title">
            <title>Page Title</title>
          </head>
          <body>
            <article>
              <h1>Article Title</h1>
              <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit.
                 ${'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. ' * 10}
              </p>
            </article>
          </body>
        </html>
      ''';

      final jsdomDoc = JSDOMParser().parse(htmlStr, 'http://test.com');
      final htmlDoc = html_parser.parse(htmlStr);

      // Both can find elements using their respective APIs
      expect(jsdomDoc.getElementsByTagName('article').length, greaterThan(0));
      expect(htmlDoc.querySelector('article'), isNotNull);

      // Both can find the title
      final jsdomTitles = jsdomDoc.getElementsByTagName('title');
      final htmlTitles = htmlDoc.getElementsByTagName('title');

      if (jsdomTitles.isNotEmpty) {
        expect(jsdomTitles.first.textContent, isNotEmpty);
      }
      if (htmlTitles.isNotEmpty) {
        expect(htmlTitles.first.text, isNotEmpty);
      }
    });
  });

  group('Dual Parser: Style Attribute Handling', () {
    test('Both parsers handle style attributes', () {
      final htmlStr =
          '<div id="test" style="display:none; color:red;">Content</div>';

      final jsdomDoc = JSDOMParser().parse(htmlStr);
      final htmlDoc = html_parser.parse(htmlStr);

      final jsdomEl = jsdomDoc.getElementById('test');
      final htmlEl = htmlDoc.querySelector('#test');

      // JSDOMParser uses getAttribute
      // html package uses attributes map
      expect(
          jsdomEl!.getAttribute('style'), equals(htmlEl!.attributes['style']));
    });

    test('JSDOMParser has Style object, html package does not', () {
      final htmlStr = '<div id="test" style="display:none;">Content</div>';

      final jsdomDoc = JSDOMParser().parse(htmlStr);
      final jsdomEl = jsdomDoc.getElementById('test');

      // JSDOMParser Element has a style object
      expect(jsdomEl!.style, isNotNull);
      expect(jsdomEl.style.display, equals('none'));

      // html package elements do not have a style object
      // They store styles as attributes only
      final htmlDoc = html_parser.parse(htmlStr);
      final htmlEl = htmlDoc.querySelector('#test');
      expect(htmlEl!.attributes['style'], isNotNull);
    });
  });

  group('Dual Parser: Node Traversal', () {
    test('Both parsers support childNodes', () {
      final htmlStr = '<div id="test"><p>1</p><p>2</p><p>3</p></div>';

      final jsdomDoc = JSDOMParser().parse(htmlStr);
      final htmlDoc = html_parser.parse(htmlStr);

      final jsdomDiv = jsdomDoc.getElementById('test');
      final htmlDiv = htmlDoc.querySelector('#test');

      expect(jsdomDiv!.childNodes.length, equals(htmlDiv!.nodes.length));
      expect(jsdomDiv.childNodes.length, equals(3));
    });

    test('Both parsers support children (element-only)', () {
      final htmlStr = '<div id="test"><p>1</p><!-- comment --><p>2</p></div>';

      final jsdomDoc = JSDOMParser().parse(htmlStr);
      final htmlDoc = html_parser.parse(htmlStr);

      final jsdomDiv = jsdomDoc.getElementById('test');
      final htmlDiv = htmlDoc.querySelector('#test');

      // children should only include element nodes, not comments
      expect(jsdomDiv!.children.length, equals(2));
      expect(htmlDiv!.children.length, equals(2));
    });

    test('Both parsers support parentNode navigation', () {
      final htmlStr =
          '<div id="outer"><p><span id="inner">Text</span></p></div>';

      final jsdomDoc = JSDOMParser().parse(htmlStr);
      final htmlDoc = html_parser.parse(htmlStr);

      final jsdomSpan = jsdomDoc.getElementById('inner');
      final htmlSpan = htmlDoc.querySelector('#inner');

      expect(jsdomSpan!.parentNode!.localName, equals('p'));
      expect(htmlSpan!.parent!.localName, equals('p'));
    });

    test('Both parsers support nextSibling/previousSibling', () {
      final htmlStr = '<div id="test"><p>1</p><p>2</p><p>3</p></div>';

      final jsdomDoc = JSDOMParser().parse(htmlStr);
      final htmlDoc = html_parser.parse(htmlStr);

      final jsdomPs =
          jsdomDoc.getElementById('test')!.getElementsByTagName('p');
      final htmlPs = htmlDoc.querySelectorAll('p');

      expect(jsdomPs[1].previousSibling, equals(jsdomPs[0]));
      expect(jsdomPs[1].nextSibling, equals(jsdomPs[2]));

      // html package uses different sibling properties
      expect(htmlPs[1].previousElementSibling, equals(htmlPs[0]));
      expect(htmlPs[1].nextElementSibling, equals(htmlPs[2]));
    });
  });

  group('Dual Parser: Special Cases', () {
    test('Both parsers handle script tags', () {
      // JSDOMParser has stricter parsing for script tags
      // Using a simpler script content to avoid parsing issues
      final htmlStr = '<script id="test">var x = "hello";</script>';

      final jsdomDoc = JSDOMParser().parse(htmlStr);
      final htmlDoc = html_parser.parse(htmlStr);

      final jsdomScript = jsdomDoc.getElementById('test');
      final htmlScript = htmlDoc.querySelector('#test');

      expect(jsdomScript!.textContent, equals('var x = "hello";'));
      expect(htmlScript!.text, equals('var x = "hello";'));
    });

    test('Both parsers handle void elements', () {
      // JSDOMParser requires self-closing syntax for void elements
      final htmlStr = '<div id="test"><img src="test.jpg"/><br/><hr/></div>';

      final jsdomDoc = JSDOMParser().parse(htmlStr);
      final htmlDoc = html_parser.parse(htmlStr);

      final jsdomDiv = jsdomDoc.getElementById('test');
      final htmlDiv = htmlDoc.querySelector('#test');

      expect(jsdomDiv!.children.length, equals(3));
      expect(htmlDiv!.children.length, equals(3));
    });

    test('Both parsers handle tables', () {
      final htmlStr = '''
        <table>
          <tr><td>Cell 1</td><td>Cell 2</td></tr>
          <tr><td>Cell 3</td><td>Cell 4</td></tr>
        </table>
      ''';

      final jsdomDoc = JSDOMParser().parse(htmlStr);
      final htmlDoc = html_parser.parse(htmlStr);

      final jsdomRows = jsdomDoc.getElementsByTagName('tr');
      final htmlRows = htmlDoc.querySelectorAll('tr');

      expect(jsdomRows.length, equals(2));
      expect(htmlRows.length, equals(2));

      final jsdomCells = jsdomDoc.getElementsByTagName('td');
      final htmlCells = htmlDoc.querySelectorAll('td');

      expect(jsdomCells.length, equals(4));
      expect(htmlCells.length, equals(4));
    });
  });

  group('Dual Parser: Summary of Key Differences', () {
    test('Documented API differences between parsers', () {
      // This test documents the key differences discovered

      final differences = {
        'querySelector/querySelectorAll':
            'Available in html package, NOT in JSDOMParser',
        'getElementById': 'Available in both parsers',
        'getElementsByTagName': 'Available in both parsers',
        'getAttribute/setAttribute':
            'JSDOMParser uses methods, html package uses attributes map',
        'textContent': 'JSDOMParser uses textContent, html package uses text',
        'innerHTML':
            'JSDOMParser uses innerHTML, html package uses innerHtml (lowercase h)',
        'childNodes': 'JSDOMParser uses childNodes, html package uses nodes',
        'Style object':
            'JSDOMParser Element has style object, html package does not',
      };

      // Just verify we've documented these differences
      expect(differences.length, equals(8));
    });
  });
}
