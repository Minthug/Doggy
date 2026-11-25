import 'package:flutter/material.dart';

/// Decorative variants; the index does not represent the dog's actual breed.
class DogFaceIcon extends StatelessWidget {
  static const breeds = [
    'poodle',
    'husky',
    'golden_retriever',
    'jindo',
    'dachshund',
    'maltipoo',
    'bichon',
    'pomeranian',
  ];
  final int variant;
  final double size;
  const DogFaceIcon({super.key, this.variant = 0, this.size = 24});

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/dog_faces/${breeds[variant % breeds.length]}.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.none,
    cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
    excludeFromSemantics: true,
  );
}
