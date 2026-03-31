import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/vf_theme.dart';
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
    final navHeight = VFTheme.navHeight(context);
    final fabSize = VFTheme.fabSize(context);
    final contentBottomPadding =
        navHeight + bottomInset + fabSize * 0.72;

    final screens = [
      DashboardHomeScreen(
        bottomPadding: contentBottomPadding,
        onOpenBrowser: () => setState(() => _browserOpen = true),
      ),
      PlanScreen(bottomPadding: contentBottomPadding),
      ProgressScreen(bottomPadding: contentBottomPadding),
      ProfileScreen(bottomPadding: contentBottomPadding),
    ];

    return Theme(
      data: VFTheme.lightTheme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: Scaffold(
          extendBody: true,
          backgroundColor: VFTheme.bg,
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
              IgnorePointer(
                ignoring: !_browserOpen,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  offset: _browserOpen ? Offset.zero : const Offset(0, 1),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _browserOpen ? 1 : 0,
                    child: ExerciseBrowser(
                      bottomPadding: contentBottomPadding,
                      onClose: () => setState(() => _browserOpen = false),
                      onSelectExercise: (definition) {
                        setState(() => _browserOpen = false);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          Navigator.of(context).pushNamed(
                            '/exercise',
                            arguments: definition,
                          );
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _BottomNavBar(
            currentIndex: _currentIndex,
            navHeight: navHeight,
            bottomInset: bottomInset,
            onTabSelected: (index) {
              setState(() {
                _currentIndex = index;
                _browserOpen = false;
              });
            },
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          floatingActionButton: _FabButton(
            size: fabSize,
            isOpen: _browserOpen,
            onTap: () => setState(() => _browserOpen = !_browserOpen),
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.navHeight,
    required this.bottomInset,
    required this.onTabSelected,
  });

  final int currentIndex;
  final double navHeight;
  final double bottomInset;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return FrostedGlass(
      decoration: VFTheme.glassBarDecoration(context),
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          height: navHeight + bottomInset,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              6 * VFTheme.scale(context),
              0,
              6 * VFTheme.scale(context),
              bottomInset,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _NavItem(
                    icon: Icons.home_rounded,
                    label: 'Trang chủ',
                    active: currentIndex == 0,
                    onTap: () => onTabSelected(0),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.calendar_month_rounded,
                    label: 'Kế hoạch',
                    active: currentIndex == 1,
                    onTap: () => onTabSelected(1),
                  ),
                ),
                SizedBox(
                  width:
                      VFTheme.fabSize(context) + 14 * VFTheme.scale(context),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.query_stats_rounded,
                    label: 'Tiến bộ',
                    active: currentIndex == 2,
                    onTap: () => onTabSelected(2),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Tôi',
                    active: currentIndex == 3,
                    onTap: () => onTabSelected(3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = VFTheme.scale(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12 * scale),
      child: Opacity(
        opacity: active ? 1 : 0.45,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: 4 * scale,
            horizontal: 8 * scale,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22 * scale,
                color: active ? VFTheme.accent : VFTheme.textMuted,
              ),
              SizedBox(height: 2 * scale),
              Text(
                label,
                style: TextStyle(
                  fontSize: VFTheme.font(context, 10),
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? VFTheme.accent : VFTheme.textMuted,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FabButton extends StatelessWidget {
  const _FabButton({
    required this.size,
    required this.isOpen,
    required this.onTap,
  });

  final double size;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedRotation(
        duration: const Duration(milliseconds: 200),
        turns: isOpen ? 0.125 : 0,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isOpen ? VFTheme.text : VFTheme.accent,
            borderRadius: BorderRadius.circular(14 * VFTheme.scale(context)),
          ),
          child: Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 24 * VFTheme.scale(context),
          ),
        ),
      ),
    );
  }
}
