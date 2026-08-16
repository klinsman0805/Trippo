import { JSDOM } from 'jsdom';
import { env } from '../../../config/env.js';
import { fetchWithRetry, readTextCapped } from '../../../lib/http.js';

/** Fetch a URL as HTML with a browser-like UA and a hard size cap. */
export async function fetchHtml(url: URL, extraHeaders: Record<string, string> = {}) {
  const res = await fetchWithRetry(url.toString(), {
    timeoutMs: env.INGEST_TIMEOUT_MS,
    retries: 1,
    provider: url.hostname,
    headers: {
      'User-Agent': env.INGEST_USER_AGENT,
      Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9,zh-CN;q=0.8',
      ...extraHeaders,
    },
    redirect: 'follow',
  });
  const html = await readTextCapped(res, env.INGEST_MAX_BYTES);
  return { status: res.status, finalUrl: res.url || url.toString(), html };
}

export interface MetaTags {
  title: string | null;
  description: string | null;
  siteName: string | null;
  author: string | null;
  images: string[];
}

/**
 * Read OpenGraph / Twitter Card / standard meta tags.
 *
 * These are the most reliable signal on JS-heavy sites, because they are
 * server-rendered for link unfurling even when the article body is not.
 */
export function readMetaTags(doc: Document): MetaTags {
  const attr = (selector: string, name = 'content') =>
    doc.querySelector(selector)?.getAttribute(name)?.trim() || null;

  const images = [
    attr('meta[property="og:image"]'),
    attr('meta[name="twitter:image"]'),
    ...[...doc.querySelectorAll('meta[property="og:image"]')].map((el) =>
      el.getAttribute('content'),
    ),
  ].filter((v): v is string => Boolean(v));

  return {
    title:
      attr('meta[property="og:title"]') ??
      attr('meta[name="twitter:title"]') ??
      doc.querySelector('title')?.textContent?.trim() ??
      null,
    description:
      attr('meta[property="og:description"]') ??
      attr('meta[name="twitter:description"]') ??
      attr('meta[name="description"]'),
    siteName: attr('meta[property="og:site_name"]'),
    author:
      attr('meta[name="author"]') ??
      attr('meta[property="article:author"]') ??
      null,
    images: [...new Set(images)],
  };
}

export function parseDom(html: string, url: string): Document {
  return new JSDOM(html, { url }).window.document;
}

/** Collapse whitespace and drop the runs of blank lines scraping leaves behind. */
export function normalizeText(input: string): string {
  return input
    .replace(/\r/g, '')
    .replace(/[ \t ]+/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .split('\n')
    .map((line) => line.trim())
    .join('\n')
    .trim();
}

/** Pull JSON out of `<script type="application/ld+json">` and inline state blobs. */
export function readJsonScripts(doc: Document): unknown[] {
  const out: unknown[] = [];
  for (const el of doc.querySelectorAll('script[type="application/ld+json"]')) {
    const raw = el.textContent?.trim();
    if (!raw) continue;
    try {
      out.push(JSON.parse(raw));
    } catch {
      // Malformed LD+JSON is common in the wild; skip rather than fail the import.
    }
  }
  return out;
}
