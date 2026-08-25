import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:time_planner/time_planner.dart';
import '../models/timetable_entry.dart';
import '../providers/timetable_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_design_tokens.dart';

// 💡 학과 공용 시간표와 학생 개인 시간표를 전환해 보여주는 뷰입니다.
class TimetableView extends ConsumerStatefulWidget {
  const TimetableView({super.key});

  @override
  ConsumerState<TimetableView> createState() => _TimetableViewState();
}

class _TimetableViewState extends ConsumerState<TimetableView> {
  final List<String> _gradeOptions = ['GRADE_1', 'GRADE_2', 'GRADE_3'];
  final List<String> _gradeLabels = ['1학년', '2학년', '3학년'];
  bool _isPersonal = false;

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
      default:
        return 0;
    }
  }

  String _getDayString(int index) {
    const days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY'];
    return days[index];
  }

  Color _getCourseBackground(String subjectName) {
    return switch (subjectName.hashCode.abs() % 3) {
      0 => AppDesignTokens.paleBlue,
      1 => AppDesignTokens.navy.withValues(alpha: 0.07),
      _ => AppDesignTokens.blue.withValues(alpha: 0.08),
    };
  }

  Color _getCourseBorder(String subjectName) {
    return switch (subjectName.hashCode.abs() % 3) {
      0 => AppDesignTokens.blue.withValues(alpha: 0.48),
      1 => AppDesignTokens.navy.withValues(alpha: 0.36),
      _ => AppDesignTokens.blue.withValues(alpha: 0.28),
    };
  }

  @override
  Widget build(BuildContext context) {
    final selectedGrade = ref.watch(selectedTimetableGradeProvider);
    final timetableAsync = _isPersonal
        ? ref.watch(personalTimetableEntriesProvider)
        : ref.watch(timetableEntriesProvider);

    final authState = ref.watch(authProvider);
    final currentUser = authState.asData?.value;
    final isAdmin =
        currentUser != null &&
        (currentUser.role == 'ADMIN' || currentUser.role == 'SUPER_ADMIN');

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      body: Column(
        children: [
          Container(
            height: 44,
            margin: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppDesignTokens.paleBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _buildModeOption(
                  label: '학과 시간표',
                  icon: Icons.school_outlined,
                  selected: !_isPersonal,
                  onTap: () => setState(() => _isPersonal = false),
                ),
                _buildModeOption(
                  label: '개인 시간표',
                  icon: Icons.person_outline_rounded,
                  selected: _isPersonal,
                  onTap: () => setState(() => _isPersonal = true),
                ),
              ],
            ),
          ),
          if (!_isPersonal)
            Container(
              height: 44,
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppDesignTokens.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppDesignTokens.divider),
              ),
              child: Row(
                children: List.generate(_gradeOptions.length, (idx) {
                  final isSelected = _gradeOptions[idx] == selectedGrade;
                  return Expanded(
                    child: Material(
                      color: isSelected
                          ? AppDesignTokens.surface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => ref
                            .read(selectedTimetableGradeProvider.notifier)
                            .updateGrade(_gradeOptions[idx]),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: isSelected
                                ? Border.all(color: AppDesignTokens.divider)
                                : null,
                          ),
                          child: Text(
                            _gradeLabels[idx],
                            style: TextStyle(
                              color: isSelected
                                  ? AppDesignTokens.navy
                                  : AppDesignTokens.muted,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          Expanded(
            child: timetableAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppDesignTokens.blue),
              ),
              error: (err, stack) => const Center(
                child: Text(
                  '시간표를 불러오지 못했습니다.',
                  style: TextStyle(color: AppDesignTokens.muted),
                ),
              ),
              data: (entries) {
                final List<TimePlannerTask> tasks = entries.map((entry) {
                  final dayIndex = _getDayIndex(entry.dayOfWeek);
                  // 1교시 = 9시, 2교시 = 10시 ... N교시 = 9 + (N - 1)
                  final startHour = 9 + (entry.startPeriod - 1);
                  final durationMinutes =
                      (entry.endPeriod - entry.startPeriod + 1) * 60;

                  final bgColor = _getCourseBackground(entry.subjectName);
                  final borderColor = _getCourseBorder(entry.subjectName);

                  return TimePlannerTask(
                    color: bgColor,
                    dateTime: TimePlannerDateTime(
                      day: dayIndex,
                      hour: startHour,
                      minutes: 0,
                    ),
                    minutesDuration: durationMinutes,
                    child: GestureDetector(
                      onTap: () {
                        if (_isPersonal || isAdmin) {
                          _showAddEditEntryDialog(entry: entry);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: borderColor, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.subjectName,
                              style: TextStyle(
                                color: AppDesignTokens.navy,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            if (entry.classroom.isNotEmpty)
                              Text(
                                entry.classroom,
                                style: TextStyle(
                                  color: AppDesignTokens.muted,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (entry.professorName.isNotEmpty)
                              Text(
                                entry.professorName,
                                style: TextStyle(
                                  color: AppDesignTokens.subtle,
                                  fontSize: 9,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList();

                return LayoutBuilder(
                  builder: (context, constraints) => TimePlanner(
                    startHour: 9,
                    endHour: 18,
                    style: TimePlannerStyle(
                      cellWidth: (constraints.maxWidth - 60) ~/ 5,
                      cellHeight: 70,
                      dividerColor: AppDesignTokens.divider,
                    ),
                    headers: const [
                      TimePlannerTitle(title: '월'),
                      TimePlannerTitle(title: '화'),
                      TimePlannerTitle(title: '수'),
                      TimePlannerTitle(title: '목'),
                      TimePlannerTitle(title: '금'),
                    ],
                    tasks: tasks,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: currentUser != null && (_isPersonal || isAdmin)
          ? FloatingActionButton(
              backgroundColor: AppDesignTokens.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onPressed: () => _showAddEditEntryDialog(),
              tooltip: _isPersonal ? '내 수업 추가' : '학과 수업 추가',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildModeOption({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: selected ? AppDesignTokens.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: selected
                  ? Border.all(color: AppDesignTokens.divider)
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected
                      ? AppDesignTokens.blue
                      : AppDesignTokens.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? AppDesignTokens.navy
                        : AppDesignTokens.muted,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 💡 수업 등록 및 수정 다이얼로그 (중복 검증 오류 대응 탑재)
  void _showAddEditEntryDialog({TimetableEntry? entry}) {
    final currentGrade = ref.read(selectedTimetableGradeProvider);
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                  decoration: const InputDecoration(
                    labelText: '과목명',
                    hintText: '예: 모바일 앱 개발',
                  ),
                ),
                TextField(
                  controller: professorController,
                  decoration: InputDecoration(
                    labelText: isPersonalEntry ? '담당 교수 (선택)' : '담당 교수',
                    hintText: '예: 홍길동 교수',
                  ),
                ),
                TextField(
                  controller: classroomController,
                  decoration: InputDecoration(
                    labelText: isPersonalEntry ? '강의실 (선택)' : '강의실',
                    hintText: '예: 정보관 303호',
                  ),
                ),
                const SizedBox(height: 16),
                // 요일 선택
                DropdownButtonFormField<int>(
                  initialValue: selectedDayIdx,
                  decoration: const InputDecoration(labelText: '요일'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('월요일')),
                    DropdownMenuItem(value: 1, child: Text('화요일')),
                    DropdownMenuItem(value: 2, child: Text('수요일')),
                    DropdownMenuItem(value: 3, child: Text('목요일')),
                    DropdownMenuItem(value: 4, child: Text('금요일')),
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
                        decoration: const InputDecoration(labelText: '시작 교시'),
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
                        decoration: const InputDecoration(labelText: '종료 교시'),
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
            TextButton(
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
