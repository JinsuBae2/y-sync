import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/member.dart';
import '../models/notice_grade_preference.dart';
import '../providers/auth_provider.dart';
import '../providers/notice_grade_prompt_provider.dart';
import '../theme/app_design_tokens.dart';
import 'notice_grade_selector.dart';

/// 💡 학년 확인이 필요한 회원에게 안내를 한 번 보여주는 래퍼입니다.
///
/// 확인 필요 여부와 현재 학년도는 모두 서버가 판정한 값을 사용합니다. 단말기 날짜가 틀려도 결과가
/// 달라지지 않아야 하기 때문입니다. 안내는 로그인 후 회원 정보가 조회된 시점과 앱을 다시 열어
/// 회원 정보가 갱신된 시점에 뜨며, 화면을 이동할 때마다 뜨지는 않습니다.
class NoticeGradePrompt extends ConsumerStatefulWidget {
  const NoticeGradePrompt({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NoticeGradePrompt> createState() => _NoticeGradePromptState();
}

class _NoticeGradePromptState extends ConsumerState<NoticeGradePrompt> {
  bool _isDialogOpen = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Member?>>(authProvider, (_, next) {
      _maybePrompt(next.asData?.value);
    });
    // 이미 회원 정보가 준비된 상태로 이 화면에 들어온 경우에도 안내가 필요할 수 있습니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybePrompt(ref.read(authProvider).asData?.value);
    });

    return widget.child;
  }

  void _maybePrompt(Member? member) {
    if (!mounted || _isDialogOpen || member == null) return;
    if (!member.gradeConfirmationRequired) return;

    // 💡 서버가 학년도를 내려주지 않는 구버전 응답이면 안내하지 않습니다.
    //    단말기 시각으로 학년도를 추측하면 잘못된 시점에 안내가 뜰 수 있습니다.
    final academicYear = member.currentAcademicYear;
    if (academicYear == null) return;

    final prompt = ref.read(noticeGradePromptProvider.notifier);
    if (!prompt.shouldPrompt(academicYear)) return;

    prompt.markPrompted(academicYear);
    _isDialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NoticeGradeDialog(member: member),
    ).whenComplete(() => _isDialogOpen = false);
  }
}

/// 학년 선택·재확인 대화상자입니다. 내 정보의 '알림 대상 변경'에서도 재사용합니다.
class NoticeGradeDialog extends ConsumerStatefulWidget {
  const NoticeGradeDialog({super.key, required this.member});

  final Member member;

  @override
  ConsumerState<NoticeGradeDialog> createState() => _NoticeGradeDialogState();
}

class _NoticeGradeDialogState extends ConsumerState<NoticeGradeDialog> {
  NoticeGradePreference? _selected;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 이전 선택을 참고로 보여줄 뿐, 자동으로 다음 학년을 고르거나 저장하지는 않습니다.
    _selected = widget.member.noticeGradePreference;
  }

  bool get _isFirstSetup => widget.member.noticeGradePreference == null;

  Future<void> _save() async {
    final selected = _selected;
    if (selected == null || _isSaving) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authProvider.notifier)
          .updateNoticeGradePreference(selected);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      // 저장에 실패하면 기존 선택과 확인 학년도를 그대로 두고 재시도를 안내합니다.
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = '저장하지 못했습니다. 연결을 확인하고 다시 시도해 주세요.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final previous = widget.member.noticeGradePreference;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        _isFirstSetup ? '공지 알림을 받을 학년을 선택해 주세요.' : '올해 현재 학년을 확인해 주세요.',
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppDesignTokens.navy,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (previous != null) ...[
              Text(
                '이전 선택: ${previous.label}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.navy.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
            ],
            NoticeGradeSelector(
              selected: _selected,
              enabled: !_isSaving,
              onChanged: (value) => setState(() => _selected = value),
            ),
            const SizedBox(height: 4),
            const NoticeGradeHelperText(),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD1453B),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          // '나중에'를 골라도 앱 사용을 막지 않습니다. 다음 앱 실행이나 로그인 때 다시 안내됩니다.
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('나중에'),
        ),
        FilledButton(
          // 저장 중에는 버튼을 비활성화해 중복 제출을 막습니다.
          onPressed: _selected == null || _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('저장'),
        ),
      ],
    );
  }
}
