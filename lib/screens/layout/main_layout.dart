import 'package:flutter/material.dart';
import 'dart:ui';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../components/common/gradient_background.dart';
import '../chat_advisor/chat_advisor_screen.dart';
import '../financial_profile/financial_profile_screen.dart';
import '../health_score/health_score_screen.dart';
import '../portfolio_tracker/portfolio_tracker_screen.dart';
import '../fire_calculator/fire_calculator_screen.dart';
import '../what_if_simulator/what_if_simulator_screen.dart';

// ── Nav model ─────────────────────────────────────────────────────────────────
class NavItem {
  final String label;
  final IconData icon;
  final int index;
  NavItem({required this.label, required this.icon, required this.index});
}

class MainLayoutWrapper extends StatelessWidget {
  const MainLayoutWrapper({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => const MainLayout();
}

class MainLayout extends StatefulWidget {
  const MainLayout({Key? key}) : super(key: key);
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  final List<NavItem> navItems = [
    NavItem(label: 'Advisor Chat', icon: Icons.chat_bubble_outline, index: 0),
    NavItem(label: 'My Profile', icon: Icons.person_outline, index: 1),
    NavItem(label: 'Health Score', icon: Icons.monitor_heart_outlined, index: 2),
    NavItem(label: 'Portfolio', icon: Icons.pie_chart_outline, index: 3),
    NavItem(label: 'FIRE Calculator', icon: Icons.local_fire_department_outlined, index: 4),
    NavItem(label: 'What-If Simulator', icon: Icons.help_outline_rounded, index: 5),
  ];

  final List<Widget> _screens = const [
    ChatAdvisorScreen(),
    FinancialProfileScreen(),
    HealthScoreScreen(),
    PortfolioTrackerScreen(),
    FireCalculatorScreen(),
    WhatIfSimulatorScreen(),
  ];

  @override
  void initState() {
    super.initState();
  }

  void _updatePage(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: GradientBackground(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // ── Sidebar (desktop only) ──────────────────────────────────
              if (!isMobile) ...[
                _GlassSidebar(
                  navItems: navItems,
                  selectedIndex: _selectedIndex,
                  isDark: isDark,
                  onNavTap: _updatePage,
                ),
                const SizedBox(width: 16),
              ],
              // ── Main content glass panel ────────────────────────────────
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.getGlassBg(isDark, 0.01),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: AppColors.getBorder(isDark, 0.08),
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.05),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              )),
                              child: child,
                            ),
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey<int>(_selectedIndex),
                          child: _screens[_selectedIndex],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: isMobile ? _buildMobileNav(isDark) : null,
    );
  }

  Widget _buildMobileNav(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getBackground(isDark).withOpacity(0.92),
        border: Border(
          top: BorderSide(color: AppColors.getBorder(isDark, 0.1)),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              final isActive = _selectedIndex == index;
              return GestureDetector(
                onTap: () => _updatePage(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isActive
                        ? AppColors.getBrandSecondary(isDark).withOpacity(isDark ? 0.6 : 0.2)
                        : Colors.transparent,
                  ),
                  child: Icon(
                    item.icon,
                    size: 22,
                    color: isActive
                        ? AppColors.getBrandPrimary(isDark)
                        : AppColors.getTextTertiary(isDark),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass Sidebar
// ─────────────────────────────────────────────────────────────────────────────
class _GlassSidebar extends StatelessWidget {
  final List<NavItem> navItems;
  final int selectedIndex;
  final bool isDark;
  final ValueChanged<int> onNavTap;

  const _GlassSidebar({
    required this.navItems,
    required this.selectedIndex,
    required this.isDark,
    required this.onNavTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 272,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getGlassBg(isDark, 0.02),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.getBorder(isDark, 0.10),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Logo ─────────────────────────────────────────────
                  _buildLogo(),
                  const SizedBox(height: 32),
                  // ── Nav links ─────────────────────────────────────────
                  Expanded(
                    child: ListView.separated(
                      itemCount: navItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (_, i) => _NavTile(
                        item: navItems[i],
                        isActive: selectedIndex == i,
                        isDark: isDark,
                        onTap: () => onNavTap(i),
                      ),
                    ),
                  ),
                  // ── Footer ────────────────────────────────────────────
                  Divider(
                      color: AppColors.getBorder(isDark, 0.1),
                      height: 28),
                  _FooterTile(
                    icon: isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    label: isDark ? 'Light Mode' : 'Dark Mode',
                    color: AppColors.getTextTertiary(isDark),
                    onTap: () => AppTheme.toggleTheme(),
                  ),
                  const SizedBox(height: 8),
                  _FooterTile(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    color: const Color(0xFFF87171),
                    onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: AppColors.getBrandGradient(isDark),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.getBrandPrimary(isDark).withOpacity(0.5),
                blurRadius: 20,
              ),
            ],
          ),
          child: const Icon(Icons.account_balance_wallet,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ShaderMask(
            shaderCallback: (b) => LinearGradient(
              colors: [AppColors.getTextPrimary(isDark), const Color(0xFF94A3B8)],
            ).createShader(b),
            child: Text(
              'Money Mentor',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(isDark),
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Individual nav tile ───────────────────
class _NavTile extends StatelessWidget {
  final NavItem item;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          // Active: gradient
          gradient: isActive
              ? LinearGradient(
                  colors: [
                    AppColors.getBrandSecondary(isDark).withOpacity(isDark ? 0.8 : 0.2),
                    Colors.transparent,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          // Active left border: 
          border: isActive
              ? Border(
                  left: BorderSide(
                    color: AppColors.getBrandPrimary(isDark),
                    width: 3.5,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 20,
              color: isActive
                  ? AppColors.getBrandPrimary(isDark)
                  : AppColors.getTextTertiary(isDark),
            ),
            const SizedBox(width: 14),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? AppColors.getBrandPrimary(isDark)
                    : AppColors.getTextTertiary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FooterTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
