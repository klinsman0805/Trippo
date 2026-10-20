import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/trippo_api.dart';
import '../auth/session.dart';
import '../design/theme.dart';
import '../design/tokens.dart';

/// Giving this device's trips somewhere to live besides this device.
///
/// Two fields and no password. An address, a code from the email, done — and
/// which of the two things that means is Supabase's to say, not something to
/// make somebody choose between before they have typed anything. Either they
/// are keeping the user they have been planning as, or they already have an
/// account and are arriving on a second device; the sheet only has to explain
/// what happened once it knows which.
Future<void> showAccountSheet(
  BuildContext context, {
  required AppSession session,
  required TrippoApi api,
  required VoidCallback onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AccountSheet(session: session, api: api, onChanged: onChanged),
  );
}

class _AccountSheet extends StatefulWidget {
  const _AccountSheet({
    required this.session,
    required this.api,
    required this.onChanged,
  });

  final AppSession session;
  final TrippoApi api;
  final VoidCallback onChanged;

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  final _email = TextEditingController();
  final _code = TextEditingController();

  /// Null until an address has been offered and Supabase has said which of
  /// the two things it is. Also what tells the sheet to ask for a code.
  EmailLink? _mode;
  bool _busy = false;
  String? _error;

  /// How many trips followed the person over, once any did. Worth saying
  /// plainly: it is the whole reason the second device asks at all.
  int? _moved;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() step) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await step();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Exception catch (e) {
      // Supabase's own wording beats anything invented here: it is the one
      // that knows about rate limits and addresses it will not accept.
      if (mounted) setState(() => _error = _readable(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _run(() async {
        final mode = await widget.session.offerEmail(_email.text.trim());
        if (mounted) setState(() => _mode = mode);
      });

  Future<void> _confirm() => _run(() async {
        final leaving = await widget.session.confirmEmail(
          address: _email.text.trim(),
          code: _code.text.trim(),
          mode: _mode!,
        );

        // Only the second device has anything to hand over, and only while
        // that token lives. Spend it now or those trips are stranded.
        var moved = 0;
        if (leaving != null) moved = await widget.api.transferTrips(leaving);

        widget.onChanged();
        if (mounted) setState(() => _moved = moved);
      });

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: BoxDecoration(
          color: WayfareColors.bgApp,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Grabber(),
            const SizedBox(height: 14),
            ..._content(theme),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(WayfareTheme theme) {
    if (_moved != null) return _done(theme);
    if (_mode != null) return _codeStep(theme);
    return _emailStep(theme);
  }

  // --- the address ---

  List<Widget> _emailStep(WayfareTheme theme) => [
        Text('Keep your trips', style: WayfareType.display(26)),
        const SizedBox(height: 8),
        const _Body(
          'Right now these trips live on this phone alone. Add an address and '
          'they survive a reinstall — and open on your other devices.',
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _email,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.go,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _busy ? null : _send(),
          decoration: _field('you@example.com', 'Email'),
        ),
        ..._errorThen(),
        const SizedBox(height: 16),
        _Primary(
          theme: theme,
          label: 'Send me a code',
          busy: _busy,
          onTap: _email.text.trim().contains('@') && !_busy ? _send : null,
        ),
      ];

  // --- the code ---

  List<Widget> _codeStep(WayfareTheme theme) {
    final signingIn = _mode == EmailLink.signingIn;
    return [
      Text(signingIn ? 'Welcome back' : 'Check your email', style: WayfareType.display(26)),
      const SizedBox(height: 8),
      _Body(
        signingIn
            // Said before the code rather than after: what becomes of this
            // phone's trips is the part worth knowing before committing.
            ? 'That address already has an account. Enter the code to sign in '
                '— anything you have planned on this phone comes with you.'
            : 'We sent a six-digit code to ${_email.text.trim()}.',
      ),
      const SizedBox(height: 18),
      TextField(
        controller: _code,
        autofocus: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textInputAction: TextInputAction.go,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _busy ? null : _confirm(),
        style: WayfareType.display(24),
        decoration: _field('000000', 'Code').copyWith(counterText: ''),
      ),
      ..._errorThen(),
      const SizedBox(height: 16),
      _Primary(
        theme: theme,
        label: signingIn ? 'Sign in' : 'Confirm',
        busy: _busy,
        onTap: _code.text.trim().length == 6 && !_busy ? _confirm : null,
      ),
      const SizedBox(height: 4),
      TextButton(
        onPressed: _busy ? null : () => setState(() => _mode = null),
        child: const Text('Use a different address'),
      ),
    ];
  }

  // --- what happened ---

  List<Widget> _done(WayfareTheme theme) {
    final moved = _moved ?? 0;
    return [
      Text('Done', style: WayfareType.display(26)),
      const SizedBox(height: 8),
      _Body(
        moved == 0
            ? 'Your trips are tied to ${_email.text.trim()}. Sign in with that '
                'address on another device and they will be waiting.'
            : moved == 1
                ? 'Signed in, and the trip you planned on this phone came with you.'
                : 'Signed in, and the $moved trips you planned on this phone came with you.',
      ),
      const SizedBox(height: 18),
      _Primary(
        theme: theme,
        label: 'Close',
        busy: false,
        onTap: () => Navigator.of(context).pop(),
      ),
    ];
  }

  // --- furniture ---

  List<Widget> _errorThen() => [
        if (_error case final message?) ...[
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(fontSize: 13.5, height: 1.35, color: WayfareColors.overBudget),
          ),
        ],
      ];

  InputDecoration _field(String hint, String label) => InputDecoration(
        hintText: hint,
        labelText: label,
        filled: true,
        fillColor: WayfareColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: WayfareColors.border),
        ),
      );

  static String _readable(Exception error) {
    // "AuthException(message: ..., statusCode: ...)" reads as a crash report.
    final match = RegExp(r'message: ([^,)]+)').firstMatch(error.toString());
    return match?.group(1) ?? 'That did not work. Try again in a moment.';
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: WayfareColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

class _Body extends StatelessWidget {
  const _Body(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 14.5, height: 1.4, color: WayfareColors.subhead),
      );
}

class _Primary extends StatelessWidget {
  const _Primary({
    required this.theme,
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final WayfareTheme theme;
  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: WayfareTouch.input,
        child: Material(
          color: onTap == null ? WayfareColors.border : WayfareColors.ink,
          shape: RoundedRectangleBorder(borderRadius: theme.cardLg),
          child: InkWell(
            onTap: onTap,
            customBorder: RoundedRectangleBorder(borderRadius: theme.cardLg),
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: WayfareColors.surface),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: WayfareColors.surface,
                      ),
                    ),
            ),
          ),
        ),
      );
}
