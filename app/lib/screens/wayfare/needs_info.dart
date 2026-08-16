import 'package:flutter/material.dart';

import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../models/plan.dart';

/// The planner asked instead of guessing.
///
/// Renders inside the Trip tab *in place of* the itinerary, not beside it —
/// the spec is explicit that a `needs_info` plan has no itinerary to show, and
/// half an itinerary above a list of questions would imply otherwise.
///
/// Every question is skippable. That is the point of the intro copy and of the
/// quiet second action: the group is never blocked on an answer they don't
/// have, they just trade it for an assumption.
class NeedsInfoView extends StatelessWidget {
  const NeedsInfoView({
    super.key,
    required this.questions,
    required this.answers,
    required this.onAnswer,
    required this.onSend,
    required this.onSkip,
  });

  final List<ClarifyingQuestion> questions;

  /// Answers so far, keyed by question id.
  final Map<String, String> answers;
  final void Function(String questionId, String answer) onAnswer;
  final VoidCallback onSend;
  final VoidCallback onSkip;

  int get _answered =>
      questions.where((q) => (answers[q.id] ?? '').trim().isNotEmpty).length;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final total = questions.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: WayfareColors.infoBg,
              borderRadius: theme.cardLg,
              border: Border.all(color: WayfareColors.infoBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WayfareEyebrow(
                  '${spellOut(total)} ${total == 1 ? 'answer' : 'answers'} needed',
                  color: WayfareColors.info,
                  size: 10.5,
                ),
                const SizedBox(height: 8),
                Text(
                  "The planner has what you've given it so far but won't guess "
                  'on these. Answer what you can — it will plan around anything '
                  'you skip.',
                  style: WayfareType.body(13.5, color: WayfareColors.infoBody),
                ),
              ],
            ),
          ),
          const SizedBox(height: WayfareSpace.sectionGap),
          for (var i = 0; i < questions.length; i++) ...[
            if (i > 0) const SizedBox(height: WayfareSpace.cardGap),
            QuestionCard(
              number: i + 1,
              question: questions[i],
              answer: answers[questions[i].id],
              onAnswer: (value) => onAnswer(questions[i].id, value),
            ),
          ],
          const SizedBox(height: WayfareSpace.sectionGap),
          WayfarePrimaryButton(
            // Counts live, so the button always says what pressing it sends.
            label: _answered == 0
                ? 'Send answers'
                : 'Send $_answered of $total ${total == 1 ? 'answer' : 'answers'}',
            onPressed: _answered == 0 ? null : onSend,
            minHeight: WayfareTouch.sheetCta,
          ),
          const SizedBox(height: 10),
          WayfareSecondaryButton(
            label: 'Plan without these',
            onPressed: onSkip,
            background: Colors.transparent,
            foreground: WayfareColors.muted,
            fontSize: 13.5,
          ),
          const SizedBox(height: 10),
          Text(
            // Points at where the assumptions actually land — the planner's
            // reply becomes a bubble in Refine. A promise with no address is
            // one the user cannot check.
            'Skipping is fine — the planner says what it assumed instead, '
            'over in Refine.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: WayfareColors.mutedLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// One numbered question: what's being asked, what it changes, and the input.
///
/// The *why* line is not decoration. A question with no stated consequence
/// reads as a form to be filled in; one that names the decision it unblocks
/// reads as a choice worth making.
class QuestionCard extends StatefulWidget {
  const QuestionCard({
    super.key,
    required this.number,
    required this.question,
    required this.onAnswer,
    this.answer,
  });

  final int number;
  final ClarifyingQuestion question;
  final String? answer;
  final ValueChanged<String> onAnswer;

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  late final TextEditingController _text =
      TextEditingController(text: widget.answer ?? '');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;

    return WayfareCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: WayfareColors.paceChipBg,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${widget.number}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: WayfareColors.inkSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question.question,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (question.why.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                question.why,
                style: WayfareType.body(12.5, color: WayfareColors.mutedLight),
              ),
            ),
          ],
          const SizedBox(height: 13),
          if (question.isChoice && question.options.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in question.options)
                  WayfareSelectChip(
                    label: option,
                    selected: widget.answer == option,
                    // Tapping the chosen option again clears it, so a
                    // mis-tap doesn't lock an answer in.
                    onTap: () => widget.onAnswer(
                      widget.answer == option ? '' : option,
                    ),
                  ),
              ],
            )
          else
            WayfareTextField(
              controller: _text,
              hint: question.placeholder ?? 'Type your answer',
              onChanged: widget.onAnswer,
            ),
        ],
      ),
    );
  }
}

/// Small counts read better as words in a sentence — the design's own
/// `THREE ANSWERS NEEDED`, not `3 ANSWERS NEEDED`.
String spellOut(int n) => switch (n) {
      1 => 'One',
      2 => 'Two',
      3 => 'Three',
      4 => 'Four',
      5 => 'Five',
      6 => 'Six',
      7 => 'Seven',
      8 => 'Eight',
      9 => 'Nine',
      _ => '$n',
    };
