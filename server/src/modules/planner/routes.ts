import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { badRequest, notFound } from '../../lib/errors.js';
import { getTrip } from '../trips/repo.js';
import { listAcknowledged, setAcknowledged } from './conflicts.js';
import { clearFailure, getFailure } from './failure.js';
import { refine } from './refine.js';
import { generatePlan, getLatestPlan, getPlan, listPlans } from './service.js';
import { chatThread, updatedDay } from './thread.js';

const GenerateBody = z.object({
  /** A refinement instruction, e.g. "make day 3 more relaxed". */
  request: z.string().max(2_000).nullish(),
});

export async function plannerRoutes(app: FastifyInstance): Promise<void> {
  /**
   * Generate the next plan revision. Slow by design — a long model call with
   * high thinking effort, so clients should show progress rather than a
   * spinner with a short timeout.
   */
  app.post<{ Params: { id: string } }>('/trips/:id/plan', async (req, reply) => {
    getTrip(req.params.id);

    const parsed = GenerateBody.safeParse(req.body ?? {});
    if (!parsed.success) {
      throw badRequest('validation_error', 'Invalid body', parsed.error.flatten());
    }

    const record = await generatePlan(req.params.id, parsed.data.request ?? null);
    reply.code(201);
    return {
      plan: record,
      updated_day: updatedDay(req.params.id),
      accepted_conflicts: listAcknowledged(req.params.id),
    };
  });

  app.get<{ Params: { id: string } }>('/trips/:id/plan', async (req) => {
    getTrip(req.params.id);
    const record = getLatestPlan(req.params.id);
    if (!record) {
      throw notFound('no_plan_yet', 'This trip has no plan yet. POST to this path to create one.');
    }
    return {
      plan: record,
      // Drives the "Updated from your last chat request." notice on the Trip tab.
      updated_day: updatedDay(req.params.id),
      accepted_conflicts: listAcknowledged(req.params.id),
    };
  });

  /**
   * The last planning attempt that produced nothing, if there is one.
   *
   * Separate from `GET /plan` on purpose: the most useful case is a trip that
   * has never been planned successfully, where that route 404s. A failure the
   * user cannot see is a failure they will retry blindly.
   */
  app.get<{ Params: { id: string } }>('/trips/:id/plan/failure', async (req) => {
    getTrip(req.params.id);
    return { failure: getFailure(req.params.id) };
  });

  /** Dismiss the failed state — "keep what's there" rather than retry. */
  app.delete<{ Params: { id: string } }>(
    '/trips/:id/plan/failure',
    async (req, reply) => {
      getTrip(req.params.id);
      clearFailure(req.params.id);
      reply.code(204);
    },
  );

  const AnswersBody = z.object({
    answers: z
      .array(
        z.object({
          id: z.string().min(1),
          answer: z.string().min(1).max(2_000),
        }),
      )
      .default([]),
    /**
     * "Plan without these" — proceed with nothing answered. Sent explicitly so
     * an empty `answers` array cannot silently mean the same thing.
     */
    plan_anyway: z.boolean().default(false),
  });

  /**
   * Answer the planner's clarifying questions and re-plan.
   *
   * The client sends ids and answers only; the question text comes from the
   * stored plan. That keeps the two halves from drifting — an answer attached
   * to a question the planner never asked is worse than no answer at all.
   */
  app.post<{ Params: { id: string } }>('/trips/:id/plan/answers', async (req, reply) => {
    getTrip(req.params.id);

    const parsed = AnswersBody.safeParse(req.body ?? {});
    if (!parsed.success) {
      throw badRequest('validation_error', 'Invalid body', parsed.error.flatten());
    }
    const { answers, plan_anyway: planAnyway } = parsed.data;

    if (answers.length === 0 && !planAnyway) {
      throw badRequest(
        'no_answers',
        'Send at least one answer, or set plan_anyway to proceed without them.',
      );
    }

    const latest = getLatestPlan(req.params.id);
    const questions = latest?.plan.clarifying_questions ?? [];
    if (questions.length === 0) {
      throw badRequest(
        'no_questions_pending',
        'The current plan is not waiting on any answers.',
      );
    }

    const known = new Set(questions.map((q) => q.id));
    const unknown = answers.filter((a) => !known.has(a.id)).map((a) => a.id);
    if (unknown.length) {
      throw badRequest(
        'unknown_question_ids',
        `These question ids are not in the current plan: ${unknown.join(', ')}`,
      );
    }

    const record = await generatePlan(
      req.params.id,
      composeAnswerRequest(questions, answers),
    );
    reply.code(201);
    return {
      plan: record,
      updated_day: updatedDay(req.params.id),
      accepted_conflicts: listAcknowledged(req.params.id),
    };
  });

  /** The Refine tab's conversation, derived from plan revisions. */
  app.get<{ Params: { id: string } }>('/trips/:id/chat', async (req) => {
    getTrip(req.params.id);
    return { messages: chatThread(req.params.id) };
  });

  const RefineBody = z.object({
    message: z.string().min(1).max(20_000),
    /** Set when this message is the pasted text for a blocked import. */
    pending_source_id: z.string().nullish(),
  });

  /**
   * One turn of the Refine composer.
   *
   * The composer is a single text box, so a turn may be a pasted link, pasted
   * article text, or a planning instruction — this route works out which and
   * responds accordingly.
   */
  app.post<{ Params: { id: string } }>('/trips/:id/refine', async (req) => {
    getTrip(req.params.id);
    const parsed = RefineBody.safeParse(req.body);
    if (!parsed.success) {
      throw badRequest('validation_error', 'Expected { message }', parsed.error.flatten());
    }

    const result = await refine(req.params.id, parsed.data.message, {
      pendingSourceId: parsed.data.pending_source_id,
    });

    return {
      ...result,
      updated_day: result.plan ? updatedDay(req.params.id) : null,
    };
  });

  const AcceptBody = z.object({
    tag: z.string().min(1),
    accepted: z.boolean().default(true),
  });

  /** "Looks good" / undo on a conflict card. */
  app.post<{ Params: { id: string } }>('/trips/:id/conflicts/accept', async (req) => {
    getTrip(req.params.id);
    const parsed = AcceptBody.safeParse(req.body);
    if (!parsed.success) {
      throw badRequest('validation_error', 'Expected { tag, accepted }', parsed.error.flatten());
    }
    setAcknowledged(req.params.id, parsed.data.tag, parsed.data.accepted);
    return { accepted_conflicts: listAcknowledged(req.params.id) };
  });

  app.get<{ Params: { id: string } }>('/trips/:id/plan/revisions', async (req) => {
    getTrip(req.params.id);
    // Metadata only — the full plan JSON per revision would be a large payload.
    return {
      revisions: listPlans(req.params.id).map((p) => ({
        id: p.id,
        revision: p.revision,
        status: p.status,
        summary: p.summary,
        user_request: p.user_request,
        created_at: p.created_at,
      })),
    };
  });

  app.get<{ Params: { planId: string } }>('/plans/:planId', async (req) => ({
    plan: getPlan(req.params.planId),
  }));
}

/**
 * Turn answered and skipped questions into one planning instruction.
 *
 * Skipped questions are named rather than omitted, with an explicit licence to
 * assume — otherwise the planner asks the same question again and the group is
 * stuck in a loop it cannot leave. This also lands in the Refine thread as the
 * user's own turn, so it is written the way a person would write it.
 */
function composeAnswerRequest(
  questions: { id: string; question: string }[],
  answers: { id: string; answer: string }[],
): string {
  const given = new Map(answers.map((a) => [a.id, a.answer]));
  const answered = questions.filter((q) => given.has(q.id));
  const skipped = questions.filter((q) => !given.has(q.id));

  const parts: string[] = [];

  if (answered.length) {
    parts.push(
      'Here are the answers you asked for:\n' +
        answered.map((q) => `- ${q.question}\n  ${given.get(q.id)}`).join('\n'),
    );
  }

  if (skipped.length) {
    parts.push(
      'I am not answering these:\n' +
        skipped.map((q) => `- ${q.question}`).join('\n') +
        '\n\nPlan around them and do not ask about them again. For each one, add ' +
        'an entry to "assumptions" naming what you decided instead — ' +
        `"assumptions" must contain at least ${skipped.length} ` +
        `${skipped.length === 1 ? 'entry' : 'entries'}. Say the same thing in the ` +
        'summary. An assumption the group cannot see is one they cannot correct.',
    );
  }

  parts.push(
    'Return a complete plan with status "complete" and an empty ' +
      '"clarifying_questions" array.',
  );

  return parts.join('\n\n');
}
