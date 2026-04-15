---
title: "Python Client for Cloud Vision"
date: 2024-05-13
source-folder: Notes
tags:
  - needs-review
  - has-attachments
  - has-media-links
review-reasons: has-attachments, has-media-links
---

## Key Insights

* Install Google Cloud SDK and Python client for Cloud Vision
* Set up project ID using `gcloud config set project`
* Use `gcloud ml vision` to detect text in images stored on Google Cloud Storage
* Explore Flutter and Dart courses on Udemy for future development
* Reference article on Medium for troubleshooting white screen issue in Flutter iOS app

## Installing Google Cloud SDK and Python Client

To get started with the Python client for Cloud Vision, first install the Google Cloud SDK. This can be done by following the instructions on the [Google Cloud website](https://cloud.google.com/sdk/docs/install). The project ID is set using `gcloud config set project`, as shown in the example: `x-goog-user-project: 850861419930`.

## Using Cloud Vision API

To use the Cloud Vision API, navigate to the Google Cloud Console and enable the API. Then, use the `gcloud ml vision` command to detect text in images stored on Google Cloud Storage. For example, running `gcloud ml vision detect-text gs://sharprpm/IMG_3023.jpg` will perform text detection on the specified image.

## Future Development

For future development, consider taking courses on Flutter and Dart using Udemy resources:
* [Flutter Bootcamp with Dart](https://gale.udemy.com/course/flutter-bootcamp-with-dart/)
* [Dart and Flutter Complete Course](https://gale.udemy.com/course/dart-flutter-the-complete-flutter-development-course/learn/lecture/30790556#overview)

Additionally, reference the article on Medium for troubleshooting white screen issues in Flutter iOS apps: [Quick Fix: Flutter iOS App with White Screen After Install Through Testflight](https://jatin-95284.medium.com/quick-fix-flutter-ios-app-with-white-screen-after-install-through-testflight-87c63030ddc4).

## Remote Patient Assistance/Monitoring

The ultimate goal is to equip doctors with a set of tools that aids in the facilitation of remote patient assistance and monitoring. This project involves using Cloud Vision API to analyze images and provide insights for healthcare professionals.
