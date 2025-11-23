import 'package:flutter/material.dart';
import '../utils/logging.dart';
import 'package:lottie/lottie.dart';

class LoadingAnimation extends StatelessWidget {
  final double width;
  final double height;

  const LoadingAnimation({super.key, this.width = 120, this.height = 120});

  @override
  Widget build(BuildContext context) {
    // Prefer JSON asset loaded directly for reliability
    return Lottie.asset(
      'assets/animations/loading_circle.json',
      width: width,
      height: height,
      fit: BoxFit.contain,
      repeat: true,
      errorBuilder: (context, error, stackTrace) {
        // ignore: avoid_print
  AppLog.d('LoadingAnimation Lottie error: $error');
        return SizedBox(
          width: width / 2,
          height: height / 2,
          child: const CircularProgressIndicator(),
        );
      },
    );
  }
}
