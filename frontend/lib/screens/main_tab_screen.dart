import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notice_list_screen.dart';
import 'community_list_screen.dart';
import 'schedule_tab_screen.dart'; // 💡 신규 추가
import 'mypage_screen.dart'; // 💡 추가
import '../providers/auth_provider.dart';

// 💡 공지사항과 커뮤니티를 탭으로 전환할 수 있는 메인 화면입니다.
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

  // 💡 각 탭에 해당하는 화면 리스트
  final List<Widget> _screens = [
    const NoticeListScreen(),
    const CommunityListScreen(),
    const ScheduleTabScreen(), // 💡 신규 추가
    const MyPageScreen(), // 💡 추가
  ];

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF164687);
    final darkNavy = const Color(0xFF0A192F);
    final pageController = _getOrCreatePageController(_currentIndex);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: Colors.grey.shade100,
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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                        color: darkNavy.withBlue(60),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.sync_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Y-Sync',
                                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    '소프트웨어융합과',
                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 사이드바 메뉴 리스트
                      _buildSidebarItem(0, Icons.campaign_rounded, '공지사항', themeColor),
                      _buildSidebarItem(1, Icons.forum_outlined, '커뮤니티', themeColor),
                      _buildSidebarItem(2, Icons.calendar_month_outlined, '일정 및 시간표', themeColor),
                      _buildSidebarItem(3, Icons.person_outline_rounded, '마이페이지', themeColor),
                    ],
                  ),
                ),
                // 우측 메인 영역
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _screens,
                  ),
                ),
              ],
            ),
          );
        }

        // 모바일 레이아웃 (기존 유지 + 터치 최적화)
        return Scaffold(
          body: PageView(
            controller: pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: _screens,
          ),
          bottomNavigationBar: Container(
            height: 72, // 💡 터치 반경 확장을 위한 전체 높이 확대
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              iconSize: 26, // 💡 아이콘 크기 확장
              selectedFontSize: 12,
              unselectedFontSize: 12,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
                pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              },
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Colors.grey,
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              elevation: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4), // 💡 터치 넉넉 패딩
                    child: Icon(Icons.campaign_rounded),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.campaign),
                  ),
                  label: '공지사항',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.forum_outlined),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.forum),
                  ),
                  label: '커뮤니티',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.calendar_month_outlined),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.calendar_month),
                  ),
                  label: '일정',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.person_outline_rounded),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.person_rounded),
                  ),
                  label: '마이페이지',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 💡 사이드바 메뉴 아이템 빌더 추가
  Widget _buildSidebarItem(int index, IconData icon, String title, Color activeColor) {
    final isSelected = _currentIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
          if (_pageController != null && _pageController!.hasClients) {
            _pageController!.jumpToPage(index);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.white70, size: 20),
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
