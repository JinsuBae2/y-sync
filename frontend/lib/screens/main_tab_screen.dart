import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_design_tokens.dart';
import 'community_list_screen.dart';
import 'home_screen.dart';
import 'schedule_tab_screen.dart';
import 'mypage_screen.dart';

class MainTabScreen extends ConsumerStatefulWidget {
  const MainTabScreen({super.key});

  @override
  ConsumerState<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends ConsumerState<MainTabScreen> {
  int _currentIndex = 0;
  PageController? _pageController;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  PageController _getOrCreatePageController(int initialPage) {
    if (_pageController == null) {
      _pageController = PageController(initialPage: initialPage);
    } else if (!_pageController!.hasClients) {
      _pageController!.dispose();
      _pageController = PageController(initialPage: initialPage);
    }
    return _pageController!;
  }

  void _selectTab(int index, {bool animate = true}) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
    if (_pageController != null && _pageController!.hasClients) {
      if (animate) {
        _pageController!.animateToPage(
          index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      } else {
        _pageController!.jumpToPage(index);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = AppDesignTokens.blue;
    const darkNavy = AppDesignTokens.navy;
    final pageController = _getOrCreatePageController(_currentIndex);
    final screens = <Widget>[
      HomeScreen(
        onOpenCommunity: () => _selectTab(1),
        onOpenSchedule: () => _selectTab(2),
      ),
      const CommunityListScreen(),
      const ScheduleTabScreen(),
      const MyPageScreen(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: AppDesignTokens.background,
            body: Row(
              children: [
                // 좌측 고정 사이드바
                Container(
                  width: 260,
                  color: darkNavy,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 사이드바 헤더
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 36,
                        ),
                        color: darkNavy.withBlue(60),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.sync_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Y-Sync',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    '소프트웨어융합과',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSidebarItem(0, Icons.home_rounded, '홈', themeColor),
                      _buildSidebarItem(
                        1,
                        Icons.forum_outlined,
                        '커뮤니티',
                        themeColor,
                      ),
                      _buildSidebarItem(
                        2,
                        Icons.calendar_month_outlined,
                        '일정 및 시간표',
                        themeColor,
                      ),
                      _buildSidebarItem(
                        3,
                        Icons.person_outline_rounded,
                        '내정보',
                        themeColor,
                      ),
                    ],
                  ),
                ),
                // 우측 메인 영역
                Expanded(
                  child: IndexedStack(index: _currentIndex, children: screens),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: PageView(
            controller: pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: screens,
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppDesignTokens.divider)),
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: Colors.white,
                elevation: 0,
                height: 76,
                indicatorColor: AppDesignTokens.paleBlue,
                indicatorShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  return IconThemeData(
                    size: 26,
                    color: states.contains(WidgetState.selected)
                        ? AppDesignTokens.blue
                        : AppDesignTokens.muted,
                  );
                }),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  return TextStyle(
                    fontSize: 12,
                    fontWeight: states.contains(WidgetState.selected)
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: states.contains(WidgetState.selected)
                        ? AppDesignTokens.blue
                        : AppDesignTokens.muted,
                  );
                }),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: _selectTab,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: '홈',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.forum_outlined),
                    selectedIcon: Icon(Icons.forum_rounded),
                    label: '커뮤니티',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month_rounded),
                    label: '일정',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: '내정보',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidebarItem(
    int index,
    IconData icon,
    String title,
    Color activeColor,
  ) {
    final isSelected = _currentIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _selectTab(index, animate: false),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
