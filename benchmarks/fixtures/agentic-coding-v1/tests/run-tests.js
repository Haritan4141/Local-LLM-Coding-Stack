'use strict';

const assert = require('node:assert/strict');
const { parseDuration, formatDuration } = require('../src/duration');
const { summarizeDurations } = require('../src/report');

const tests = [
  ['single unit', () => assert.equal(parseDuration('45s'), 45)],
  ['compound hours/minutes', () => assert.equal(parseDuration('1h30m'), 5400)],
  ['compound minutes/seconds', () => assert.equal(parseDuration('2m15s'), 135)],
  ['all units', () => assert.equal(parseDuration('1h2m3s'), 3723)],
  ['format without duplicate minutes', () => assert.equal(formatDuration(3661), '1h1m1s')],
  ['summary across files', () => assert.deepEqual(summarizeDurations(['1h', '30m', '15s']), {
    count: 3,
    totalSeconds: 5415,
    formatted: '1h30m15s',
  })],
  ['reject wrong unit order', () => assert.throws(() => parseDuration('30m1h'))],
  ['reject duplicate unit', () => assert.throws(() => parseDuration('1h2h'))],
  ['reject empty', () => assert.throws(() => parseDuration(''))],
  ['reject zero total', () => assert.throws(() => parseDuration('0s'))],
];

let passed = 0;
for (const [name, test] of tests) {
  try {
    test();
    passed += 1;
    console.log(`PASS ${name}`);
  } catch (error) {
    console.error(`FAIL ${name}: ${error.message}`);
  }
}

console.log(`${passed}/${tests.length} tests passed`);
if (passed !== tests.length) {
  process.exitCode = 1;
}
