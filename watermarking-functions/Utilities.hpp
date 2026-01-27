//
//  Utilities.hpp
//  WatermarkingFunctionsTests
//
//  Created by Nicholas Meinhold on 17/07/2016.
//  Copyright © 2016 ENSPYR. All rights reserved.
//

#ifndef Utilities_hpp
#define Utilities_hpp

#include <opencv2/opencv.hpp>
#include <vector>
#include <chrono>

// Structure to hold peak information for each detected sequence
struct SequenceStats {
  int k;           // Sequence number (family index)
  double psnr;     // Peak-to-RMS ratio for this sequence
  int peakX;       // X coordinate of peak in correlation matrix
  int peakY;       // Y coordinate of peak in correlation matrix
  double peakVal;  // Raw peak correlation value
  double rms;      // RMS of all correlation values
  int shift;       // Detected shift value (peakY * p + peakX)
};

// Structure to hold all detection statistics
struct DetectionStats {
  // Core results
  std::string message;
  double confidence;  // Minimum PSNR (weakest link)

  // Image properties
  int imageWidth;
  int imageHeight;
  int primeSize;  // p value used for watermark arrays

  // Per-sequence statistics
  std::vector<SequenceStats> sequences;
  int totalSequencesTested;  // Total k values tested (including failed ones)

  // Timing information (in milliseconds)
  double timeImageLoad;
  double timeExtraction;
  double timeCorrelation;
  double timeTotal;

  // Correlation matrix statistics (for the last sequence tested)
  double correlationMin;
  double correlationMax;
  double correlationMean;
  double correlationStdDev;

  // Threshold used for detection
  double threshold;

  // Success metrics
  bool detected;
  int sequencesAboveThreshold;
  double avgPsnr;  // Average PSNR of successful sequences
  double maxPsnr;  // Maximum PSNR across all sequences
};

std::string ocv_type2str(int type);
void saveImageToFile(std::string file_name, cv::Mat& imageMat);
int largestPrimeFor(cv::Mat& imgMat);
void findShiftAndPSNR(double* array, int array_len, double& peak2rms, int& shift);
void scramble(double* array, int array_len, int key);
void unscramble(double* array, int array_len, int key);

// Legacy function for backward compatibility
int outputResultsFile(std::string message, double confidence, std::string filePath);

// Extended output with full statistics
int outputResultsFileExtended(const DetectionStats& stats, std::string filePath);

#endif /* Utilities_hpp */
