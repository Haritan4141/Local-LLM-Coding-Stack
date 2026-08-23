'use strict';

function parseDuration(input) {
  if (typeof input !== 'string') {
    throw new TypeError('duration must be a string');
  }

  const match = /^(\d+)([hms])$/.exec(input.trim());
  if (!match) {
    throw new Error('invalid duration');
  }

  const value = Number(match[1]);
  const multiplier = match[2] === 'h' ? 3600 : match[2] === 'm' ? 60 : 1;
  const total = value * multiplier;
  if (total <= 0) {
    throw new Error('duration must be positive');
  }
  return total;
}

function formatDuration(totalSeconds) {
  if (!Number.isInteger(totalSeconds) || totalSeconds <= 0) {
    throw new Error('seconds must be a positive integer');
  }

  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return [hours && `${hours}h`, minutes && `${minutes}m`, seconds && `${seconds}s`]
    .filter(Boolean)
    .join('');
}

module.exports = { parseDuration, formatDuration };
