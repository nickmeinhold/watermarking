//
//  detect.cpp
//  WatermarkingMarkImage
//
//  Created by Nicholas Meinhold on 10/10/2016.
//  Copyright © 2016 ENSPYR. All rights reserved.
//

#include <opencv2/opencv.hpp>

#include "watermarking-functions/Utilities.hpp"
#include "watermarking-functions/WatermarkDetection.hpp"

int main(int argc, const char* argv[]) {
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

  int p, k, maxX, maxY, imgRows, imgCols;
  double ms, peak2rms, maxVal;
  std::vector<int> shifts;
  std::vector<double> psnrs;

  // read in images and convert to 3 channel BGR

  cv::Mat original = cv::imread(originalFilePath, cv::IMREAD_COLOR);
  cv::Mat marked = cv::imread(markedFilePath, cv::IMREAD_COLOR);

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

  // calculate the largest prime for this image
  p = largestPrimeFor(original);

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

  // extract the watermark from the frequency domain
  std::cout << "PROGRESS:Extracting watermark from frequency domain..." << std::endl;
  double* extractedMark = new double[p * p];
  extractMark(hsvOriginal.rows, hsvOriginal.cols, p, p, lumaArray, extractedMark);

  double* wmArray = new double[p * p];
  double* correlationVals = new double[p * p];

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
    peak2rms = maxVal / sqrt(ms);

    // increment k to move on to next family
    k++;

    if (peak2rms > 6) {
      shifts.push_back(maxY * p +
                       maxX);  // store the detected shift (the shift that had the peak value)
      psnrs.push_back(peak2rms);

    } else {
      // TODO: if keeping the last peak, it will need to be removed before being
      // used in getASCII

      // add the last peak as well, so that results include the last rejected
      // peak shifts.push_back(maxY*p+maxX); psnrs.push_back(peak2rms);

      break;
    }
  }

  std::string messageStr = "No message found.";
  // calculate the message from the shifts
  if (shifts.size() != 0) {
    messageStr = getASCII(shifts, p * p);
  }

  outputResultsFile(messageStr, outputFilePath);

  return 0;
}
