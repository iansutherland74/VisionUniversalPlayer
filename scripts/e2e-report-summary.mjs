#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';

function usage() {
  console.log('Usage: node ./scripts/e2e-report-summary.mjs <report.json>');
}

const reportArg = process.argv[2];
if (!reportArg) {
  usage();
  process.exit(1);
}

const reportPath = path.isAbsolute(reportArg)
  ? reportArg
  : path.resolve(process.cwd(), reportArg);

if (!fs.existsSync(reportPath)) {
  console.error(`FAIL: report not found: ${reportPath}`);
  process.exit(1);
}

let report;
try {
  report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
} catch (error) {
  const message = error && typeof error === 'object' && 'message' in error
    ? String(error.message)
    : String(error ?? 'unknown parse error');
  console.error(`FAIL: could not parse report JSON (${message})`);
  process.exit(1);
}

const totals = report.totals ?? {};
const missing = report.checklist?.missing ?? [];
const found = report.checklist?.found ?? [];
const schemaIssues = report.schemaIssues ?? [];
const connectError = report.connectError ?? '';

console.log('E2E Session Report Summary');
console.log(`File: ${reportPath}`);
console.log(`Duration(ms): ${report.durationMs ?? 'n/a'}`);
console.log(`Events: ${totals.events ?? 0}`);
console.log(`Categories: ${totals.categories ?? 0}`);
console.log(`Severities: ${totals.severities ?? 0}`);
console.log(`Checklist found: ${found.length}`);
console.log(`Checklist missing: ${missing.length}`);
console.log(`Schema issue events: ${schemaIssues.length}`);
if (connectError) {
  console.log(`Relay connect error: ${connectError}`);
}

if (schemaIssues.length > 0) {
  console.log('Schema issues:');
  for (const issue of schemaIssues) {
    const fields = Array.isArray(issue.missingFields) ? issue.missingFields.join(', ') : 'unknown';
    console.log(`- ${issue.id ?? '(missing-id)'} -> missing: ${fields}`);
  }
}

if (missing.length > 0) {
  console.log('Missing checklist phrases:');
  for (const phrase of missing) {
    console.log(`- ${phrase}`);
  }
}

if ((totals.events ?? 0) > 0 && missing.length === 0 && schemaIssues.length === 0) {
  console.log('STATUS: PASS (full checklist + schema)');
  process.exit(0);
}

if ((totals.events ?? 0) === 0) {
  console.log('STATUS: INCOMPLETE (no captured events)');
  process.exit(2);
}

console.log('STATUS: PARTIAL (events captured, checklist/schema gaps remain)');
process.exit(3);
