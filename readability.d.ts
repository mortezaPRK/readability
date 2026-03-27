/**
 * Readability - Extract readable content from HTML
 *
 * A Dart port of Mozilla's Readability.js compiled to JavaScript.
 */

/**
 * Extracted article content and metadata.
 */
export interface Article {
  /** Article title */
  title: string;
  /** Article content as HTML */
  content: string;
  /** Article content as plain text */
  textContent: string;
  /** Length of text content in characters */
  length: number;
  /** Short excerpt or description */
  excerpt: string | null;
  /** Author name */
  byline: string | null;
  /** Text direction (e.g., "ltr" or "rtl") */
  dir: string | null;
  /** Site name */
  siteName: string | null;
  /** Language code (e.g., "en") */
  lang: string | null;
  /** Publication date as ISO 8601 string */
  publishedTime: string | null;
}

/**
 * Options for the parse function.
 */
export interface ParseOptions {
  /** Base URI for resolving relative URLs */
  baseUri?: string;
  /** Minimum character threshold for content (default: 500) */
  charThreshold?: number;
  /** Maximum elements to parse, 0 for unlimited (default: 0) */
  maxElemsToParse?: number;
  /** Whether to preserve CSS classes (default: false) */
  keepClasses?: boolean;
}

/**
 * Options for the isProbablyReaderable function.
 */
export interface ReaderableOptions {
  /** Minimum content length to consider readable (default: 140) */
  minContentLength?: number;
  /** Minimum score threshold (default: 20) */
  minScore?: number;
}

/**
 * Parse HTML content and extract the main article.
 *
 * @param html - The HTML content to parse
 * @param options - Optional parsing configuration
 * @returns The extracted article, or null if no readable content found
 *
 * @example
 * ```js
 * const article = parse('<html>...</html>', { baseUri: 'https://example.com' });
 * if (article) {
 *   console.log(article.title);
 *   console.log(article.textContent);
 * }
 * ```
 */
export function parse(html: string, options?: ParseOptions): Article | null;

/**
 * Check if HTML content is likely readable.
 *
 * This is a fast check that analyzes the document without doing a full parse.
 * Useful for deciding whether to attempt full article extraction.
 *
 * @param html - The HTML content to check
 * @param options - Optional configuration
 * @returns true if the content appears to be an article worth parsing
 *
 * @example
 * ```js
 * if (isProbablyReaderable(html)) {
 *   const article = parse(html);
 *   // ...
 * }
 * ```
 */
export function isProbablyReaderable(html: string, options?: ReaderableOptions): boolean;
