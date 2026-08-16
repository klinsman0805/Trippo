import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { badRequest } from '../../lib/errors.js';
import * as ingest from './service.js';

const ImportUrlBody = z.object({
  /** A URL, or the raw share text a user pasted from an app. */
  url: z.string().min(4),
});

const ImportTextBody = z.object({
  text: z.string().min(1),
  title: z.string().optional(),
  kind: z.enum(['xiaohongshu', 'tripadvisor', 'web', 'manual']).optional(),
  /** Set when completing a source that previously came back `needs_manual`. */
  source_id: z.string().optional(),
});

export async function ingestRoutes(app: FastifyInstance): Promise<void> {
  app.get<{ Params: { id: string } }>('/trips/:id/sources', async (req) => ({
    sources: ingest.listSources(req.params.id),
  }));

  app.post<{ Params: { id: string } }>('/trips/:id/sources/url', async (req, reply) => {
    const parsed = ImportUrlBody.safeParse(req.body);
    if (!parsed.success) {
      throw badRequest('validation_error', 'Expected { url }', parsed.error.flatten());
    }
    const result = await ingest.importUrl(req.params.id, parsed.data.url);
    // 202: the source is stored, but it needs the user to supply the text.
    reply.code(result.manual_input_required ? 202 : 201);
    return result;
  });

  app.post<{ Params: { id: string } }>('/trips/:id/sources/text', async (req, reply) => {
    const parsed = ImportTextBody.safeParse(req.body);
    if (!parsed.success) {
      throw badRequest('validation_error', 'Expected { text }', parsed.error.flatten());
    }
    const { text, title, kind, source_id } = parsed.data;
    const result = await ingest.importManualText(req.params.id, text, {
      title,
      kind,
      sourceId: source_id,
    });
    reply.code(201);
    return result;
  });

  app.delete<{ Params: { sourceId: string } }>(
    '/trips/:id/sources/:sourceId',
    async (req, reply) => {
      ingest.deleteSource(req.params.sourceId);
      reply.code(204);
    },
  );
}
