# Research Configuration

## Project Context
Digital watermarking system for embedding and detecting invisible messages in images that survive print-and-scan.

## Tech Stack
- **Flutter/Dart**: watermarking_core (shared), watermarking_mobile (iOS), watermarking_webapp (web)
- **Node.js**: watermarking-docker (backend queue processing)
- **C++/OpenCV**: watermarking-functions (DFT-based watermark algorithms)
- **Firebase**: Firestore, Storage, Auth (project: watermarking-4a428)

## Research Priorities
- Image processing and computer vision techniques
- DFT/FFT watermarking algorithms and robustness
- iOS Vision Framework and ARKit for rectangle detection
- Flutter cross-platform patterns
- Firebase/GCP best practices

## Preferred Sources
- pub.dev for Flutter/Dart packages
- OpenCV documentation for image processing
- Apple Developer docs for iOS Vision/ARKit
- Firebase documentation
- Academic papers for watermarking algorithms (IEEE, ACM)

## Project Structure Reference
See CLAUDE.md in project root for full architecture diagram and file locations.

## Output Format
Write findings to `RESEARCH.md` with:
- Clear title and date
- Executive summary
- Detailed findings with code examples where applicable
- Recommendations specific to this project's architecture
- References and links to sources
