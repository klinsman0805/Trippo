import { UpstreamError } from './errors.js';

export interface FetchOptions extends RequestInit {
  /** Abort after this many ms. */
  timeoutMs?: number;
  /** Retry count for 429/5xx/network errors. Default 2. */
  retries?: number;
  /** Reject bodies larger than this many bytes. */
  maxBytes?: number;
  /** Provider name used in error messages. */
  provider?: string;
}

const RETRYABLE_STATUS = new Set([408, 425, 429, 500, 502, 503, 504]);

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/**
 * fetch with timeout, bounded exponential backoff and a response size cap.
 *
 * The size cap matters for link ingestion: an arbitrary user-supplied URL can
 * point at a multi-gigabyte file, and streaming it into memory would take the
 * process down.
 */
export async function fetchWithRetry(url: string, opts: FetchOptions = {}): Promise<Response> {
  const {
    timeoutMs = 15_000,
    retries = 2,
    provider = 'upstream',
    maxBytes,
    ...init
  } = opts;

  let lastError: unknown;

  for (let attempt = 0; attempt <= retries; attempt++) {
    if (attempt > 0) {
      // 400ms, 800ms, 1600ms … plus jitter to avoid synchronised retries.
      await sleep(Math.min(400 * 2 ** (attempt - 1), 4_000) + Math.random() * 200);
    }

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const res = await fetch(url, { ...init, signal: controller.signal });

      if (RETRYABLE_STATUS.has(res.status) && attempt < retries) {
        lastError = new UpstreamError(provider, `HTTP ${res.status}`, res.status);
        continue;
      }

      if (maxBytes) {
        const declared = Number(res.headers.get('content-length') ?? 0);
        if (declared > maxBytes) {
          throw new UpstreamError(
            provider,
            `Response too large: ${declared} bytes exceeds the ${maxBytes} byte limit`,
            res.status,
          );
        }
      }

      return res;
    } catch (err) {
      lastError = err;
      const aborted = err instanceof Error && err.name === 'AbortError';
      if (aborted && attempt >= retries) {
        throw new UpstreamError(provider, `Request timed out after ${timeoutMs}ms`);
      }
      if (err instanceof UpstreamError) throw err;
      if (attempt >= retries) break;
    } finally {
      clearTimeout(timer);
    }
  }

  throw new UpstreamError(
    provider,
    lastError instanceof Error ? lastError.message : 'Request failed',
  );
}

/** Read a response body as text, refusing to buffer more than `maxBytes`. */
export async function readTextCapped(res: Response, maxBytes: number): Promise<string> {
  const reader = res.body?.getReader();
  if (!reader) return '';

  const chunks: Uint8Array[] = [];
  let total = 0;

  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    if (!value) continue;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel();
      break; // Return what we have — a truncated page still extracts usefully.
    }
    chunks.push(value);
  }

  return new TextDecoder('utf-8').decode(
    chunks.reduce<Uint8Array>((acc, c) => {
      const merged = new Uint8Array(acc.length + c.length);
      merged.set(acc);
      merged.set(c, acc.length);
      return merged;
    }, new Uint8Array()),
  );
}

/** Parse a JSON API response, turning non-2xx into an UpstreamError. */
export async function jsonOrThrow<T>(res: Response, provider: string): Promise<T> {
  const text = await res.text();
  if (!res.ok) {
    throw new UpstreamError(provider, `HTTP ${res.status}: ${text.slice(0, 500)}`, res.status);
  }
  try {
    return JSON.parse(text) as T;
  } catch {
    throw new UpstreamError(provider, `Malformed JSON response: ${text.slice(0, 200)}`);
  }
}
