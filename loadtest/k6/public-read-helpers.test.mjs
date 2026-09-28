import test from 'node:test';
import assert from 'node:assert/strict';

import { buildRequestUrl, buildSummary } from './public-read-helpers.mjs';

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
