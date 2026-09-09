import 'package:flutter/material.dart';
import '../theme/app_design_tokens.dart';
import 'feedback_screen.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _questions = [
    (
      '시간표',
      '학과 시간표와 개인 시간표는 어떻게 다른가요?',
      '학과 시간표는 학년과 반을 선택해 보는 공용 수업표입니다. 개인 시간표는 내가 듣는 수업을 직접 모아 구성하는 나만의 시간표입니다.',
    ),
    (
      '시간표',
      '개인 시간표에 수업을 어떻게 추가하나요?',
      '일정 → 시간표 → 개인 시간표에서 + 버튼을 누르세요. 학과 시간표에서 여러 수업을 선택하거나, 교양·타과 수업을 직접 입력할 수 있습니다. 시간이 겹치는 수업은 함께 등록할 수 없습니다.',
    ),
    (
      '시간표',
      '수업 수정과 주간표 확인은 어떻게 하나요?',
      '개인 시간표의 수업을 누르면 수정하거나 삭제할 수 있습니다. 모바일에서는 요일별 목록과 주간표를 전환할 수 있고, 주간표는 좌우로 움직여 다른 요일을 확인합니다.',
    ),
    (
      '알림·스크랩',
      '알림은 어디서 설정하나요?',
      '내정보 → 알림 설정에서 공지와 댓글 알림을 설정할 수 있습니다. 알림이 오지 않으면 기기와 브라우저의 Y-Sync 알림 권한도 확인해주세요.',
    ),
    (
      '알림·스크랩',
      '저장한 글은 어디서 보나요?',
      '공지나 커뮤니티 글의 북마크 버튼으로 스크랩할 수 있습니다. 저장한 글은 내정보 → 스크랩한 글에서 모아볼 수 있습니다.',
    ),
    (
      '계정',
      '비밀번호를 잊었어요.',
      '로그인 화면에서 비밀번호 재설정을 선택하고 안내에 따라 학번과 이름을 입력해주세요. 인증 후 새 비밀번호를 설정할 수 있습니다.',
    ),
    (
      '의견 보내기',
      '보낸 의견은 다른 사람에게 보이나요?',
      '오류 신고와 개선 제안은 관리자만 확인합니다. 개별 답변이나 처리 상태 조회는 제공하지 않으며, 보내주신 내용은 서비스 개선을 위해 검토합니다.',
    ),
  ];

  static const _categoryIcons = {
    '시간표': Icons.calendar_month_outlined,
    '알림·스크랩': Icons.notifications_none_rounded,
    '계정': Icons.lock_outline_rounded,
    '의견 보내기': Icons.chat_bubble_outline_rounded,
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppDesignTokens.background,
    appBar: AppBar(
      title: const Text('도움말'),
      backgroundColor: AppDesignTokens.background,
      foregroundColor: AppDesignTokens.navy,
      surfaceTintColor: Colors.transparent,
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppDesignTokens.navy,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💡', style: TextStyle(fontSize: 28)),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Y-Sync 사용이 궁금한가요?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '자주 묻는 질문에서 기능별 사용법을 빠르게 확인하세요.',
                          style: TextStyle(
                            color: Color(0xFFD7E2F4),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              '자주 묻는 질문',
              style: TextStyle(
                color: AppDesignTokens.navy,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '항목을 누르면 답변을 확인할 수 있어요.',
              style: TextStyle(color: AppDesignTokens.muted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            for (final category in ['시간표', '알림·스크랩', '계정', '의견 보내기']) ...[
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppDesignTokens.paleBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _categoryIcons[category],
                      size: 18,
                      color: AppDesignTokens.blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppDesignTokens.navy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppDesignTokens.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppDesignTokens.divider),
                ),
                child: Column(
                  children: [
                    for (final indexed
                        in _questions.where((q) => q.$1 == category).indexed)
                      Column(
                        children: [
                          if (indexed.$1 > 0)
                            const Divider(
                              height: 1,
                              color: AppDesignTokens.divider,
                            ),
                          ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            iconColor: AppDesignTokens.blue,
                            collapsedIconColor: AppDesignTokens.subtle,
                            title: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Q${indexed.$1 + 1}',
                                  style: const TextStyle(
                                    color: AppDesignTokens.blue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    indexed.$2.$2,
                                    style: const TextStyle(
                                      color: AppDesignTokens.navy,
                                      fontSize: 14,
                                      height: 1.4,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              16,
                            ),
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppDesignTokens.background,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    indexed.$2.$3,
                                    style: const TextStyle(
                                      height: 1.6,
                                      fontSize: 13,
                                      color: AppDesignTokens.muted,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
            ],
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppDesignTokens.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppDesignTokens.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '원하는 답변을 찾지 못했나요?',
                    style: TextStyle(
                      color: AppDesignTokens.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '발견한 오류나 개선 아이디어를 관리자에게 보내주세요.',
                    style: TextStyle(
                      color: AppDesignTokens.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FeedbackScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.send_outlined, size: 18),
                      label: const Text('오류 신고·개선 제안 보내기'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
