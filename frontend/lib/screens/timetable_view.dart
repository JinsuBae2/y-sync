import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:time_planner/time_planner.dart';
import '../models/timetable_entry.dart';
import '../providers/timetable_provider.dart';
import '../providers/auth_provider.dart';

// 💡 에브리타임 스타일의 과 시간표 그리드를 보여주는 뷰입니다.
class TimetableView extends ConsumerStatefulWidget {
  const TimetableView({super.key});

  @override
  ConsumerState<TimetableView> createState() => _TimetableViewState();
}

class _TimetableViewState extends ConsumerState<TimetableView> {
  final List<String> _gradeOptions = ['GRADE_1', 'GRADE_2', 'GRADE_3'];
  final List<String> _gradeLabels = ['1학년', '2학년', '3학년'];

  // 요일 매핑 헬퍼
  int _getDayIndex(String dayOfWeek) {
    switch (dayOfWeek) {
      case 'MONDAY': return 0;
      case 'TUESDAY': return 1;
      case 'WEDNESDAY': return 2;
      case 'THURSDAY': return 3;
      case 'FRIDAY': return 4;
      default: return 0;
    }
  }

  String _getDayString(int index) {
    const days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY'];
    return days[index];
  }



  // 과목명에 따른 파스텔 색상 동적 매핑
  Color _getPastelColor(String subjectName) {
    final hash = subjectName.hashCode;
    final colors = [
      Colors.red.shade50,
      Colors.orange.shade50,
      Colors.amber.shade50,
      Colors.green.shade50,
      Colors.teal.shade50,
      Colors.blue.shade50,
      Colors.indigo.shade50,
      Colors.purple.shade50,
      Colors.pink.shade50,
    ];
    return colors[hash.abs() % colors.length];
  }

  Color _getPastelBorderColor(String subjectName) {
    final hash = subjectName.hashCode;
    final colors = [
      Colors.red.shade300,
      Colors.orange.shade300,
      Colors.amber.shade300,
      Colors.green.shade300,
      Colors.teal.shade300,
      Colors.blue.shade300,
      Colors.indigo.shade300,
      Colors.purple.shade300,
      Colors.pink.shade300,
    ];
    return colors[hash.abs() % colors.length];
  }

  Color _getTextColor(String subjectName) {
    final hash = subjectName.hashCode;
    final colors = [
      Colors.red.shade800,
      Colors.orange.shade800,
      Colors.amber.shade800,
      Colors.green.shade800,
      Colors.teal.shade800,
      Colors.blue.shade800,
      Colors.indigo.shade800,
      Colors.purple.shade800,
      Colors.pink.shade800,
    ];
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedGrade = ref.watch(selectedTimetableGradeProvider);
    final timetableAsync = ref.watch(timetableEntriesProvider);
    
    final authState = ref.watch(authProvider);
    final currentUser = authState.asData?.value;
    final isAdmin = currentUser != null && (currentUser.role == 'ADMIN' || currentUser.role == 'SUPER_ADMIN');

    return Scaffold(
      body: Column(
        children: [
          // 💡 학년 선택 토글 영역 (디자인 톤 맞춤)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_gradeOptions.length, (idx) {
                final isSelected = _gradeOptions[idx] == selectedGrade;
                return GestureDetector(
                  onTap: () {
                    ref.read(selectedTimetableGradeProvider.notifier).updateGrade(_gradeOptions[idx]);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? theme.colorScheme.primary : Colors.white,
                      border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Text(
                      _gradeLabels[idx],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const Divider(height: 1),
          // 💡 시간표 렌더링 영역 (time_planner 패키지 적용)
          Expanded(
            child: timetableAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('시간표 로딩 에러: $err')),
              data: (entries) {
                final List<TimePlannerTask> tasks = entries.map((entry) {
                  final dayIndex = _getDayIndex(entry.dayOfWeek);
                  // 1교시 = 9시, 2교시 = 10시 ... N교시 = 9 + (N - 1)
                  final startHour = 9 + (entry.startPeriod - 1);
                  final durationMinutes = (entry.endPeriod - entry.startPeriod + 1) * 60;
                  
                  final bgColor = _getPastelColor(entry.subjectName);
                  final borderColor = _getPastelBorderColor(entry.subjectName);
                  final textColor = _getTextColor(entry.subjectName);

                  return TimePlannerTask(
                    color: bgColor,
                    dateTime: TimePlannerDateTime(day: dayIndex, hour: startHour, minutes: 0),
                    minutesDuration: durationMinutes,
                    child: GestureDetector(
                      onTap: () {
                        if (isAdmin) {
                          _showAddEditEntryDialog(entry: entry);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.subjectName,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            Text(
                              entry.classroom,
                              style: TextStyle(
                                color: textColor.withOpacity(0.8),
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              entry.professorName,
                              style: TextStyle(
                                color: textColor.withOpacity(0.7),
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

                return TimePlanner(
                  startHour: 9,
                  endHour: 18,
                  style: TimePlannerStyle(
                    cellWidth: (MediaQuery.of(context).size.width - 60) ~/ 5,
                    cellHeight: 70,
                    dividerColor: Colors.grey.shade200,
                  ),
                  headers: const [
                    TimePlannerTitle(title: '월'),
                    TimePlannerTitle(title: '화'),
                    TimePlannerTitle(title: '수'),
                    TimePlannerTitle(title: '목'),
                    TimePlannerTitle(title: '금'),
                  ],
                  tasks: tasks,
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _showAddEditEntryDialog(),
              tooltip: '수업 등록',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  // 💡 수업 등록 및 수정 다이얼로그 (중복 검증 오류 대응 탑재)
  void _showAddEditEntryDialog({TimetableEntry? entry}) {
    final currentGrade = ref.read(selectedTimetableGradeProvider);
    final subjectController = TextEditingController(text: entry?.subjectName ?? '');
    final professorController = TextEditingController(text: entry?.professorName ?? '');
    final classroomController = TextEditingController(text: entry?.classroom ?? '');
    
    int selectedDayIdx = entry != null ? _getDayIndex(entry.dayOfWeek) : 0;
    int startPeriod = entry?.startPeriod ?? 1;
    int endPeriod = entry?.endPeriod ?? 2;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(entry == null ? '신규 수업 등록' : '수업 정보 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: '과목명', hintText: '예: 모바일 앱 개발'),
                ),
                TextField(
                  controller: professorController,
                  decoration: const InputDecoration(labelText: '담당 교수', hintText: '예: 홍길동 교수'),
                ),
                TextField(
                  controller: classroomController,
                  decoration: const InputDecoration(labelText: '강의실', hintText: '예: 정보관 303호'),
                ),
                const SizedBox(height: 16),
                // 요일 선택
                DropdownButtonFormField<int>(
                  value: selectedDayIdx,
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
                        value: startPeriod,
                        decoration: const InputDecoration(labelText: '시작 교시'),
                        items: List.generate(9, (index) => DropdownMenuItem(value: index + 1, child: Text('${index + 1}교시'))),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              startPeriod = val;
                              if (endPeriod < startPeriod) endPeriod = startPeriod;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: endPeriod,
                        decoration: const InputDecoration(labelText: '종료 교시'),
                        items: List.generate(9, (index) => DropdownMenuItem(value: index + 1, child: Text('${index + 1}교시'))),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              endPeriod = val;
                              if (endPeriod < startPeriod) endPeriod = startPeriod;
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
                  _confirmDelete(entry.id);
                },
                child: const Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            TextButton(
              onPressed: () async {
                final subject = subjectController.text.trim();
                final professor = professorController.text.trim();
                final classroom = classroomController.text.trim();
                if (subject.isEmpty || professor.isEmpty || classroom.isEmpty) return;

                final dayOfWeekStr = _getDayString(selectedDayIdx);

                try {
                  if (entry == null) {
                    await ref.read(timetableNotifierProvider).createEntry(
                          grade: currentGrade,
                          dayOfWeek: dayOfWeekStr,
                          subjectName: subject,
                          professorName: professor,
                          classroom: classroom,
                          startPeriod: startPeriod,
                          endPeriod: endPeriod,
                        );
                  } else {
                    await ref.read(timetableNotifierProvider).updateEntry(
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
                  if (mounted) {
                    Navigator.pop(ctx);
                  }
                } catch (e) {
                  // 💡 시간표 중복(겹침) 검증 오류 메시지를 토스트/스낵바로 노출
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

  void _confirmDelete(int entryId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('수업 삭제'),
        content: const Text('선택한 수업을 시간표에서 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(timetableNotifierProvider).deleteEntry(entryId);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
