import { Readability } from '@mozilla/readability';
import type { ExtractedContent, Extractor } from '../types.js';
import { NeedsManualInputError } from '../types.js';
import { fetchHtml, normalizeText, parseDom, readMetaTags } from './html.js';

/**
 * Fallback extractor for any URL no specialised extractor claimed.
 *
 * Readability gives us the article body for blogs, travel guides and news
 * pieces. When it comes back empty (SPA shells, paywalls) we fall back to the
 * OpenGraph description, which is usually enough for the model to work with.
 */
export const genericExtractor: Extractor = {
  kind: 'web',
  matches: () => true,

  async extract(url: URL): Promise<ExtractedContent> {
    const { html, finalUrl, status } = await fetchHtml(url);

    if (status === 403 || status === 401) {
      throw new NeedsManualInputError(
        'web',
        `${url.hostname} refused the request (HTTP ${status}). Paste the page text instead.`,
      );
    }

    const doc = parseDom(html, finalUrl);
    const meta = readMetaTags(doc);

    // Readability mutates the document, so read meta tags first.
    let body = '';
    try {
      const article = new Readability(doc).parse();
      body = normalizeText(article?.textContent ?? '');
    } catch {
      body = '';
    }

    const text = body.length > 200 ? body : normalizeText(meta.description ?? '');

    if (text.length < 40) {
      throw new NeedsManualInputError(
        'web',
        `Could not read meaningful content from ${url.hostname}. Paste the text instead.`,
      );
    }

    return {
      kind: 'web',
      title: meta.title,
      author: meta.author ?? meta.siteName,
      text,
      images: meta.images,
      locationHints: [],
    };
  },
};
