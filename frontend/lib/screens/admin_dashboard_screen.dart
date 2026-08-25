import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';
import 'admin_approval_tab.dart';
import 'admin_member_tab.dart';
import 'admin_post_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _selectedIndex = 0;

  static const _destinations =
      <({String label, String description, IconData icon})>[
        (
          label: '회원 관리',
          description: '학생 계정과 권한',
          icon: Icons.people_outline_rounded,
        ),
        (
          label: '권한 승인',
          description: '관리자 신청 처리',
          icon: Icons.verified_user_outlined,
        ),
        (label: '콘텐츠 관리', description: '게시글과 신고', icon: Icons.article_outlined),
      ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _destinations.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging ||
          _selectedIndex == _tabController.index) {
        return;
      }
      setState(() => _selectedIndex = _tabController.index);
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
      builder: (context, constraints) => constraints.maxWidth >= 900
          ? _DesktopAdminShell(
              selectedIndex: _selectedIndex,
              onSelected: _selectDestination,
              onExit: () => Navigator.pop(context),
            )
          : _MobileAdminShell(tabController: _tabController),
    );
  }

  void _selectDestination(int index) {
    setState(() => _selectedIndex = index);
    _tabController.animateTo(index);
  }
}

class _MobileAdminShell extends StatelessWidget {
  const _MobileAdminShell({required this.tabController});

  final TabController tabController;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppDesignTokens.background,
    appBar: AppBar(
      backgroundColor: AppDesignTokens.background,
      foregroundColor: AppDesignTokens.navy,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      title: const Text(
        '관리자',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      bottom: TabBar(
        controller: tabController,
        indicatorColor: AppDesignTokens.blue,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppDesignTokens.navy,
        unselectedLabelColor: AppDesignTokens.muted,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        tabs: const [
          Tab(text: '회원'),
          Tab(text: '권한 승인'),
          Tab(text: '콘텐츠'),
        ],
      ),
    ),
    body: TabBarView(
      controller: tabController,
      children: const [
        AdminMemberTab(),
        AdminApprovalTab(),
        AdminPostManagementScreen(isTabMode: true),
      ],
    ),
  );
}

class _DesktopAdminShell extends StatelessWidget {
  const _DesktopAdminShell({
    required this.selectedIndex,
    required this.onSelected,
    required this.onExit,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppDesignTokens.background,
    body: Row(
      children: [
        Container(
          width: 248,
          decoration: const BoxDecoration(
            color: AppDesignTokens.surface,
            border: Border(right: BorderSide(color: AppDesignTokens.divider)),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(22, 24, 22, 26),
                  child: Row(
                    children: [
                      _AdminLogo(),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Y-Sync',
                              style: TextStyle(
                                color: AppDesignTokens.navy,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '관리자 콘솔',
                              style: TextStyle(
                                color: AppDesignTokens.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                for (
                  var index = 0;
                  index < _AdminDashboardScreenState._destinations.length;
                  index++
                )
                  _SidebarDestination(
                    destination:
                        _AdminDashboardScreenState._destinations[index],
                    selected: selectedIndex == index,
                    onTap: () => onSelected(index),
                  ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    onPressed: onExit,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('관리자 종료'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppDesignTokens.navy,
                      side: const BorderSide(color: AppDesignTokens.divider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 74,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                alignment: Alignment.centerLeft,
                decoration: const BoxDecoration(
                  color: AppDesignTokens.surface,
                  border: Border(
                    bottom: BorderSide(color: AppDesignTokens.divider),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _AdminDashboardScreenState
                          ._destinations[selectedIndex]
                          .label,
                      style: const TextStyle(
                        color: AppDesignTokens.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _AdminDashboardScreenState
                          ._destinations[selectedIndex]
                          .description,
                      style: const TextStyle(
                        color: AppDesignTokens.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: selectedIndex,
                  children: const [
                    AdminMemberTab(isDesktop: true),
                    AdminApprovalTab(isDesktop: true),
                    AdminPostManagementScreen(isTabMode: true),
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

class _AdminLogo extends StatelessWidget {
  const _AdminLogo();

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppDesignTokens.paleBlue,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.sync_rounded, color: AppDesignTokens.blue),
  );
}

class _SidebarDestination extends StatelessWidget {
  const _SidebarDestination({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final ({String label, String description, IconData icon}) destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
    child: Material(
      color: selected ? AppDesignTokens.paleBlue : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(
                destination.icon,
                size: 20,
                color: selected ? AppDesignTokens.blue : AppDesignTokens.muted,
              ),
              const SizedBox(width: 12),
              Text(
                destination.label,
                style: TextStyle(
                  color: selected
                      ? AppDesignTokens.navy
                      : AppDesignTokens.muted,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
