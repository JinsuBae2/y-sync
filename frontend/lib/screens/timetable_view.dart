import '../providers/demo_access_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/timetable_entry.dart';
import '../providers/timetable_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_design_tokens.dart';
import '../widgets/selection_highlight.dart';

// 💡 학과 공용 시간표와 학생 개인 시간표를 전환해 보여주는 뷰입니다.
class TimetableView extends ConsumerStatefulWidget {
  const TimetableView({super.key});

  @override
  ConsumerState<TimetableView> createState() => _TimetableViewState();
}

class _TimetableViewState extends ConsumerState<TimetableView> {
  static const _gridDayStyle = TextStyle(
    color: AppDesignTokens.navy,
    fontSize: 13,
    letterSpacing: -0.2,
    fontWeight: FontWeight.w800,
  );
  final List<String> _gradeOptions = ['GRADE_1', 'GRADE_2', 'GRADE_3'];
  final List<String> _gradeLabels = ['1학년', '2학년', '3학년'];
  bool _isPersonal = false;
  bool _showWeeklyGrid = true;
  int _selectedDayIndex = (DateTime.now().weekday - 1).clamp(0, 5);

  // 요일 매핑 헬퍼
  int _getDayIndex(String dayOfWeek) {
    switch (dayOfWeek) {
      case 'MONDAY':
        return 0;
      case 'TUESDAY':
        return 1;
      case 'WEDNESDAY':
        return 2;
      case 'THURSDAY':
        return 3;
      case 'FRIDAY':
        return 4;
      case 'SATURDAY':
        return 5;
      default:
        return 0;
    }
  }

  String _getDayString(int index) {
    const days = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
    ];
    return days[index];
  }

  static const _coursePalette = [
    (background: Color(0xFFE8F0FF), accent: Color(0xFF5378B9)),
    (background: Color(0xFFE9F4F1), accent: Color(0xFF4F8177)),
    (background: Color(0xFFF2ECF8), accent: Color(0xFF80669A)),
    (background: Color(0xFFFFF1E7), accent: Color(0xFFA66F45)),
    (background: Color(0xFFE9F3F8), accent: Color(0xFF4D7E96)),
    (background: Color(0xFFF7ECEF), accent: Color(0xFF986579)),
  ];

  ({Color background, Color accent}) _courseColor(String subjectName) {
    var hash = 0x811C9DC5;
    for (final codeUnit in subjectName.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0xFFFFFFFF;
    }
    return _coursePalette[hash % _coursePalette.length];
  }

  @override
  Widget build(BuildContext context) {
    final selectedGrade = ref.watch(selectedTimetableGradeProvider);
    final selectedClass = ref.watch(selectedTimetableClassProvider);
    final timetableAsync = _isPersonal
        ? ref.watch(personalTimetableEntriesProvider)
        : ref.watch(timetableEntriesProvider);

    final authState = ref.watch(authProvider);
    final currentUser = authState.asData?.value;
    final isAdmin =
        currentUser != null &&
        (currentUser.role == 'ADMIN' || currentUser.role == 'SUPER_ADMIN');
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    final controls = <Widget>[
      _buildTopControls(
        selectedGrade: selectedGrade,
        selectedClass: selectedClass,
      ),
      if (isMobile) _buildMobileViewControls(),
    ];
    final timetableContent = timetableAsync.when(
      loading: () => const SizedBox(
        height: 240,
        child: Center(
          child: CircularProgressIndicator(color: AppDesignTokens.blue),
        ),
      ),
      error: (err, stack) => const SizedBox(
        height: 240,
        child: Center(
          child: Text(
            '시간표를 불러오지 못했습니다.',
            style: TextStyle(color: AppDesignTokens.muted),
          ),
        ),
      ),
      data: (entries) {
        if (isMobile && !_showWeeklyGrid) {
          return _buildMobileDayList(entries, isAdmin: isAdmin);
        }
        final planner = _buildWeeklyPlanner(
          entries,
          isAdmin: isAdmin,
          isMobile: isMobile,
        );
        return planner;
      },
    );

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      body: isMobile
          ? SingleChildScrollView(
              key: const ValueKey('mobile-timetable-page-scroll'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [...controls, timetableContent],
              ),
            )
          : Column(
              children: [
                ...controls,
                Expanded(child: timetableContent),
              ],
            ),
      floatingActionButton: currentUser != null && !currentUser.isDemo && (_isPersonal || isAdmin)
          ? FloatingActionButton(
              backgroundColor: AppDesignTokens.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onPressed: _isPersonal
                  ? _showPersonalAddOptions
                  : () => _showAddEditEntryDialog(),
              tooltip: _isPersonal ? '내 수업 추가' : '학과 수업 추가',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  static const double _weeklyRowHeight = 70;

  Widget _buildWeeklyPlanner(
    List<TimetableEntry> entries, {
    required bool isAdmin,
    required bool isMobile,
  }) {
    final dayCount = entries.any((e) => e.dayOfWeek == 'SATURDAY') ? 6 : 5;
    final periods = entries.fold<int>(
      9,
      (n, e) => e.endPeriod > n ? e.endPeriod : n,
    );
    const days = ['월', '화', '수', '목', '금', '토'];
    final grid = Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      child: Column(
        children: [
          SizedBox(
            height: 36,
            child: Row(
              children: [
                const SizedBox(width: 36),
                for (var day = 0; day < dayCount; day++)
                  Expanded(
                    child: Center(child: Text(days[day], style: _gridDayStyle)),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: periods * _weeklyRowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 36,
                  child: Column(
                    children: [
                      for (var p = 1; p <= periods; p++)
                        SizedBox(
                          height: _weeklyRowHeight,
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              '${8 + p}:00',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppDesignTokens.muted,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                for (var day = 0; day < dayCount; day++)
                  Expanded(
                    child: _buildWeeklyDay(
                      entries
                          .where((e) => _getDayIndex(e.dayOfWeek) == day)
                          .toList(),
                      periods: periods,
                      isAdmin: isAdmin,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    return isMobile ? grid : SingleChildScrollView(child: grid);
  }

  Widget _buildWeeklyDay(
    List<TimetableEntry> entries, {
    required int periods,
    required bool isAdmin,
  }) {
    entries.sort((a, b) => a.startPeriod.compareTo(b.startPeriod));
    final laneEnds = <int>[];
    final lanes = <int>[];
    for (final entry in entries) {
      var lane = laneEnds.indexWhere((end) => end < entry.startPeriod);
      if (lane == -1) {
        lane = laneEnds.length;
        laneEnds.add(entry.endPeriod);
      } else {
        laneEnds[lane] = entry.endPeriod;
      }
      lanes.add(lane);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final laneWidth =
            constraints.maxWidth / (laneEnds.isEmpty ? 1 : laneEnds.length);
        return Stack(
          children: [
            Column(
              children: [
                for (var p = 0; p < periods; p++)
                  Container(
                    height: _weeklyRowHeight,
                    decoration: const BoxDecoration(
                      color: AppDesignTokens.surface,
                      border: Border(
                        top: BorderSide(
                          color: AppDesignTokens.divider,
                          width: 0.5,
                        ),
                        left: BorderSide(
                          color: AppDesignTokens.divider,
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            for (var i = 0; i < entries.length; i++)
              Positioned(
                top: (entries[i].startPeriod - 1) * _weeklyRowHeight + 2,
                left: lanes[i] * laneWidth + 2,
                width: laneWidth - 4,
                height:
                    (entries[i].endPeriod - entries[i].startPeriod + 1) *
                        _weeklyRowHeight -
                    4,
                child: _buildWeeklyCourse(entries[i], isAdmin: isAdmin),
              ),
          ],
        );
      },
    );
  }

  Widget _buildWeeklyCourse(TimetableEntry entry, {required bool isAdmin}) {
    final colors = _courseColor(entry.subjectName);
    final current = _isCurrentClass(entry, useEntryDay: true);
    return Semantics(
      label:
          '${entry.subjectName}, ${_periodStart(entry.startPeriod)}부터 ${_periodEnd(entry.endPeriod)}, ${entry.classroom}',
      button: true,
      child: Material(
        key: ValueKey('weekly-course-${entry.id}'),
        color: colors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: current
                ? AppDesignTokens.blue
                : colors.accent.withValues(alpha: 0.35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showCourseDetails(entry, isAdmin: isAdmin),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    entry.subjectName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: AppDesignTokens.navy,
                    ),
                  ),
                ),
                if (entry.classroom.isNotEmpty)
                  Text(
                    entry.classroom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppDesignTokens.muted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCourseDetails(TimetableEntry entry, {required bool isAdmin}) {
    const days = ['월', '화', '수', '목', '금', '토'];
    showModalBottomSheet<void>(
      context: context,
      constraints: BoxConstraints.tightFor(
        width: MediaQuery.sizeOf(context).width.clamp(0, 640).toDouble(),
      ),
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SizedBox(
        key: const ValueKey('course-details'),
        width: MediaQuery.sizeOf(context).width.clamp(0, 640).toDouble(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.subjectName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppDesignTokens.navy,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${days[_getDayIndex(entry.dayOfWeek)]}요일 · ${entry.startPeriod}~${entry.endPeriod}교시',
                ),
                const SizedBox(height: 6),
                Text(
                  '${_periodStart(entry.startPeriod)} - ${_periodEnd(entry.endPeriod)}',
                ),
                if (entry.classroom.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(entry.classroom),
                ],
                if (entry.professorName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('${entry.professorName} 교수'),
                ],
                if (_isPersonal || isAdmin) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _showAddEditEntryDialog(entry: entry);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('수정'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls({
    required String selectedGrade,
    required int selectedClass,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildModeOption(
                  label: '학과 시간표',
                  selected: !_isPersonal,
                  onTap: () => setState(() => _isPersonal = false),
                ),
              ),
              Expanded(
                child: _buildModeOption(
                  label: '개인 시간표',
                  selected: _isPersonal,
                  onTap: () => setState(() => _isPersonal = true),
                ),
              ),
            ],
          ),
          if (!_isPersonal) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TimetableDropdown<String>(
                    key: const ValueKey('timetable-grade-dropdown'),
                    value: selectedGrade,
                    items: List.generate(_gradeOptions.length, (index) {
                      final grade = _gradeOptions[index];
                      return DropdownMenuItem(
                        key: ValueKey('timetable-grade-option-$grade'),
                        value: grade,
                        child: Text(_gradeLabels[index]),
                      );
                    }),
                    onChanged: (grade) {
                      if (grade == null) return;
                      if (grade != 'GRADE_3' && selectedClass > 2) {
                        ref
                            .read(selectedTimetableClassProvider.notifier)
                            .updateClass(1);
                      }
                      ref
                          .read(selectedTimetableGradeProvider.notifier)
                          .updateGrade(grade);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimetableDropdown<int>(
                    key: const ValueKey('timetable-class-dropdown'),
                    value: selectedClass,
                    items: List.generate(selectedGrade == 'GRADE_3' ? 3 : 2, (
                      index,
                    ) {
                      final classNumber = index + 1;
                      return DropdownMenuItem(
                        key: ValueKey('timetable-class-option-$classNumber'),
                        value: classNumber,
                        child: Text('$classNumber반'),
                      );
                    }),
                    onChanged: (classNumber) {
                      if (classNumber == null) return;
                      ref
                          .read(selectedTimetableClassProvider.notifier)
                          .updateClass(classNumber);
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileViewControls() {
    const dayLabels = ['월', '화', '수', '목', '금', '토'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        children: [
          Container(
            key: const ValueKey('timetable-view-mode'),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 38),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppDesignTokens.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppDesignTokens.divider),
            ),
            child: Row(
              children: [
                _buildTimetableViewOption(
                  label: '요일별',
                  icon: Icons.view_agenda_outlined,
                  selected: !_showWeeklyGrid,
                  onTap: () => setState(() => _showWeeklyGrid = false),
                ),
                _buildTimetableViewOption(
                  label: '주간',
                  icon: Icons.grid_view_outlined,
                  selected: _showWeeklyGrid,
                  onTap: () => setState(() => _showWeeklyGrid = true),
                ),
              ],
            ),
          ),
          if (!_showWeeklyGrid) ...[
            const SizedBox(height: 6),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                border: const Border(
                  bottom: BorderSide(color: AppDesignTokens.divider),
                ),
              ),
              child: Row(
                children: List.generate(dayLabels.length, (index) {
                  final selected = index == _selectedDayIndex;
                  return Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: ValueKey('timetable-day-$index'),
                        borderRadius: BorderRadius.circular(9),
                        onTap: () => setState(() => _selectedDayIndex = index),
                        child: Center(
                          child: Text(
                            dayLabels[index],
                            style: TextStyle(
                              color: selected
                                  ? AppDesignTokens.navy
                                  : AppDesignTokens.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimetableViewOption({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AppDesignTokens.blue : AppDesignTokens.muted,
              ),
              const SizedBox(width: 7),
              SelectionHighlight(
                selected: selected,
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? AppDesignTokens.navy
                        : AppDesignTokens.muted,
                    fontSize: 13,
                    letterSpacing: -0.2,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDayList(
    List<TimetableEntry> entries, {
    required bool isAdmin,
  }) {
    final dayEntries =
        entries
            .where(
              (entry) => _getDayIndex(entry.dayOfWeek) == _selectedDayIndex,
            )
            .toList()
          ..sort((a, b) => a.startPeriod.compareTo(b.startPeriod));
    if (dayEntries.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_available_outlined,
                size: 38,
                color: AppDesignTokens.subtle,
              ),
              SizedBox(height: 10),
              Text(
                '이날은 등록된 수업이 없어요.',
                style: TextStyle(color: AppDesignTokens.muted),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      key: const ValueKey('mobile-timetable-day-list'),
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
      child: Column(
        children: [
          for (final (index, entry) in dayEntries.indexed) ...[
            if (index > 0) const SizedBox(height: 8),
            _buildMobileDayCard(entry, isAdmin: isAdmin),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileDayCard(TimetableEntry entry, {required bool isAdmin}) {
    final isCurrent = _isCurrentClass(entry);
    final accentColor = _courseColor(entry.subjectName).accent;
    return Material(
      key: ValueKey('timetable-entry-${entry.id}'),
      color: AppDesignTokens.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: !ref.watch(isDemoAccountProvider) && (_isPersonal || isAdmin)
            ? () => _showAddEditEntryDialog(entry: entry)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppDesignTokens.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrent ? AppDesignTokens.blue : AppDesignTokens.divider,
              width: isCurrent ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  key: ValueKey('timetable-course-accent-${entry.id}'),
                  width: 4,
                  color: isCurrent ? AppDesignTokens.blue : accentColor,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${_periodStart(entry.startPeriod)} - ${_periodEnd(entry.endPeriod)}',
                              style: const TextStyle(
                                color: AppDesignTokens.muted,
                                fontSize: 12,
                                letterSpacing: -0.15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            if (isCurrent) const _CurrentClassBadge(),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.subjectName,
                          style: const TextStyle(
                            color: AppDesignTokens.navy,
                            fontSize: 16,
                            height: 1.25,
                            letterSpacing: -0.35,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (entry.classroom.isNotEmpty)
                          _TimetableMeta(
                            icon: Icons.location_on_outlined,
                            text: entry.classroom,
                          ),
                        if (entry.classroom.isNotEmpty &&
                            entry.professorName.isNotEmpty)
                          const SizedBox(height: 6),
                        if (entry.professorName.isNotEmpty)
                          _TimetableMeta(
                            icon: Icons.person_outline_rounded,
                            text: '${entry.professorName} 교수',
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isCurrentClass(TimetableEntry entry, {bool useEntryDay = false}) {
    final now = DateTime.now();
    final dayIndex = useEntryDay
        ? _getDayIndex(entry.dayOfWeek)
        : _selectedDayIndex;
    if (now.weekday - 1 != dayIndex) return false;
    final start = DateTime(now.year, now.month, now.day, 8 + entry.startPeriod);
    final end = DateTime(now.year, now.month, now.day, 9 + entry.endPeriod);
    return !now.isBefore(start) && now.isBefore(end);
  }

  String _periodStart(int period) =>
      '${(8 + period).toString().padLeft(2, '0')}:00';

  String _periodEnd(int period) =>
      '${(9 + period).toString().padLeft(2, '0')}:00';

  Widget _buildModeOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          alignment: Alignment.center,
          child: SelectionHighlight(
            selected: selected,
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppDesignTokens.navy : AppDesignTokens.muted,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPersonalAddOptions() async {
    if (blockDemoChange(context, ref)) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.school_outlined,
                  color: AppDesignTokens.blue,
                ),
                title: const Text('학과 시간표에서 선택'),
                subtitle: const Text('과목과 수업 시간을 자동으로 불러와요.'),
                onTap: () => Navigator.pop(context, 'department'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_calendar_outlined),
                title: const Text('직접 입력'),
                subtitle: const Text('교양·타과 수업을 직접 추가해요.'),
                onTap: () => Navigator.pop(context, 'manual'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'manual') {
      _showAddEditEntryDialog();
      return;
    }
    await _showDepartmentCoursePicker();
  }

  Future<void> _showDepartmentCoursePicker() async {
    final group = await _chooseDepartmentGroup();
    if (!mounted || group == null) return;
    final grade = group.$1;
    final classNumber = group.$2;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppDesignTokens.blue),
      ),
    );
    List<TimetableEntry> entries;
    try {
      entries = await ref.read(timetableEntriesProvider.future);
    } catch (_) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('학과 수업을 불러오지 못했습니다.')));
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    final personalEntries =
        ref.read(personalTimetableEntriesProvider).value ?? [];
    final alreadyAddedIds = entries
        .where(
          (entry) => personalEntries.any(
            (personal) =>
                personal.dayOfWeek == entry.dayOfWeek &&
                personal.startPeriod == entry.startPeriod &&
                personal.endPeriod == entry.endPeriod &&
                personal.subjectName == entry.subjectName,
          ),
        )
        .map((entry) => entry.id)
        .toSet();
    final selected = await showModalBottomSheet<List<TimetableEntry>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final selectedIds = <int>{};
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.72,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_gradeLabels[_gradeOptions.indexOf(grade)]} $classNumber반 수업',
                            style: const TextStyle(
                              color: AppDesignTokens.navy,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('닫기'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: entries.isEmpty
                        ? const Center(child: Text('등록된 학과 수업이 없습니다.'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                            itemCount: entries.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              final isAdded = alreadyAddedIds.contains(
                                entry.id,
                              );
                              final isSelected = selectedIds.contains(entry.id);
                              final dayLabel = const {
                                'MONDAY': '월',
                                'TUESDAY': '화',
                                'WEDNESDAY': '수',
                                'THURSDAY': '목',
                                'FRIDAY': '금',
                                'SATURDAY': '토',
                              }[entry.dayOfWeek];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(entry.subjectName),
                                subtitle: Text(
                                  isAdded
                                      ? '이미 등록된 수업'
                                      : '$dayLabel요일 ${entry.startPeriod}~${entry.endPeriod}교시 · ${entry.professorName} · ${entry.classroom}',
                                ),
                                trailing: IconButton(
                                  key: ValueKey(
                                    'department-course-${entry.id}',
                                  ),
                                  tooltip: isAdded
                                      ? '이미 등록됨'
                                      : (isSelected ? '선택 취소' : '수업 선택'),
                                  onPressed: isAdded
                                      ? null
                                      : () => setSheetState(() {
                                          if (isSelected) {
                                            selectedIds.remove(entry.id);
                                          } else {
                                            selectedIds.add(entry.id);
                                          }
                                        }),
                                  icon: Icon(
                                    isAdded
                                        ? Icons.check_circle_rounded
                                        : (isSelected
                                              ? Icons.check_circle_rounded
                                              : Icons
                                                    .add_circle_outline_rounded),
                                    color: isAdded
                                        ? AppDesignTokens.subtle
                                        : AppDesignTokens.blue,
                                  ),
                                ),
                                onTap: isAdded
                                    ? null
                                    : () => setSheetState(() {
                                        if (isSelected) {
                                          selectedIds.remove(entry.id);
                                        } else {
                                          selectedIds.add(entry.id);
                                        }
                                      }),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: selectedIds.isEmpty
                            ? null
                            : () => Navigator.pop(
                                context,
                                entries
                                    .where(
                                      (entry) => selectedIds.contains(entry.id),
                                    )
                                    .toList(),
                              ),
                        child: Text('선택한 수업 ${selectedIds.length}개 추가'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || selected == null || selected.isEmpty) return;
    try {
      await ref.read(timetableNotifierProvider).createPersonalEntries(selected);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('수업 ${selected.length}개를 개인 시간표에 추가했습니다.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<(String, int)?> _chooseDepartmentGroup() {
    String grade = ref.read(selectedTimetableGradeProvider);
    int classNumber = ref.read(selectedTimetableClassProvider);
    return showDialog<(String, int)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final maxClass = grade == 'GRADE_3' ? 3 : 2;
          return AlertDialog(
            title: const Text('학년·반 선택'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: grade,
                  decoration: const InputDecoration(labelText: '학년'),
                  items: List.generate(
                    _gradeOptions.length,
                    (index) => DropdownMenuItem(
                      value: _gradeOptions[index],
                      child: Text(_gradeLabels[index]),
                    ),
                  ),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() {
                      grade = value;
                      if (grade != 'GRADE_3' && classNumber > 2) {
                        classNumber = 1;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  key: ValueKey('$grade-$classNumber'),
                  initialValue: classNumber,
                  decoration: const InputDecoration(labelText: '반'),
                  items: List.generate(
                    maxClass,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text('${index + 1}반'),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => classNumber = value);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () {
                  ref
                      .read(selectedTimetableGradeProvider.notifier)
                      .updateGrade(grade);
                  ref
                      .read(selectedTimetableClassProvider.notifier)
                      .updateClass(classNumber);
                  Navigator.pop(context, (grade, classNumber));
                },
                child: const Text('수업 보기'),
              ),
            ],
          );
        },
      ),
    );
  }

  // 💡 수업 등록 및 수정 다이얼로그 (중복 검증 오류 대응 탑재)
  void _showAddEditEntryDialog({TimetableEntry? entry}) {
    if (blockDemoChange(context, ref)) return;
    final currentGrade = ref.read(selectedTimetableGradeProvider);
    final currentClass = ref.read(selectedTimetableClassProvider);
    final isPersonalEntry = _isPersonal;
    final subjectController = TextEditingController(
      text: entry?.subjectName ?? '',
    );
    final professorController = TextEditingController(
      text: entry?.professorName ?? '',
    );
    final classroomController = TextEditingController(
      text: entry?.classroom ?? '',
    );

    int selectedDayIdx = entry != null ? _getDayIndex(entry.dayOfWeek) : 0;
    int startPeriod = entry?.startPeriod ?? 1;
    int endPeriod = entry?.endPeriod ?? 2;

    InputDecoration fieldDecoration(String label, {String? hint}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.72),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppDesignTokens.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppDesignTokens.blue, width: 1.5),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppDesignTokens.background.withValues(alpha: 0.96),
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.9)),
          ),
          title: Text(
            entry == null
                ? (isPersonalEntry ? '내 수업 추가' : '학과 수업 등록')
                : (isPersonalEntry ? '내 수업 수정' : '학과 수업 수정'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subjectController,
                  decoration: fieldDecoration('과목명', hint: '예: 모바일 앱 개발'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: professorController,
                  decoration: fieldDecoration(
                    isPersonalEntry ? '담당 교수 (선택)' : '담당 교수',
                    hint: '예: 홍길동 교수',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: classroomController,
                  decoration: fieldDecoration(
                    isPersonalEntry ? '강의실 (선택)' : '강의실',
                    hint: '예: 정보관 303호',
                  ),
                ),
                const SizedBox(height: 16),
                // 요일 선택
                DropdownButtonFormField<int>(
                  initialValue: selectedDayIdx,
                  decoration: fieldDecoration('요일'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('월요일')),
                    DropdownMenuItem(value: 1, child: Text('화요일')),
                    DropdownMenuItem(value: 2, child: Text('수요일')),
                    DropdownMenuItem(value: 3, child: Text('목요일')),
                    DropdownMenuItem(value: 4, child: Text('금요일')),
                    DropdownMenuItem(value: 5, child: Text('토요일')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedDayIdx = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                // 교시 선택
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: startPeriod,
                        decoration: fieldDecoration('시작 교시'),
                        items: List.generate(
                          9,
                          (index) => DropdownMenuItem(
                            value: index + 1,
                            child: Text('${index + 1}교시'),
                          ),
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              startPeriod = val;
                              if (endPeriod < startPeriod) {
                                endPeriod = startPeriod;
                              }
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: endPeriod,
                        decoration: fieldDecoration('종료 교시'),
                        items: List.generate(
                          9,
                          (index) => DropdownMenuItem(
                            value: index + 1,
                            child: Text('${index + 1}교시'),
                          ),
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              endPeriod = val;
                              if (endPeriod < startPeriod) {
                                endPeriod = startPeriod;
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (entry != null)
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  _confirmDelete(entry.id, personal: isPersonalEntry);
                },
                child: const Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () async {
                final subject = subjectController.text.trim();
                final professor = professorController.text.trim();
                final classroom = classroomController.text.trim();
                if (subject.isEmpty ||
                    (!isPersonalEntry &&
                        (professor.isEmpty || classroom.isEmpty))) {
                  return;
                }

                final dayOfWeekStr = _getDayString(selectedDayIdx);

                try {
                  if (isPersonalEntry && entry == null) {
                    await ref
                        .read(timetableNotifierProvider)
                        .createPersonalEntry(
                          dayOfWeek: dayOfWeekStr,
                          subjectName: subject,
                          professorName: professor,
                          classroom: classroom,
                          startPeriod: startPeriod,
                          endPeriod: endPeriod,
                        );
                  } else if (isPersonalEntry) {
                    await ref
                        .read(timetableNotifierProvider)
                        .updatePersonalEntry(
                          id: entry!.id,
                          dayOfWeek: dayOfWeekStr,
                          subjectName: subject,
                          professorName: professor,
                          classroom: classroom,
                          startPeriod: startPeriod,
                          endPeriod: endPeriod,
                        );
                  } else if (entry == null) {
                    await ref
                        .read(timetableNotifierProvider)
                        .createEntry(
                          grade: currentGrade,
                          classNumber: currentClass,
                          dayOfWeek: dayOfWeekStr,
                          subjectName: subject,
                          professorName: professor,
                          classroom: classroom,
                          startPeriod: startPeriod,
                          endPeriod: endPeriod,
                        );
                  } else {
                    await ref
                        .read(timetableNotifierProvider)
                        .updateEntry(
                          id: entry.id,
                          grade: currentGrade,
                          classNumber: currentClass,
                          dayOfWeek: dayOfWeekStr,
                          subjectName: subject,
                          professorName: professor,
                          classroom: classroom,
                          startPeriod: startPeriod,
                          endPeriod: endPeriod,
                        );
                  }
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                } catch (e) {
                  // 💡 시간표 중복(겹침) 검증 오류 메시지를 토스트/스낵바로 노출
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppDesignTokens.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(int entryId, {required bool personal}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('수업 삭제'),
        content: const Text('선택한 수업을 시간표에서 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (personal) {
                await ref
                    .read(timetableNotifierProvider)
                    .deletePersonalEntry(entryId);
              } else {
                await ref.read(timetableNotifierProvider).deleteEntry(entryId);
              }
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _CurrentClassBadge extends StatelessWidget {
  const _CurrentClassBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppDesignTokens.paleBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        '진행 중',
        style: TextStyle(
          color: AppDesignTokens.blue,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TimetableDropdown<T> extends StatelessWidget {
  const _TimetableDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppDesignTokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF164687).withValues(alpha: 0.4),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF164687),
          ),
          dropdownColor: AppDesignTokens.surface,
          borderRadius: BorderRadius.circular(10),
          style: const TextStyle(
            color: AppDesignTokens.navy,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _TimetableMeta extends StatelessWidget {
  const _TimetableMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppDesignTokens.subtle),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppDesignTokens.muted,
              fontSize: 12.5,
              height: 1.3,
              letterSpacing: -0.15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
