// 조사 단계에서 쓰던 임시 진단 기록을 지웁니다.
// 💡 인라인 스크립트로 두면 CSP에서 해시나 nonce가 필요해집니다. 해시는 공백 한 칸만 바뀌어도
//    깨지므로, 별도 파일로 두어 'self'만으로 허용되게 합니다.
(() => {
  try {
    sessionStorage.removeItem('ysync.swipe.enabled');
    sessionStorage.removeItem('ysync.swipe.events');
  } catch (_) { /* 저장소 접근이 막힌 환경에서도 부팅을 막지 않습니다. */ }
})();
