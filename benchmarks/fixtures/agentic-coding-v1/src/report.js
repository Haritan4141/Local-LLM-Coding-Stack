'use strict';

const { parseDuration, formatDuration } = require('./duration');

function summarizeDurations(values) {
  const totalSeconds = values.reduce((sum, value) => sum + parseDuration(value), 0);
  return {
    count: values.length,
    totalSeconds,
    formatted: formatDuration(totalSeconds),
  };
}

module.exports = { summarizeDurations };
