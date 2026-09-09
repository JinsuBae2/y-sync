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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppDesignTokens.background,
    appBar: AppBar(title: const Text('도움말 및 의견 보내기')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '무엇이 궁금하신가요?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppDesignTokens.navy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '자주 묻는 질문에서 Y-Sync 사용법을 확인하세요.',
              style: TextStyle(color: AppDesignTokens.muted),
            ),
            const SizedBox(height: 24),
            for (final category in ['시간표', '알림·스크랩', '계정', '의견 보내기']) ...[
              Text(
                category,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppDesignTokens.navy,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final question in _questions.where(
                      (q) => q.$1 == category,
                    ))
                      ExpansionTile(
                        title: Text(question.$2),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              question.$3,
                              style: const TextStyle(
                                height: 1.6,
                                color: AppDesignTokens.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            const Text(
              '해결되지 않았거나 좋은 아이디어가 있나요?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FeedbackScreen()),
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('오류 신고·개선 제안 보내기'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}
