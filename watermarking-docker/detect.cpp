//
//  detect.cpp
//  WatermarkingMarkImage
//
//  Created by Nicholas Meinhold on 10/10/2016.
//  Copyright © 2016 ENSPYR. All rights reserved.
//

#include <opencv2/opencv.hpp>
#include <chrono>
#include <cmath>
#include <numeric>

#include "watermarking-functions/Utilities.hpp"
#include "watermarking-functions/WatermarkDetection.hpp"

// Helper to calculate statistics for correlation matrix
void calculateCorrelationStats(double* correlationVals, int size,
                               double& minVal, double& maxVal,
                               double& mean, double& stdDev) {
  minVal = correlationVals[0];
  maxVal = correlationVals[0];
  double sum = 0.0;

  for (int i = 0; i < size; i++) {
    if (correlationVals[i] < minVal) minVal = correlationVals[i];
    if (correlationVals[i] > maxVal) maxVal = correlationVals[i];
    sum += correlationVals[i];
  }

  mean = sum / size;

  double sumSquaredDiff = 0.0;
  for (int i = 0; i < size; i++) {
    double diff = correlationVals[i] - mean;
    sumSquaredDiff += diff * diff;
  }
  stdDev = sqrt(sumSquaredDiff / size);
}

int main(int argc, const char* argv[]) {
  // Start total timer
  auto totalStart = std::chrono::high_resolution_clock::now();

  // check args have been passed in
  // args are: unique id for db entry, file path for original image, file path
  // for marked image
  if (argc != 4) {
    std::cout << "incorrect number of arguments" << std::endl;
    return -1;
  }

  std::string uid = argv[argc - 3];  // the userid, used in the file path for saving results
  std::string originalFilePath = argv[argc - 2];
  std::string markedFilePath = argv[argc - 1];
  std::string outputFilePath = "/tmp/" + uid + ".json";

  std::cout << "user with id " << uid << ", detecting message in marked image at " << markedFilePath
            << std::endl;

  // Initialize detection stats
  DetectionStats stats;
  stats.threshold = 6.0;  // Detection threshold

  int p, k, maxX, maxY, imgRows, imgCols;
  double ms, peak2rms, maxVal;
  std::vector<int> shifts;

  // Time image loading
  auto loadStart = std::chrono::high_resolution_clock::now();

  // read in images and convert to 3 channel BGR
  cv::Mat original = cv::imread(originalFilePath, cv::IMREAD_COLOR);
  cv::Mat marked = cv::imread(markedFilePath, cv::IMREAD_COLOR);

  auto loadEnd = std::chrono::high_resolution_clock::now();
  stats.timeImageLoad = std::chrono::duration<double, std::milli>(loadEnd - loadStart).count();

  std::cout << "images read in and converted to 3 channel BGR " << std::endl;

  // check original and marked images are of equal size
  if (original.rows != marked.rows || original.cols != marked.cols) {
    std::cout << "Original and marked images are not equal sizes. Resizing marked image to match "
                 "original."
              << std::endl;
    std::cout << "Original: " << original.cols << "x" << original.rows
              << ", Marked: " << marked.cols << "x" << marked.rows << std::endl;
    cv::resize(marked, marked, original.size());
  }

  // set variables for the image rows and cols, now we know original and marked
  // are the same size
  imgRows = original.rows;
  imgCols = original.cols;

  // Store image properties
  stats.imageWidth = imgCols;
  stats.imageHeight = imgRows;

  // calculate the largest prime for this image
  p = largestPrimeFor(original);
  stats.primeSize = p;

  std::cout << "largest prime was found to be " << p << std::endl;

  // convert images to HSV
  cv::Mat hsvOriginal, hsvMarked;
  cvtColor(original, hsvOriginal, cv::COLOR_BGR2HSV);
  cvtColor(marked, hsvMarked, cv::COLOR_BGR2HSV);

  // create 1d array for luma values
  double* lumaArray = new double[imgCols * imgRows];
  // subtract original luma from marked luma and store the result
  for (int y = 0; y < imgRows; y++) {
    for (int x = 0; x < imgCols; x++) {
      lumaArray[y * imgCols + x] =
          (hsvMarked.at<cv::Vec3b>(y, x).val[2] - hsvOriginal.at<cv::Vec3b>(y, x).val[2]) / 255.0;
    }
  }

  // Time extraction phase
  auto extractStart = std::chrono::high_resolution_clock::now();

  // extract the watermark from the frequency domain
  std::cout << "PROGRESS:Extracting watermark from frequency domain..." << std::endl;
  double* extractedMark = new double[p * p];
  extractMark(hsvOriginal.rows, hsvOriginal.cols, p, p, lumaArray, extractedMark);

  auto extractEnd = std::chrono::high_resolution_clock::now();
  stats.timeExtraction = std::chrono::duration<double, std::milli>(extractEnd - extractStart).count();

  double* wmArray = new double[p * p];
  double* correlationVals = new double[p * p];

  // Time correlation phase
  auto corrStart = std::chrono::high_resolution_clock::now();

  // perform detection for each family of arrays (family determined by k value)
  k = 1;
  while (1) {
    if (k >= 1) {
      std::cout << "PROGRESS:Analyzing sequence " << k << "..." << std::endl;
    }
    // generate each array and perform correlation
    generateArray(p, k, wmArray);
    fastCorrelation(p, p, extractedMark, wmArray, correlationVals);

    // calculate peak value and peak2rms for this family of arrays
    maxVal = 0.0;
    maxX = -1;
    maxY = -1;
    for (int y = 0; y < p; y++) {
      for (int x = 0; x < p; x++) {
        if (correlationVals[y * p + x] > maxVal) {
          maxVal = correlationVals[y * p + x];
          maxY = y;
          maxX = x;
        }
      }
    }

    // calculate peak2rms
    ms = 0;
    for (int i = 0; i < p * p; i++)
      ms += (correlationVals[i] * correlationVals[i]) / (p * p);
    double rmsVal = sqrt(ms);
    peak2rms = maxVal / rmsVal;

    // Store sequence statistics
    SequenceStats seqStats;
    seqStats.k = k;
    seqStats.psnr = peak2rms;
    seqStats.peakX = maxX;
    seqStats.peakY = maxY;
    seqStats.peakVal = maxVal;
    seqStats.rms = rmsVal;
    seqStats.shift = maxY * p + maxX;
    stats.sequences.push_back(seqStats);

    // increment k to move on to next family
    k++;

    if (peak2rms > stats.threshold) {
      shifts.push_back(maxY * p + maxX);  // store the detected shift
    } else {
      break;
    }
  }

  auto corrEnd = std::chrono::high_resolution_clock::now();
  stats.timeCorrelation = std::chrono::duration<double, std::milli>(corrEnd - corrStart).count();

  // Calculate correlation matrix statistics (from last tested sequence)
  calculateCorrelationStats(correlationVals, p * p,
                            stats.correlationMin, stats.correlationMax,
                            stats.correlationMean, stats.correlationStdDev);

  // Store total sequences tested
  stats.totalSequencesTested = k - 1;
  stats.sequencesAboveThreshold = shifts.size();

  // Calculate PSNR statistics
  if (!stats.sequences.empty()) {
    double psnrSum = 0.0;
    stats.maxPsnr = stats.sequences[0].psnr;

    for (const auto& seq : stats.sequences) {
      psnrSum += seq.psnr;
      if (seq.psnr > stats.maxPsnr) {
        stats.maxPsnr = seq.psnr;
      }
    }
    stats.avgPsnr = psnrSum / stats.sequences.size();
  } else {
    stats.avgPsnr = 0.0;
    stats.maxPsnr = 0.0;
  }

  stats.message = "No message found.";
  stats.confidence = 0.0;
  stats.detected = false;

  // calculate the message from the shifts
  if (shifts.size() != 0) {
    stats.message = getASCII(shifts, p * p);
    stats.detected = true;

    // Find minimum PSNR among successful sequences (weakest link)
    double minPsnr = stats.sequences[0].psnr;
    for (size_t i = 0; i < shifts.size() && i < stats.sequences.size(); i++) {
      if (stats.sequences[i].psnr < minPsnr) {
        minPsnr = stats.sequences[i].psnr;
      }
    }
    stats.confidence = minPsnr;
  }

  // Calculate total time
  auto totalEnd = std::chrono::high_resolution_clock::now();
  stats.timeTotal = std::chrono::duration<double, std::milli>(totalEnd - totalStart).count();

  // Clean up
  delete[] lumaArray;
  delete[] extractedMark;
  delete[] wmArray;
  delete[] correlationVals;

  // Output extended results
  outputResultsFileExtended(stats, outputFilePath);

  return 0;
}
