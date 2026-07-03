import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// 💡 [LinkifyText] 텍스트 내 URL을 감지하여 클릭 시 브라우저를 열고 드래그 복사를 지원하는 위젯
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

    final List<TextSpan> spans = [];
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
      spans.add(
        TextSpan(
          text: urlString,
          style: (style ?? const TextStyle()).copyWith(
            color: Colors.blue.shade700,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.bold,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              try {
                final Uri uri = Uri.parse(urlString);
                // 💡 웹/모바일 보안 샌드박스 오동작 우회를 위해 canLaunchUrl 검사 없이 즉시 링크 실행
                await launchUrl(
                  uri,
                  mode: LaunchMode.platformDefault,
                );
              } catch (_) {
                // 예외 처리
              }
            },
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

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }
}
