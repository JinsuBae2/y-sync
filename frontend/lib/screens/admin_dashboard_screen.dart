import 'package:flutter/material.dart';
import 'admin_member_tab.dart';
import 'admin_approval_tab.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0; // 데스크톱용 인덱스

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _selectedIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        
        if (isDesktop) {
          return _buildDesktopLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

  // 📱 모바일 레이아웃 (상단 TabBar + TabBarView)
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          '학과 관리자 페이지',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF164687),
          labelColor: const Color(0xFF164687),
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_alt_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('학생 정보 관리'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.how_to_reg_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('관리자 승인 대기'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AdminMemberTab(isDesktop: false),
          AdminApprovalTab(isDesktop: false),
        ],
      ),
    );
  }

  // 💻 데스크톱 레이아웃 (좌측 고정 사이드 바 + 우측 메인 작업 영역)
  Widget _buildDesktopLayout() {
    final themeColor = const Color(0xFF164687);
    final darkNavy = const Color(0xFF0A192F);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Row(
        children: [
          // 좌측 사이드바 네비게이션
          Container(
            width: 260,
            color: darkNavy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 사이드바 헤더 영역
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
                              'Y-Sync Admin',
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
                
                // 네비게이션 메뉴들
                _buildSidebarItem(
                  index: 0,
                  icon: Icons.people_alt_rounded,
                  title: '학생 정보 관리',
                  activeColor: themeColor,
                ),
                _buildSidebarItem(
                  index: 1,
                  icon: Icons.how_to_reg_rounded,
                  title: '관리자 승인 대기',
                  activeColor: themeColor,
                ),
                
                const Spacer(),
                
                // 뒤로가기 (마이페이지로 이동)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('관리자 종료'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 우측 메인 영역
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 상단 헤더
                Container(
                  height: 70,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedIndex == 0 ? '학생 정보 관리 대시보드' : '관리자 승인 처리 패널',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87),
                      ),
                      Text(
                        '운영 모드: 데스크톱 브라우저',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                
                // 내용 본문
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: const [
                      AdminMemberTab(isDesktop: true),
                      AdminApprovalTab(isDesktop: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required int index,
    required IconData icon,
    required String title,
    required Color activeColor,
  }) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
            _tabController.index = index;
          });
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
