import http from 'k6/http';
import { check, sleep } from 'k6';
import exec from 'k6/execution';
import { Counter, Rate, Trend } from 'k6/metrics';
import { buildRequestUrl, buildSummary } from './public-read-helpers.mjs';

const stages = [
  { name: 'stage_5_vu', label: '5 VU / 1분', vus: 5, duration: '1m', seconds: 60 },
  { name: 'stage_10_vu', label: '10 VU / 2분', vus: 10, duration: '2m', seconds: 120 },
  { name: 'stage_20_vu', label: '20 VU / 2분', vus: 20, duration: '2m', seconds: 120 },
  { name: 'stage_30_vu', label: '30 VU / 2분', vus: 30, duration: '2m', seconds: 120 },
  { name: 'stage_50_vu', label: '50 VU / 2분', vus: 50, duration: '2m', seconds: 120 },
];

const stageMetrics = Object.fromEntries(
  stages.map((stage) => [stage.name, {
    requests: new Counter(`requests_${stage.name}`),
    failed: new Rate(`failed_${stage.name}`),
    timeout: new Counter(`timeout_${stage.name}`),
    duration: new Trend(`duration_${stage.name}`, true),
  }]),
);

export const options = {
  summaryTrendStats: ['avg', 'p(95)', 'p(99)'],
  scenarios: Object.fromEntries(
    stages.map((stage, index) => [stage.name, {
      executor: 'constant-vus',
      vus: stage.vus,
      duration: stage.duration,
      startTime: `${stages.slice(0, index).reduce((total, item) => total + item.seconds, 0)}s`,
      tags: { load_stage: stage.name },
    }]),
  ),
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<1000'],
  },
};

function baseUrl() {
  const value = (__ENV.BASE_URL || '').replace(/\/$/, '');
  if (!value) {
    throw new Error('BASE_URL must be provided.');
  }
  return value;
}

function requestForUser(url) {
  return buildRequestUrl(url, Math.random(), Math.random(), Math.random());
}

export default function () {
  const stageName = exec.scenario.name;
  const metrics = stageMetrics[stageName];
  const response = http.get(requestForUser(baseUrl()), { timeout: '10s' });
  const ok = check(response, {
    '공개 조회 API가 2xx를 반환함': (res) => res.status >= 200 && res.status < 300,
  });

  metrics.requests.add(1);
  metrics.failed.add(!ok);
  metrics.duration.add(response.timings.duration);
  if (response.status === 0 || response.error_code) {
    metrics.timeout.add(1);
  }

  // Keep a modest think time so the test approximates browsing rather than a tight loop.
  sleep(0.5);
}

export function handleSummary(data) {
  return { stdout: buildSummary(data, stages) };
}
