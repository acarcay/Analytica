// lib/services/quiz_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quiz.dart';

class QuizService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String collection = 'quizzes';

  Future<List<QuizQuestion>> fetchAll() async {
    try {
      final snapshot = await _db.collection(collection).get();
      if (snapshot.docs.isEmpty) return sampleQuizQuestions;
      return snapshot.docs.map((d) => QuizQuestion.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      // fallback to local static sample
      return sampleQuizQuestions;
    }
  }

  Future<void> saveQuestion(QuizQuestion q) async {
    await _db.collection(collection).doc(q.id).set(q.toMap());
  }

  Future<void> deleteQuestion(String id) async {
    await _db.collection(collection).doc(id).delete();
  }
}
