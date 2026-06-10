import 'package:flutter/widgets.dart';

enum MainTab { home, scan, fridge, profile }

class MainTabsScope extends InheritedWidget {
  const MainTabsScope({
    super.key,
    required this.currentTab,
    required this.onSelectTab,
    required super.child,
  });

  final MainTab currentTab;
  final ValueChanged<MainTab> onSelectTab;

  static MainTabsScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MainTabsScope>();
    assert(scope != null, 'MainTabsScope not found');
    return scope!;
  }

  static void select(BuildContext context, MainTab tab) {
    of(context).onSelectTab(tab);
  }

  @override
  bool updateShouldNotify(MainTabsScope oldWidget) {
    return currentTab != oldWidget.currentTab;
  }
}
