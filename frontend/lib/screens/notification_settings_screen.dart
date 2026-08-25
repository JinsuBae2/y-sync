import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/mypage_provider.dart';
import '../providers/notice_provider.dart';
import '../theme/app_design_tokens.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _isLoading = false;
  bool _initialized = false;
  bool _noticeEnabled = true;
  bool _commentEnabled = true;

  @override
  void initState() {
    super.initState();
    final data = ref.read(myPageProvider).asData?.value;
    if (data != null) {
      _noticeEnabled = data.member.noticeEnabled;
      _commentEnabled = data.member.commentEnabled;
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(myPageProvider, (_, next) {
      if (_initialized || !mounted) return;
      next.whenData((data) {
        if (!mounted) return;
        setState(() {
          _noticeEnabled = data.member.noticeEnabled;
          _commentEnabled = data.member.commentEnabled;
          _initialized = true;
        });
      });
    });

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.background,
        foregroundColor: AppDesignTokens.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: const Text(
          '알림 설정',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        bottom: _isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: AppDesignTokens.blue,
                  backgroundColor: AppDesignTokens.paleBlue,
                ),
              )
            : null,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDesignTokens.contentMaxWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const Text(
                '수신할 알림',
                style: TextStyle(
                  color: AppDesignTokens.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                '필요한 소식만 선택해서 받을 수 있습니다.',
                style: TextStyle(color: AppDesignTokens.muted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              _SettingGroup(
                children: [
                  _NotificationToggle(
                    icon: Icons.campaign_outlined,
                    title: '공지사항',
                    subtitle: '학과 공지와 긴급 안내를 받습니다.',
                    value: _noticeEnabled,
                    enabled: !_isLoading,
                    onChanged: (value) =>
                        _updateSettings(value, _commentEnabled),
                  ),
                  _NotificationToggle(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: '댓글',
                    subtitle: '내 게시글에 새 댓글이 달리면 알려줍니다.',
                    value: _commentEnabled,
                    enabled: !_isLoading,
                    onChanged: (value) =>
                        _updateSettings(_noticeEnabled, value),
                  ),
                ],
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.paleBlue.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: AppDesignTokens.blue,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '웹에서는 브라우저 알림 권한도 허용되어 있어야 푸시 알림을 받을 수 있습니다.',
                          style: TextStyle(
                            color: AppDesignTokens.muted,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateSettings(bool noticeEnabled, bool commentEnabled) async {
    setState(() => _isLoading = true);

    try {
      final dio = ref.read(dioProvider);
      await dio.put(
        '/members/settings',
        data: {
          'noticeEnabled': noticeEnabled,
          'commentEnabled': commentEnabled,
        },
      );
      if (!mounted) return;
      setState(() {
        _noticeEnabled = noticeEnabled;
        _commentEnabled = commentEnabled;
      });
      await ref.read(myPageProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('알림 설정을 저장했습니다.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('알림 설정을 저장하지 못했습니다.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _SettingGroup extends StatelessWidget {
  const _SettingGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppDesignTokens.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppDesignTokens.divider),
    ),
    child: Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index < children.length - 1)
            const Divider(
              height: 1,
              indent: 62,
              color: AppDesignTokens.divider,
            ),
        ],
      ],
    ),
  );
}

class _NotificationToggle extends StatelessWidget {
  const _NotificationToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    value: value,
    onChanged: enabled ? onChanged : null,
    activeTrackColor: AppDesignTokens.blue,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
    secondary: Icon(icon, color: AppDesignTokens.navy, size: 22),
    title: Text(
      title,
      style: const TextStyle(
        color: AppDesignTokens.navy,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    ),
    subtitle: Text(
      subtitle,
      style: const TextStyle(
        color: AppDesignTokens.muted,
        fontSize: 12,
        height: 1.4,
      ),
    ),
  );
}
