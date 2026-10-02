import 'package:flutter/material.dart';

import '../models/notice_grade_preference.dart';
import '../theme/app_design_tokens.dart';

/// 💡 공지 알림 수신 대상을 고르는 공통 선택 목록입니다.
///
/// 가입 화면, 첫 설정·재확인 안내, 내 정보에서 같은 선택지를 같은 문구로 보여주기 위해 한 곳에 둡니다.
class NoticeGradeSelector extends StatelessWidget {
  const NoticeGradeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final NoticeGradePreference? selected;
  final ValueChanged<NoticeGradePreference> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: NoticeGradePreference.values.map((preference) {
        final isSelected = selected == preference;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: enabled ? () => onChanged(preference) : null,
            borderRadius: BorderRadius.circular(12),
            child: Semantics(
              selected: isSelected,
              button: true,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppDesignTokens.blue.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppDesignTokens.blue
                        : AppDesignTokens.navy.withValues(alpha: 0.15),
                    width: isSelected ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: isSelected
                          ? AppDesignTokens.blue
                          : AppDesignTokens.navy.withValues(alpha: 0.35),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        preference.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: AppDesignTokens.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 💡 '전체 공지만 받기'가 모든 학년 공지를 받는다는 뜻으로 오해되지 않도록 함께 쓰는 설명입니다.
class NoticeGradeHelperText extends StatelessWidget {
  const NoticeGradeHelperText({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      '전체 공지와 선택한 학년의 공지 알림을 받습니다. '
      "'전체 공지만 받기'를 고르면 학년 공지 알림은 받지 않습니다. "
      '다른 학년 공지도 목록에서 찾아 읽을 수 있습니다.',
      style: TextStyle(
        fontSize: 12.5,
        height: 1.45,
        color: AppDesignTokens.navy.withValues(alpha: 0.6),
      ),
    );
  }
}
