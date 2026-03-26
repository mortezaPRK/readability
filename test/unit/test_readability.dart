/// Unit tests for Readability library.
library;

import 'package:html/parser.dart' as html_parser;
import 'package:readability/readability.dart';
import 'package:test/test.dart';

void main() {
  group('Readability', () {
    group('constructor', () {
      // Tags: unit tests for Readability constructor
      late Document doc;

      setUp(() {
        final parser = JSDOMParser();
        doc = parser.parse('<html><body><div>Hello world</div></body></html>');
      });

      test('should create instance with default options', () {
        final reader = Readability(JsdomDomDocument(doc));
        expect(reader.debug, isFalse);
        expect(reader.maxElemsToParse, equals(0));
        expect(reader.numTopCandidates, equals(5));
        expect(reader.charThreshold, equals(500));
        expect(reader.keepClasses, isFalse);
      });

      test('should accept debug option', () {
        expect(Readability(JsdomDomDocument(doc)).debug, isFalse);
        expect(
          Readability(JsdomDomDocument(doc), ReadabilityOptions(debug: true))
              .debug,
          isTrue,
        );
      });

      test('should accept numTopCandidates option', () {
        expect(Readability(JsdomDomDocument(doc)).numTopCandidates, equals(5));
        expect(
          Readability(JsdomDomDocument(doc),
                  ReadabilityOptions(numTopCandidates: 10))
              .numTopCandidates,
          equals(10),
        );
      });

      test('should accept maxElemsToParse option', () {
        expect(Readability(JsdomDomDocument(doc)).maxElemsToParse, equals(0));
        expect(
          Readability(JsdomDomDocument(doc),
                  ReadabilityOptions(maxElemsToParse: 100))
              .maxElemsToParse,
          equals(100),
        );
      });

      test('should accept charThreshold option', () {
        expect(Readability(JsdomDomDocument(doc)).charThreshold, equals(500));
        expect(
          Readability(
                  JsdomDomDocument(doc), ReadabilityOptions(charThreshold: 250))
              .charThreshold,
          equals(250),
        );
      });

      test('should accept keepClasses option', () {
        expect(Readability(JsdomDomDocument(doc)).keepClasses, isFalse);
        expect(
          Readability(
                  JsdomDomDocument(doc), ReadabilityOptions(keepClasses: true))
              .keepClasses,
          isTrue,
        );
      });

      test('should accept classesToPreserve option', () {
        // classesToPreserve is used internally during parsing
        // Test by verifying that classes are preserved in output
        final parser = JSDOMParser();
        final testDoc = parser.parse(
          '<html><body>'
          '<article>'
          '<p class="important highlight">${'Content. ' * 30}</p>'
          '</article>'
          '</body></html>',
        );
        final reader = Readability(
          JsdomDomDocument(testDoc),
          ReadabilityOptions(classesToPreserve: ['important', 'highlight']),
        );
        final result = reader.parse();
        expect(result?.content, contains('class="'));
        expect(result?.content, contains('important'));
        expect(result?.content, contains('highlight'));
      });
    });

    group('parse()', () {
      test('should return Article with content for valid document', () {
        final parser = JSDOMParser();
        final doc = parser.parse(
          '<html><body>'
          '<article>'
          '<p>${'This is valid article content. ' * 30}</p>'
          '</article>'
          '</body></html>',
        );
        final reader = Readability(JsdomDomDocument(doc));
        final result = reader.parse();
        expect(result, isNotNull);
        expect(result!.content, contains('valid article content'));
      });

      test('should throw when maxElemsToParse is exceeded', () {
        final parser = JSDOMParser();
        final doc = parser.parse(
          '<html><body><div><p>1</p><p>2</p><p>3</p></div></body></html>',
        );
        expect(
          () => Readability(
                  JsdomDomDocument(doc), ReadabilityOptions(maxElemsToParse: 1))
              .parse(),
          throwsA(predicate((e) => e.toString().contains('Aborting parsing'))),
        );
      });

      test('should extract title from <title> tag', () {
        final parser = JSDOMParser();
        final doc = parser.parse(
          '<html>'
          '<head><title>Test Title</title></head>'
          '<body>'
          '<article>'
          '<p>${'Lorem ipsum dolor sit amet. ' * 20}</p>'
          '</article>'
          '</body>'
          '</html>',
        );
        final reader = Readability(JsdomDomDocument(doc));
        final result = reader.parse();
        expect(result?.title, equals('Test Title'));
      });

      test('should extract title from og:title meta tag', () {
        final parser = JSDOMParser();
        final doc = parser.parse(
          '<html>'
          '<head>'
          '<title>Page Title</title>'
          '<meta property="og:title" content="OG Title"/>'
          '</head>'
          '<body>'
          '<article>'
          '<p>${'Lorem ipsum dolor sit amet. ' * 20}</p>'
          '</article>'
          '</body>'
          '</html>',
        );
        final reader = Readability(JsdomDomDocument(doc));
        final result = reader.parse();
        expect(result?.title, equals('OG Title'));
      });

      test('should extract byline from author meta tag', () {
        final parser = JSDOMParser();
        final doc = parser.parse(
          '<html>'
          '<head>'
          '<meta name="author" content="John Doe"/>'
          '</head>'
          '<body>'
          '<article>'
          '<p>${'Lorem ipsum dolor sit amet. ' * 20}</p>'
          '</article>'
          '</body>'
          '</html>',
        );
        final reader = Readability(JsdomDomDocument(doc));
        final result = reader.parse();
        expect(result?.byline, equals('John Doe'));
      });

      test('should extract excerpt from description meta tag', () {
        final parser = JSDOMParser();
        final doc = parser.parse(
          '<html>'
          '<head>'
          '<meta name="description" content="This is the article description."/>'
          '</head>'
          '<body>'
          '<article>'
          '<p>${'Lorem ipsum dolor sit amet. ' * 20}</p>'
          '</article>'
          '</body>'
          '</html>',
        );
        final reader = Readability(JsdomDomDocument(doc));
        final result = reader.parse();
        expect(result?.excerpt, equals('This is the article description.'));
      });

      test('should extract siteName from og:site_name', () {
        final parser = JSDOMParser();
        final doc = parser.parse(
          '<html>'
          '<head>'
          '<meta property="og:site_name" content="Example Site"/>'
          '</head>'
          '<body>'
          '<article>'
          '<p>${'Lorem ipsum dolor sit amet. ' * 20}</p>'
          '</article>'
          '</body>'
          '</html>',
        );
        final reader = Readability(JsdomDomDocument(doc));
        final result = reader.parse();
        expect(result?.siteName, equals('Example Site'));
      });

      test('should extract content from article element', () {
        final parser = JSDOMParser();
        final doc = parser.parse(
          '<html>'
          '<body>'
          '<article>'
          '<h1>Article Title</h1>'
          '<p>${'This is paragraph content. ' * 30}</p>'
          '</article>'
          '<aside>Sidebar content</aside>'
          '</body>'
          '</html>',
        );
        final reader = Readability(JsdomDomDocument(doc));
        final result = reader.parse();
        expect(result, isNotNull);
        expect(result!.content, contains('This is paragraph content'));
        expect(result.content, isNot(contains('Sidebar content')));
      });

      test('should handle JSON-LD metadata', () {
        final parser = JSDOMParser();
        final doc = parser.parse(
          '<html>'
          '<head>'
          '<script type="application/ld+json">'
          '{"@context":"http://schema.org","@type":"Article",'
          '"headline":"JSON-LD Title",'
          '"author":{"@type":"Person","name":"Jane Smith"},'
          '"description":"JSON-LD description"}'
          '</script>'
          '</head>'
          '<body>'
          '<article>'
          '<p>${'Lorem ipsum dolor sit amet. ' * 20}</p>'
          '</article>'
          '</body>'
          '</html>',
        );
        final reader = Readability(JsdomDomDocument(doc));
        final result = reader.parse();
        expect(result?.title, equals('JSON-LD Title'));
        expect(result?.byline, equals('Jane Smith'));
        expect(result?.excerpt, equals('JSON-LD description'));
      });

      test('should preserve classes when keepClasses is true', () {
        final parser = JSDOMParser();
        final doc = parser.parse(
          '<html>'
          '<body>'
          '<article>'
          '<p class="intro lead">${'Lorem ipsum. ' * 30}</p>'
          '</article>'
          '</body>'
          '</html>',
        );
        final reader = Readability(
            JsdomDomDocument(doc), ReadabilityOptions(keepClasses: true));
        final result = reader.parse();
        expect(result?.content, contains('class='));
      });

      test('should strip classes when keepClasses is false', () {
        final parser = JSDOMParser();
        final doc = parser.parse(
          '<html>'
          '<body>'
          '<article>'
          '<p class="intro lead">${'Lorem ipsum. ' * 30}</p>'
          '</article>'
          '</body>'
          '</html>',
        );
        final reader = Readability(
            JsdomDomDocument(doc), ReadabilityOptions(keepClasses: false));
        final result = reader.parse();
        expect(result?.content, isNot(contains('class="intro')));
      });

      test('should preserve specified classes via classesToPreserve', () {
        final parser = JSDOMParser();
        final doc = parser.parse(
          '<html>'
          '<body>'
          '<article>'
          '<p class="caption other">${'Lorem ipsum. ' * 30}</p>'
          '</article>'
          '</body>'
          '</html>',
        );
        final reader = Readability(
          JsdomDomDocument(doc),
          ReadabilityOptions(classesToPreserve: ['caption']),
        );
        final result = reader.parse();
        expect(result?.content, contains('class="caption"'));
        expect(result?.content, isNot(contains('other')));
      });
    });

    group('Article', () {
      test('toJson() should return correct structure', () {
        final parser = JSDOMParser();
        final doc = parser.parse(
          '<html>'
          '<head><title>Test</title></head>'
          '<body>'
          '<article>'
          '<p>${'Lorem ipsum dolor sit amet. ' * 20}</p>'
          '</article>'
          '</body>'
          '</html>',
        );
        final reader = Readability(JsdomDomDocument(doc));
        final result = reader.parse();
        final json = result?.toJson();

        expect(json, isNotNull);
        expect(json, contains('title'));
        expect(json, contains('byline'));
        expect(json, contains('dir'));
        expect(json, contains('lang'));
        expect(json, contains('content'));
        expect(json, contains('textContent'));
        expect(json, contains('length'));
        expect(json, contains('excerpt'));
        expect(json, contains('siteName'));
        expect(json, contains('publishedTime'));
      });

      test('length should reflect text content length', () {
        final parser = JSDOMParser();
        final content = 'Test content. ' * 50;
        final doc = parser.parse(
          '<html>'
          '<body>'
          '<article><p>$content</p></article>'
          '</body>'
          '</html>',
        );
        final reader = Readability(JsdomDomDocument(doc));
        final result = reader.parse();
        expect(result?.length, greaterThan(0));
        expect(result?.textContent, contains('Test content'));
      });
    });
  });

  group('ReadabilityOptions', () {
    test('should have correct default values', () {
      final options = ReadabilityOptions();
      expect(options.debug, isFalse);
      expect(options.maxElemsToParse, equals(0));
      expect(options.numTopCandidates, equals(5));
      expect(options.charThreshold, equals(500));
      expect(options.keepClasses, isFalse);
      expect(options.classesToPreserve, isEmpty);
      expect(options.enableJSONLD, isTrue);
      expect(options.allowedVideoRegex, isNull);
    });

    test('should accept custom values', () {
      final options = ReadabilityOptions(
        debug: true,
        maxElemsToParse: 100,
        numTopCandidates: 10,
        charThreshold: 250,
        keepClasses: true,
        classesToPreserve: ['important'],
        enableJSONLD: false,
        allowedVideoRegex: RegExp(r'youtube'),
      );
      expect(options.debug, isTrue);
      expect(options.maxElemsToParse, equals(100));
      expect(options.numTopCandidates, equals(10));
      expect(options.charThreshold, equals(250));
      expect(options.keepClasses, isTrue);
      expect(options.classesToPreserve, contains('important'));
      expect(options.enableJSONLD, isFalse);
      expect(options.allowedVideoRegex, isNotNull);
    });
  });

  group('isProbablyReaderable + parse workflow', () {
    test('should return null for non-readerable content', () {
      final html = '''
        <html>
          <head><title>Short</title></head>
          <body>
            <div>Too short to be an article.</div>
          </body>
        </html>
      ''';

      final doc = html_parser.parse(html);
      if (!isProbablyReaderable(doc)) {
        expect(true, isTrue); // Content is not readerable as expected
      } else {
        final article = parse(html);
        expect(article, isNull);
      }
    });

    test('should parse readerable content', () {
      final html = '''
        <html>
          <head><title>Good Article</title></head>
          <body>
            <article>
              <h1>Article Title</h1>
              <p>This is paragraph one with enough content to be considered readerable. It has substantial text that makes it a good article candidate.</p>
              <p>This is paragraph two with more content and additional information. We need to make sure this passes the readability check with flying colors.</p>
              <p>This is paragraph three with even more content to ensure readability. Adding more sentences here to make absolutely sure we have enough text.</p>
              <p>And a fourth paragraph to really seal the deal with lots of meaningful content. This should definitely pass any reasonable threshold.</p>
              <p>Fifth paragraph just to be absolutely certain we have enough content for the readability check to pass without any issues.</p>
            </article>
          </body>
        </html>
      ''';

      final doc = html_parser.parse(html);
      expect(isProbablyReaderable(doc), isTrue);
      final article = parse(html);
      expect(article, isNotNull);
      expect(article?.title, contains('Article'));
      expect(article?.content, isNotEmpty);
    });

    test('should respect custom minContentLength option', () {
      final html = '''
        <html>
          <body>
            <article>
              <p>Medium length content here that might pass with lower threshold. This paragraph has substantial text content.</p>
              <p>Second paragraph with more text and additional information to make it longer.</p>
              <p>Third paragraph adding even more content to reach the threshold.</p>
            </article>
          </body>
        </html>
      ''';

      final doc = html_parser.parse(html);

      // Should fail with high threshold
      final strictReaderable = isProbablyReaderable(
        doc,
        ReaderableOptions(minContentLength: 1000),
      );
      expect(strictReaderable, isFalse);

      // Should pass with low threshold
      final lenientReaderable = isProbablyReaderable(
        doc,
        ReaderableOptions(minContentLength: 50),
      );
      expect(lenientReaderable, isTrue);
    });

    test('should respect custom minScore option', () {
      final html = '''
        <html>
          <body>
            <article>
              <p>Some content here that is long enough to be considered.</p>
              <p>More content here with additional text.</p>
              <p>Even more content to make this substantial.</p>
              <p>And another paragraph for good measure.</p>
            </article>
          </body>
        </html>
      ''';

      final doc = html_parser.parse(html);

      // Should fail with very high score requirement
      final strictReaderable = isProbablyReaderable(
        doc,
        ReaderableOptions(minScore: 100),
      );
      expect(strictReaderable, isFalse);

      // Should pass with low score requirement
      final lenientReaderable = isProbablyReaderable(
        doc,
        ReaderableOptions(minScore: 5),
      );
      expect(lenientReaderable, isTrue);
    });

    test('should work with baseUri parameter', () {
      final html = '''
        <html>
          <head><title>Article with Links</title></head>
          <body>
            <article>
              <h1>Main Title</h1>
              <p>Content with <a href="/relative">relative link</a> here.</p>
              <p>More content here to make it readerable and substantial.</p>
              <p>Even more content to ensure we pass the threshold check.</p>
              <p>Another paragraph with meaningful text content.</p>
              <p>And one more for good measure to be safe.</p>
            </article>
          </body>
        </html>
      ''';

      final doc = html_parser.parse(html);
      final isReaderable = isProbablyReaderable(
        doc,
        ReaderableOptions(minContentLength: 100, minScore: 10),
      );
      expect(isReaderable, isTrue);

      final article = parse(html, baseUri: 'https://example.com');
      expect(article, isNotNull);
      expect(article?.title, isNotEmpty);
    });

    test('should work with parse options', () {
      final html = '''
        <html>
          <body>
            <article class="main-content">
              <h1>Article Title</h1>
              <p>Content paragraph one with substantial text.</p>
              <p>Content paragraph two with more information.</p>
              <p>Content paragraph three with even more details.</p>
              <p>Content paragraph four to ensure readability.</p>
              <p>Content paragraph five for good measure.</p>
            </article>
          </body>
        </html>
      ''';

      final doc = html_parser.parse(html);
      final isReaderable = isProbablyReaderable(
        doc,
        ReaderableOptions(minContentLength: 100, minScore: 10),
      );
      expect(isReaderable, isTrue);

      final article = parse(html, keepClasses: true, charThreshold: 50);
      expect(article, isNotNull);
      expect(article?.content, contains('main-content'));
    });

    test('should handle empty HTML gracefully', () {
      final doc = html_parser.parse('');
      expect(isProbablyReaderable(doc), isFalse);
    });

    test('should handle HTML with no body', () {
      final html = '<html><head><title>No Body</title></head></html>';
      final doc = html_parser.parse(html);
      expect(isProbablyReaderable(doc), isFalse);
    });

    test('should handle malformed HTML', () {
      final html =
          '<html><body><p>Unclosed paragraph<div>Mixed nesting</p></div>';
      // Should not crash
      final doc = html_parser.parse(html);
      expect(() => isProbablyReaderable(doc), returnsNormally);
    });

    test('should return false for gallery pages', () {
      final html = '''
        <html>
          <body>
            <div class="gallery">
              <img src="1.jpg" alt="Image 1">
              <img src="2.jpg" alt="Image 2">
              <img src="3.jpg" alt="Image 3">
            </div>
          </body>
        </html>
      ''';

      final doc = html_parser.parse(html);
      expect(isProbablyReaderable(doc), isFalse);
    });
  });
}
