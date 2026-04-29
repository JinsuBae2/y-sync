import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notice.dart';
import '../models/community_post.dart';
import '../providers/notice_provider.dart'; // contains dioProvider
import '../screens/notice_detail_screen.dart';
import '../screens/community_detail_screen.dart';

// 💡 백그라운드 푸시 알람을 눌렀을 때, targetId만 알고 있는 상태에서 
// 객체를 불러와 DetailScreen으로 넘겨주는 중간 로딩/라우터 화면
class DeepLinkLoadingScreen extends ConsumerStatefulWidget {
  final String targetType;
  final String targetId;

  const DeepLinkLoadingScreen({
    super.key,
    required this.targetType,
    required this.targetId,
  });

  @override
  ConsumerState<DeepLinkLoadingScreen> createState() => _DeepLinkLoadingScreenState();
}

class _DeepLinkLoadingScreenState extends ConsumerState<DeepLinkLoadingScreen> {
  @override
  void initState() {
    super.initState();
    // 화면이 렌더링되자마자 API 호출 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAndNavigate();
    });
  }

  Future<void> _loadAndNavigate() async {
    try {
      final dio = ref.read(dioProvider);
      
      if (widget.targetType == 'NOTICE') {
        final response = await dio.get('/notices/${widget.targetId}');
        final notice = Notice.fromJson(response.data);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => NoticeDetailScreen(notice: notice)),
          );
        }
      } else if (widget.targetType == 'COMMUNITY') {
        final response = await dio.get('/community/${widget.targetId}');
        final post = CommunityPost.fromJson(response.data);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => CommunityDetailScreen(post: post)),
          );
        }
      } else {
         throw Exception("알 수 없는 알림 타입: ${widget.targetType}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제되었거나 불러올 수 없는 게시글입니다.')),
        );
        Navigator.pop(context); // 로딩 화면 닫기 (원래 있던 탭으로 이동)
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF164687)),
            const SizedBox(height: 24),
            Text(
              '해당 게시글로 이동 중입니다...', 
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
