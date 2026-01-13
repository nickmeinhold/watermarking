# Watermarking Research Summary

## Executive Summary

This document summarizes current research on digital watermarking technologies, with focus on Google's SynthID and approaches relevant to print-and-scan survival scenarios.

---

## 1. Google SynthID

### Overview
SynthID is Google DeepMind's AI-powered watermarking technology for identifying AI-generated content. It embeds imperceptible watermarks directly into the generation process.

### Key Characteristics
- **Invisible integration**: Watermarks are embedded during content generation, not post-processing
- **Multi-modal support**: Works with images, audio, video, and text
- **Robustness**: Designed to survive common modifications like compression, cropping, and filters
- **Detection API**: Provides confidence levels rather than binary yes/no answers

### SynthID for Images
- Uses neural networks to embed patterns in the latent space during image generation
- Watermark survives JPEG compression, resizing, and color adjustments
- Currently integrated into Google's Imagen and other generative AI tools
- **Limitation**: Primarily designed for digital-to-digital scenarios, not print-and-scan

### SynthID for Text
- Embeds watermarks by subtly influencing token selection during LLM generation
- Uses statistical patterns detectable across sufficient text length
- Requires ~200+ tokens for reliable detection

---

## 2. Watermarking Approaches Comparison

### DFT-Based (Discrete Fourier Transform)
**Your current approach**

| Aspect | Details |
|--------|---------|
| Mechanism | Embeds data in frequency domain coefficients |
| Robustness | Good for print-scan if mid-frequencies used |
| Capacity | Moderate (tens to hundreds of bits) |
| Complexity | Lower computational requirements |
| Advantages | Well-understood, deterministic extraction |

### Neural Network-Based
**Modern deep learning approach**

| Aspect | Details |
|--------|---------|
| Mechanism | End-to-end learned embedding and extraction |
| Robustness | Can be trained specifically for print-scan |
| Capacity | Higher potential capacity |
| Complexity | Requires training data and GPU resources |
| Advantages | Adaptive to specific distortion types |

### Hybrid Approaches
Combine traditional signal processing with neural networks:
- Use CNNs to learn optimal embedding locations
- Apply traditional transforms for actual embedding
- Neural extractors for robust detection

---

## 3. Print-and-Scan Specific Challenges

### Distortions to Survive
1. **Geometric**: Rotation, scaling, perspective distortion
2. **Optical**: Scanner noise, lens distortion, lighting variation
3. **Color**: Ink spreading, paper absorption, color shift
4. **Halftoning**: Printer dot patterns interfere with watermark
5. **Resolution**: Information loss during print/scan conversion

### Successful Strategies
- **Mid-frequency embedding**: Avoid low frequencies (easily removed) and high frequencies (destroyed by printing)
- **Synchronization patterns**: Help realign after geometric distortion
- **Error correction codes**: BCH, LDPC, or turbo codes for bit recovery
- **Template matching**: Embed known patterns for geometric correction
- **Multiple redundancy**: Repeat message across image regions

---

## 4. Current Research Trends (2024-2025)

### Adversarial Robustness
- Training watermarks to survive intentional removal attacks
- Generative adversarial networks (GANs) for attack simulation

### Standardization Efforts
- **C2PA (Coalition for Content Provenance and Authenticity)**: Industry standard for content credentials
- **IPTC Photo Metadata**: Extended for AI provenance
- **ISO/IEC initiatives**: Working on watermarking standards

### Open Source Tools
| Tool | Type | Notes |
|------|------|-------|
| invisible-watermark | Python | DWT-DCT-SVD based |
| blind-watermark | Python | Frequency domain |
| StegaStamp | Neural | End-to-end learned |
| RivaGAN | Neural | GAN-based robust watermarking |

### Academic Highlights
- **HiDDeN (2018)**: End-to-end deep learning watermarking, foundational work
- **StegaStamp (2019)**: Specifically designed for print-scan survival
- **MBRS (2022)**: Multi-bit robust steganography using attention
- **Tree-Ring Watermarks (2023)**: Embeds in diffusion model's initial noise
- **Gaussian Shading (2024)**: Improved robustness for diffusion models

---

## 5. Recommendations for This Project

### Short-term Improvements
1. **Add error correction**: Implement BCH or Reed-Solomon codes for bit recovery
2. **Synchronization marks**: Embed corner markers for geometric correction
3. **Adaptive strength**: Vary embedding strength based on local image content

### Medium-term Considerations
1. **Train a neural extractor**: Keep DFT embedding but use CNN for extraction
2. **Print-scan dataset**: Collect real print-scan pairs for testing/training
3. **Multiple watermark copies**: Embed same message in multiple image regions

### Long-term Exploration
1. **Hybrid DFT-Neural**: Use neural network to select optimal DFT coefficients
2. **StegaStamp integration**: Evaluate end-to-end neural approach
3. **C2PA compatibility**: Consider adding content credentials alongside watermark

---

## 6. Key References

1. Zhu et al. "HiDDeN: Hiding Data With Deep Networks" (ECCV 2018)
2. Tancik et al. "StegaStamp: Invisible Hyperlinks in Physical Photographs" (CVPR 2020)
3. Google DeepMind. "SynthID: Identifying AI-generated content" (2023)
4. Wen et al. "Tree-Ring Watermarks: Fingerprints for Diffusion Images" (NeurIPS 2023)
5. Yang et al. "Gaussian Shading: Provable Watermarking for Diffusion Models" (CVPR 2024)

---

## 7. Glossary

| Term | Definition |
|------|------------|
| DFT | Discrete Fourier Transform - converts image to frequency domain |
| DCT | Discrete Cosine Transform - similar to DFT, used in JPEG |
| DWT | Discrete Wavelet Transform - multi-resolution frequency analysis |
| PSNR | Peak Signal-to-Noise Ratio - image quality metric |
| BER | Bit Error Rate - measure of extraction accuracy |
| Payload | The hidden message/data being embedded |
| Robustness | Ability to survive modifications/attacks |
| Imperceptibility | Invisibility of watermark to human eye |

---

*Research compiled January 2026*
