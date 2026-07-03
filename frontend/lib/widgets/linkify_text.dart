import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

// 💡 [LinkifyText] 텍스트 내 URL을 감지하여 다음 기능을 제공하는 하이브리드 UI/UX 위젯
// 1. 일반 본문 텍스트: 모바일/웹 100% 드래그 선택 및 우클릭 복사 보장 (SelectableText.rich)
// 2. 인라인 링크: 드래그 충돌 없이 원터치 클릭 연결 (WidgetSpan + GestureDetector)
// 3. 인라인 복사 버튼: 링크 주소 바로 뒤에 [📋 복사] 미니 버튼 배치로 단독 복사 지원
// 4. 하단 바로가기 카드: 본문 밑에 큼직한 원클릭 바로가기 아웃라인 카드 동적 노출
class LinkifyText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const LinkifyText({super.key, required this.text, this.style});

  Future<void> _launchURL(BuildContext context, String urlString) async {
    try {
      final Uri uri = Uri.parse(urlString);
      await launchUrl(
        uri,
        mode: LaunchMode.platformDefault, // 💡 웹/모바일 표준 브라우저 기동
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('링크를 열 수 없습니다: $urlString')));
      }
    }
  }

  String _simplifyUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.isNotEmpty
          ? uri.host
          : url; // 도메인 도메인 호스트명만 추출 (예: zoom.us, meet.google.com)
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 💡 URL 패턴 정규식
    final urlRegex = RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);

    final matches = urlRegex.allMatches(text);
    if (matches.isEmpty) {
      return SelectableText(text, style: style);
    }

    final List<InlineSpan> spans = [];
    int lastMatchEnd = 0;
    final List<String> urlList = [];

    for (final match in matches) {
      // 💡 매칭 이전의 일반 텍스트 처리
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: style,
          ),
        );
      }

      final urlString = match.group(0)!;
      urlList.add(urlString);

      // 💡 1. 하이퍼링크 텍스트 영역을 WidgetSpan + GestureDetector 조합으로 이식 (제스처 충돌 원천 해결)
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: () => _launchURL(context, urlString),
            child: Text(
              urlString,
              style: (style ?? const TextStyle()).copyWith(
                color: Colors.blue.shade700,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );

      // 💡 2. 링크 바로 뒤에 아주 작고 깜찍한 [📋 복사] 미니 아이콘 버튼 융합
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: urlString));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('링크 주소가 클립보드에 복사되었습니다.'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Icon(
                Icons.content_copy_rounded,
                size: 14,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ),
      );

      lastMatchEnd = match.end;
    }

    // 💡 마지막 매칭 이후의 잔여 텍스트 처리
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd), style: style));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 본문: 복사와 드래그가 100% 작동하는 영역
        SelectableText.rich(TextSpan(children: spans)),

        // 💡 3. 본문 하단에 감지된 링크들에 대한 큼직한 [🔗 첨부 링크 바로가기] 카드 노출
        if (urlList.isNotEmpty) ...[
          const SizedBox(height: 24),
          ...urlList.map(
            (url) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _launchURL(context, url),
                icon: const Icon(Icons.link_rounded, size: 18),
                label: Text(
                  '첨부 링크 바로가기 (${_simplifyUrl(url)})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
