import http from 'k6/http';
import { check, sleep } from 'k6';
import exec from 'k6/execution';
import { Counter, Rate, Trend } from 'k6/metrics';
import {
  buildRequest,
  buildSummary,
  buildTestProfile,
  endpointTypes,
  transportPhases,
} from './public-read-helpers.mjs';

const stages = buildTestProfile(__ENV.TEST_PROFILE);

const stageMetrics = Object.fromEntries(
  stages.map((stage) => [stage.name, {
    requests: new Counter(`requests_${stage.name}`),
    failed: new Rate(`failed_${stage.name}`),
    timeout: new Counter(`timeout_${stage.name}`),
    duration: new Trend(`duration_${stage.name}`, true),
  }]),
);

const endpointMetrics = Object.fromEntries(
  endpointTypes.map((endpoint) => [endpoint.type, {
    requests: new Counter(`requests_endpoint_${endpoint.type}`),
    failed: new Rate(`failed_endpoint_${endpoint.type}`),
    timeout: new Counter(`timeout_endpoint_${endpoint.type}`),
    duration: new Trend(`duration_endpoint_${endpoint.type}`, true),
  }]),
);

const transportMetrics = Object.fromEntries(
  transportPhases.map((phase) => [phase.metric, new Trend(phase.metric, true)]),
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
    http_req_failed: [
      'rate<0.01',
      { threshold: 'rate<0.05', abortOnFail: true, delayAbortEval: '1m' },
    ],
    http_req_duration: [
      'p(95)<1000',
      { threshold: 'p(95)<3000', abortOnFail: true, delayAbortEval: '1m' },
    ],
  },
};

function baseUrl() {
  const value = (__ENV.BASE_URL || '').replace(/\/$/, '');
  if (!value) {
    throw new Error('BASE_URL must be provided.');
  }
  return value;
}

export default function () {
  const stageName = exec.scenario.name;
  const metrics = stageMetrics[stageName];
  const request = buildRequest(baseUrl(), Math.random(), Math.random(), Math.random());
  const endpoint = endpointMetrics[request.type];
  const response = http.get(request.url, { timeout: '10s', tags: { endpoint_type: request.type } });
  const ok = check(response, {
    '공개 조회 API가 2xx를 반환함': (res) => res.status >= 200 && res.status < 300,
  });

  metrics.requests.add(1);
  metrics.failed.add(!ok);
  metrics.duration.add(response.timings.duration);
  endpoint.requests.add(1);
  endpoint.failed.add(!ok);
  endpoint.duration.add(response.timings.duration);
  transportMetrics.transport_blocked.add(response.timings.blocked);
  transportMetrics.transport_connecting.add(response.timings.connecting);
  transportMetrics.transport_tls_handshaking.add(response.timings.tls_handshaking);
  transportMetrics.transport_waiting.add(response.timings.waiting);
  transportMetrics.transport_receiving.add(response.timings.receiving);
  if (response.status === 0 || response.error_code) {
    metrics.timeout.add(1);
    endpoint.timeout.add(1);
  }

  // Keep a modest think time so the test approximates browsing rather than a tight loop.
  sleep(0.5);
}

export function handleSummary(data) {
  return { stdout: buildSummary(data, stages, endpointTypes) };
}
