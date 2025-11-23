// lib/screens/quiz_result_screen.dart
import 'package:flutter/material.dart';

class QuizResultScreen extends StatelessWidget {
  final int correct;
  final int total;
  final VoidCallback onRetry;

  const QuizResultScreen({super.key, required this.correct, required this.total, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final pct = (correct / total * 100).round();
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Sonucu')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Başarı: $pct%', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('$correct doğru / $total soru', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Tekrar Dene')),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Geri Dön'))
          ],
        ),
      ),
    );
  }
}
