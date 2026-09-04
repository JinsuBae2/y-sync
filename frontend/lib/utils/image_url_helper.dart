import '../config/api_config.dart';

/// 💡 이미지 서버 주소와 로컬호스트 주소를 비교하여 모바일 및 웹에서 이미지가 정상 로드되도록
/// 이미지 URL 경로를 클린하게 정제해주는 공용 헬퍼 함수입니다.
String getCleanImageUrl(String url) {
  final cleanImageBase = imageBaseUrl
      .replaceAll('http://', '')
      .replaceAll('https://', '');
  return url.startsWith('/')
      ? '$imageBaseUrl$url'
      : url
            .replaceAll('localhost:8080', cleanImageBase)
            .replaceAll('localhost', cleanImageBase);
}
