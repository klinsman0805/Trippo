import type { ExtractedContent, Extractor } from '../types.js';
import { NeedsManualInputError } from '../types.js';
import { fetchHtml, normalizeText, parseDom, readMetaTags } from './html.js';

const HOSTS = ['xiaohongshu.com', 'xhslink.com', 'xhs.link'];

/**
 * Xiaohongshu (小红书).
 *
 * Reality check: XHS aggressively blocks unauthenticated server-side reads.
 * Note pages are client-rendered and gated behind a signed-request check, so a
 * plain fetch usually returns a login wall rather than the note body. What
 * *does* survive is the OpenGraph metadata served for link unfurling — title,
 * description and cover images — which is often enough to identify the places
 * a note is about.
 *
 * So this extractor tries, in order:
 *   1. `__INITIAL_STATE__` — the full note when the shell happens to include it
 *   2. OpenGraph title + description — the reliable path
 *   3. NeedsManualInputError — the user pastes the note text in the app
 *
 * Step 3 is not a failure mode to engineer around; it's the honest fallback.
 * The client should treat `needs_manual` as a normal branch of the import flow
 * and show a paste box, because it will be hit regularly.
 */
export const xiaohongshuExtractor: Extractor = {
  kind: 'xiaohongshu',

  matches: (url) => HOSTS.some((h) => url.hostname === h || url.hostname.endsWith(`.${h}`)),

  async extract(url: URL): Promise<ExtractedContent> {
    const { html, finalUrl, status } = await fetchHtml(url, {
      Referer: 'https://www.xiaohongshu.com/',
    });

    if (status >= 400) {
      throw new NeedsManualInputError(
        'xiaohongshu',
        `小红书 returned HTTP ${status}. Open the note in the app, copy its text, and paste it here.`,
      );
    }

    const doc = parseDom(html, finalUrl);
    const meta = readMetaTags(doc);

    const fromState = readInitialState(html);
    const bodyText = fromState?.desc ?? '';
    const title = fromState?.title ?? meta.title;

    const text = normalizeText(
      [title, bodyText, bodyText ? '' : meta.description ?? ''].filter(Boolean).join('\n\n'),
    );

    if (text.length < 30 || looksLikeLoginWall(text)) {
      throw new NeedsManualInputError(
        'xiaohongshu',
        '小红书 served a login wall instead of the note. Copy the note text from the app and paste it here.',
      );
    }

    return {
      kind: 'xiaohongshu',
      title,
      author: fromState?.author ?? meta.author,
      text,
      images: meta.images,
      locationHints: fromState?.location ? [fromState.location] : [],
    };
  },
};

interface NoteState {
  title: string | null;
  desc: string | null;
  author: string | null;
  location: string | null;
}

/**
 * XHS embeds its Vue store as `window.__INITIAL_STATE__ = {...}`. The shape is
 * undocumented and changes without notice, so every field access is defensive
 * and a parse failure just falls through to the OpenGraph path.
 */
function readInitialState(html: string): NoteState | null {
  const match = /window\.__INITIAL_STATE__\s*=\s*(\{[\s\S]*?\})\s*[;<]/.exec(html);
  if (!match?.[1]) return null;

  let state: unknown;
  try {
    // XHS emits JS `undefined` literals, which JSON.parse rejects.
    state = JSON.parse(match[1].replace(/\bundefined\b/g, 'null'));
  } catch {
    return null;
  }

  const noteMap = dig(state, ['note', 'noteDetailMap']);
  if (!isRecord(noteMap)) return null;

  const first = Object.values(noteMap)[0];
  const note = dig(first, ['note']);
  if (!isRecord(note)) return null;

  return {
    title: asString(note.title),
    desc: asString(note.desc),
    author: asString(dig(note, ['user', 'nickname'])),
    location: asString(note.ipLocation),
  };
}

const isRecord = (v: unknown): v is Record<string, unknown> =>
  typeof v === 'object' && v !== null && !Array.isArray(v);

const asString = (v: unknown): string | null =>
  typeof v === 'string' && v.trim() ? v.trim() : null;

function dig(source: unknown, path: string[]): unknown {
  let cur = source;
  for (const key of path) {
    if (!isRecord(cur)) return undefined;
    cur = cur[key];
  }
  return cur;
}

const LOGIN_WALL_MARKERS = ['登录后查看', '扫码登录', '打开小红书', 'Sign up or log in'];
const looksLikeLoginWall = (text: string) =>
  LOGIN_WALL_MARKERS.some((marker) => text.includes(marker));

/**
 * Users share XHS notes as a blob of text with a short link buried in it,
 * e.g. `12 复制本条信息，打开【小红书】App查看精彩内容！ http://xhslink.com/a/abc123`.
 * Pull the first URL out so the client can pass the raw paste straight through.
 */
export function extractUrlFromShareText(input: string): string | null {
  const match = /https?:\/\/[^\s，,。、]+/.exec(input);
  return match?.[0] ?? null;
}
