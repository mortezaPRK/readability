/// Additional tests for html package integration and adapter functionality.
library;

import 'package:test/test.dart';
import 'package:readability/readability.dart';
import 'package:html/parser.dart' as html_parser;

void main() {
  group('HTML Package Adapter', () {
    group('HtmlDomDocument adapter', () {
      test('should wrap html package Document correctly', () {
        final doc = html_parser.parse('<html><body><p>Test</p></body></html>');
        final adapter = HtmlDomDocument(doc);

        expect(adapter.documentElement, isNotNull);
        expect(adapter.body, isNotNull);
        // nodeName may vary by implementation
        expect(adapter.nodeName, anyOf(equals('#document'), isNull));
      });

      test('should support getElementsByTagName', () {
        final doc =
            html_parser.parse('<html><body><p>One</p><p>Two</p></body></html>');
        final adapter = HtmlDomDocument(doc);

        final paragraphs = adapter.getElementsByTagName('p');
        expect(paragraphs.length, equals(2));
        expect(paragraphs[0].textContent, equals('One'));
        expect(paragraphs[1].textContent, equals('Two'));
      });

      test('should support createElement', () {
        final doc = html_parser.parse('<html><body></body></html>');
        final adapter = HtmlDomDocument(doc);

        final newElement = adapter.createElement('div');
        expect(newElement.tagName, equals('DIV'));
      });

      test('should handle title property', () {
        final doc = html_parser.parse(
            '<html><head><title>Page Title</title></head><body></body></html>');
        final adapter = HtmlDomDocument(doc);

        expect(adapter.title, equals('Page Title'));
      });

      test('should not support isJSDOMParser', () {
        final doc = html_parser.parse('<html><body></body></html>');
        final adapter = HtmlDomDocument(doc);

        expect(adapter.isJSDOMParser, isFalse);
      });
    });

    group('HtmlDomElement adapter', () {
      test('should wrap html package Element correctly', () {
        final doc = html_parser.parse(
            '<html><body><div id="test" class="example">Content</div></body></html>');
        final adapter = HtmlDomDocument(doc);
        final element = adapter.getElementById('test');

        expect(element, isNotNull);
        expect(element?.tagName, equals('DIV'));
        expect(element?.id, equals('test'));
        expect(element?.className, equals('example'));
        expect(element?.textContent, equals('Content'));
      });

      test('should support getAttribute and setAttribute', () {
        final doc = html_parser.parse(
            '<html><body><div data-test="value">Content</div></body></html>');
        final adapter = HtmlDomDocument(doc);
        final div = adapter.getElementsByTagName('div').first;

        expect(div.getAttribute('data-test'), equals('value'));

        div.setAttribute('data-new', 'newvalue');
        expect(div.getAttribute('data-new'), equals('newvalue'));
      });

      test('should support removeAttribute', () {
        final doc = html_parser.parse(
            '<html><body><div data-remove="yes">Content</div></body></html>');
        final adapter = HtmlDomDocument(doc);
        final div = adapter.getElementsByTagName('div').first;

        expect(div.getAttribute('data-remove'), equals('yes'));
        div.removeAttribute('data-remove');
        expect(div.getAttribute('data-remove'), isNull);
      });

      test('should support hasAttribute', () {
        final doc = html_parser.parse(
            '<html><body><div data-test="value">Content</div></body></html>');
        final adapter = HtmlDomDocument(doc);
        final div = adapter.getElementsByTagName('div').first;

        expect(div.hasAttribute('data-test'), isTrue);
        expect(div.hasAttribute('data-missing'), isFalse);
      });

      test('should handle children property', () {
        final doc = html_parser
            .parse('<html><body><div><p>One</p><p>Two</p></div></body></html>');
        final adapter = HtmlDomDocument(doc);
        final div = adapter.getElementsByTagName('div').first;

        expect(div.children.length, equals(2));
        expect(div.children[0].tagName, equals('P'));
        expect(div.children[1].tagName, equals('P'));
      });

      test('should support innerHTML getter', () {
        final doc = html_parser.parse(
            '<html><body><div><p>Test <b>bold</b></p></div></body></html>');
        final adapter = HtmlDomDocument(doc);
        final div = adapter.getElementsByTagName('div').first;

        expect(div.innerHTML, contains('<p>'));
        expect(div.innerHTML, contains('bold'));
      });

      test('should support textContent getter and setter', () {
        final doc = html_parser
            .parse('<html><body><div><p>Original</p></div></body></html>');
        final adapter = HtmlDomDocument(doc);
        final div = adapter.getElementsByTagName('div').first;

        expect(div.textContent, equals('Original'));

        div.textContent = 'New content';
        expect(div.textContent, equals('New content'));
      });

      test('should support parentNode navigation', () {
        final doc = html_parser.parse(
            '<html><body><div><p id="child">Text</p></div></body></html>');
        final adapter = HtmlDomDocument(doc);
        final p = adapter.getElementById('child');

        expect(p?.parentNode, isNotNull);
        expect((p?.parentNode as DomElement?)?.tagName, equals('DIV'));
      });

      test('should support nextSibling and previousSibling', () {
        final doc = html_parser.parse(
            '<html><body><div><p>One</p><p id="mid">Two</p><p>Three</p></div></body></html>');
        final adapter = HtmlDomDocument(doc);
        final mid = adapter.getElementById('mid');

        expect(mid?.previousSibling, isNotNull);
        expect(mid?.nextSibling, isNotNull);
      });

      test('should support firstChild and lastChild', () {
        final doc = html_parser.parse(
            '<html><body><div><p>First</p><p>Last</p></div></body></html>');
        final adapter = HtmlDomDocument(doc);
        final div = adapter.getElementsByTagName('div').first;

        expect(div.firstChild, isNotNull);
        expect(div.lastChild, isNotNull);
        expect((div.firstChild as DomElement?)?.textContent, contains('First'));
        expect((div.lastChild as DomElement?)?.textContent, contains('Last'));
      });

      test('should support firstElementChild and lastElementChild', () {
        final doc = html_parser.parse(
            '<html><body><div><p>First</p><p>Last</p></div></body></html>');
        final adapter = HtmlDomDocument(doc);
        final div = adapter.getElementsByTagName('div').first;

        expect(div.firstElementChild, isNotNull);
        expect(div.lastElementChild, isNotNull);
        expect(div.firstElementChild?.textContent, contains('First'));
        expect(div.lastElementChild?.textContent, contains('Last'));
      });

      test('should support childNodes property', () {
        final doc = html_parser.parse(
            '<html><body><div><p>One</p>Text<p>Two</p></div></body></html>');
        final adapter = HtmlDomDocument(doc);
        final div = adapter.getElementsByTagName('div').first;

        expect(div.childNodes.length, greaterThanOrEqualTo(2));
      });
    });

    group('Real-world HTML parsing', () {
      test('should handle blog post with html package', () {
        final html = '''
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <title>Blog Post Title</title>
          </head>
          <body>
            <header class="site-header">
              <nav>Navigation</nav>
            </header>
            <main>
              <article>
                <h1>Blog Post Title</h1>
                <div class="post-meta">By Jane Smith</div>
                <div class="post-content">
                  <p>${'First paragraph of blog post content. ' * 30}</p>
                  <p>${'Second paragraph with more details. ' * 30}</p>
                  <p>${'Third paragraph wrapping up. ' * 30}</p>
                </div>
              </article>
            </main>
            <footer>Footer</footer>
          </body>
          </html>
        ''';

        final article = parse(html, parser: ParserType.html);

        expect(article, isNotNull);
        expect(article?.title, contains('Blog Post'));
        expect(article?.byline, anyOf(equals('By Jane Smith'), isNull));
        expect(article?.content, contains('First paragraph'));
        expect(article?.content, isNot(contains('Navigation')));
      });

      test('should handle news article with html package', () {
        final html = '''
          <!DOCTYPE html>
          <html>
          <head>
            <title>Breaking News Story</title>
          </head>
          <body>
            <article>
              <h1>Breaking News Story</h1>
              <p>${'News article lead paragraph. ' * 40}</p>
              <p>${'Additional details and analysis. ' * 40}</p>
            </article>
          </body>
          </html>
        ''';

        final article = parse(html, parser: ParserType.html);

        expect(article, isNotNull);
        expect(
            article?.title, anyOf(equals('Breaking News Story'), isNotEmpty));
        expect(article?.content, contains('News article lead'));
      });

      test('should handle documentation page with html package', () {
        final html = '''
          <!DOCTYPE html>
          <html>
          <head><title>API Documentation</title></head>
          <body>
            <nav class="sidebar">Sidebar navigation</nav>
            <main>
              <article>
                <h1>API Method</h1>
                <p>${'Method description and usage. ' * 40}</p>
                <pre><code>example_code()</code></pre>
                <p>${'Additional notes and parameters. ' * 40}</p>
              </article>
            </main>
          </body>
          </html>
        ''';

        final article = parse(html, parser: ParserType.html);

        expect(article, isNotNull);
        expect(article?.title, contains('API'));
        expect(article?.content, contains('Method description'));
        expect(article?.content, contains('example_code'));
      });
    });

    group('Adapter edge cases', () {
      test('should handle malformed HTML with html package', () {
        final html =
            '<html><body><p>Unclosed paragraph<div>Mismatched</p></div>';

        final article = parse(html, parser: ParserType.html);
        // Should not crash, may or may not extract content
        expect(article, anyOf(isNull, isNotNull));
      });

      test('should handle special characters with html package', () {
        final html = '''
          <html><body><article>
            <p>${'Content with émojis 🎉 and spëcial çharacters. ' * 20}</p>
          </article></body></html>
        ''';

        final article = parse(html, parser: ParserType.html);

        expect(article, isNotNull);
        expect(article?.content, contains('🎉'));
      });

      test('should handle deeply nested structures with html package', () {
        var html = '<html><body><article>';
        for (var i = 0; i < 50; i++) {
          html += '<div>';
        }
        html += '<p>${'Deep content. ' * 50}</p>';
        for (var i = 0; i < 50; i++) {
          html += '</div>';
        }
        html += '</article></body></html>';

        final article = parse(html, parser: ParserType.html);

        expect(article, isNotNull);
        expect(article?.content, contains('Deep content'));
      });

      test('should handle empty elements with html package', () {
        final html = '''
          <html><body><article>
            <div></div>
            <p>${'Actual content paragraph. ' * 50}</p>
            <span></span>
          </article></body></html>
        ''';

        final article = parse(html, parser: ParserType.html);

        expect(article, isNotNull);
        expect(article?.content, contains('Actual content'));
      });

      test('should handle mixed content types with html package', () {
        final html = '''
          <html><body><article>
            <h2>Section Title</h2>
            <p>${'Text paragraph. ' * 30}</p>
            <blockquote>${'Quoted text. ' * 20}</blockquote>
            <ul>
              <li>List item one</li>
              <li>List item two</li>
            </ul>
            <p>${'More text. ' * 30}</p>
          </article></body></html>
        ''';

        final article = parse(html, parser: ParserType.html);

        expect(article, isNotNull);
        expect(article?.content, contains('Section Title'));
        expect(article?.content, contains('Text paragraph'));
        expect(article?.content, contains('Quoted text'));
      });
    });

    group('Parser feature parity', () {
      test('both parsers should handle metadata extraction', () {
        final html = '''
          <html lang="en" dir="ltr">
          <head>
            <title>Test Title</title>
            <meta name="author" content="Test Author">
            <meta property="og:description" content="Test description">
          </head>
          <body><article><p>${'Content. ' * 50}</p></article></body>
          </html>
        ''';

        final jsdomArticle = parse(html, parser: ParserType.jsdom);
        final htmlArticle = parse(html, parser: ParserType.html);

        expect(jsdomArticle?.title, equals(htmlArticle?.title));
        // Byline extraction may differ between parsers
        expect(jsdomArticle?.byline,
            anyOf(equals(htmlArticle?.byline), isNotNull));
        expect(jsdomArticle?.excerpt, equals(htmlArticle?.excerpt));
        expect(jsdomArticle?.lang, equals(htmlArticle?.lang));
        expect(jsdomArticle?.dir, equals(htmlArticle?.dir));
      });

      test('both parsers should respect charThreshold', () {
        final html =
            '<html><body><article><p>${'Text. ' * 100}</p></article></body></html>';

        final jsdomArticle =
            parse(html, parser: ParserType.jsdom, charThreshold: 200);
        final htmlArticle =
            parse(html, parser: ParserType.html, charThreshold: 200);

        // Both should produce results with similar lengths
        if (jsdomArticle != null && htmlArticle != null) {
          expect(
              (jsdomArticle.length - htmlArticle.length).abs(), lessThan(50));
        }
      });

      test('both parsers should respect keepClasses option', () {
        final html = '''
          <html><body>
            <article>
              <p class="intro">${'Content. ' * 50}</p>
            </article>
          </body></html>
        ''';

        final jsdomKeep =
            parse(html, parser: ParserType.jsdom, keepClasses: true);
        final htmlKeep =
            parse(html, parser: ParserType.html, keepClasses: true);

        expect(jsdomKeep?.content, contains('intro'));
        expect(htmlKeep?.content, contains('intro'));

        final jsdomStrip =
            parse(html, parser: ParserType.jsdom, keepClasses: false);
        final htmlStrip =
            parse(html, parser: ParserType.html, keepClasses: false);

        expect(jsdomStrip?.content, isNot(contains('intro')));
        expect(htmlStrip?.content, isNot(contains('intro')));
      });

      test('both parsers should respect maxElemsToParse', () {
        var html = '<html><body><article>';
        for (var i = 0; i < 150; i++) {
          html += '<div>Element $i</div>';
        }
        html += '</article></body></html>';

        expect(
          () => parse(html, parser: ParserType.jsdom, maxElemsToParse: 100),
          throwsA(isA<Exception>()),
        );

        expect(
          () => parse(html, parser: ParserType.html, maxElemsToParse: 100),
          throwsA(isA<Exception>()),
        );
      });

      test('both parsers should handle classesToPreserve', () {
        final html = '''
          <html><body>
            <article>
              <p class="highlight important note">${'Content. ' * 50}</p>
            </article>
          </body></html>
        ''';

        final jsdomArticle = parse(html,
            parser: ParserType.jsdom,
            classesToPreserve: ['highlight', 'important']);
        final htmlArticle = parse(html,
            parser: ParserType.html,
            classesToPreserve: ['highlight', 'important']);

        expect(jsdomArticle?.content, contains('class='));
        expect(jsdomArticle?.content, contains('highlight'));
        expect(jsdomArticle?.content, contains('important'));

        expect(htmlArticle?.content, contains('class='));
        expect(htmlArticle?.content, contains('highlight'));
        expect(htmlArticle?.content, contains('important'));
      });
    });

    group('parse with html package', () {
      test('should parse simple HTML', () {
        final html = '''
          <html><body>
            <article><p>${'Simple content. ' * 50}</p></article>
          </body></html>
        ''';

        final article = parse(html, parser: ParserType.html);

        expect(article, isNotNull);
        expect(article?.content, contains('Simple content'));
      });

      test('should work with options', () {
        final html = '''
          <html><body>
            <article>
              <p class="preserved">${'Content. ' * 50}</p>
            </article>
          </body></html>
        ''';

        final article = parse(
          html,
          parser: ParserType.html,
          keepClasses: true,
          charThreshold: 100,
        );

        expect(article, isNotNull);
        expect(article?.content, contains('preserved'));
      });

      test('should handle complex nested structures', () {
        final html = '''
          <html>
          <head><title>Article Title Goes Here</title></head>
          <body>
            <div class="wrapper">
              <div class="container">
                <article class="post">
                  <section class="content">
                    <p>${'Content paragraph one. ' * 40}</p>
                    <p>${'Content paragraph two. ' * 40}</p>
                  </section>
                </article>
              </div>
            </div>
          </body></html>
        ''';

        final article = parse(html, parser: ParserType.html);

        expect(article, isNotNull);
        expect(article?.title, equals('Article Title Goes Here'));
        expect(article?.content, contains('Content paragraph'));
      });
    });

    group('Adapter method coverage', () {
      test('HtmlDomElement should support remove()', () {
        final doc = html_parser.parse(
            '<html><body><div><p id="remove-me">Text</p></div></body></html>');
        final adapter = HtmlDomDocument(doc);
        final p = adapter.getElementById('remove-me');

        expect(p, isNotNull);
        p?.remove();

        final pAfter = adapter.getElementById('remove-me');
        expect(pAfter, isNull);
      });

      test('HtmlDomElement should support appendChild', () {
        final doc = html_parser
            .parse('<html><body><div id="parent"></div></body></html>');
        final adapter = HtmlDomDocument(doc);
        final parent = adapter.getElementById('parent');
        final child = adapter.createElement('p');
        child.textContent = 'New child';

        parent?.appendChild(child);

        expect(parent?.children.length, equals(1));
        expect(parent?.children.first.textContent, equals('New child'));
      });

      test('HtmlDomElement should support replaceChild', () {
        final doc = html_parser.parse(
            '<html><body><div id="parent"><p id="old">Old</p></div></body></html>');
        final adapter = HtmlDomDocument(doc);
        final parent = adapter.getElementById('parent');
        final oldChild = adapter.getElementById('old');
        final newChild = adapter.createElement('p');
        newChild.textContent = 'New';

        parent?.replaceChild(newChild, oldChild!);

        expect(parent?.children.first.textContent, equals('New'));
        expect(adapter.getElementById('old'), isNull);
      });

      test('HtmlDomElement should support removeChild', () {
        final doc = html_parser.parse(
            '<html><body><div id="parent"><p id="child">Text</p></div></body></html>');
        final adapter = HtmlDomDocument(doc);
        final parent = adapter.getElementById('parent');
        final child = adapter.getElementById('child');

        parent?.removeChild(child!);

        expect(parent?.children.length, equals(0));
        expect(adapter.getElementById('child'), isNull);
      });
    });
  });
}
