import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/vf_theme.dart';
import '../widgets/vf_primitives.dart';
import 'dashboard_home_screen.dart';
import 'exercise_browser.dart';
import 'plan_screen.dart';
import 'profile_screen.dart';
import 'progress_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _browserOpen = false;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom;
    const navHeight = VFTheme.navHeight;
    final s = VFTheme.scale(context);
    final contentBottomPadding = navHeight + bottomInset + 26 * s;

    final screens = [
      DashboardHomeScreen(
        bottomPadding: contentBottomPadding,
        onOpenBrowser: _toggleBrowser,
      ),
      PlanScreen(bottomPadding: contentBottomPadding),
      ProgressScreen(bottomPadding: contentBottomPadding),
      ProfileScreen(bottomPadding: contentBottomPadding),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBody: true,
        backgroundColor: VFTheme.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              bottom: false,
              child: IndexedStack(
                index: _currentIndex,
                children: screens,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_browserOpen,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  offset: _browserOpen ? Offset.zero : const Offset(0, 1),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _browserOpen ? 1 : 0,
                    child: ExerciseBrowser(
                      bottomPadding: contentBottomPadding,
                      onClose: _toggleBrowser,
                      onSelectExercise: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _BottomNavBar(
          currentIndex: _currentIndex,
          browserOpen: _browserOpen,
          bottomInset: bottomInset,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
              _browserOpen = false;
            });
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: Transform.translate(
          offset: Offset(0, -18 * s),
          child: _BrowserFab(
            isOpen: _browserOpen,
            onTap: _toggleBrowser,
          ),
        ),
      ),
    );
  }

  void _toggleBrowser() {
    setState(() => _browserOpen = !_browserOpen);
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.browserOpen,
    required this.bottomInset,
    required this.onTap,
  });

  final int currentIndex;
  final bool browserOpen;
  final double bottomInset;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return FrostedGlass(
      sigma: 28,
      decoration: VFTheme.navDecoration(),
      child: SizedBox(
        height: VFTheme.navHeight + bottomInset,
        child: Padding(
          padding: EdgeInsets.fromLTRB(8 * s, 0, 8 * s, bottomInset),
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  label: 'Trang chủ',
                  glyph: VFNavGlyph.home,
                  active: currentIndex == 0 && !browserOpen,
                  onTap: () => onTap(0),
                ),
              ),
              Expanded(
                child: _NavItem(
                  label: 'Kế hoạch',
                  glyph: VFNavGlyph.plan,
                  active: currentIndex == 1 && !browserOpen,
                  onTap: () => onTap(1),
                ),
              ),
              SizedBox(width: VFTheme.fabSize + (12 * s)),
              Expanded(
                child: _NavItem(
                  label: 'Tiến bộ',
                  glyph: VFNavGlyph.progress,
                  active: currentIndex == 2 && !browserOpen,
                  onTap: () => onTap(2),
                ),
              ),
              Expanded(
                child: _NavItem(
                  label: 'Tôi',
                  glyph: VFNavGlyph.profile,
                  active: currentIndex == 3 && !browserOpen,
                  onTap: () => onTap(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.glyph,
    required this.active,
    required this.onTap,
  });

  final String label;
  final VFNavGlyph glyph;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);
    final opacity = active ? 1.0 : 0.3;
    final color = active ? VFTheme.jade : VFTheme.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14 * s),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8 * s),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: opacity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              VFNavIcon(
                glyph: glyph,
                color: color,
              ),
              SizedBox(height: 4 * s),
              Text(
                label,
                style: VFTheme.textStyle(
                  context,
                  size: 10,
                  weight: active ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
              SizedBox(height: 2 * s),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 4 * s,
                height: 4 * s,
                decoration: BoxDecoration(
                  color: active ? VFTheme.jade : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrowserFab extends StatelessWidget {
  const _BrowserFab({
    required this.isOpen,
    required this.onTap,
  });

  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = VFTheme.scale(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedRotation(
        duration: const Duration(milliseconds: 220),
        turns: isOpen ? 0.125 : 0,
        curve: Curves.easeOutCubic,
        child: Container(
          width: VFTheme.fabSize,
          height: VFTheme.fabSize,
          decoration: BoxDecoration(
            gradient: VFTheme.jadeGradient,
            borderRadius: BorderRadius.circular(17 * s),
            boxShadow: [
              BoxShadow(
                color: VFTheme.jade.withValues(alpha: 0.28),
                blurRadius: 18 * s,
                offset: Offset(0, 4 * s),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: VFNavIcon(
            glyph: VFNavGlyph.plus,
            color: VFTheme.white,
            size: 22 * s,
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }
}
