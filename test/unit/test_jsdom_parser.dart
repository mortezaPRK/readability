/// Unit tests for JSDOM parser.
library;

import 'package:reader_mode/reader_mode.dart' as jsdom;
import 'package:test/test.dart';

const _baseTestCase =
    '<html><body><p>Some text and <a class="someclass" href="#">a link</a></p>'
    '<div id="foo">With a <script>With &lt; fancy " characters in it because'
    '</script> that is fun.<span>And another node to make it harder</span></div>'
    '<form><input type="text"/><input type="number"/>Here\'s a form</form></body></html>';

void main() {
  late jsdom.Document baseDoc;

  setUpAll(() {
    baseDoc = jsdom.JSDOMParser().parse(_baseTestCase, 'http://fakehost/');
  });

  group('Test JSDOM functionality', () {
    test(
      'should work for basic operations using the parent child hierarchy and innerHTML',
      () {
        expect(baseDoc.childNodes.length, equals(1));
        expect(baseDoc.getElementsByTagName('*').length, equals(10));
        final foo = baseDoc.getElementById('foo')!;
        expect(foo.parentNode!.localName, equals('body'));
        expect(baseDoc.body, equals(foo.parentNode));
        expect(baseDoc.body!.parentNode, equals(baseDoc.documentElement));
        expect(baseDoc.body!.childNodes.length, equals(3));

        var generatedHTML = baseDoc.getElementsByTagName('p')[0].innerHTML;
        expect(
          generatedHTML,
          equals('Some text and <a class="someclass" href="#">a link</a>'),
        );
        final scriptNode = baseDoc.getElementsByTagName('script')[0];
        generatedHTML = scriptNode.innerHTML;
        // Script content is raw text - entities preserved as-is
        expect(
          generatedHTML,
          equals('With &lt; fancy " characters in it because'),
        );
        // Per JSDOM behavior, textContent also preserves entities in script tags
        expect(
          scriptNode.textContent,
          equals('With &lt; fancy " characters in it because'),
        );
      },
    );

    test('should have basic URI information', () {
      expect(baseDoc.documentURI, equals('http://fakehost/'));
      expect(baseDoc.baseURI, equals('http://fakehost/'));
    });

    test('should deal with script tags', () {
      final scripts = baseDoc.getElementsByTagName('script');
      expect(scripts.length, equals(1));
      // Per JSDOM behavior, textContent preserves entities in script tags
      expect(
        scripts[0].textContent,
        equals('With &lt; fancy " characters in it because'),
      );
    });

    test('should have working sibling/first+lastChild properties', () {
      final foo = baseDoc.getElementById('foo')!;

      expect(foo.previousSibling!.nextSibling, equals(foo));
      expect(foo.nextSibling!.previousSibling, equals(foo));
      expect(foo.nextSibling, equals(foo.nextElementSibling));
      expect(foo.previousSibling, equals(foo.previousElementSibling));

      final beforeFoo = foo.previousSibling!;
      final afterFoo = foo.nextSibling!;

      expect(baseDoc.body!.lastChild, equals(afterFoo));
      expect(baseDoc.body!.firstChild, equals(beforeFoo));
    });

    test(
      'should have working removeChild and appendChild functionality',
      () {
        // Re-parse for this test since it mutates the DOM
        final doc =
            jsdom.JSDOMParser().parse(_baseTestCase, 'http://fakehost/');
        final foo = doc.getElementById('foo')!;
        final beforeFoo = foo.previousSibling!;
        final afterFoo = foo.nextSibling!;

        final removedFoo = foo.parentNode!.removeChild(foo);
        expect(removedFoo, equals(foo));
        expect(foo.parentNode, isNull);
        expect(foo.previousSibling, isNull);
        expect(foo.nextSibling, isNull);
        expect((foo).previousElementSibling, isNull);
        expect(foo.nextElementSibling, isNull);

        expect(beforeFoo.localName, equals('p'));
        expect(beforeFoo.nextSibling, equals(afterFoo));
        expect(afterFoo.previousSibling, equals(beforeFoo));
        expect(
            (beforeFoo as jsdom.Element).nextElementSibling, equals(afterFoo));
        expect((afterFoo as jsdom.Element).previousElementSibling,
            equals(beforeFoo));

        expect(doc.body!.childNodes.length, equals(2));

        doc.body!.appendChild(foo);

        expect(doc.body!.childNodes.length, equals(3));
        expect(afterFoo.nextSibling, equals(foo));
        expect(foo.previousSibling, equals(afterFoo));
        expect(afterFoo.nextElementSibling, equals(foo));
        expect(foo.previousElementSibling, equals(afterFoo));

        // This should reorder back to sanity:
        doc.body!.appendChild(afterFoo);
        expect(foo.previousSibling, equals(beforeFoo));
        expect(foo.nextSibling, equals(afterFoo));
        expect(foo.previousElementSibling, equals(beforeFoo));
        expect(foo.nextElementSibling, equals(afterFoo));

        expect(foo.previousSibling!.nextSibling, equals(foo));
        expect(foo.nextSibling!.previousSibling, equals(foo));
        expect(foo.nextSibling, equals(foo.nextElementSibling));
        expect(foo.previousSibling, equals(foo.previousElementSibling));
      },
    );

    test('should handle attributes', () {
      final link = baseDoc.getElementsByTagName('a')[0];
      expect(link.getAttribute('href'), equals('#'));
      expect(link.getAttribute('class'), equals(link.className));
      final foo = baseDoc.getElementById('foo')!;
      expect(foo.id, equals(foo.getAttribute('id')));
    });

    test('should have a working replaceChild', () {
      // Re-parse for this test since it mutates the DOM
      final doc = jsdom.JSDOMParser().parse(_baseTestCase, 'http://fakehost/');
      final parent = doc.getElementsByTagName('div')[0];
      final p = doc.createElement('p');
      p.setAttribute('id', 'my-replaced-kid');
      final childCount = parent.childNodes.length;
      final childElCount = parent.children.length;

      for (var i = 0; i < parent.childNodes.length; i++) {
        final replacedNode = parent.childNodes[i];
        final replacedAnElement =
            replacedNode.nodeType == jsdom.Node.ELEMENT_NODE;
        final oldNext = replacedNode.nextSibling;
        final oldNextEl = replacedAnElement
            ? (replacedNode as jsdom.Element).nextElementSibling
            : null;
        final oldPrev = replacedNode.previousSibling;
        final oldPrevEl = replacedAnElement
            ? (replacedNode as jsdom.Element).previousElementSibling
            : null;

        parent.replaceChild(p, replacedNode);

        // Check siblings and parents on both nodes were set:
        expect(p.nextSibling, equals(oldNext));
        expect(p.previousSibling, equals(oldPrev));
        expect(p.parentNode, equals(parent));

        expect(replacedNode.parentNode, isNull);
        expect(replacedNode.nextSibling, isNull);
        expect(replacedNode.previousSibling, isNull);
        if (replacedAnElement) {
          expect((replacedNode as jsdom.Element).nextElementSibling, isNull);
          expect(replacedNode.previousElementSibling, isNull);
        }

        // Check the siblings were updated
        if (oldNext != null) {
          expect(oldNext.previousSibling, equals(p));
        }
        if (oldPrev != null) {
          expect(oldPrev.nextSibling, equals(p));
        }

        // Check the array was updated
        expect(parent.childNodes[i], equals(p));

        // Now check element properties/lists:
        final kidElementIndex = parent.children.indexOf(p);
        expect(kidElementIndex, isNot(equals(-1)));

        if (kidElementIndex > 0) {
          expect(
            parent.children[kidElementIndex - 1],
            equals(p.previousElementSibling),
          );
          expect(p.previousElementSibling!.nextElementSibling, equals(p));
        } else {
          expect(p.previousElementSibling, isNull);
        }
        if (kidElementIndex < parent.children.length - 1) {
          expect(
            parent.children[kidElementIndex + 1],
            equals(p.nextElementSibling),
          );
          expect(p.nextElementSibling!.previousElementSibling, equals(p));
        } else {
          expect(p.nextElementSibling, isNull);
        }

        if (replacedAnElement) {
          expect(oldNextEl, equals(p.nextElementSibling));
          expect(oldPrevEl, equals(p.previousElementSibling));
        }

        expect(parent.childNodes.length, equals(childCount));
        expect(
          parent.children.length,
          equals(replacedAnElement ? childElCount : childElCount + 1),
        );

        parent.replaceChild(replacedNode, p);

        expect(replacedNode.nextSibling, equals(oldNext));
        if (replacedAnElement) {
          expect(
            (replacedNode as jsdom.Element).nextElementSibling,
            equals(oldNextEl),
          );
        }
        expect(replacedNode.previousSibling, equals(oldPrev));
        if (replacedAnElement) {
          expect(
            (replacedNode as jsdom.Element).previousElementSibling,
            equals(oldPrevEl),
          );
        }
        if (replacedNode.nextSibling != null) {
          expect(
            replacedNode.nextSibling!.previousSibling,
            equals(replacedNode),
          );
        }
        if (replacedNode.previousSibling != null) {
          expect(
            replacedNode.previousSibling!.nextSibling,
            equals(replacedNode),
          );
        }
        if (replacedAnElement) {
          final elem = replacedNode as jsdom.Element;
          if (elem.previousElementSibling != null) {
            expect(
              elem.previousElementSibling!.nextElementSibling,
              equals(elem),
            );
          }
          if (elem.nextElementSibling != null) {
            expect(
              elem.nextElementSibling!.previousElementSibling,
              equals(elem),
            );
          }
        }
      }
    });

    test('should have a working insertBefore', () {
      final doc = jsdom.JSDOMParser().parse(_baseTestCase);
      final body = doc.body!;
      final foo = doc.getElementById('foo')!;
      final p = doc.getElementsByTagName('p')[0];
      final form = doc.getElementsByTagName('form')[0];

      // Insert in the middle
      final newEl = doc.createElement('hr');
      body.insertBefore(newEl, foo);
      expect(p.nextSibling, equals(newEl));
      expect(newEl.nextSibling, equals(foo));
      expect(foo.previousSibling, equals(newEl));
      expect(newEl.previousSibling, equals(p));
      expect(p.nextElementSibling, equals(newEl));
      expect(newEl.nextElementSibling, equals(foo));
      expect(foo.previousElementSibling, equals(newEl));
      expect(newEl.previousElementSibling, equals(p));
      expect(body.childNodes.length, equals(4));
      expect(body.children.length, equals(4));

      // Insert at the end (ref = null)
      final newEl2 = doc.createElement('hr');
      body.insertBefore(newEl2, null);
      expect(body.lastChild, equals(newEl2));
      expect(form.nextSibling, equals(newEl2));
      expect(newEl2.previousSibling, equals(form));
      expect(body.childNodes.length, equals(5));
      expect(body.children.length, equals(5));

      // Insert at the beginning
      final newEl3 = doc.createElement('hr');
      body.insertBefore(newEl3, p);
      expect(body.firstChild, equals(newEl3));
      expect(newEl3.nextSibling, equals(p));
      expect(p.previousSibling, equals(newEl3));
      expect(body.childNodes.length, equals(6));
      expect(body.children.length, equals(6));
    });

    test(
      'should correctly handle mixed element/text siblings on insertBefore',
      () {
        // Insert between a text node and an element node
        final doc1 = jsdom.JSDOMParser()
            .parse('<div><p>A</p>Some Text<span>B</span></div>');
        final div1 = doc1.getElementsByTagName('div')[0];
        final pA1 = doc1.getElementsByTagName('p')[0];
        final textNode1 = div1.childNodes[1];
        final spanB1 = doc1.getElementsByTagName('span')[0];
        final newEl1 = doc1.createElement('hr');
        div1.insertBefore(newEl1, spanB1);
        expect(newEl1.previousSibling, equals(textNode1));
        expect(newEl1.previousElementSibling, equals(pA1));
        expect(newEl1.nextSibling, equals(spanB1));
        expect(newEl1.nextElementSibling, equals(spanB1));
        expect(pA1.nextElementSibling, equals(newEl1));
        expect(spanB1.previousElementSibling, equals(newEl1));

        // Insert between an element node and a text node
        final doc2 = jsdom.JSDOMParser()
            .parse('<div><p>A</p><span>B</span>Some Text</div>');
        final div2 = doc2.getElementsByTagName('div')[0];
        final pA2 = doc2.getElementsByTagName('p')[0];
        final spanB2 = doc2.getElementsByTagName('span')[0];
        final textNode2 = div2.childNodes[2];
        final newEl2 = doc2.createElement('hr');
        div2.insertBefore(newEl2, textNode2);
        expect(newEl2.previousSibling, equals(spanB2));
        expect(newEl2.previousElementSibling, equals(spanB2));
        expect(newEl2.nextSibling, equals(textNode2));
        expect(newEl2.nextElementSibling, isNull);
        expect(pA2.nextElementSibling, equals(spanB2));
        expect(spanB2.nextElementSibling, equals(newEl2));
      },
    );

    test('should throw an error when inserting before a non-child', () {
      final doc = jsdom.JSDOMParser().parse('<div><p>A</p></div>');
      final div = doc.getElementsByTagName('div')[0];
      final p = doc.createElement('p');
      final unconnected = doc.createElement('span');

      expect(
        () => div.insertBefore(p, unconnected),
        throwsStateError,
      );
    });

    test('should have a working createDocumentFragment', () {
      final doc = jsdom.JSDOMParser().parse(_baseTestCase);
      final body = doc.body!;
      final fragment = doc.createDocumentFragment();
      expect(fragment.nodeType, equals(jsdom.Node.DOCUMENT_FRAGMENT_NODE));
      expect(fragment.nodeName, equals('#document-fragment'));

      final p = doc.getElementsByTagName('p')[0];
      final foo = doc.getElementById('foo')!;

      fragment.appendChild(p);
      fragment.appendChild(foo);

      expect(p.parentNode, equals(fragment));
      expect(foo.parentNode, equals(fragment));
      expect(fragment.childNodes.length, equals(2));
      expect(fragment.children.length, equals(2));
      expect(body.childNodes.length, equals(1)); // only form is left

      body.appendChild(fragment);
      expect(body.childNodes.length, equals(3));
      expect(p.parentNode, equals(body));
      expect(foo.parentNode, equals(body));
      expect(fragment.childNodes.length, equals(0));
    });

    test('should handle moving an existing child with insertBefore', () {
      final doc =
          jsdom.JSDOMParser().parse('<div><p>A</p><p>B</p><p>C</p></div>');
      final div = doc.getElementsByTagName('div')[0];
      final pA = div.children[0];
      final pB = div.children[1];
      final pC = div.children[2];

      // Move C before B
      div.insertBefore(pC, pB);

      expect(div.children.length, equals(3));
      expect(div.children[0], equals(pA));
      expect(div.children[1], equals(pC));
      expect(div.children[2], equals(pB));

      expect(pA.previousSibling, isNull);
      expect(pA.nextSibling, equals(pC));
      expect(pC.previousSibling, equals(pA));
      expect(pC.nextSibling, equals(pB));
      expect(pB.previousSibling, equals(pC));
      expect(pB.nextSibling, isNull);
    });

    test('should handle inserting a node before itself as a no-op', () {
      final doc = jsdom.JSDOMParser().parse('<div><p>A</p><p>B</p></div>');
      final div = doc.getElementsByTagName('div')[0];
      final pA = div.children[0];
      final pB = div.children[1];

      div.insertBefore(pB, pB);

      expect(div.children.length, equals(2));
      expect(div.children[0], equals(pA));
      expect(div.children[1], equals(pB));
      expect(pA.nextSibling, equals(pB));
      expect(pB.previousSibling, equals(pA));
    });

    test('should handle replacing a node with itself as a no-op', () {
      final doc = jsdom.JSDOMParser().parse('<div><p>A</p><p>B</p></div>');
      final div = doc.getElementsByTagName('div')[0];
      final pA = div.children[0];
      final pB = div.children[1];

      div.replaceChild(pB, pB);

      expect(div.children.length, equals(2));
      expect(div.children[0], equals(pA));
      expect(div.children[1], equals(pB));
      expect(pA.nextSibling, equals(pB));
      expect(pB.previousSibling, equals(pA));
    });

    test('should correctly handle sibling pointers on remove()', () {
      final doc =
          jsdom.JSDOMParser().parse('<div><p>A</p>Some text<p>B</p></div>');
      final div = doc.getElementsByTagName('div')[0];
      final pA = div.children[0];
      final textNode = div.childNodes[1];
      final pB = div.children[1];

      expect(pA.nextElementSibling, equals(pB));
      expect(pB.previousElementSibling, equals(pA));

      textNode.remove();

      expect(pA.nextElementSibling, equals(pB));
      expect(pB.previousElementSibling, equals(pA));

      expect(textNode.parentNode, isNull);
      expect(textNode.nextSibling, isNull);
      expect(textNode.previousSibling, isNull);
    });
  });

  group('Test HTML escaping', () {
    final baseStr =
        '<p>Hello, everyone &amp; all their friends, &lt;this&gt; is a &quot; test with &apos; quotes.</p>';
    late jsdom.Document doc;
    late jsdom.Node p;
    late jsdom.Node txtNode;

    setUpAll(() {
      doc = jsdom.JSDOMParser().parse(baseStr);
      p = doc.getElementsByTagName('p')[0];
      txtNode = p.firstChild!;
    });

    test('should handle encoding HTML correctly', () {
      expect('<p>${p.innerHTML}</p>', equals(baseStr));
      expect('<p>${txtNode.innerHTML}</p>', equals(baseStr));
    });

    test('should have decoded correctly', () {
      expect(
        p.textContent,
        equals(
          'Hello, everyone & all their friends, <this> is a " test with \' quotes.',
        ),
      );
      expect(
        txtNode.textContent,
        equals(
          'Hello, everyone & all their friends, <this> is a " test with \' quotes.',
        ),
      );
    });

    test('should handle updates via textContent correctly', () {
      // Re-parse to avoid mutation issues
      final doc2 = jsdom.JSDOMParser().parse(baseStr);
      final p2 = doc2.getElementsByTagName('p')[0];
      final txtNode2 = p2.firstChild!;

      txtNode2.textContent = '${txtNode2.textContent} ';
      txtNode2.textContent = txtNode2.textContent.trim();
      final expectedHTML =
          baseStr.replaceFirst('&quot;', '"').replaceFirst('&apos;', "'");
      expect('<p>${txtNode2.innerHTML}</p>', equals(expectedHTML));
      expect('<p>${p2.innerHTML}</p>', equals(expectedHTML));
    });

    test('should handle decimal and hex escape sequences', () {
      final parsedDoc = jsdom.JSDOMParser().parse('<p>&#32;&#x20;</p>');
      expect(
        parsedDoc.getElementsByTagName('p')[0].textContent,
        equals('  '),
      );
    });
  });

  group('Script parsing', () {
    // Script content should be treated as raw text per HTML5 spec.
    // Tests updated to match JSDOM behavior.
    test('should keep ?-based processing instructions as raw text', () {
      final html = '<script><?Silly test <img src="test"></script>';
      final doc = jsdom.JSDOMParser().parse(html);
      expect(doc.firstChild!.nodeName, equals('SCRIPT'));
      expect(
        doc.firstChild!.textContent,
        equals('<?Silly test <img src="test">'),
      );
      expect(doc.firstChild!.children.length, equals(0));
      expect(doc.firstChild!.childNodes.length, equals(1));
    });

    test('should keep HTML comments as raw text within script tags', () {
      final html =
          '<script><!--Silly test > <script src="foo.js"></script>--></script>';
      final doc = jsdom.JSDOMParser().parse(html);
      expect(doc.firstChild!.nodeName, equals('SCRIPT'));
      expect(
        doc.firstChild!.textContent,
        equals('<!--Silly test > <script src="foo.js"></script>-->'),
      );
      expect(doc.firstChild!.children.length, equals(0));
      expect(doc.firstChild!.childNodes.length, equals(1));
    });

    test('should keep entities as-is within script tags', () {
      final html =
          "<script>&lt;div>Hello, I'm not really in a &lt;/div></script>";
      final doc = jsdom.JSDOMParser().parse(html);
      expect(doc.firstChild!.nodeName, equals('SCRIPT'));
      // Script content is raw text - entities are NOT decoded
      expect(
        doc.firstChild!.textContent,
        equals("&lt;div>Hello, I'm not really in a &lt;/div>"),
      );
      expect(doc.firstChild!.children.length, equals(0));
      expect(doc.firstChild!.childNodes.length, equals(1));
    });

    test('should keep script-like content as raw text', () {
      final html = '<script>&lt;script src="foo.js">&lt;/script></script>';
      final doc = jsdom.JSDOMParser().parse(html);
      expect(doc.firstChild!.nodeName, equals('SCRIPT'));
      // Script content is raw text - entities are NOT decoded
      expect(
        doc.firstChild!.textContent,
        equals('&lt;script src="foo.js">&lt;/script>'),
      );
      expect(doc.firstChild!.children.length, equals(0));
      expect(doc.firstChild!.childNodes.length, equals(1));
    });

    test('should not be confused by partial closing tags', () {
      final html = "<script>var x = '&lt;script>Hi&lt;' + '/script>';</script>";
      final doc = jsdom.JSDOMParser().parse(html);
      expect(doc.firstChild!.nodeName, equals('SCRIPT'));
      // Script content is raw text - entities are NOT decoded
      expect(
        doc.firstChild!.textContent,
        equals("var x = '&lt;script>Hi&lt;' + '/script>';"),
      );
      expect(doc.firstChild!.children.length, equals(0));
      expect(doc.firstChild!.childNodes.length, equals(1));
    });
  });

  group('Tag local name case handling', () {
    test('should lowercase tag names', () {
      final html = '<DIV><svG><clippath/></svG></DIV>';
      final doc = jsdom.JSDOMParser().parse(html);
      final first = doc.firstChild! as jsdom.Element;
      expect(first.tagName, equals('DIV'));
      expect(first.localName, equals('div'));
      final svg = first.firstChild! as jsdom.Element;
      expect(svg.tagName, equals('SVG'));
      expect(svg.localName, equals('svg'));
      final clip = svg.firstChild! as jsdom.Element;
      expect(clip.tagName, equals('CLIPPATH'));
      expect(clip.localName, equals('clippath'));
    });
  });

  group('Recovery from self-closing tags that have close tags', () {
    // Per HTML5 spec, void elements like <input> cannot have children.
    // The </input> closing tag is ignored, and <p> becomes a sibling.
    // Test updated to match JSDOM behavior.
    test('should handle closing tag for void element', () {
      final html = "<div><input><p>I'm in an input</p></input></div>";
      final doc = jsdom.JSDOMParser().parse(html);
      expect(doc.firstChild!.localName, equals('div'));
      // JSDOM: div has 2 children - input and p are siblings
      expect(doc.firstChild!.childNodes.length, equals(2));
      expect(doc.firstChild!.childNodes[0].localName, equals('input'));
      expect(doc.firstChild!.childNodes[0].childNodes.length, equals(0));
      expect(doc.firstChild!.childNodes[1].localName, equals('p'));
    });
  });

  group('baseURI parsing', () {
    test(
      'should handle various types of relative and absolute base URIs',
      () {
        void checkBase(String base, String expectedResult) {
          final html =
              "<html><head><base href='$base'></base></head><body/></html>";
          final doc =
              jsdom.JSDOMParser().parse(html, 'http://fakehost/some/dir/');
          expect(doc.baseURI, equals(expectedResult));
        }

        checkBase(
          'relative/path',
          'http://fakehost/some/dir/relative/path',
        );
        checkBase('/path', 'http://fakehost/path');
        checkBase('http://absolute/', 'http://absolute/');
        checkBase('//absolute/path', 'http://absolute/path');
      },
    );
  });

  group('namespace workarounds', () {
    test(
      'should handle random namespace information in the serialized DOM',
      () {
        final html =
            '<a0:html><a0:body><a0:DIV><a0:svG><a0:clippath/></a0:svG></a0:DIV></a0:body></a0:html>';
        final doc = jsdom.JSDOMParser().parse(html);
        final div = doc.getElementsByTagName('div')[0];
        expect(div.tagName, equals('DIV'));
        expect(div.localName, equals('div'));
        final svg = div.firstChild! as jsdom.Element;
        expect(svg.tagName, equals('SVG'));
        expect(svg.localName, equals('svg'));
        final clip = svg.firstChild! as jsdom.Element;
        expect(clip.tagName, equals('CLIPPATH'));
        expect(clip.localName, equals('clippath'));
        expect(doc.documentElement, equals(doc.firstChild));
        expect(doc.body, equals(doc.documentElement!.firstChild));
      },
    );
  });
}
