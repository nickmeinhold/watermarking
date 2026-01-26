# Dockerfile for Watermarking API
# Multi-stage build: compile C++ binary, then run with Node.js

# =============================================================================
# Stage 1: Build the C++ mark-image binary
# =============================================================================
FROM ubuntu:22.04 AS builder

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    pkg-config \
    libopencv-dev \
    libboost-all-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy C++ source files
COPY mark.cpp /build/mark.cpp
COPY watermarking-functions /build/watermarking-functions

# Compile the marking program
RUN g++ mark.cpp -std=c++11 \
    watermarking-functions/WatermarkDetection.cpp \
    watermarking-functions/Utilities.cpp \
    -I. -I/usr/include -I/usr/include/opencv4 \
    -L/usr/lib/x86_64-linux-gnu \
    -lopencv_core -lopencv_imgcodecs -lopencv_imgproc \
    -o mark-image

# =============================================================================
# Stage 2: Runtime with Node.js
# =============================================================================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    # OpenCV runtime libraries
    libopencv-core4.5d \
    libopencv-imgcodecs4.5d \
    libopencv-imgproc4.5d \
    # Node.js
    curl \
    ca-certificates \
    gnupg \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy compiled binary from builder
COPY --from=builder /build/mark-image /app/mark-image

# Copy Node.js package files and install dependencies
COPY package.json /app/package.json
RUN npm install --production

# Copy server code
COPY server.js /app/server.js

# Create temp directories
RUN mkdir -p /tmp/uploads

# Cloud Run expects PORT environment variable
ENV PORT=8080

EXPOSE 8080

CMD ["node", "server.js"]
