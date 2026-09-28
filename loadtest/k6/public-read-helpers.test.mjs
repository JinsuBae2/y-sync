import test from 'node:test';
import assert from 'node:assert/strict';

import { buildRequest, buildRequestUrl, buildSummary, buildTestProfile } from './public-read-helpers.mjs';

test('공지 목록 요청은 여러 페이지를 사용한다', () => {
  assert.equal(
    buildRequestUrl('https://api.example.com', 0.1, 0.75, 0),
    'https://api.example.com/api/v1/notices?page=3&size=20&sort=createdAt,desc',
  );
});

test('공지 검색 요청은 여러 검색어를 사용한다', () => {
  assert.equal(
    buildRequestUrl('https://api.example.com', 0.8, 0, 0.6),
    'https://api.example.com/api/v1/notices?keyword=%ED%95%99%EC%82%AC&page=0&size=20',
  );
});

test('부하 테스트 요약은 한국어 제목과 p99를 출력한다', () => {
  const summary = buildSummary({
    metrics: {
      requests_stage_5_vu: { values: { count: 120 } },
      failed_stage_5_vu: { values: { rate: 0.005 } },
      timeout_stage_5_vu: { values: { count: 1 } },
      duration_stage_5_vu: { values: { avg: 101.2, 'p(95)': 202.3, 'p(99)': 303.4 } },
    },
  }, [{ name: 'stage_5_vu', label: '5 VU / 1분', seconds: 60 }]);

  assert.match(summary, /Y-Sync 공개 조회 부하 테스트 결과/);
  assert.match(summary, /단계 \| RPS \| 평균 \| p95 \| p99 \| 실패율 \| 타임아웃/);
  assert.match(summary, /5 VU \/ 1분 \| 2\.00 \| 101\.2 ms \| 202\.3 ms \| 303\.4 ms \| 0\.50% \| 1/);
});

test('지속 부하 프로필은 50 VU를 10분 동안 유지한다', () => {
  assert.deepEqual(buildTestProfile('soak'), [
    { name: 'soak_50_vu', label: '50 VU / 10분 지속', vus: 50, duration: '10m', seconds: 600 },
  ]);
});

test('알 수 없는 프로필은 단계형 테스트를 사용한다', () => {
  assert.equal(buildTestProfile('unknown').at(-1).name, 'stage_50_vu');
});

test('요청은 URL과 지표용 종류를 함께 반환한다', () => {
  assert.deepEqual(
    buildRequest('https://api.example.com', 0.8, 0, 0.6),
    {
      url: 'https://api.example.com/api/v1/notices?keyword=%ED%95%99%EC%82%AC&page=0&size=20',
      type: 'search',
      label: '공지 검색',
    },
  );
});

test('부하 테스트 요약은 요청 종류별 병목 지표를 출력한다', () => {
  const summary = buildSummary({
    metrics: {
      requests_soak_50_vu: { values: { count: 600 } },
      failed_soak_50_vu: { values: { rate: 0.01 } },
      timeout_soak_50_vu: { values: { count: 2 } },
      duration_soak_50_vu: { values: { avg: 100, 'p(95)': 200, 'p(99)': 300 } },
      requests_endpoint_search: { values: { count: 300 } },
      failed_endpoint_search: { values: { rate: 0.02 } },
      timeout_endpoint_search: { values: { count: 3 } },
      duration_endpoint_search: { values: { avg: 150, 'p(95)': 250, 'p(99)': 350 } },
    },
  }, [{ name: 'soak_50_vu', label: '50 VU / 10분 지속', seconds: 600 }], [
    { type: 'search', label: '공지 검색' },
  ]);

  assert.match(summary, /요청 종류별 결과/);
  assert.match(summary, /공지 검색 \| 0\.50 \| 150\.0 ms \| 250\.0 ms \| 350\.0 ms \| 2\.00% \| 3/);
});
