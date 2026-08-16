import 'package:flutter/material.dart';

import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../models/plan.dart';
import '../../models/trip.dart';
import '../../state/wayfare_controller.dart';
import 'formatting.dart';

/// Group tab: travellers, the Generate CTA, and the conflicts the planner
/// surfaced with how it handled each one.
class GroupTab extends StatelessWidget {
  const GroupTab({super.key, required this.controller});

  final WayfareController controller;

  @override
  Widget build(BuildContext context) {
    final members = controller.members;
    final conflicts = controller.plan?.conflicts ?? const <Conflict>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (members.isEmpty)
            _EmptyState(onAdd: controller.openSheet)
          else
            _MemberCard(controller: controller),
          if (conflicts.isNotEmpty) ...[
            const SizedBox(height: WayfareSpace.sectionGap),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
              child: const WayfareEyebrow('Where you differ'),
            ),
            // These compromises were worked out against the old preferences.
            // Leaving them looking current would be the more comfortable
            // choice and the wrong one.
            if (controller.conflictsMayBeStale) ...[
              _StaleConflictsNotice(onRegenerate: controller.generate),
              const SizedBox(height: WayfareSpace.cardGap),
            ],
            for (var i = 0; i < conflicts.length; i++) ...[
              if (i > 0) const SizedBox(height: WayfareSpace.cardGap),
              ConflictCard(
                conflict: conflicts[i],
                controller: controller,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
      decoration: BoxDecoration(
        color: WayfareColors.emptyStateBg,
        borderRadius: theme.cardLg,
        border: Border.all(
          color: WayfareColors.emptyStateBorder,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: WayfareColors.placeholderTile,
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No travellers yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: Text(
              'Add each person with their own pace and needs — the planner '
              'needs at least two to find compromises.',
              textAlign: TextAlign.center,
              style: WayfareType.body(13.5, color: WayfareColors.subhead),
            ),
          ),
          const SizedBox(height: 18),
          WayfarePrimaryButton(
            label: 'Add the first traveller',
            onPressed: onAdd,
            fontSize: 15,
            weight: FontWeight.w500,
          ),
        ],
      ),
    );
  }
}

/// Shown after a traveller is edited or removed: the conflicts below were
/// reconciled against preferences that have since changed.
class _StaleConflictsNotice extends StatelessWidget {
  const _StaleConflictsNotice({required this.onRegenerate});

  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: WayfareColors.amberSurface,
        borderRadius: theme.card,
        border: Border.all(color: WayfareColors.amberBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'These were worked out before the change you just made. They still '
            'describe the old group.',
            style: WayfareType.body(13.5, color: WayfareColors.amberInk),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: WayfareSecondaryButton(
              label: 'Work them out again',
              onPressed: onRegenerate,
              minHeight: WayfareTouch.ios,
              fontSize: 13.5,
              foreground: WayfareColors.amberButtonInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.controller});

  final WayfareController controller;

  @override
  Widget build(BuildContext context) {
    final members = controller.members;
    final plan = controller.plan;
    final currency = plan?.trip.currency ?? controller.trip?.currency ?? 'EUR';
    final budget = controller.trip?.totalBudget;
    final destinations = controller.trip?.destinations.length ?? 0;

    return WayfareCard(
      clip: true,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < members.length; i++)
            _MemberRow(
              member: members[i],
              color: WayfareColors.memberColor(i),
              showTopBorder: i > 0,
              onEdit: () => controller.editMember(members[i].id),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: WayfareColors.divider)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WayfareSecondaryButton(
                  label: 'Add traveller',
                  onPressed: controller.openSheet,
                ),
                const SizedBox(height: 10),
                WayfarePrimaryButton(
                  label: controller.isReady
                      ? 'Regenerate itinerary'
                      : 'Generate itinerary',
                  // Disabled under two travellers — there are no compromises
                  // to find with one person.
                  onPressed: controller.canGenerate ? controller.generate : null,
                ),
                const SizedBox(height: 10),
                Text(
                  controller.canGenerate
                      ? [
                          if (budget != null)
                            '${formatMoney(budget, currency)} budget',
                          if (destinations > 0)
                            '$destinations ${destinations == 1 ? 'stop' : 'stops'}',
                        ].join(' · ')
                      : 'Two travellers minimum',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: WayfareColors.mutedLight,
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

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.color,
    required this.showTopBorder,
    required this.onEdit,
  });

  final Member member;
  final Color color;
  final bool showTopBorder;

  /// The whole row opens the edit sheet. Removal lives in there rather than as
  /// an `×` beside every name — a one-tap delete next to the person's details
  /// is too easy to hit by accident for something that takes their
  /// preferences with it.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final needs = [
      ...member.dietaryRestrictions,
      ...member.accessibilityNeeds,
    ];

    return InkWell(
      onTap: onEdit,
      child: Semantics(
        button: true,
        label: 'Edit ${member.name}',
        child: _content(needs),
      ),
    );
  }

  Widget _content(List<String> needs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: showTopBorder
            ? const Border(top: BorderSide(color: WayfareColors.divider))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WayfareAvatar(
            initials: initialsOf(member.name),
            color: color,
            size: 38,
            ringWidth: 0,
            fontSize: 13,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    WayfarePill.pace(_paceLabel(member.pace)),
                  ],
                ),
                if (member.interests.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    member.interests.join(' · '),
                    style: const TextStyle(
                      fontSize: 13,
                      color: WayfareColors.muted,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  // Saying "none" beats an empty gap: it confirms the planner
                  // has nothing to work around for this person.
                  needs.isEmpty ? 'No dietary or access needs' : needs.join(' · '),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: WayfareColors.faint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.chevron_right,
              size: 20,
              color: WayfareColors.removeIcon,
            ),
          ),
        ],
      ),
    );
  }

  static String _paceLabel(Pace pace) => switch (pace) {
        Pace.packed => 'Packed',
        Pace.moderate => 'Moderate',
        Pace.relaxed => 'Relaxed',
      };
}

/// A conflict the planner surfaced, with the compromise it made and two ways
/// to respond. Rendered prominently rather than buried, per the handoff.
class ConflictCard extends StatelessWidget {
  const ConflictCard({
    super.key,
    required this.conflict,
    required this.controller,
  });

  final Conflict conflict;
  final WayfareController controller;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final accepted = controller.isAccepted(conflict.tag);

    final involved = conflict.membersInvolved
        .map((id) => controller.memberIndex(id))
        .where((i) => i >= 0)
        .toList();

    return WayfareCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              WayfarePill.conflictTag(conflict.tag),
              const Spacer(),
              WayfareAvatarStack(
                size: 26,
                overlap: 6,
                avatars: [
                  for (final i in involved)
                    (
                      initials: initialsOf(controller.members[i].name),
                      color: WayfareColors.memberColor(i),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            conflict.description,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: WayfareColors.infoBg,
              borderRadius: theme.card,
              border: Border.all(color: WayfareColors.infoBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WayfareEyebrow(
                  "How it's handled",
                  color: WayfareColors.info,
                  size: 10.5,
                ),
                const SizedBox(height: 6),
                Text(
                  conflict.resolution,
                  style: WayfareType.body(13.5, color: WayfareColors.infoBody),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: WayfareSecondaryButton(
                  label: accepted ? '✓ Accepted' : 'Looks good',
                  onPressed: () => controller.toggleAccepted(conflict.tag),
                  minHeight: 46,
                  fontSize: 13.5,
                  background:
                      accepted ? WayfareColors.successBg : Colors.transparent,
                  foreground:
                      accepted ? WayfareColors.successText : WayfareColors.ink,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: WayfareSecondaryButton(
                  label: 'Discuss',
                  onPressed: () => controller.discussConflict(conflict),
                  minHeight: 46,
                  fontSize: 13.5,
                  foreground: WayfareColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
