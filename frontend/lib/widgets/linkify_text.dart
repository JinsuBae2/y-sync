import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 💡 [LinkifyText] 텍스트 내 URL을 감지하여 복사 칩만 깔끔하게 제공하는 컴포넌트
// 1. 일반 본문 텍스트: 모바일/웹 100% 드래그 선택 및 우클릭 복사 보장 (SelectableText.rich)
// 2. 인라인 복사 버튼: 링크 주소 바로 뒤에 [📋 복사] 미니 버튼 배치로 단독 복사 지원 (클릭 이동은 제거하여 팝업 차단 이슈 원천 예방)
class LinkifyText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const LinkifyText({
    super.key,
    required this.text,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    // 💡 URL 패턴 정규식
    final urlRegex = RegExp(
      r'(https?:\/\/[^\s]+)',
      caseSensitive: false,
    );

    final matches = urlRegex.allMatches(text);
    if (matches.isEmpty) {
      return SelectableText(text, style: style);
    }

    final List<InlineSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      // 💡 매칭 이전의 일반 텍스트 처리
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: style,
        ));
      }

      final urlString = match.group(0)!;

      // 💡 1. 하이퍼링크 주소는 클릭 없이 시각적 포인트(밑줄, 블루) 텍스트로만 처리 (제스처 충돌 방지)
      spans.add(
        TextSpan(
          text: urlString,
          style: (style ?? const TextStyle()).copyWith(
            color: Colors.blue.shade700,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      // 💡 2. 링크 바로 뒤에 시인성이 극대화된 [📋 복사] 미니 칩 버튼 융합
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
              padding: const EdgeInsets.only(left: 6, right: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF164687).withOpacity(0.08), // 브랜드 블루 옅은 8% 배경
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: const Color(0xFF164687).withOpacity(0.2), // 테두리 라인
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.content_copy_rounded,
                      size: 10,
                      color: Color(0xFF164687),
                    ),
                    SizedBox(width: 3),
                    Text(
                      '복사',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF164687),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      lastMatchEnd = match.end;
    }

    // 💡 마지막 매칭 이후의 잔여 텍스트 처리
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: style,
      ));
    }

    // 💡 최종적으로 제스처 충돌이 전혀 없는 초경량 SelectableText.rich 리턴
    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }
}
