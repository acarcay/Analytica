// lib/screens/quiz_screen.dart
import 'package:flutter/material.dart';
import '../widgets/loading_animation.dart';
import '../models/quiz.dart';
import 'quiz_result_screen.dart';
import 'dart:math';
import '../services/quiz_service.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _current = 0;
  final Map<String,int> _answers = {};
  List<QuizQuestion> _questions = sampleQuizQuestions;
  bool _loading = true;

  final QuizService _quizService = QuizService();

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() { _loading = true; });
    final fetched = await _quizService.fetchAll();
    setState(() {
      _questions = fetched;
      _loading = false;
      _current = 0;
      _answers.clear();
    });
  }

  void _select(int idx) {
    final q = _questions[_current];
    setState(() {
      _answers[q.id] = idx;
    });
  }

  void _next() {
    if (_current < _questions.length - 1) {
      setState(() { _current++; });
    }
  }

  void _prev() {
    if (_current > 0) setState(() { _current--; });
  }

  void _shuffle() {
    setState(() {
      // Shuffle the current questions list instead of resetting to sample
      _questions = List.from(_questions);
      _questions.shuffle(Random());
      _answers.clear();
      _current = 0;
    });
  }

  void _finish() {
    int correct = 0;
    for (var q in _questions) {
      final sel = _answers[q.id];
      if (sel != null && sel == q.correctIndex) correct++;
    }
    Navigator.push(context, MaterialPageRoute(builder: (context) => QuizResultScreen(correct: correct, total: _questions.length, onRetry: _shuffle)));
  }

  void _reset() {
    setState(() { _answers.clear(); _current = 0; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(title: const Text('İnteraktif Quizler')), body: Center(child: LoadingAnimation()));
    }

    final q = _questions[_current];
    final selected = _answers[q.id];
    final isCorrect = selected != null && selected == q.correctIndex;

    return Scaffold(
      appBar: AppBar(title: const Text('İnteraktif Quizler'), actions: [
        IconButton(onPressed: _shuffle, icon: const Icon(Icons.shuffle)),
        IconButton(onPressed: _reset, icon: const Icon(Icons.restart_alt)),
      ]),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q.section, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Text(q.question, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: (_current + 1) / _questions.length),
            const SizedBox(height: 12),
            ...List.generate(q.options.length, (i) {
              final opt = q.options[i];
              final checked = selected == i;
              Color? tileColor;
              if (selected != null) {
                if (i == q.correctIndex) {
                  tileColor = Colors.green.withOpacity(0.12);
                } else if (checked && !isCorrect) tileColor = Colors.red.withOpacity(0.08);
              }
              return Card(
                color: tileColor,
                child: ListTile(
                  leading: Radio<int?>(value: i, groupValue: selected, onChanged: (v) { _select(i); }),
                  title: Text(opt),
                  onTap: () => _select(i),
                ),
              );
            }),
            const SizedBox(height: 12),
            if (selected != null) ...[
              Text(isCorrect ? 'Doğru!' : 'Yanlış', style: TextStyle(color: isCorrect ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Açıklama:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(q.explanation),
            ],
            const Spacer(),
            Row(
              children: [
                ElevatedButton(onPressed: _prev, child: const Text('Önceki')),
                const SizedBox(width: 12),
                ElevatedButton(onPressed: _next, child: const Text('Sonraki')),
                const SizedBox(width: 12),
                ElevatedButton(onPressed: _finish, child: const Text('Bitir')),
                const Spacer(),
                Text('${_current+1}/${_questions.length}'),
              ],
            )
          ],
        ),
      ),
    );
  }
}
