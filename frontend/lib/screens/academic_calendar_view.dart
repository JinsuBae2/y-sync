import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/calendar_event.dart';
import '../providers/calendar_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notice_provider.dart';
import '../theme/app_design_tokens.dart';
import 'notice_detail_screen.dart';

// 💡 학사 일정을 캘린더 형식으로 보여주는 뷰입니다.
class AcademicCalendarView extends ConsumerStatefulWidget {
  const AcademicCalendarView({super.key});

  @override
  ConsumerState<AcademicCalendarView> createState() =>
      _AcademicCalendarViewState();
}

class _AcademicCalendarViewState extends ConsumerState<AcademicCalendarView> {
  double _horizontalRatio = 0.55; // PC/Web 가로 분할 비율 (55%가 캘린더)
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  // 💡 특정 날짜에 해당하는 일정들을 필터링하여 반환하는 헬퍼 함수
  List<CalendarEvent> _getEventsForDay(
    DateTime day,
    List<CalendarEvent> allEvents,
  ) {
    return allEvents.where((event) {
      try {
        final start = DateTime.parse(event.startDate);
        final end = DateTime.parse(event.endDate);

        final compareDay = DateTime(day.year, day.month, day.day);
        final compareStart = DateTime(start.year, start.month, start.day);
        final compareEnd = DateTime(end.year, end.month, end.day);

        return compareDay.compareTo(compareStart) >= 0 &&
            compareDay.compareTo(compareEnd) <= 0;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  // 💡 달력 카드 뷰 추출
  Widget _buildCalendarCard({
    required double rowHeight,
    required double daysOfWeekHeight,
    required List<CalendarEvent> allEvents,
    required ThemeData theme,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      decoration: BoxDecoration(
        color: AppDesignTokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppDesignTokens.divider),
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2025, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        sixWeekMonthsEnforced: true,
        rowHeight: rowHeight,
        daysOfWeekHeight: daysOfWeekHeight,
        locale: 'ko_KR', // 💡 한국어 로캘 지정
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          leftChevronIcon: Icon(
            Icons.chevron_left_rounded,
            color: AppDesignTokens.navy,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right_rounded,
            color: AppDesignTokens.navy,
          ),
          titleTextStyle: TextStyle(
            color: AppDesignTokens.navy,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: AppDesignTokens.muted,
            fontWeight: FontWeight.w600,
          ),
          weekendStyle: TextStyle(
            color: AppDesignTokens.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        calendarStyle: const CalendarStyle(
          outsideTextStyle: TextStyle(color: AppDesignTokens.divider),
          weekendTextStyle: TextStyle(color: AppDesignTokens.navy),
          defaultTextStyle: TextStyle(color: AppDesignTokens.navy),
          todayDecoration: BoxDecoration(
            color: AppDesignTokens.paleBlue,
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: AppDesignTokens.blue,
            fontWeight: FontWeight.bold,
          ),
          selectedDecoration: BoxDecoration(
            color: AppDesignTokens.navy,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onPageChanged: (focusedDay) {
          ref.read(selectedMonthProvider.notifier).updateMonth(focusedDay);
          setState(() {
            _focusedDay = focusedDay;
          });
        },
        eventLoader: (day) => _getEventsForDay(day, allEvents),
        calendarBuilders: CalendarBuilders(
          // 💡 날짜 하단에 동그란 일정 색상 마커 렌더링
          markerBuilder: (context, day, events) {
            if (events.isEmpty) return null;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: events.take(3).map((event) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.0),
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppDesignTokens.blue,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  // 💡 일정 목록 리스트 뷰 추출
  Widget _buildEventList({
    required List<CalendarEvent> selectedDayEvents,
    required bool isAdmin,
    required ThemeData theme,
  }) {
    final selectedDate = _selectedDay ?? _focusedDay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
          child: Row(
            children: [
              Text(
                '${selectedDate.month}월 ${selectedDate.day}일 일정',
                style: const TextStyle(
                  color: AppDesignTokens.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${selectedDayEvents.length}건',
                style: const TextStyle(
                  color: AppDesignTokens.blue,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppDesignTokens.divider),
        Expanded(
          child: selectedDayEvents.isEmpty
              ? const Center(
                  child: Text(
                    '등록된 일정이 없습니다.',
                    style: TextStyle(
                      color: AppDesignTokens.muted,
                      fontSize: 14,
                    ),
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  itemCount: selectedDayEvents.length,
                  itemBuilder: (context, index) {
                    final event = selectedDayEvents[index];
                    final isNoticeLink = event.type == 'NOTICE';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppDesignTokens.divider),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                        leading: Container(
                          width: 4,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isNoticeLink
                                ? AppDesignTokens.blue
                                : AppDesignTokens.navy,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        title: Text(
                          event.title,
                          style: const TextStyle(
                            color: AppDesignTokens.navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (event.description != null &&
                                event.description!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 4,
                                  bottom: 4,
                                ),
                                child: Text(
                                  event.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppDesignTokens.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            Text(
                              '기간: ${event.startDate} ~ ${event.endDate}',
                              style: const TextStyle(
                                color: AppDesignTokens.subtle,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: isNoticeLink
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppDesignTokens.paleBlue,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '공지 연결',
                                  style: TextStyle(
                                    color: AppDesignTokens.blue,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : (isAdmin
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: '일정 수정',
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 20,
                                            color: AppDesignTokens.blue,
                                          ),
                                          onPressed: () =>
                                              _showAddEditEventDialog(
                                                event: event,
                                              ),
                                        ),
                                        IconButton(
                                          tooltip: '일정 삭제',
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 20,
                                            color: AppDesignTokens.coral,
                                          ),
                                          onPressed: () =>
                                              _confirmDelete(event.id),
                                        ),
                                      ],
                                    )
                                  : null),
                        onTap: isNoticeLink && event.noticeId != null
                            ? () => _navigateToNoticeDetail(event.noticeId!)
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final currentUser = authState.asData?.value;
    final isAdmin =
        currentUser != null &&
        (currentUser.role == 'ADMIN' || currentUser.role == 'SUPER_ADMIN');

    final eventsAsync = ref.watch(calendarEventsProvider);

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('일정을 불러오는 중 오류가 발생했습니다: $err')),
        data: (allEvents) {
          final selectedDayEvents = _getEventsForDay(
            _selectedDay ?? _focusedDay,
            allEvents,
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 768) {
                // 💻 PC/Web Layout: Horizontal split with vertical drag divider
                final totalWidth = constraints.maxWidth;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left panel: Calendar Card
                    SizedBox(
                      width: totalWidth * _horizontalRatio,
                      child: SingleChildScrollView(
                        child: _buildCalendarCard(
                          rowHeight: 48.0,
                          daysOfWeekHeight: 28.0,
                          allEvents: allEvents,
                          theme: theme,
                        ),
                      ),
                    ),
                    // Resizable divider handle
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          _horizontalRatio += details.delta.dx / totalWidth;
                          _horizontalRatio = _horizontalRatio.clamp(0.35, 0.70);
                        });
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeLeftRight,
                        child: Container(
                          width: 10,
                          color: AppDesignTokens.background,
                          child: Center(
                            child: Container(
                              width: 3,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppDesignTokens.divider,
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Right panel: Event List
                    Expanded(
                      child: _buildEventList(
                        selectedDayEvents: selectedDayEvents,
                        isAdmin: isAdmin,
                        theme: theme,
                      ),
                    ),
                  ],
                );
              } else {
                // 💡 모바일은 달력 전체를 먼저 배치해 마지막 주 날짜가 잘리지 않도록 합니다.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCalendarCard(
                      rowHeight: constraints.maxHeight < 500 ? 34.0 : 38.0,
                      daysOfWeekHeight: 24.0,
                      allEvents: allEvents,
                      theme: theme,
                    ),
                    Expanded(
                      child: _buildEventList(
                        selectedDayEvents: selectedDayEvents,
                        isAdmin: isAdmin,
                        theme: theme,
                      ),
                    ),
                  ],
                );
              }
            },
          );
        },
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              backgroundColor: AppDesignTokens.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onPressed: () => _showAddEditEventDialog(),
              tooltip: '학사 일정 추가',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  // 💡 공지사항 상세 화면으로 네비게이션 처리 (로딩 바 표시 및 데이터 패치 포함)
  void _navigateToNoticeDetail(int noticeId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final notice = await ref.read(noticeNotifierProvider).getNotice(noticeId);
      if (mounted) {
        Navigator.pop(context); // 로딩 팝업 제거
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NoticeDetailScreen(notice: notice)),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('공지사항을 가져오는 데 실패했습니다.')));
      }
    }
  }

  // 💡 일정 삭제 확인 팝업
  void _confirmDelete(int eventId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일정 삭제'),
        content: const Text('선택한 학사 일정을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(calendarNotifierProvider).deleteEvent(eventId);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 💡 학사 일정 신규 등록 및 수정 다이얼로그 (ColorPicker 탑재)
  void _showAddEditEventDialog({CalendarEvent? event}) {
    final titleController = TextEditingController(text: event?.title ?? '');
    final descController = TextEditingController(
      text: event?.description ?? '',
    );

    DateTime start = event != null
        ? DateTime.parse(event.startDate)
        : (_selectedDay ?? DateTime.now());
    DateTime end = event != null
        ? DateTime.parse(event.endDate)
        : (_selectedDay ?? DateTime.now());

    String selectedColor = event?.color ?? '#4A90E2';

    final colorsMap = {
      '파란색': '#4A90E2',
      '빨간색': '#FF5733',
      '보라색': '#8E44AD',
      '주황색': '#F39C12',
      '회색': '#7F8C8D',
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(event == null ? '신규 학사 일정 추가' : '학사 일정 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: '일정명',
                    hintText: '예: 1학기 중간고사',
                  ),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: '상세 설명',
                    hintText: '예: 강의실 시험 공지 참고',
                  ),
                ),
                const SizedBox(height: 16),
                // 날짜 선택기
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: start,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            setDialogState(() {
                              start = date;
                              if (end.isBefore(start)) end = start;
                            });
                          }
                        },
                        child: Text(
                          '시작일:\n${start.year}-${start.month}-${start.day}',
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: end,
                            firstDate: start,
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            setDialogState(() {
                              end = date;
                            });
                          }
                        },
                        child: Text(
                          '종료일:\n${end.year}-${end.month}-${end.day}',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 색상 선택 드롭다운
                DropdownButtonFormField<String>(
                  initialValue: selectedColor,
                  decoration: const InputDecoration(labelText: '구분 색상'),
                  items: colorsMap.entries.map((entry) {
                    final colorValue = Color(
                      int.parse(entry.value.replaceFirst('#', '0xff')),
                    );
                    return DropdownMenuItem<String>(
                      value: entry.value,
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorValue,
                            ),
                          ),
                          Text(entry.key),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedColor = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;

                final startStr =
                    "${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}";
                final endStr =
                    "${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}";

                Navigator.pop(ctx);

                if (event == null) {
                  await ref
                      .read(calendarNotifierProvider)
                      .createEvent(
                        title,
                        descController.text.trim(),
                        startStr,
                        endStr,
                        selectedColor,
                      );
                } else {
                  await ref
                      .read(calendarNotifierProvider)
                      .updateEvent(
                        event.id,
                        title,
                        descController.text.trim(),
                        startStr,
                        endStr,
                        selectedColor,
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
}
