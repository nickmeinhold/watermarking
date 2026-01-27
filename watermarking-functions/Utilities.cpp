//
//  Utilities.cpp
//  WatermarkingFunctionsTests
//
//  Created by Nicholas Meinhold on 17/07/2016.
//  Copyright © 2016 ENSPYR. All rights reserved.
//

#include "Utilities.hpp"

#include <algorithm>
#include <boost/math/special_functions/prime.hpp>
#include <fstream>
#include <iostream>

#include "json.hpp"

// convert opencv type to a human readable string
// Note: code taken from Stack Overflow answer, don't assume it is correct
// http://stackoverflow.com/a/17820615/1992736
std::string ocv_type2str(int type) {
  std::string r;

  uchar depth = type & CV_MAT_DEPTH_MASK;
  uchar chans = 1 + (type >> CV_CN_SHIFT);

  switch (depth) {
    case CV_8U:
      r = "8U";
      break;
    case CV_8S:
      r = "8S";
      break;
    case CV_16U:
      r = "16U";
      break;
    case CV_16S:
      r = "16S";
      break;
    case CV_32S:
      r = "32S";
      break;
    case CV_32F:
      r = "32F";
      break;
    case CV_64F:
      r = "64F";
      break;
    default:
      r = "User";
      break;
  }

  r += "C";
  r += (chans + '0');

  return r;
}

// Used in test project to save output
void saveImageToFile(std::string file_name, cv::Mat& imageMat) {
  std::vector<int> compression_params;
  compression_params.push_back(cv::IMWRITE_PNG_COMPRESSION);
  compression_params.push_back(9);

  try {
    imwrite(file_name, imageMat, compression_params);
  } catch (std::runtime_error& ex) {
    std::cerr << "Exception converting " << file_name << " image to PNG format: " << ex.what()
              << std::endl;
  }
}

int largestPrimeFor(cv::Mat& imgMat) {
  int minImgDim = std::min(imgMat.rows, imgMat.cols);

  // we avoid marking the first row and col (dc components) so the largest
  // square array we can use is 2 less than the min dimension

  int maxArrayDim = minImgDim - 2;

  // the arrays are size p*p where p is a prime so find the largest prime we can
  // use, ie. closest to maxArrayDim

  int maxP;

  for (int i = 0; i < 10000; i++) {
    if (boost::math::prime(i) > maxArrayDim) {
      maxP = boost::math::prime(i - 1);
      break;
    }
  }

  return maxP;
}

// find the shift of the array that was used for the watermark (ie. the peak)
// and the PSNR of the correlations
void findShiftAndPSNR(double* correlation_vals, int array_len, double& peak2rms, int& peak_pos) {
  // find the peak value and it's position
  double maxVal = 0.0;
  int i, maxI = -1;
  for (i = 0; i < array_len; i++) {
    if (correlation_vals[i] > maxVal) {
      maxVal = correlation_vals[i];
      maxI = i;
    }
  }

  // use the peak value to find the PSNR
  double ms = 0;
  for (i = 0; i < array_len; i++)
    ms += (correlation_vals[i] * correlation_vals[i]) / array_len;

  // assign the shift and peak2rms to the passed in variables
  peak_pos = maxI;
  peak2rms = maxVal / sqrt(ms);
}

void scramble(double* array, int array_len, int key) {
  srand(key);
  double tmp;
  int index;
  for (int i = array_len - 1; i > 0; i--) {
    index = rand() % (i + 1);
    double tmp = array[index];
    array[index] = array[i];
    array[i] = tmp;
  }
}

void unscramble(double* array, int array_len, int key) {
  // rebuild the random number sequence
  srand(key);
  int* randoms = new int[array_len - 1];
  int j = 0;
  for (int i = array_len - 1; i > 0; i--) {
    randoms[j++] = rand() % (i + 1);
  }

  // reverse the scramble - use the random values backwards
  double tmp;
  int index;
  for (int i = 1; i < array_len; i++) {
    index = randoms[array_len - i - 1];
    tmp = array[index];
    array[index] = array[i];
    array[i] = tmp;
  }
}

// write out a json file with the message and confidence to the specified path
int outputResultsFile(std::string message, double confidence, std::string filePath) {
  nlohmann::json j;
  j["message"] = message;
  j["confidence"] = confidence;

  // write prettified JSON to file
  std::ofstream o(filePath);
  o << std::setw(4) << j << std::endl;

  return 0;
}

// write out extended statistics as json file
int outputResultsFileExtended(const DetectionStats& stats, std::string filePath) {
  nlohmann::json j;

  // Core results (same as legacy for backward compatibility)
  j["message"] = stats.message;
  j["confidence"] = stats.confidence;

  // Image properties
  j["imageWidth"] = stats.imageWidth;
  j["imageHeight"] = stats.imageHeight;
  j["primeSize"] = stats.primeSize;

  // Detection status
  j["detected"] = stats.detected;
  j["threshold"] = stats.threshold;

  // Timing breakdown (milliseconds)
  j["timing"]["imageLoad"] = stats.timeImageLoad;
  j["timing"]["extraction"] = stats.timeExtraction;
  j["timing"]["correlation"] = stats.timeCorrelation;
  j["timing"]["total"] = stats.timeTotal;

  // Sequence statistics
  j["totalSequencesTested"] = stats.totalSequencesTested;
  j["sequencesAboveThreshold"] = stats.sequencesAboveThreshold;

  // PSNR summary
  j["psnrStats"]["min"] = stats.confidence;  // min is the confidence
  j["psnrStats"]["max"] = stats.maxPsnr;
  j["psnrStats"]["avg"] = stats.avgPsnr;

  // Per-sequence details (for histogram/chart visualization)
  nlohmann::json sequencesArray = nlohmann::json::array();
  for (const auto& seq : stats.sequences) {
    nlohmann::json seqJson;
    seqJson["k"] = seq.k;
    seqJson["psnr"] = seq.psnr;
    seqJson["peakX"] = seq.peakX;
    seqJson["peakY"] = seq.peakY;
    seqJson["peakVal"] = seq.peakVal;
    seqJson["rms"] = seq.rms;
    seqJson["shift"] = seq.shift;
    sequencesArray.push_back(seqJson);
  }
  j["sequences"] = sequencesArray;

  // Correlation matrix statistics (summary, not full matrix)
  j["correlationStats"]["min"] = stats.correlationMin;
  j["correlationStats"]["max"] = stats.correlationMax;
  j["correlationStats"]["mean"] = stats.correlationMean;
  j["correlationStats"]["stdDev"] = stats.correlationStdDev;

  // write prettified JSON to file
  std::ofstream o(filePath);
  o << std::setw(4) << j << std::endl;

  return 0;
}
