import 'package:flutter/material.dart';

import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../state/wayfare_controller.dart';

/// Refine tab: the conversation. Scroll area only — the composer is pinned
/// above the nav bar by the shell.
class RefineTab extends StatelessWidget {
  const RefineTab({super.key, required this.controller});

  final WayfareController controller;

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final message in controller.messages) ...[
            _Bubble(text: message.text, isUser: message.isUser, theme: theme),
            const SizedBox(height: 11),
          ],
          if (controller.thinking)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: BoxDecoration(
                  color: WayfareColors.surface,
                  borderRadius: theme.cardLg,
                  border: Border.all(color: WayfareColors.borderSoft),
                ),
                child: const WayfarePulsingDots(
                  colors: [
                    WayfareColors.removeIcon,
                    WayfareColors.removeIcon,
                    WayfareColors.removeIcon,
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.isUser,
    required this.theme,
  });

  final String text;
  final bool isUser;
  final WayfareTheme theme;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.84,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: isUser ? WayfareColors.ink : WayfareColors.surface,
            borderRadius: theme.cardLg,
            border: Border.all(
              color: isUser ? WayfareColors.ink : WayfareColors.borderSoft,
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.5,
              color: isUser
                  ? WayfareColors.generatingInk
                  : const Color(0xFF3A332B),
            ),
          ),
        ),
      ),
    );
  }
}

/// The composer, pinned above the nav bar: suggestion chips over a pill input
/// and a circular send button.
class RefineComposer extends StatefulWidget {
  const RefineComposer({super.key, required this.controller});

  final WayfareController controller;

  @override
  State<RefineComposer> createState() => _RefineComposerState();
}

class _RefineComposerState extends State<RefineComposer> {
  final _input = TextEditingController();

  /// One chip advertises link import — without it, the app's best feature is
  /// invisible, because the composer looks like it only takes instructions.
  static const _suggestions = [
    'Import a link',
    'Make day 3 more relaxed',
    'Get us under budget',
    'More food, less museums',
  ];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _input.clear();
    widget.controller.send(text);
  }

  void _onChipTap(String label) {
    if (label == 'Import a link') {
      // Not a message — it's a prompt to paste. Focus the field with a hint
      // rather than sending "Import a link" to the planner.
      _showImportHint();
      return;
    }
    _send(label);
  }

  void _showImportHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Paste a 小红书, TripAdvisor or blog link below and I\'ll pull the '
          'places out of it.',
        ),
      ),
    );
    FocusScope.of(context).requestFocus(_inputFocus);
  }

  final _inputFocus = FocusNode();

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final awaitingPaste = widget.controller.pendingSourceId != null;

    return Container(
      decoration: const BoxDecoration(
        color: WayfareColors.surface,
        border: Border(top: BorderSide(color: WayfareColors.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              children: [
                for (final s in _suggestions) ...[
                  WayfareSelectChip(
                    label: s,
                    selected: false,
                    onTap: () => _onChipTap(s),
                    minHeight: 40,
                    fontSize: 12.5,
                  ),
                  const SizedBox(width: 7),
                ],
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  focusNode: _inputFocus,
                  minLines: 1,
                  maxLines: 5,
                  onSubmitted: _send,
                  textInputAction: TextInputAction.send,
                  style: const TextStyle(fontSize: 15, color: WayfareColors.ink),
                  cursorColor: WayfareColors.ink,
                  decoration: InputDecoration(
                    // The hint changes when we're waiting for pasted text, so
                    // the user knows this turn means something different.
                    hintText: awaitingPaste
                        ? 'Paste the post text here…'
                        : 'Ask for a change…',
                    hintStyle: const TextStyle(
                      fontSize: 15,
                      color: WayfareColors.mutedLight,
                    ),
                    filled: true,
                    fillColor: WayfareColors.surfaceAlt,
                    constraints: const BoxConstraints(minHeight: 48),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: WayfareColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: WayfareColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(
                        color: WayfareColors.info,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Semantics(
                button: true,
                label: 'Send',
                child: Material(
                  color: theme.sendButtonColor,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _send(_input.text),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.arrow_upward,
                        size: 20,
                        color: WayfareColors.surface,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
