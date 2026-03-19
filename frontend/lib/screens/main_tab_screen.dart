import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notice_list_screen.dart';
import 'community_list_screen.dart';
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

  // 💡 각 탭에 해당하는 화면 리스트
  final List<Widget> _screens = [
    const NoticeListScreen(),
    const CommunityListScreen(),
    const MyPageScreen(), // 💡 추가
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.campaign_rounded),
              activeIcon: Icon(Icons.campaign),
              label: '공지사항',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.forum_outlined),
              activeIcon: Icon(Icons.forum),
              label: '커뮤니티',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: '마이페이지',
            ),
          ],
        ),
      ),
    );
  }
}
