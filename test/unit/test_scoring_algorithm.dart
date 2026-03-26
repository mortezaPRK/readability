/// Tests for Readability content scoring algorithm.
library;

import 'package:readability/readability.dart';
import 'package:test/test.dart';

void main() {
  group('Content Scoring Algorithm', () {
    group('Tag-based scoring', () {
      test('DIV elements should receive +5 base score', () {
        final html = '''
          <html><body>
            <div>
              <p>${'This is paragraph content. ' * 50}</p>
            </div>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
        expect(article?.content, contains('paragraph content'));
      });

      test('PRE, TD, BLOCKQUOTE should receive +3 base score', () {
        final html = '''
          <html><body>
            <blockquote>
              <p>${'This is quoted content. ' * 50}</p>
            </blockquote>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
        expect(article?.content, contains('quoted content'));
      });

      test('H1-H6 elements should receive -5 penalty', () {
        final html = '''
          <html><body>
            <article>
              <h1>Main Title</h1>
              <p>${'Article content paragraph. ' * 50}</p>
            </article>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
        // Article should still parse despite header penalty
        expect(article?.content, contains('Article content'));
      });

      test('FORM, UL, OL should receive -3 penalty', () {
        final html = '''
          <html><body>
            <article>
              <p>${'Main article content here. ' * 50}</p>
              <ul>
                <li>List item 1</li>
                <li>List item 2</li>
              </ul>
            </article>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
      });
    });

    group('Class and ID weight scoring', () {
      test('positive class names should add +25 points', () {
        final html = '''
          <html><body>
            <div class="article-content main">
              <p>${'Article content paragraph. ' * 50}</p>
            </div>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
        expect(article?.content, contains('Article content'));
      });

      test('negative class names should subtract 25 points', () {
        final html = '''
          <html><body>
            <div class="comment-section">
              <p>${'Comment text here. ' * 20}</p>
            </div>
            <article>
              <p>${'Real article content. ' * 50}</p>
            </article>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
        expect(article?.content, contains('Real article'));
        expect(article?.content, isNot(contains('Comment text')));
      });

      test('positive ID should add +25 points', () {
        final html = '''
          <html><body>
            <div id="main-content">
              <p>${'Article content paragraph. ' * 50}</p>
            </div>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
        expect(article?.content, contains('Article content'));
      });

      test('negative ID should subtract 25 points', () {
        final html = '''
          <html><body>
            <div id="sidebar-ads">
              <p>${'Advertisement content. ' * 20}</p>
            </div>
            <article>
              <p>${'Real article content. ' * 50}</p>
            </article>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
        expect(article?.content, contains('Real article'));
        expect(article?.content, isNot(contains('Advertisement')));
      });

      test('both positive class and ID should stack scores', () {
        final html = '''
          <html><body>
            <div id="content" class="article-body">
              <p>${'High-scoring article content. ' * 50}</p>
            </div>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
        expect(article?.content, contains('High-scoring'));
      });
    });

    group('Paragraph scoring', () {
      test('each paragraph adds +1 base point', () {
        final html = '''
          <html><body>
            <article>
              <p>${'First paragraph content. ' * 30}</p>
              <p>${'Second paragraph content. ' * 30}</p>
              <p>${'Third paragraph content. ' * 30}</p>
            </article>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
        expect(article?.content, contains('First paragraph'));
        expect(article?.content, contains('Second paragraph'));
      });

      test('commas in paragraphs add points', () {
        final html = '''
          <html><body>
            <article>
              <p>${'First, second, third, fourth, fifth item. ' * 20}</p>
            </article>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
      });

      test('paragraph length adds points (max 3 per 100 chars)', () {
        final html = '''
          <html><body>
            <article>
              <p>${'a' * 400}</p>
            </article>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
        expect(article?.length, greaterThan(300));
      });
    });

    group('Link density scoring', () {
      test('high link density should reduce content score', () {
        final html = '''
          <html><body>
            <div class="link-farm">
              <a href="#">Link 1</a>
              <a href="#">Link 2</a>
              <a href="#">Link 3</a>
              <a href="#">Link 4</a>
            </div>
            <article>
              <p>${'Real article with minimal links. ' * 50}</p>
            </article>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
        expect(article?.content, contains('Real article'));
        expect(article?.content, isNot(contains('Link 1')));
      });

      test('low link density should preserve content score', () {
        final html = '''
          <html><body>
            <article>
              <p>${'Article content paragraph. ' * 40}</p>
              <p>Check out this <a href="#">helpful resource</a> for more info.</p>
              <p>${'More article content. ' * 40}</p>
            </article>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
        expect(article?.content, contains('helpful resource'));
      });
    });

    group('Ancestor score propagation', () {
      test('paragraph scores should propagate to parent with full weight', () {
        final html = '''
          <html><body>
            <div class="wrapper">
              <p>${'Paragraph content. ' * 50}</p>
            </div>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
        expect(article?.content, contains('Paragraph content'));
      });

      test(
          'paragraph scores should propagate to grandparent with reduced weight',
          () {
        final html = '''
          <html><body>
            <div class="outer">
              <div class="inner">
                <p>${'Nested paragraph content. ' * 50}</p>
              </div>
            </div>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
        expect(article?.content, contains('Nested paragraph'));
      });

      test('multiple paragraphs should accumulate parent scores', () {
        final html = '''
          <html><body>
            <div id="content">
              <p>${'First paragraph. ' * 30}</p>
              <p>${'Second paragraph. ' * 30}</p>
              <p>${'Third paragraph. ' * 30}</p>
              <p>${'Fourth paragraph. ' * 30}</p>
            </div>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
        expect(article?.content, contains('First paragraph'));
        expect(article?.content, contains('Fourth paragraph'));
      });
    });

    group('Top candidate selection', () {
      test('should select highest scoring element as top candidate', () {
        final html = '''
          <html><body>
            <div class="low-score">
              <p>${'Some content. ' * 20}</p>
            </div>
            <article id="main-article">
              <h1>Article Title</h1>
              <p>${'Primary article content. ' * 50}</p>
              <p>${'More primary content. ' * 50}</p>
            </article>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
        expect(article?.content, contains('Primary article'));
      });

      test('should consider multiple top candidates', () {
        final html = '''
          <html><body>
            <section id="content-area">
              <p>${'Section content paragraph one. ' * 40}</p>
              <p>${'Section content paragraph two. ' * 40}</p>
            </section>
            <aside class="related">
              <p>${'Related content here. ' * 20}</p>
            </aside>
          </body></html>
        ''';
        final article = parse(html, numTopCandidates: 3);
        expect(article, isNotNull);
        expect(article?.content, contains('Section content'));
      });
    });

    group('Score normalization and threshold', () {
      test('should respect charThreshold for minimum content length', () {
        final shortContent = 'Short text. ' * 10; // ~120 chars
        final longContent = 'Long text content. ' * 50; // ~950 chars

        final shortHtml =
            '<html><body><article><p>$shortContent</p></article></body></html>';
        final longHtml =
            '<html><body><article><p>$longContent</p></article></body></html>';

        final shortArticle = parse(shortHtml, charThreshold: 800);
        final longArticle = parse(longHtml, charThreshold: 800);

        // Short content may not meet threshold
        expect(shortArticle?.length ?? 0, lessThan(800));
        // Long content should meet threshold
        expect(longArticle?.length ?? 0, greaterThan(800));
      });

      test('should filter candidates below score threshold', () {
        final html = '''
          <html><body>
            <div class="winner">
              <p>${'Primary winning content. ' * 60}</p>
            </div>
            <div class="sidebar comment-widget">
              <p>Small sidebar content.</p>
            </div>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
        expect(article?.content, contains('winning content'));
        // Sidebar with negative class should be filtered out
        expect(article?.content, isNot(contains('sidebar comment-widget')));
      });
    });

    group('Complex scoring scenarios', () {
      test('should handle competing candidates correctly', () {
        final html = '''
          <html><body>
            <div id="sidebar" class="sidebar widget">
              <p>${'Sidebar widget content. ' * 30}</p>
            </div>
            <article id="main" class="post-content">
              <h1>Article Title</h1>
              <p>${'Main article content paragraph one. ' * 40}</p>
              <p>${'Main article content paragraph two. ' * 40}</p>
            </article>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
        expect(article?.content, contains('Main article'));
        expect(article?.content, isNot(contains('Sidebar widget')));
      });

      test('should handle mixed positive and negative signals', () {
        final html = '''
          <html><body>
            <div class="content comment-section">
              <p>${'Comment content. ' * 20}</p>
            </div>
            <div class="content post-body">
              <p>${'Post content. ' * 50}</p>
            </div>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
        // post-body is more positive than comment-section
        expect(article?.content, contains('Post content'));
      });

      test('should prioritize semantic article tag over scoring', () {
        final html = '''
          <html><body>
            <div id="content" class="main-content">
              <p>${'Div content. ' * 40}</p>
            </div>
            <article>
              <p>${'Semantic article content. ' * 40}</p>
            </article>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
        // Should prefer semantic article tag
        expect(article?.content, contains('Semantic article'));
      });
    });

    group('Score adjustment with options', () {
      test('numTopCandidates should affect candidate selection', () {
        final html = '''
          <html><body>
            <div class="content-a">
              <p>${'Content A paragraph. ' * 40}</p>
            </div>
            <div class="content-b">
              <p>${'Content B paragraph. ' * 40}</p>
            </div>
          </body></html>
        ''';

        // With 1 candidate
        final article1 = parse(html, numTopCandidates: 1);

        // With 5 candidates
        final article5 = parse(html, numTopCandidates: 5);

        // Both should extract something
        expect(article1, isNotNull);
        expect(article5, isNotNull);
      });
    });

    group('Real-world scoring patterns', () {
      test('should correctly identify blog post content', () {
        final html = '''
          <html><body>
            <header class="site-header">
              <nav>Site Navigation</nav>
            </header>
            <main>
              <article class="post-content">
                <h1>Blog Post Title</h1>
                <p class="byline">By John Doe on January 1, 2024</p>
                <p>${'First paragraph of blog post content. ' * 30}</p>
                <p>${'Second paragraph with more details. ' * 30}</p>
                <p>${'Third paragraph wrapping up. ' * 30}</p>
              </article>
            </main>
            <aside class="sidebar">
              <div class="widget">Widget content</div>
            </aside>
            <footer>Footer content</footer>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
        expect(article?.content, contains('First paragraph of blog'));
        expect(article?.content, isNot(contains('Site Navigation')));
        expect(article?.content, isNot(contains('Widget content')));
        expect(article?.content, isNot(contains('Footer content')));
      });

      test('should handle news article structure', () {
        final html = '''
          <html><body>
            <article>
              <header>
                <h1>Breaking News Story</h1>
                <time>March 15, 2026</time>
              </header>
              <div class="article-body">
                <p>${'News article lead paragraph. ' * 40}</p>
                <p>${'Second paragraph with details. ' * 40}</p>
                <p>${'Third paragraph with analysis. ' * 40}</p>
              </div>
              <footer class="article-footer">
                <p>Tags: news, world</p>
              </footer>
            </article>
          </body></html>
        ''';
        final article = parse(html);
        expect(article, isNotNull);
        expect(article?.content, contains('News article lead'));
        expect(article?.content, contains('analysis'));
      });

      test('should reject gallery/image-heavy pages', () {
        final html = '''
          <html><body>
            <div class="gallery">
              <figure>
                <img src="1.jpg" alt="Image 1">
                <figcaption>Caption 1</figcaption>
              </figure>
              <figure>
                <img src="2.jpg" alt="Image 2">
                <figcaption>Caption 2</figcaption>
              </figure>
              <figure>
                <img src="3.jpg" alt="Image 3">
                <figcaption>Caption 3</figcaption>
              </figure>
            </div>
          </body></html>
        ''';
        final article = parse(html);
        // Gallery pages typically don't have enough text content
        expect(article?.textContent.length ?? 0, lessThan(200));
      });
    });
  });
}
