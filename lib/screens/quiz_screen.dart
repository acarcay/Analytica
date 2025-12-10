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
    if (mounted) {
      setState(() {
        _questions = fetched;
        _loading = false;
        _current = 0;
        _answers.clear();
      });
    }
  }

  void _select(int idx) {
    final q = _questions[_current];
    setState(() { _answers[q.id] = idx; });
  }

  void _next() {
    if (_current < _questions.length - 1) setState(() { _current++; });
  }

  void _prev() {
    if (_current > 0) setState(() { _current--; });
  }

  void _shuffle() {
    setState(() {
      _questions = List.from(_questions)..shuffle(Random());
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
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => QuizResultScreen(correct: correct, total: _questions.length, onRetry: _shuffle)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: LoadingAnimation()));
    if (_questions.isEmpty) return const Scaffold(body: Center(child: Text("Soru bulunamadı")));

    final q = _questions[_current];
    final selected = _answers[q.id];
    final isCorrect = selected != null && selected == q.correctIndex;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Quiz', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _shuffle, icon: const Icon(Icons.shuffle)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            LinearProgressIndicator(
              value: (_current + 1) / _questions.length,
              minHeight: 6,
              backgroundColor: colorScheme.surfaceContainerHighest,
              color: colorScheme.primary,
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Soru ${_current + 1} / ${_questions.length}",
                      style: TextStyle(color: colorScheme.outline),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      q.question,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
                    ...List.generate(q.options.length, (i) {
                      final isSelected = selected == i;
                      // Logic: 
                      // If user answered:
                      // - Correct option gets GREEN
                      // - Selected option (if WRONG) gets RED
                      // - Others default
                      Color? cardColor;
                      Color? borderColor;
                      
                      if (selected != null) {
                         if (i == q.correctIndex) {
                           cardColor = Colors.green.withValues(alpha: 0.1);
                           borderColor = Colors.green;
                         } else if (isSelected && !isCorrect) {
                           cardColor = Colors.red.withValues(alpha: 0.1);
                           borderColor = Colors.red;
                         }
                      } else if (isSelected) {
                         cardColor = colorScheme.primaryContainer;
                         borderColor = colorScheme.primary;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: selected == null ? () => _select(i) : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardColor ?? colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: borderColor ?? Colors.transparent, 
                                width: 2
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: borderColor ?? colorScheme.surfaceContainerHighest,
                                  child: Text(
                                    String.fromCharCode(65 + i), // A, B, C...
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: borderColor != null ? Colors.white : colorScheme.onSurface,
                                      fontSize: 12
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(child: Text(q.options[i], style: const TextStyle(fontSize: 16))),
                                if (selected != null && i == q.correctIndex)
                                   const Icon(Icons.check_circle, color: Colors.green),
                                if (selected != null && isSelected && !isCorrect)
                                   const Icon(Icons.cancel, color: Colors.red),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    
                    if (selected != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.info_outline, size: 20, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text("Açıklama", style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                            ]),
                            const SizedBox(height: 8),
                            Text(q.explanation),
                          ],
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
            
            // Bottom Buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                   if (_current > 0)
                     TextButton(onPressed: _prev, child: const Text("Önceki")),
                   const Spacer(),
                   if (_current < _questions.length - 1)
                     FilledButton.icon(
                       onPressed: _next, 
                       label: const Text("Sonraki"),
                       icon: const Icon(Icons.arrow_forward),
                     )
                   else
                     FilledButton.icon(
                       onPressed: _finish,
                       label: const Text("Bitir"),
                       icon: const Icon(Icons.check),
                       style: FilledButton.styleFrom(backgroundColor: Colors.green),
                     ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
