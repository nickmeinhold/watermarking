# Review Configuration

## Project Context
Digital watermarking system for embedding and detecting invisible messages in images.

## Tech Stack
- **Flutter/Dart**: watermarking_core, watermarking_mobile, watermarking_webapp
- **Node.js**: watermarking-docker (backend processing)
- **C++**: watermarking-functions (OpenCV algorithms)

## Review Focus Areas
- Firebase security rules and data access patterns
- Image processing performance considerations
- Cross-platform compatibility (iOS, Web)
- Redux state management patterns in Flutter code

## Code Standards
- Dart: Follow flutter_lints rules
- Node.js: ES6+ style, async/await patterns
- Run `flutter analyze` for Dart, `npm test` for Node.js

## Required Checks
- CI must pass (Analyze & Test job)
- No new linter warnings
