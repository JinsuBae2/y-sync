import 'package:flutter/material.dart';
import 'academic_calendar_view.dart';
import 'timetable_view.dart';

// 💡 학사 일정(캘린더)과 과 시간표를 상단 탭으로 전환하여 보여주는 화면입니다.
class ScheduleTabScreen extends StatefulWidget {
  const ScheduleTabScreen({super.key});

  @override
  State<ScheduleTabScreen> createState() => _ScheduleTabScreenState();
}

class _ScheduleTabScreenState extends State<ScheduleTabScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '학과 일정 및 시간표',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: theme.colorScheme.primary,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 16),
          tabs: const [
            Tab(text: '학사 일정'),
            Tab(text: '과 시간표'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AcademicCalendarView(),
          TimetableView(),
        ],
      ),
    );
  }
}
