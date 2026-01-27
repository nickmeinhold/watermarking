# Watermark Detection Process

## How Does the Detection Correlation Work?

### Detection Flow

```
Original Image ──┐
                 ├──► Subtract Luma ──► DFT ──► Extract p×p region
Marked Image ────┘                              │
                                                ▼
                                         Extracted Mark
                                                │
For each k = 1, 2, 3...                         │
    ┌───────────────────────────────────────────┘
    ▼
Generate Legendre Array(p, k)
    │
    ▼
Fast Correlation (via DFT)
    │
    ▼
Find Peak Position & PSNR
    │
    ├── PSNR > threshold (6.0) ──► Record shift, continue to k+1
    │
    └── PSNR < threshold ──► Stop, decode message from shifts
```

### The Correlation Math

From `WatermarkDetection.cpp:85-148`, `fastCorrelation` computes **circular cross-correlation** using the DFT:

```cpp
// Correlation theorem: corr(a,b) = IDFT( DFT(a) × conj(DFT(b)) )

dft(mat1, complexI1);  // DFT of extracted mark
dft(mat2, complexI2);  // DFT of reference Legendre array

// Element-wise: multiply by complex conjugate
for each (i,j):
    z3 = z1 * conj(z2);

// Inverse DFT gives correlation surface
dft(complexI1, inverseTransform, DFT_INVERSE);
```

This is **O(n² log n)** instead of O(n⁴) for direct correlation.

### What the Correlation Surface Looks Like

```
No watermark present:          Watermark present (shift=42):
┌─────────────────┐            ┌─────────────────┐
│ ~ ~ ~ ~ ~ ~ ~ ~ │            │ ~ ~ ~ ~ ~ ~ ~ ~ │
│ ~ ~ ~ ~ ~ ~ ~ ~ │            │ ~ ~ ▲ ~ ~ ~ ~ ~ │  ← Sharp peak at position 42
│ ~ ~ ~ ~ ~ ~ ~ ~ │            │ ~ ~ ~ ~ ~ ~ ~ ~ │
│ ~ ~ ~ ~ ~ ~ ~ ~ │            │ ~ ~ ~ ~ ~ ~ ~ ~ │
└─────────────────┘            └─────────────────┘
   (all noise)                  Peak/RMS ratio > 6.0
```

### Peak Detection (`detect.cpp:149-167`)

```cpp
// Find the maximum value and its (x,y) position
for (y = 0; y < p; y++) {
    for (x = 0; x < p; x++) {
        if (correlationVals[y * p + x] > maxVal) {
            maxVal = correlationVals[y * p + x];
            maxY = y;
            maxX = x;
        }
    }
}

// Calculate PSNR (peak-to-RMS ratio)
ms = sum(correlationVals[i]²) / (p * p);
peak2rms = maxVal / sqrt(ms);

// The shift encodes one digit of the message
shift = maxY * p + maxX;  // 2D position → 1D index (base p²)
```

### Why This Works

| Property | Effect |
|----------|--------|
| **Legendre autocorrelation** | Peak appears only at the correct shift |
| **Cross-correlation ~0** | Different k families don't interfere |
| **DFT linearity** | Multiple embedded arrays sum; correlation separates them |
| **Threshold = 6.0** | ~99.7% confidence (peak is 6 standard deviations above noise) |

### Message Reconstruction

Once detection stops (PSNR drops below threshold):

```cpp
// shifts = [42, 1337, 7, ...] (one per k-family)
// Each shift is a digit in base p²
message = getASCII(shifts, p * p);  // Convert back to text
```

The number of successful k-families determines how many characters were embedded.

## Detection Statistics

The detection process outputs extended statistics for analysis (see `Utilities.cpp:outputResultsFileExtended`):

### Per-Sequence Statistics

For each k-family tested:
- **k**: Family index
- **psnr**: Peak-to-RMS ratio (signal strength)
- **peakX, peakY**: Location of correlation peak
- **peakVal**: Raw peak value
- **rms**: RMS of correlation surface
- **shift**: Decoded shift value (peakY × p + peakX)

### Aggregate Statistics

- **threshold**: Detection threshold (default 6.0)
- **totalSequencesTested**: Number of k-families tested before stopping
- **sequencesAboveThreshold**: Number of successfully detected digits
- **confidence**: Minimum PSNR among successful sequences (weakest link)

### Timing Breakdown

- **timeImageLoad**: Time to load and decode images (ms)
- **timeExtraction**: Time to extract watermark from frequency domain (ms)
- **timeCorrelation**: Time for all correlation operations (ms)
- **timeTotal**: Total detection time (ms)

### Correlation Matrix Statistics

From the final tested sequence:
- **correlationMin, correlationMax**: Value range
- **correlationMean**: Average correlation value
- **correlationStdDev**: Standard deviation (noise floor indicator)
