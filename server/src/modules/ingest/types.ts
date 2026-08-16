export type SourceKind = 'xiaohongshu' | 'tripadvisor' | 'web' | 'manual';

export type SourceStatus =
  | 'pending'
  | 'fetched'
  | 'extracted'
  | 'failed'
  /** Fetch was blocked upstream; the user must paste the text themselves. */
  | 'needs_manual';

/** What an extractor pulls off a page before the LLM structures it. */
export interface ExtractedContent {
  kind: SourceKind;
  title: string | null;
  author: string | null;
  /** Plain text, already stripped of nav/boilerplate. */
  text: string;
  /** Image URLs, kept for the client to preview. Not sent to the model. */
  images: string[];
  /** Location hints the page stated explicitly (geo tags, breadcrumb regions). */
  locationHints: string[];
}

export interface Extractor {
  kind: SourceKind;
  /** Whether this extractor claims the URL. Checked in registration order. */
  matches(url: URL): boolean;
  extract(url: URL): Promise<ExtractedContent>;
}

/** Raised when a site actively blocks server-side fetching. */
export class NeedsManualInputError extends Error {
  constructor(
    readonly kind: SourceKind,
    message: string,
  ) {
    super(message);
    this.name = 'NeedsManualInputError';
  }
}

export interface SourceRecord {
  id: string;
  trip_id: string;
  url: string | null;
  kind: SourceKind;
  status: SourceStatus;
  title: string | null;
  author: string | null;
  raw_text: string | null;
  error: string | null;
  created_at: string;
  updated_at: string;
}
