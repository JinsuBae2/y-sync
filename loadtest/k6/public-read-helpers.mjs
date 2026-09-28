const searchKeywords = ['공지', '장학', '학사', '행사'];
const noticePageCount = 4;

export function buildRequestUrl(baseUrl, requestRoll, pageRoll, keywordRoll) {
  if (requestRoll < 0.65) {
    const page = Math.floor(pageRoll * noticePageCount);
    return `${baseUrl}/api/v1/notices?page=${page}&size=20&sort=createdAt,desc`;
  }
  if (requestRoll < 0.95) {
    const keyword = searchKeywords[Math.floor(keywordRoll * searchKeywords.length)];
    return `${baseUrl}/api/v1/notices?keyword=${encodeURIComponent(keyword)}&page=0&size=20`;
  }
  return `${baseUrl}/api/v1/hello`;
}

function value(data, metricName, key) {
  return data.metrics[metricName]?.values?.[key] ?? 0;
}

function formatMs(number) {
  return `${number.toFixed(1)} ms`;
}

export function buildSummary(data, stages) {
  const lines = [
    '',
    'Y-Sync 공개 조회 부하 테스트 결과',
    '통과 기준: HTTP 실패율 1% 미만, 응답시간 p95 1000ms 미만',
    '',
    '단계 | RPS | 평균 | p95 | p99 | 실패율 | 타임아웃',
    '--- | ---: | ---: | ---: | ---: | ---: | ---:',
  ];

  for (const stage of stages) {
    const requests = value(data, `requests_${stage.name}`, 'count');
    const failedRate = value(data, `failed_${stage.name}`, 'rate');
    const timeoutCount = value(data, `timeout_${stage.name}`, 'count');
    lines.push(
      `${stage.label} | ${(requests / stage.seconds).toFixed(2)} | ` +
      `${formatMs(value(data, `duration_${stage.name}`, 'avg'))} | ` +
      `${formatMs(value(data, `duration_${stage.name}`, 'p(95)'))} | ` +
      `${formatMs(value(data, `duration_${stage.name}`, 'p(99)'))} | ` +
      `${(failedRate * 100).toFixed(2)}% | ${timeoutCount}`,
    );
  }

  lines.push('', '타임아웃은 k6가 상태 코드 0 또는 전송 오류를 보고한 요청입니다.');
  return `${lines.join('\n')}\n`;
}
