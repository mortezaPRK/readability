// Copyright (c) 2024 Dart Readability contributors
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.

/// Tests for dual parser support using both JSDOMParser and html package.
library;

import 'package:test/test.dart';
import 'package:readability/readability.dart';

void main() {
  group('Dual Parser Support', () {
    final html = '''
      <!DOCTYPE html>
      <html>
      <head>
        <title>Test Article</title>
      </head>
      <body>
        <div>
          <h1>Main Title</h1>
          <p>This is a test article with some content.</p>
          <p>It has multiple paragraphs to test content extraction.</p>
        </div>
      </body>
      </html>
    ''';

    test('parse with jsdom should extract article content', () {
      final article = parse(html, parser: ParserType.jsdom);

      expect(article, isNotNull);
      expect(article?.title, contains('Test Article'));
      expect(article?.textContent, contains('test article'));
      expect(article?.textContent, contains('content'));
    });

    test('parse with html package should extract article content', () {
      final article = parse(html, parser: ParserType.html);

      expect(article, isNotNull);
      expect(article?.title, contains('Test Article'));
      expect(article?.textContent, contains('test article'));
      expect(article?.textContent, contains('content'));
    });

    test('Both parsers should produce equivalent results', () {
      final jsdomArticle = parse(html, parser: ParserType.jsdom);
      final htmlPackageArticle = parse(html, parser: ParserType.html);

      expect(jsdomArticle, isNotNull);
      expect(htmlPackageArticle, isNotNull);

      // Titles should match
      expect(jsdomArticle?.title, htmlPackageArticle?.title);

      // Content should be similar (may have minor differences due to parser quirks)
      expect(jsdomArticle?.textContent.trim(),
          htmlPackageArticle?.textContent.trim());

      // Both should have extracted the main content
      expect(jsdomArticle?.textContent.length, greaterThan(50));
      expect(htmlPackageArticle?.textContent.length, greaterThan(50));
    });

    test('Convenience functions should handle empty HTML', () {
      final emptyHtml = '<html><body></body></html>';

      final jsdomArticle = parse(emptyHtml, parser: ParserType.jsdom);
      final htmlPackageArticle = parse(emptyHtml, parser: ParserType.html);

      // Both should handle empty HTML gracefully (not crash).
      // JSDOM returns empty content, htmlPackage returns just a wrapper div.
      // Neither should have meaningful text content.
      expect(jsdomArticle?.textContent.trim().isEmpty ?? true, isTrue);
      expect(htmlPackageArticle?.textContent.trim().isEmpty ?? true, isTrue);
    });

    test('parse should support baseUri parameter', () {
      final htmlWithLinks = '''
        <!DOCTYPE html>
        <html>
        <head>
          <title>Test with Links</title>
          <base href="https://example.com/">
        </head>
        <body>
          <div>
            <p>Content with a <a href="page.html">link</a>.</p>
          </div>
        </body>
        </html>
      ''';

      final article =
          parse(htmlWithLinks, baseUri: 'https://test.example.com/');

      expect(article, isNotNull);
      expect(article?.title, contains('Test with Links'));
    });
  });

  group('Parser Comparison', () {
    final complexHtml = '''
      <!DOCTYPE html>
      <html>
      <head>
        <title>Complex Article</title>
      </head>
      <body>
        <nav>
          <a href="/">Home</a>
          <a href="/about">About</a>
        </nav>
        <main>
          <article>
            <h1>Article Title</h1>
            <p class="author">By Jane Doe</p>
            <p class="date">January 1, 2024</p>
            <p>This is the main content of the article.</p>
            <p>It has multiple paragraphs with <strong>formatting</strong>.</p>
          </article>
        </main>
        <aside>
          <p>Sidebar content</p>
        </aside>
        <footer>
          <p>Footer content</p>
        </footer>
      </body>
      </html>
    ''';

    test('Both parsers should extract article from complex HTML', () {
      final jsdomArticle = parse(complexHtml, parser: ParserType.jsdom);
      final htmlPackageArticle = parse(complexHtml, parser: ParserType.html);

      expect(jsdomArticle, isNotNull);
      expect(htmlPackageArticle, isNotNull);

      // Both should extract the article content
      expect(jsdomArticle?.textContent, contains('main content'));
      expect(htmlPackageArticle?.textContent, contains('main content'));

      // Both should exclude navigation
      expect(jsdomArticle?.textContent, isNot(contains('Home')));
      expect(htmlPackageArticle?.textContent, isNot(contains('Home')));

      // Both should exclude sidebar
      expect(jsdomArticle?.textContent, isNot(contains('Sidebar')));
      expect(htmlPackageArticle?.textContent, isNot(contains('Sidebar')));

      // Both should exclude footer
      expect(jsdomArticle?.textContent, isNot(contains('Footer')));
      expect(htmlPackageArticle?.textContent, isNot(contains('Footer')));
    });

    test('Both parsers should handle HTML5 semantic elements', () {
      final html5Html = '''
        <!DOCTYPE html>
        <html>
        <head>
          <title>HTML5 Article</title>
        </head>
        <body>
          <article>
            <header>
              <h1>Header</h1>
            </header>
            <section>
              <p>Content</p>
            </section>
            <footer>
              <p>Article footer</p>
            </footer>
          </article>
        </body>
        </html>
      ''';

      final jsdomArticle = parse(html5Html, parser: ParserType.jsdom);
      final htmlPackageArticle = parse(html5Html, parser: ParserType.html);

      expect(jsdomArticle, isNotNull);
      expect(htmlPackageArticle, isNotNull);

      // Both should extract the article content
      expect(jsdomArticle?.textContent, contains('Header'));
      expect(jsdomArticle?.textContent, contains('Content'));

      expect(htmlPackageArticle?.textContent, contains('Header'));
      expect(htmlPackageArticle?.textContent, contains('Content'));
    });
  });

  group('Options Support', () {
    final html = '''
      <!DOCTYPE html>
      <html>
      <head>
        <title>Test Options</title>
      </head>
      <body>
        <div class="content">
          <h1>Article Title</h1>
          <p>Article content here.</p>
        </div>
      </body>
      </html>
    ''';

    test('parse with jsdom should support options', () {
      final article = parse(
        html,
        parser: ParserType.jsdom,
        debug: true,
        maxElemsToParse: 100,
        charThreshold: 100,
      );

      expect(article, isNotNull);
    });

    test('parse with html package should support options', () {
      final article = parse(
        html,
        parser: ParserType.html,
        debug: true,
        maxElemsToParse: 100,
        charThreshold: 100,
      );

      expect(article, isNotNull);
    });

    test('Both parsers should respect keepClasses option', () {
      final htmlWithClasses = '''
        <!DOCTYPE html>
        <html>
        <head>
          <title>Classes Test</title>
        </head>
        <body>
          <div>
            <h1 class="my-custom-class">Title</h1>
            <p class="another-class">Content</p>
          </div>
        </body>
        </html>
      ''';

      // With keepClasses=true, custom classes should be preserved
      final jsdomKeep =
          parse(htmlWithClasses, parser: ParserType.jsdom, keepClasses: true);
      final htmlKeep =
          parse(htmlWithClasses, parser: ParserType.html, keepClasses: true);

      expect(jsdomKeep?.content, contains('my-custom-class'));
      expect(htmlKeep?.content, contains('my-custom-class'));

      // With keepClasses=false, custom classes should be stripped
      final jsdomStrip =
          parse(htmlWithClasses, parser: ParserType.jsdom, keepClasses: false);
      final htmlStrip =
          parse(htmlWithClasses, parser: ParserType.html, keepClasses: false);

      expect(jsdomStrip?.content, isNot(contains('my-custom-class')));
      expect(htmlStrip?.content, isNot(contains('my-custom-class')));
    });
  });
}
