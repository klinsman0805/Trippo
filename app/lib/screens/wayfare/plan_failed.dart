import 'package:flutter/material.dart';

import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../models/plan.dart';

/// The planner stopped and produced nothing.
///
/// A page rather than an overlay, per the handoff: the user has to be able to
/// leave with whatever survived, and an overlay traps them in the failure.
///
/// The design's copy talks about partial days — *"It planned days 1 and 2, then
/// the request timed out"*. This system cannot be in that state: a planning run
/// writes one complete revision or it writes nothing. Wording it that way would
/// promise half an itinerary that does not exist, so the same three facts are
/// stated against revisions instead, which is what actually survived.
class PlanFailedView extends StatelessWidget {
  const PlanFailedView({
    super.key,
    required this.failure,
    required this.onRetry,
    required this.onDismiss,
    required this.onFinishByHand,
  });

  final PlanFailure failure;

  /// Run the same planning attempt again.
  final VoidCallback onRetry;

  /// Keep the surviving revision and stop showing this. Null when there is
  /// nothing to keep — an action that does nothing is worse than no action.
  final VoidCallback onDismiss;

  /// Go to Refine, where the group can change something before trying again.
  final VoidCallback onFinishByHand;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final revision = failure.lastGoodRevision;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: WayfareColors.surface,
              borderRadius: theme.cardLg,
              border: Border.all(color: WayfareColors.amberBorder, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WayfareEyebrow(
                  'Stopped at ${failure.stoppedAtLabel}',
                  color: WayfareColors.amberInkDeep,
                  size: 10.5,
                ),
                const SizedBox(height: 10),
                Text(
                  'The planner stopped partway',
                  style: WayfareType.display(27),
                ),
                const SizedBox(height: 10),
                Text(_body(), style: WayfareType.body(14)),
                const SizedBox(height: 16),
                _FactRows(failure: failure),
                const SizedBox(height: 16),
                if (revision != null) ...[
                  WayfarePrimaryButton(
                    label: 'Keep revision $revision',
                    onPressed: onDismiss,
                    minHeight: WayfareTouch.sheetCta,
                  ),
                  const SizedBox(height: 10),
                  WayfareSecondaryButton(
                    label: 'Try again',
                    onPressed: onRetry,
                  ),
                ] else
                  WayfarePrimaryButton(
                    label: 'Try again',
                    onPressed: onRetry,
                    minHeight: WayfareTouch.sheetCta,
                  ),
                const SizedBox(height: 10),
                WayfareSecondaryButton(
                  label: 'Change something first',
                  onPressed: onFinishByHand,
                  background: Colors.transparent,
                  foreground: WayfareColors.muted,
                  fontSize: 13.5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Names what stopped and, in the same breath, what is still here. The
  /// second half is the load-bearing one — the fear this state has to answer
  /// is "did I just lose everything I typed in?".
  String _body() {
    final revision = failure.lastGoodRevision;
    final days = failure.lastGoodDays;

    if (revision == null) {
      return 'Nothing was planned before it stopped. Everything you entered — '
          'travellers, dates, saved places — is still here.';
    }

    final scope = days == null
        ? 'Revision $revision'
        : 'Revision $revision, all $days days of it';
    return 'The new plan never finished, so nothing replaced what you had. '
        '$scope is still on the trip and nothing you entered was lost.';
  }
}

/// The three fact rows. Green for what survived, red for the cause — the
/// design's own colour logic, which is what makes the block scannable.
class _FactRows extends StatelessWidget {
  const _FactRows({required this.failure});

  final PlanFailure failure;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final revision = failure.lastGoodRevision;
    final days = failure.lastGoodDays;

    final rows = <({String label, String value, Color color})>[
      (
        label: 'Still on the trip',
        value: revision == null
            ? 'Nothing planned yet'
            : days == null
                ? 'Revision $revision'
                : 'Revision $revision · $days days',
        color: revision == null
            ? WayfareColors.mutedLight
            : WayfareColors.liveFareInk,
      ),
      (
        label: 'Reason',
        value: failure.reason,
        color: WayfareColors.overBudget,
      ),
      (
        label: 'Your inputs',
        value: 'All saved',
        color: WayfareColors.liveFareInk,
      ),
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: WayfareColors.surfaceAlt,
        borderRadius: theme.card,
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : const Border(
                        top: BorderSide(color: WayfareColors.skeletonLight),
                      ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rows[i].label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: WayfareColors.mutedLight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      rows[i].value,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        color: rows[i].color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
