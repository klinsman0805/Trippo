import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/trippo_logo.dart';

/// The first thing the app shows: the hippo, the name, and what it is for.
///
/// Stacked and centred, which is what a screen with one thing on it wants —
/// the side-by-side lockup is for a header, where height is the scarce
/// dimension. Here there is nothing but height.
///
/// It holds until [ready] has somewhere to go. The intro is not a loading
/// bar and must not be mistaken for one: if the session is still arriving
/// when the hippo has finished rising, the screen waits; if the session
/// arrived first, the screen still plays once rather than flashing past.
/// Whichever finishes second decides.
class LandingScreen extends StatefulWidget {
  const LandingScreen({
    super.key,
    required this.ready,
    required this.onReady,
  });

  /// Completes when there is somewhere to go — the session resolved, the
  /// first request answered.
  final Future<void> ready;

  /// Called once, after both the intro and [ready] have finished.
  final VoidCallback onReady;

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool _introDone = false;
  bool _loaded = false;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    widget.ready.whenComplete(() {
      if (!mounted) return;
      _loaded = true;
      _leaveIfReady();
    });
  }

  void _leaveIfReady() {
    // Both, and only once: the two finish in either order, and whichever is
    // second is the one that matters.
    if (_left || !_introDone || !_loaded) return;
    _left = true;
    widget.onReady();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WayfareColors.bgApp,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: TrippoLogoAnimation(
              height: 132,
              axis: Axis.vertical,
              loop: false,
              tagline: 'Your personal trip advisor',
              onIntroComplete: () {
                _introDone = true;
                _leaveIfReady();
              },
            ),
          ),
        ),
      ),
    );
  }
}
