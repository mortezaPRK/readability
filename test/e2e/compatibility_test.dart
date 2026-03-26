/// Compatibility tests against Mozilla Readability.js test suite.
///
/// This test file validates that the Dart implementation produces
/// the same output as the expected files from Mozilla's test suite.
///
/// Each test page directory contains:
/// - `source.html` - The input HTML to parse
/// - `expected.html` - The expected extracted content
/// - `expected-metadata.json` - Expected metadata (title, byline, excerpt, etc.)
///
/// This test performs node-by-node comparison, traversing the entire DOM tree
/// and comparing each element's tag name, attributes, and text content exactly.
/// This catches any structural differences but is sensitive to minor formatting
/// variations.
library;

import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:readability/readability.dart';
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  group('Detailed DOM Traversal Tests', () {
    final testPages = getTestPages();

    for (final testPage in testPages) {
      group(testPage.dir, () {
        late Article? article;
        late Map<String, dynamic> result;
        late html_dom.Document htmlDoc;

        setUpAll(() {
          final parser = JSDOMParser();
          final doc = parser.parse(
            testPage.source,
            'http://fakehost/test/page.html',
          );
          final reader = Readability(
            JsdomDomDocument(doc),
            ReadabilityOptions(classesToPreserve: ['caption']),
          );
          article = reader.parse();
          result = article?.toJson() ?? {};

          // Also parse with html package for isProbablyReaderable test
          htmlDoc = html_parser.parse(testPage.source);
        });

        test('should correctly detect if page is readerable', () {
          final expectedReaderable =
              testPage.expectedMetadata['readerable'] as bool?;
          if (expectedReaderable == null) return;

          expect(isProbablyReaderable(htmlDoc), equals(expectedReaderable));
        });

        test('should return a result object', () {
          expect(result, isNotNull);
          expect(result, contains('content'));
          expect(result, contains('title'));
          expect(result, contains('excerpt'));
          expect(result, contains('byline'));
        });

        test('should extract expected content', () {
          if (result['content'] == null) {
            fail('No content extracted');
          }

          final actualDOM = html_parser.parse(
            prettyPrint(result['content'] as String),
          );
          final expectedDOM = html_parser.parse(
            prettyPrint(testPage.expectedContent),
          );

          traverseDOM(
            (actualNode, expectedNode) {
              if (actualNode != null && expectedNode != null) {
                final actualDesc = nodeStr(actualNode);
                final expectedDesc = nodeStr(expectedNode);
                expect(
                  actualDesc,
                  equals(expectedDesc),
                  reason: actualNode is html_dom.Element
                      ? findableNodeDesc(actualNode)
                      : 'node comparison',
                );

                // Compare text content for text nodes
                if (actualNode is html_dom.Text &&
                    expectedNode is html_dom.Text) {
                  final actualText = htmlTransform(actualNode.text);
                  final expectedText = htmlTransform(expectedNode.text);
                  expect(
                    actualText,
                    equals(expectedText),
                    reason: 'text content at '
                        '${actualNode.parentNode != null ? findableNodeDesc(actualNode) : "root"}',
                  );
                  if (actualText != expectedText) return false;
                }
                // Compare attributes for element nodes
                else if (actualNode is html_dom.Element &&
                    expectedNode is html_dom.Element) {
                  final actualAttrs = attributesForNode(actualNode);
                  final expectedAttrs = attributesForNode(expectedNode);
                  expect(
                    actualAttrs.length,
                    equals(expectedAttrs.length),
                    reason: 'node ${nodeStr(actualNode)} attributes '
                        '(${actualAttrs.join(",")}) should match '
                        '(${expectedAttrs.join(",")})',
                  );
                  for (final attrEntry in actualNode.attributes.entries) {
                    final attr = attrEntry.key.toString();
                    final actualValue = actualNode.attributes[attr];
                    final expectedValue = expectedNode.attributes[attr];
                    expect(
                      actualValue,
                      equals(expectedValue),
                      reason: 'node (${findableNodeDesc(actualNode)}) '
                          'attribute $attr should match',
                    );
                  }
                }
              } else {
                expect(
                  nodeStr(actualNode),
                  equals(nodeStr(expectedNode)),
                  reason: 'Should have a node from both DOMs',
                );
                return false;
              }
              return true;
            },
            expectedDOM,
            actualDOM,
          );
        });

        test('should extract expected title', () {
          expect(
            result['title'],
            equals(testPage.expectedMetadata['title']),
          );
        });

        test('should extract expected byline', () {
          expect(
            result['byline'],
            equals(testPage.expectedMetadata['byline']),
          );
        });

        test('should extract expected excerpt', () {
          expect(
            result['excerpt'],
            equals(testPage.expectedMetadata['excerpt']),
          );
        });

        test('should extract expected site name', () {
          expect(
            result['siteName'],
            equals(testPage.expectedMetadata['siteName']),
          );
        });

        // Optional metadata tests
        if (testPage.expectedMetadata['dir'] != null) {
          test('should extract expected direction', () {
            expect(
              result['dir'],
              equals(testPage.expectedMetadata['dir']),
            );
          });
        }

        if (testPage.expectedMetadata['lang'] != null) {
          test('should extract expected language', () {
            expect(
              result['lang'],
              equals(testPage.expectedMetadata['lang']),
            );
          });
        }

        if (testPage.expectedMetadata['publishedTime'] != null) {
          test('should extract expected published time', () {
            expect(
              result['publishedTime'],
              equals(testPage.expectedMetadata['publishedTime']),
            );
          });
        }
      });
    }
  });
}
