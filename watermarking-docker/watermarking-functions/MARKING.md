# Watermark Marking Process

## What Sequence Are We Using for Marking?

The marking uses **Legendre sequences** constructed from quadratic residues.

### Sequence Details

From `WatermarkDetection.cpp:10-29`, the `generateArray(p, k, array)` function creates a 2D array using:

1. **Base sequence**: Legendre symbol - values are +1 if the index is a quadratic residue mod p, otherwise -1
2. **Column construction**: Each column is a shifted version of the Legendre sequence, with shift = `(i² × k) mod p`

### How It's Used in Marking (`mark.cpp:67-82`)

```cpp
for (int k = 1; k <= totalShifts; k++) {
    generateArray(p, k, wmArray);
    // multiply by strength
    insertMark(..., wmArray, messageShifts[k - 1]);
}
```

- **p**: Largest prime ≤ (min image dimension - 2)
- **k**: Family parameter, starts at 1 and increments for each character
- **Message encoding**: Each character's shift value (base p²) determines the 2D offset of the array before embedding

### Key Properties

- The arrays are **p × p** where p is prime
- Each k value produces a different "family" of arrays (orthogonal to other families)
- The message is converted to shifts in base p², then each digit is embedded using a different k-family
- Detection works by correlating extracted frequency domain data against each k-family and finding the peak position (the shift)

## Why Legendre Sequences Specifically?

Legendre sequences are chosen for their **ideal correlation properties**, which are critical for reliable watermark detection.

### Key Properties

**1. Sharp Autocorrelation Peak**

When you correlate a Legendre sequence with a shifted version of itself, you get:
- A strong peak at the correct shift position
- Near-zero values everywhere else (sidelobe level of -1/p)

This makes finding the embedded message shift unambiguous.

**2. Orthogonal Families**

Different k values produce arrays that are nearly orthogonal to each other. This allows embedding multiple "digits" of a message independently—each k-family carries one digit without interfering with others.

**3. Noise-like Spectrum**

The ±1 values are distributed pseudo-randomly, so the watermark spreads across the frequency domain like noise—making it invisible to human eyes and robust against compression.

**4. Robustness to Attacks**

The mathematical structure means:
- Cropping/scaling only shifts the correlation peak (recoverable)
- JPEG compression attenuates but doesn't destroy the signal
- Print-and-scan survives because the correlation operation is tolerant of noise

### Why Not Other Sequences?

| Sequence Type | Issue |
|--------------|-------|
| Random noise | No structure—can't reconstruct at detector |
| PN sequences | Shorter period, worse sidelobe properties |
| Walsh/Hadamard | Vulnerable to specific frequency attacks |
| Legendre | Optimal autocorrelation, proven mathematical properties |

### Academic Background

This approach is based on research by **Andrew Tirkel**. The 2D arrays constructed from shifted Legendre sequences are related to **Costas arrays** and **perfect arrays**—structures specifically designed for radar, sonar, and watermarking applications where detection in noise is critical.

## Marking Performance Optimizations

The current marking process is **extremely slow** (hours for a small image with 4 characters on CPU).

### The Problem

```cpp
// mark.cpp:67-82 - Current implementation
for (int k = 1; k <= totalShifts; k++) {
    generateArray(p, k, wmArray);
    insertMark(...);  // Does 2 full DFTs per character
}
```

For a 1000×1000 image with a 4-character message:
- **8 full-image DFTs** (2 per character)
- Each DFT is ~20M operations
- Takes **hours** on Cloud Run CPU, hits 1-hour timeout

### Suggested Optimizations

#### 1. Batch Watermarks in Frequency Domain (~Nx speedup)

**The key insight**: DFT is linear, so addition in spatial domain = addition in frequency domain.

```
Current (2N DFTs for N characters):
  spatial → DFT → add wm₁ → IDFT → DFT → add wm₂ → IDFT → ...

Proposed (2 DFTs total):
  spatial → DFT → add (wm₁ + wm₂ + ... + wmₙ) → IDFT
```

```cpp
// Pseudocode for batched approach
dft(image);  // Once

for (int k = 1; k <= totalShifts; k++) {
    generateArray(p, k, wmArray);
    shiftArray(wmArray, messageShifts[k-1]);
    // Accumulate in frequency domain (no DFT needed)
    for (i = 0; i < p*p; i++)
        freqAccumulator[i] += wmArray[i] * strength;
}

// Add accumulated watermark
addToFrequencyDomain(image, freqAccumulator);
idft(image);  // Once
```

**Speedup**: From 2N to 2 DFTs — for a 10-character message, ~10x faster.

#### 2. Use Optimal DFT Size (~2x speedup)

DFT is fastest when dimensions are powers of 2 (or have small prime factors).

```cpp
// Current: uses actual image size (e.g., 1000×1000)
// Proposed: pad to 1024×1024

int optimalSize = nextPowerOf2(max(rows, cols));
copyMakeBorder(image, padded, 0, optimalSize-rows, 0, optimalSize-cols, BORDER_CONSTANT);
```

**Speedup**: ~2x with no quality impact.

#### 3. Downsample to Fixed Size (~4x speedup)

```cpp
// Resize to 512×512 for watermarking, then resize back
resize(image, small, Size(512, 512));
// ... apply watermark ...
resize(small, image, originalSize);
```

**Tradeoff**: Slight quality reduction, but watermark survives print-and-scan anyway.

#### 4. GPU Acceleration (~10-100x speedup)

```cpp
// Use OpenCV's CUDA DFT
cv::cuda::GpuMat gpuImage;
gpuImage.upload(image);
cv::cuda::dft(gpuImage, gpuImage);
```

**Effort**: High — requires Cloud Run with GPU, CUDA-enabled OpenCV build.

### Optimization Summary

| Optimization | Speedup | Effort | Quality Impact |
|--------------|---------|--------|----------------|
| **Batch in freq domain** | ~Nx | Medium | None (mathematically equivalent) |
| Optimal DFT size | ~2x | Low | None |
| Downsample to 512² | ~4x | Low | Slight reduction |
| GPU (CUDA) | ~10-100x | High | None |

### Recommendation

The **batching optimization** is the best first step:
- Biggest impact for messages with multiple characters
- Mathematically identical output
- No infrastructure changes needed

**Note**: Discuss with Andrew Tirkel before implementing to confirm the mathematical equivalence holds for the specific Legendre array construction being used.
