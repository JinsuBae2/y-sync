const searchKeywords = ['공지', '장학', '학사', '행사'];
const noticePageCount = 4;

const stagedProfile = [
  { name: 'stage_5_vu', label: '5 VU / 1분', vus: 5, duration: '1m', seconds: 60 },
  { name: 'stage_10_vu', label: '10 VU / 2분', vus: 10, duration: '2m', seconds: 120 },
  { name: 'stage_20_vu', label: '20 VU / 2분', vus: 20, duration: '2m', seconds: 120 },
  { name: 'stage_30_vu', label: '30 VU / 2분', vus: 30, duration: '2m', seconds: 120 },
  { name: 'stage_50_vu', label: '50 VU / 2분', vus: 50, duration: '2m', seconds: 120 },
];

const soakProfile = [
  { name: 'soak_50_vu', label: '50 VU / 10분 지속', vus: 50, duration: '10m', seconds: 600 },
];

export const endpointTypes = [
  { type: 'list', label: '공지 목록' },
  { type: 'search', label: '공지 검색' },
  { type: 'health', label: '상태 확인' },
];

export const transportPhases = [
  { metric: 'transport_blocked', label: '연결 대기' },
  { metric: 'transport_connecting', label: 'TCP 연결' },
  { metric: 'transport_tls_handshaking', label: 'TLS 협상' },
  { metric: 'transport_waiting', label: '서버 응답 대기' },
  { metric: 'transport_receiving', label: '응답 수신' },
];

export function buildTestProfile(profile) {
  return profile === 'soak' ? soakProfile : stagedProfile;
}

export function buildRequest(baseUrl, requestRoll, pageRoll, keywordRoll) {
  if (requestRoll < 0.65) {
    const page = Math.floor(pageRoll * noticePageCount);
    return {
      url: `${baseUrl}/api/v1/notices?page=${page}&size=20&sort=createdAt,desc`,
      type: 'list',
      label: '공지 목록',
    };
  }
  if (requestRoll < 0.95) {
    const keyword = searchKeywords[Math.floor(keywordRoll * searchKeywords.length)];
    return {
      url: `${baseUrl}/api/v1/notices?keyword=${encodeURIComponent(keyword)}&page=0&size=20`,
      type: 'search',
      label: '공지 검색',
    };
  }
  return { url: `${baseUrl}/api/v1/hello`, type: 'health', label: '상태 확인' };
}

export function buildRequestUrl(baseUrl, requestRoll, pageRoll, keywordRoll) {
  return buildRequest(baseUrl, requestRoll, pageRoll, keywordRoll).url;
}

function value(data, metricName, key) {
  return data.metrics[metricName]?.values?.[key] ?? 0;
}

function formatMs(number) {
  return `${number.toFixed(1)} ms`;
}

export function buildSummary(data, stages, endpoints = endpointTypes) {
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

  lines.push(
    '',
    '요청 종류별 결과',
    '',
    '요청 | RPS | 평균 | p95 | p99 | 실패율 | 타임아웃',
    '--- | ---: | ---: | ---: | ---: | ---: | ---:',
  );

  const totalSeconds = stages.reduce((total, stage) => total + stage.seconds, 0);
  for (const endpoint of endpoints) {
    const requests = value(data, `requests_endpoint_${endpoint.type}`, 'count');
    const failedRate = value(data, `failed_endpoint_${endpoint.type}`, 'rate');
    const timeoutCount = value(data, `timeout_endpoint_${endpoint.type}`, 'count');
    lines.push(
      `${endpoint.label} | ${(requests / totalSeconds).toFixed(2)} | ` +
      `${formatMs(value(data, `duration_endpoint_${endpoint.type}`, 'avg'))} | ` +
      `${formatMs(value(data, `duration_endpoint_${endpoint.type}`, 'p(95)'))} | ` +
      `${formatMs(value(data, `duration_endpoint_${endpoint.type}`, 'p(99)'))} | ` +
      `${(failedRate * 100).toFixed(2)}% | ${timeoutCount}`,
    );
  }

  lines.push(
    '',
    '전송 단계별 지연',
    '',
    '단계 | 평균 | p95 | p99',
    '--- | ---: | ---: | ---:',
  );

  for (const phase of transportPhases) {
    lines.push(
      `${phase.label} | ${formatMs(value(data, phase.metric, 'avg'))} | ` +
      `${formatMs(value(data, phase.metric, 'p(95)'))} | ` +
      `${formatMs(value(data, phase.metric, 'p(99)'))}`,
    );
  }

  lines.push('', '타임아웃은 k6가 상태 코드 0 또는 전송 오류를 보고한 요청입니다.');
  return `${lines.join('\n')}\n`;
}
