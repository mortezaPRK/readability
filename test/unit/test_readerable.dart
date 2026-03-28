/// Unit tests for isProbablyReaderable function.
library;

import 'package:html/parser.dart' as html_parser;
import 'package:reader_mode/reader_mode.dart';
import 'package:test/test.dart';

void main() {
  group('isProbablyReaderable', () {
    group('content length thresholds', () {
      final verySmallDoc =
          html_parser.parse('<html><p id="main">hello there</p></html>');
      final smallDoc = html_parser.parse(
        '<html><p id="main">${'hello there ' * 11}</p></html>',
      );
      final largeDoc = html_parser.parse(
        '<html><p id="main">${'hello there ' * 12}</p></html>',
      );
      final veryLargeDoc = html_parser.parse(
        '<html><p id="main">${'hello there ' * 50}</p></html>',
      );

      test(
          'should only declare large documents as readerable with default options',
          () {
        expect(isProbablyReaderable(verySmallDoc), isFalse,
            reason: 'very small doc');
        expect(isProbablyReaderable(smallDoc), isFalse, reason: 'small doc');
        expect(isProbablyReaderable(largeDoc), isFalse, reason: 'large doc');
        expect(isProbablyReaderable(veryLargeDoc), isTrue,
            reason: 'very large doc');
      });

      test(
          'should declare small and large documents as readerable with lower minContentLength',
          () {
        final options = ReaderableOptions(
          minContentLength: 120,
          minScore: 0,
        );
        expect(isProbablyReaderable(verySmallDoc, options), isFalse,
            reason: 'very small doc');
        expect(isProbablyReaderable(smallDoc, options), isTrue,
            reason: 'small doc');
        expect(isProbablyReaderable(largeDoc, options), isTrue,
            reason: 'large doc');
        expect(isProbablyReaderable(veryLargeDoc, options), isTrue,
            reason: 'very large doc');
      });

      test(
          'should only declare largest document as readerable with higher minContentLength',
          () {
        final options = ReaderableOptions(
          minContentLength: 200,
          minScore: 0,
        );
        expect(isProbablyReaderable(verySmallDoc, options), isFalse,
            reason: 'very small doc');
        expect(isProbablyReaderable(smallDoc, options), isFalse,
            reason: 'small doc');
        expect(isProbablyReaderable(largeDoc, options), isFalse,
            reason: 'large doc');
        expect(isProbablyReaderable(veryLargeDoc, options), isTrue,
            reason: 'very large doc');
      });
    });

    group('score thresholds', () {
      final verySmallDoc =
          html_parser.parse('<html><p id="main">hello there</p></html>');
      final smallDoc = html_parser.parse(
        '<html><p id="main">${'hello there ' * 11}</p></html>',
      );
      final largeDoc = html_parser.parse(
        '<html><p id="main">${'hello there ' * 12}</p></html>',
      );
      final veryLargeDoc = html_parser.parse(
        '<html><p id="main">${'hello there ' * 50}</p></html>',
      );

      test(
          'should declare small and large documents as readerable with lower minScore',
          () {
        final options = ReaderableOptions(
          minContentLength: 0,
          minScore: 4,
        );
        expect(isProbablyReaderable(verySmallDoc, options), isFalse,
            reason: 'very small doc');
        expect(isProbablyReaderable(smallDoc, options), isTrue,
            reason: 'small doc');
        expect(isProbablyReaderable(largeDoc, options), isTrue,
            reason: 'large doc');
        expect(isProbablyReaderable(veryLargeDoc, options), isTrue,
            reason: 'very large doc');
      });

      test('should declare large documents as readerable with higher minScore',
          () {
        final options = ReaderableOptions(
          minContentLength: 0,
          minScore: 11,
        );
        expect(isProbablyReaderable(verySmallDoc, options), isFalse,
            reason: 'very small doc');
        expect(isProbablyReaderable(smallDoc, options), isTrue,
            reason: 'small doc');
        expect(isProbablyReaderable(largeDoc, options), isTrue,
            reason: 'large doc');
        expect(isProbablyReaderable(veryLargeDoc, options), isTrue,
            reason: 'very large doc');
      });
    });

    group('visibility checker', () {
      final veryLargeDoc = html_parser.parse(
        '<html><p id="main">${'hello there ' * 50}</p></html>',
      );

      test('should use custom visibility checker - not visible', () {
        var called = false;
        final options = ReaderableOptions(
          visibilityChecker: (_) {
            called = true;
            return false;
          },
        );
        expect(isProbablyReaderable(veryLargeDoc, options), isFalse);
        expect(called, isTrue);
      });

      test('should use custom visibility checker - visible', () {
        var called = false;
        final options = ReaderableOptions(
          visibilityChecker: (_) {
            called = true;
            return true;
          },
        );
        expect(isProbablyReaderable(veryLargeDoc, options), isTrue);
        expect(called, isTrue);
      });
    });

    group('element types', () {
      test('should consider paragraph elements', () {
        final doc = html_parser.parse(
          '<html><body><p>${'Content here. ' * 50}</p></body></html>',
        );
        expect(isProbablyReaderable(doc), isTrue);
      });

      test('should consider pre elements', () {
        final doc = html_parser.parse(
          '<html><body><pre>${'Code content. ' * 50}</pre></body></html>',
        );
        expect(isProbablyReaderable(doc), isTrue);
      });

      test('should consider article elements', () {
        final doc = html_parser.parse(
          '<html><body><article>${'Article content. ' * 50}</article></body></html>',
        );
        expect(isProbablyReaderable(doc), isTrue);
      });

      test('should ignore unlikely candidates', () {
        final doc = html_parser.parse(
          '<html><body><div class="comment">${'Comment. ' * 100}</div></body></html>',
        );
        expect(isProbablyReaderable(doc), isFalse);
      });

      test('should recognize likely candidates', () {
        final doc = html_parser.parse(
          '<html><body><p class="article-body">${'Main content. ' * 50}</p></body></html>',
        );
        expect(isProbablyReaderable(doc), isTrue);
      });
    });
  });

  group('ReaderableOptions', () {
    test('should have correct default values', () {
      final options = ReaderableOptions();
      expect(options.minContentLength, equals(140));
      expect(options.minScore, equals(20));
      // visibilityChecker has a default implementation, not null
      expect(options.visibilityChecker, isNotNull);
    });

    test('should accept custom values', () {
      final options = ReaderableOptions(
        minContentLength: 100,
        minScore: 10,
        visibilityChecker: (_) => true,
      );
      expect(options.minContentLength, equals(100));
      expect(options.minScore, equals(10));
      expect(options.visibilityChecker, isNotNull);
    });
  });
}
