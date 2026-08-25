import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';
import 'academic_calendar_view.dart';
import 'timetable_view.dart';

class ScheduleTabScreen extends StatefulWidget {
  const ScheduleTabScreen({super.key});

  @override
  State<ScheduleTabScreen> createState() => _ScheduleTabScreenState();
}

class _ScheduleTabScreenState extends State<ScheduleTabScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDesignTokens.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 22, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '일정',
                        style: TextStyle(
                          color: AppDesignTokens.navy,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        '학사 일정과 학년별 시간표를 확인하세요',
                        style: TextStyle(
                          color: AppDesignTokens.muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 46,
                  margin: AppDesignTokens.contentPadding,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.paleBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: AppDesignTokens.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppDesignTokens.divider),
                    ),
                    labelColor: AppDesignTokens.navy,
                    unselectedLabelColor: AppDesignTokens.muted,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: const [
                      Tab(text: '학사 일정'),
                      Tab(text: '과 시간표'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: const [AcademicCalendarView(), TimetableView()],
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
