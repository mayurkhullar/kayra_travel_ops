const crypto = require('crypto');

function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function intBetween(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function chance(probability) {
  return Math.random() < probability;
}

function shuffle(arr) {
  const copy = [...arr];
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

function sample(arr, count) {
  return shuffle(arr).slice(0, Math.min(count, arr.length));
}

function addDays(date, days) {
  const d = new Date(date);
  d.setUTCDate(d.getUTCDate() + days);
  return d;
}

function addHours(date, hours) {
  const d = new Date(date);
  d.setUTCHours(d.getUTCHours() + hours);
  return d;
}

function isoDate(date) {
  return new Date(date).toISOString().slice(0, 10);
}

function makeId(prefix) {
  return `${prefix}_${crypto.randomBytes(4).toString('hex')}`;
}

function calcAgeAtDate(dob, referenceDate) {
  const birth = new Date(dob);
  const ref = new Date(referenceDate);
  let age = ref.getUTCFullYear() - birth.getUTCFullYear();
  const monthDiff = ref.getUTCMonth() - birth.getUTCMonth();
  const dayDiff = ref.getUTCDate() - birth.getUTCDate();
  if (monthDiff < 0 || (monthDiff === 0 && dayDiff < 0)) {
    age -= 1;
  }
  return age;
}

function ageCategoryFor(age) {
  if (age < 2) return 'infant';
  if (age < 12) return 'child';
  return 'adult';
}

function uniqueEmail(name, suffix = '') {
  const normalized = name.toLowerCase().replace(/[^a-z]+/g, '.').replace(/(^\.|\.$)/g, '');
  const token = crypto.randomBytes(2).toString('hex');
  return `${normalized}${suffix ? `.${suffix}` : ''}.${token}@example.com`;
}

function phone() {
  return `+91${intBetween(7000000000, 9999999999)}`;
}

module.exports = {
  pick,
  intBetween,
  chance,
  shuffle,
  sample,
  addDays,
  addHours,
  isoDate,
  makeId,
  calcAgeAtDate,
  ageCategoryFor,
  uniqueEmail,
  phone,
};
