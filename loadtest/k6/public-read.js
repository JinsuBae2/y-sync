import http from 'k6/http';
import { check, sleep } from 'k6';
import exec from 'k6/execution';
import { Counter, Rate, Trend } from 'k6/metrics';

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
  // Notices/search carry almost all traffic; hello is only a low-volume probe.
  const roll = Math.random();
  if (roll < 0.65) {
    return `${url}/api/v1/notices?page=0&size=20&sort=createdAt,desc`;
  }
  if (roll < 0.95) {
    return `${url}/api/v1/notices/search?keyword=%EA%B3%B5%EC%A7%80`;
  }
  return `${url}/api/v1/hello`;
}

export default function () {
  const stageName = exec.scenario.name;
  const metrics = stageMetrics[stageName];
  const response = http.get(requestForUser(baseUrl()), { timeout: '10s' });
  const ok = check(response, {
    'public GET returns 2xx': (res) => res.status >= 200 && res.status < 300,
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

function value(data, metricName, key) {
  return data.metrics[metricName]?.values?.[key] ?? 0;
}

function formatMs(number) {
  return `${number.toFixed(1)} ms`;
}

export function handleSummary(data) {
  const lines = [
    '',
    'Y-Sync public GET load-test summary',
    'Thresholds: http_req_failed < 1%, http_req_duration p(95) < 1000ms',
    '',
    'Stage | RPS | avg | p95 | p99 | failed | timeout',
    '--- | ---: | ---: | ---: | ---: | ---: | ---:',
  ];

  for (const stage of stages) {
    const prefix = `${stage.name}`;
    const requests = value(data, `requests_${prefix}`, 'count');
    const failedRate = value(data, `failed_${prefix}`, 'rate');
    const timeoutCount = value(data, `timeout_${prefix}`, 'count');
    lines.push(
      `${stage.label} | ${(requests / stage.seconds).toFixed(2)} | ` +
      `${formatMs(value(data, `duration_${prefix}`, 'avg'))} | ` +
      `${formatMs(value(data, `duration_${prefix}`, 'p(95)'))} | ` +
      `${formatMs(value(data, `duration_${prefix}`, 'p(99)'))} | ` +
      `${(failedRate * 100).toFixed(2)}% | ${timeoutCount}`,
    );
  }

  lines.push('', 'A timeout is counted when k6 reports status 0 or a transport error.');
  return { stdout: `${lines.join('\n')}\n` };
}
