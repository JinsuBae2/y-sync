import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../providers/mypage_provider.dart';
import '../providers/notice_provider.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _isLoading = false;
  bool _noticeEnabled = true;
  bool _commentEnabled = true;

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  void _initSettings() {
    // 💡 마이페이지 프로바이더의 현재 회원 정보에서 기존 설정을 로드합니다.
    final myPageState = ref.read(myPageProvider);
    myPageState.whenData((data) {
      setState(() {
        _noticeEnabled = data.member.noticeEnabled;
        _commentEnabled = data.member.commentEnabled;
      });
    });
  }

  Future<void> _updateSettings(bool noticeEnabled, bool commentEnabled) async {
    setState(() => _isLoading = true);

    try {
      final dio = ref.read(dioProvider);
      
      // 1. 백엔드 설정 저장
      await dio.put('/members/settings', data: {
        'noticeEnabled': noticeEnabled,
        'commentEnabled': commentEnabled,
      });

      // 2. 모바일 환경의 경우 FCM 토픽 구독 동적 제어
      if (!kIsWeb) {
        if (noticeEnabled) {
          await FirebaseMessaging.instance.subscribeToTopic('all');
        } else {
          await FirebaseMessaging.instance.unsubscribeFromTopic('all');
        }
      }

      setState(() {
        _noticeEnabled = noticeEnabled;
        _commentEnabled = commentEnabled;
      });

      // 3. 마이페이지 로컬 캐시 갱신
      await ref.read(myPageProvider.notifier).refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('알림 설정이 변경되었습니다.'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('설정 저장 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          '알림 설정',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Text(
                  '알림 수신 동의 설정',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text(
                          '공지사항 알림',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: const Text(
                          '학부 공식 공지사항 및 긴급 안내 푸시 알림을 수신합니다.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        secondary: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.campaign_rounded,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        value: _noticeEnabled,
                        onChanged: _isLoading
                            ? null
                            : (val) => _updateSettings(val, _commentEnabled),
                        activeColor: const Color(0xFF164687),
                      ),
                      const Divider(height: 1, indent: 70),
                      SwitchListTile(
                        title: const Text(
                          '댓글 알림',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: const Text(
                          '내가 작성한 게시글에 새 댓글이 달리면 알림을 수신합니다.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        secondary: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.comment_rounded,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        value: _commentEnabled,
                        onChanged: _isLoading
                            ? null
                            : (val) => _updateSettings(_noticeEnabled, val),
                        activeColor: const Color(0xFF164687),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (kIsWeb)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '웹 환경에서는 브라우저 자체의 푸시 알림 권한 상태가 켜져 있어야 알림 수신이 정상 작동합니다.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.15),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
