/**
 * Report generator for test battery results.
 *
 * Produces both a machine-readable JSON file and a human-readable
 * markdown summary with pass/fail rates by distortion type.
 */

import fs from 'fs';
import path from 'path';

const RESULTS_DIR = new URL('../results/', import.meta.url).pathname;

/**
 * Collect results during the test run.
 * Singleton accumulator — tests push results here, then generateReport()
 * processes everything at the end.
 */
const allResults = [];

/**
 * Record a single detection result.
 */
export function recordResult({
  imageName,
  message,
  strength,
  distortionName,
  detected,
  detectedMessage,
  confidence,
  baselineConfidence,
  error,
}) {
  allResults.push({
    imageName,
    message,
    strength,
    distortionName,
    detected: detected || false,
    detectedMessage: detectedMessage || null,
    confidence: confidence || 0,
    baselineConfidence: baselineConfidence || null,
    pass: detected && detectedMessage === message,
    error: error || null,
  });
}

/**
 * Compute summary statistics from collected results.
 */
function computeSummary(results) {
  const total = results.length;
  const passed = results.filter((r) => r.pass).length;
  const failed = total - passed;
  const errored = results.filter((r) => r.error).length;

  // Group by distortion
  const byDistortion = {};
  for (const r of results) {
    if (!byDistortion[r.distortionName]) {
      byDistortion[r.distortionName] = { passed: 0, failed: 0, total: 0, avgConfidence: 0, confidences: [] };
    }
    const d = byDistortion[r.distortionName];
    d.total++;
    if (r.pass) d.passed++;
    else d.failed++;
    if (r.confidence > 0) d.confidences.push(r.confidence);
  }

  // Calculate average confidence per distortion
  for (const d of Object.values(byDistortion)) {
    d.avgConfidence =
      d.confidences.length > 0
        ? d.confidences.reduce((a, b) => a + b, 0) / d.confidences.length
        : 0;
    delete d.confidences; // Don't include raw array in summary
  }

  // Group by strength
  const byStrength = {};
  for (const r of results) {
    if (!byStrength[r.strength]) {
      byStrength[r.strength] = { passed: 0, total: 0 };
    }
    byStrength[r.strength].total++;
    if (r.pass) byStrength[r.strength].passed++;
  }

  return {
    total,
    passed,
    failed,
    errored,
    passRate: total > 0 ? passed / total : 0,
    byDistortion,
    byStrength,
  };
}

/**
 * Generate a markdown summary table.
 */
function generateMarkdown(summary, config) {
  const lines = [];
  lines.push('# Watermark Robustness Test Report');
  lines.push('');
  lines.push(`**Date**: ${new Date().toISOString()}`);
  lines.push(`**Mode**: ${process.env.TEST_MODE || 'fast'}`);
  lines.push(`**Image size**: ${config.imageSize}x${config.imageSize}`);
  lines.push(`**Threshold**: ${config.threshold}`);
  lines.push('');
  lines.push(`## Overall: ${summary.passed}/${summary.total} passed (${(summary.passRate * 100).toFixed(1)}%)`);
  lines.push('');

  // Distortion results table
  lines.push('## Results by Distortion');
  lines.push('');
  lines.push('| Distortion | Passed | Failed | Total | Pass Rate | Avg Confidence |');
  lines.push('|------------|--------|--------|-------|-----------|----------------|');

  const sorted = Object.entries(summary.byDistortion).sort(
    ([, a], [, b]) => b.passed / b.total - a.passed / a.total,
  );

  for (const [name, d] of sorted) {
    const rate = ((d.passed / d.total) * 100).toFixed(0);
    const conf = d.avgConfidence.toFixed(1);
    const status = d.passed === d.total ? 'PASS' : d.passed === 0 ? 'FAIL' : 'PARTIAL';
    lines.push(
      `| ${name} | ${d.passed} | ${d.failed} | ${d.total} | ${rate}% ${status} | ${conf} |`,
    );
  }

  // Strength results table
  lines.push('');
  lines.push('## Results by Strength');
  lines.push('');
  lines.push('| Strength | Passed | Total | Pass Rate |');
  lines.push('|----------|--------|-------|-----------|');

  for (const [strength, s] of Object.entries(summary.byStrength).sort(
    ([a], [b]) => Number(a) - Number(b),
  )) {
    const rate = ((s.passed / s.total) * 100).toFixed(0);
    lines.push(`| ${strength} | ${s.passed} | ${s.total} | ${rate}% |`);
  }

  return lines.join('\n');
}

/**
 * Generate and save the test report.
 * Call this in afterAll() after all tests have run.
 */
export function generateReport(config) {
  if (allResults.length === 0) {
    console.log('No results to report.');
    return;
  }

  // Ensure results directory exists
  if (!fs.existsSync(RESULTS_DIR)) {
    fs.mkdirSync(RESULTS_DIR, { recursive: true });
  }

  const summary = computeSummary(allResults);
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');

  // Write JSON report
  const jsonPath = path.join(RESULTS_DIR, `report-${timestamp}.json`);
  const jsonReport = {
    timestamp: new Date().toISOString(),
    config: {
      imageSize: config.imageSize,
      threshold: config.threshold,
      mode: process.env.TEST_MODE || 'fast',
    },
    summary,
    results: allResults,
  };
  fs.writeFileSync(jsonPath, JSON.stringify(jsonReport, null, 2));

  // Write markdown report
  const mdPath = path.join(RESULTS_DIR, `report-${timestamp}.md`);
  fs.writeFileSync(mdPath, generateMarkdown(summary, config));

  // Console summary
  console.log('\n' + '='.repeat(60));
  console.log(`ROBUSTNESS TEST REPORT: ${summary.passed}/${summary.total} passed (${(summary.passRate * 100).toFixed(1)}%)`);
  console.log('='.repeat(60));
  console.log(`  JSON: ${jsonPath}`);
  console.log(`  Markdown: ${mdPath}`);
  if (summary.errored > 0) {
    console.log(`  Errors: ${summary.errored}`);
  }
  console.log('');

  return { jsonPath, mdPath, summary };
}

/**
 * Get all collected results (for testing the report module itself).
 */
export function getCollectedResults() {
  return [...allResults];
}

/**
 * Clear collected results (useful between test runs).
 */
export function clearResults() {
  allResults.length = 0;
}
