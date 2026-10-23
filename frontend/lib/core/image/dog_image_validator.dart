import 'dart:io';

import 'package:flutter/services.dart';

class DogImageValidator {
  static const _channel = MethodChannel(
    'com.doggy.frontend/dog_image_validator',
  );

  Future<bool> containsDog(File image) async {
    if (!Platform.isAndroid) {
      throw const DogImageValidationException('현재 Android에서만 사진 검사가 가능해요');
    }
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'validate',
        {'path': image.path},
      );
      if (result == null) {
        throw const DogImageValidationException('사진을 판별할 수 없어요');
      }
      return result['isDog'] == true;
    } on PlatformException catch (error) {
      throw DogImageValidationException(error.message ?? '사진을 판별할 수 없어요');
    }
  }
}

class DogImageValidationException implements Exception {
  final String message;

  const DogImageValidationException(this.message);
}
