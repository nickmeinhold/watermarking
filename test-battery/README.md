# Watermark Test Battery

Robustness test suite that validates watermark survival across real-world image degradation scenarios. Tests the full pipeline: generate image, embed watermark via the REST API, apply distortion, detect watermark, and verify correct message recovery.

## Quick Start

```bash
# Start the watermarking API locally
./scripts/start-docker.sh

# Run fast test suite (2 images, 1 message, 2 strengths)
npm test

# Run full test suite (4 images, 2 messages, 4 strengths)
npm run test:full

# Stop the API
./scripts/start-docker.sh --stop
```

## What It Tests

Each test case embeds a watermark, applies a distortion, then verifies detection succeeds with the correct message and confidence above threshold (6.0).

### Distortion Matrix

| Category | Distortions |
|----------|-------------|
| Baseline | Identity (no distortion) |
| Compression | JPEG quality 10, 30, 50, 75, 95 |
| Blur | Gaussian sigma 0.5, 1.0, 2.0 |
| Resize | Down/up 50%, 75% |
| Rotation | 1, 5, 15 degrees |
| Noise | Gaussian sigma 5, 15, 30 |
| Gamma | 0.7, 1.5 |
| Combined | JPEG+blur, resize+JPEG |

### Test Parameters

| Parameter | Fast Mode | Full Mode |
|-----------|-----------|-----------|
| Image types | 2 (gradient, noise) | 4 (gradient, checkerboard, noise, natural-like) |
| Messages | 1 ("AB") | 2 ("AB", "Test") |
| Strengths | 2 (10, 50) | 4 (5, 10, 25, 50) |
| Total cases | ~38 | ~304 |

## Image Types

Generated test images exercise different frequency characteristics:

- **Gradient**: smooth transitions (low frequency)
- **Checkerboard**: regular patterns (mixed frequency)
- **Noise**: random pixels (high frequency)
- **Natural-like**: overlapping circles simulating natural image structure

## Output

Results are written to `results/` (gitignored):

- `results.json` — raw per-test results with confidence scores
- `report.md` — summary table with pass rates by distortion type and strength

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `TEST_API_URL` | `http://localhost:8080` | API endpoint |
| `TEST_API_KEY` | `test-battery-key` | API authentication key |
| `TEST_MODE` | (fast) | Set to `full` for comprehensive suite |

## Dependencies

- Node.js 20+
- [sharp](https://sharp.pixelplumbing.com/) — image distortion transforms
- [vitest](https://vitest.dev/) — test runner
- Running watermarking API (local Docker or remote)
