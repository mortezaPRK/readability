/// Tests for the new querySelector and querySelectorAll methods in JSDOMParser.
library;

import 'package:reader_mode/reader_mode.dart';
import 'package:test/test.dart';

void main() {
  group('JSDOMParser querySelector', () {
    test('Document.querySelector with ID selector', () {
      final html = '<div id="test">Content</div>';
      final doc = JSDOMParser().parse(html);

      final result = doc.querySelector('#test');
      expect(result, isNotNull);
      expect(result!.id, equals('test'));
    });

    test('Document.querySelector with class selector', () {
      final html = '<div class="content">Text</div>';
      final doc = JSDOMParser().parse(html);

      final result = doc.querySelector('.content');
      expect(result, isNotNull);
      expect(result!.className, equals('content'));
    });

    test('Document.querySelector with tag selector', () {
      final html = '<div>Text</div><span>Other</span>';
      final doc = JSDOMParser().parse(html);

      final result = doc.querySelector('div');
      expect(result, isNotNull);
      expect(result!.tagName, equals('DIV'));
    });

    test('Document.querySelector with combined tag.class selector', () {
      final html =
          '<div class="content">Text</div><span class="content">Other</span>';
      final doc = JSDOMParser().parse(html);

      final result = doc.querySelector('div.content');
      expect(result, isNotNull);
      expect(result!.tagName, equals('DIV'));
      expect(result.className, equals('content'));
    });

    test('Document.querySelector with combined tag#id selector', () {
      final html = '<div id="main">Text</div><span id="main">Other</span>';
      final doc = JSDOMParser().parse(html);

      final result = doc.querySelector('div#main');
      expect(result, isNotNull);
      expect(result!.tagName, equals('DIV'));
      expect(result.id, equals('main'));
    });

    test('Document.querySelector returns null when no match', () {
      final html = '<div>Text</div>';
      final doc = JSDOMParser().parse(html);

      final result = doc.querySelector('.nonexistent');
      expect(result, isNull);
    });

    test(
        'Document.querySelector with descendant selector returns null (not supported)',
        () {
      final html = '<div><p>Text</p></div>';
      final doc = JSDOMParser().parse(html);

      // Descendant selectors are not supported
      final result = doc.querySelector('div p');
      expect(result, isNull);
    });
  });

  group('JSDOMParser querySelectorAll', () {
    test('Document.querySelectorAll with class selector', () {
      final html =
          '<div class="item">1</div><div class="item">2</div><span class="item">3</span>';
      final doc = JSDOMParser().parse(html);

      final results = doc.querySelectorAll('.item');
      expect(results.length, equals(3));
    });

    test('Document.querySelectorAll with tag selector', () {
      final html = '<div>1</div><div>2</div><span>3</span>';
      final doc = JSDOMParser().parse(html);

      final results = doc.querySelectorAll('div');
      expect(results.length, equals(2));
    });

    test('Document.querySelectorAll with combined selector', () {
      final html =
          '<div class="item">1</div><div class="other">2</div><span class="item">3</span>';
      final doc = JSDOMParser().parse(html);

      final results = doc.querySelectorAll('div.item');
      expect(results.length, equals(1));
      expect(results.first.className, equals('item'));
    });

    test('Element.querySelector within subtree', () {
      final html = '''
        <div id="outer">
          <span class="inner">1</span>
          <p class="inner">2</p>
        </div>
        <span class="inner">3</span>
      ''';
      final doc = JSDOMParser().parse(html);

      final outer = doc.getElementById('outer');
      expect(outer, isNotNull);

      final results = outer!.querySelectorAll('.inner');
      // Should only find inner elements within #outer
      expect(results.length, equals(2));
    });

    test('Element.querySelector finds direct child', () {
      final html = '<div id="outer"><span class="target">Text</span></div>';
      final doc = JSDOMParser().parse(html);

      final outer = doc.getElementById('outer');
      expect(outer, isNotNull);

      final result = outer!.querySelector('.target');
      expect(result, isNotNull);
      expect(result!.className, equals('target'));
    });
  });

  group('JSDOMParser selector edge cases', () {
    test('Handles multiple classes in selector (first one only)', () {
      final html = '<div class="foo bar">Text</div>';
      final doc = JSDOMParser().parse(html);

      // .foo.bar will match .foo
      final result = doc.querySelector('.foo.bar');
      expect(result, isNotNull);
      expect(result!.className, contains('foo'));
    });

    test('Handles hyphenated class names', () {
      final html = '<div class="my-class">Text</div>';
      final doc = JSDOMParser().parse(html);

      final result = doc.querySelector('.my-class');
      expect(result, isNotNull);
      expect(result!.className, equals('my-class'));
    });

    test('Handles hyphenated IDs', () {
      final html = '<div id="my-id">Text</div>';
      final doc = JSDOMParser().parse(html);

      final result = doc.querySelector('#my-id');
      expect(result, isNotNull);
      expect(result!.id, equals('my-id'));
    });

    test('Handles underscore in names', () {
      final html = '<div class="my_class" id="my_id">Text</div>';
      final doc = JSDOMParser().parse(html);

      final classResult = doc.querySelector('.my_class');
      expect(classResult, isNotNull);

      final idResult = doc.querySelector('#my_id');
      expect(idResult, isNotNull);
    });

    test('Empty selector returns null', () {
      final html = '<div>Text</div>';
      final doc = JSDOMParser().parse(html);

      final result = doc.querySelector('');
      expect(result, isNull);
    });

    test('Whitespace-only selector returns null', () {
      final html = '<div>Text</div>';
      final doc = JSDOMParser().parse(html);

      final result = doc.querySelector('   ');
      expect(result, isNull);
    });
  });

  group('JSDOMParser selector limitations', () {
    test('Attribute selectors are not supported', () {
      final html = '<div data-value="123">Text</div>';
      final doc = JSDOMParser().parse(html);

      final result = doc.querySelector('[data-value]');
      expect(result, isNull);
    });

    test('Pseudo-class selectors are not supported', () {
      final html = '<div><p>First</p><p>Second</p></div>';
      final doc = JSDOMParser().parse(html);

      final result = doc.querySelector('p:first-child');
      expect(result, isNull);
    });

    test('Child combinator is not supported', () {
      final html = '<div><p>Text</p></div>';
      final doc = JSDOMParser().parse(html);

      final result = doc.querySelector('div > p');
      expect(result, isNull);
    });
  });

  group('JSDOMParser selector performance', () {
    test('querySelectorAll on large document', () {
      final items =
          List.generate(100, (i) => '<div class="item">Item $i</div>').join();
      final html = '<div id="container">$items</div>';
      final doc = JSDOMParser().parse(html);

      final results = doc.querySelectorAll('.item');
      expect(results.length, equals(100));
    });

    test('querySelector returns first match only', () {
      final html =
          '<div class="target">First</div><div class="target">Second</div>';
      final doc = JSDOMParser().parse(html);

      final result = doc.querySelector('.target');
      expect(result, isNotNull);
      expect(result!.textContent, equals('First'));
    });
  });
}
