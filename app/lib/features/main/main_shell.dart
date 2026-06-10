import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/inventory_events.dart';
import '../fridge/fridge_screen.dart';
import '../home/home_screen.dart';
import '../scan/scan_ticket_screen.dart';
import '../stats/stats_screen.dart';
import 'main_tabs.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  MainTab _currentTab = MainTab.home;

  late final List<Widget> _pages = [
    const HomeScreen(),
    ScanTicketScreen(onProductsSaved: () => _selectTab(MainTab.fridge)),
    const FridgeScreen(),
    const StatsScreen(),
  ];

  int get _currentIndex => MainTab.values.indexOf(_currentTab);

  void _selectTab(MainTab tab) {
    if (!mounted) return;
    setState(() {
      _currentTab = tab;
    });
    if (tab == MainTab.home ||
        tab == MainTab.fridge ||
        tab == MainTab.profile) {
      notifyInventoryChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainTabsScope(
      currentTab: _currentTab,
      onSelectTab: _selectTab,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: _MainBottomBar(
          currentTab: _currentTab,
          onSelectTab: _selectTab,
        ),
      ),
    );
  }
}

class _MainBottomBar extends StatelessWidget {
  const _MainBottomBar({
    required this.currentTab,
    required this.onSelectTab,
  });

  final MainTab currentTab;
  final ValueChanged<MainTab> onSelectTab;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .08),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            _TabButton(
              tab: MainTab.home,
              currentTab: currentTab,
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'Inicio',
              onTap: onSelectTab,
            ),
            _TabButton(
              tab: MainTab.scan,
              currentTab: currentTab,
              icon: Icons.document_scanner_outlined,
              selectedIcon: Icons.document_scanner_rounded,
              label: 'Escanear',
              onTap: onSelectTab,
            ),
            _TabButton(
              tab: MainTab.fridge,
              currentTab: currentTab,
              icon: Icons.kitchen_outlined,
              selectedIcon: Icons.kitchen_rounded,
              label: 'Nevera',
              onTap: onSelectTab,
            ),
            _TabButton(
              tab: MainTab.profile,
              currentTab: currentTab,
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              label: 'Perfil',
              onTap: onSelectTab,
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.currentTab,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  final MainTab tab;
  final MainTab currentTab;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final ValueChanged<MainTab> onTap;

  bool get _selected => tab == currentTab;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => onTap(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 6),
          transform: Matrix4.translationValues(0, _selected ? -4 : 0, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: _selected ? 52 : 42,
                height: _selected ? 52 : 42,
                decoration: BoxDecoration(
                  color: _selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(_selected ? 16 : 14),
                ),
                child: Icon(
                  _selected ? selectedIcon : icon,
                  color: _selected ? Colors.white : AppColors.textSecondary,
                  size: _selected ? 28 : 26,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _selected ? FontWeight.w900 : FontWeight.w600,
                  color:
                      _selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
