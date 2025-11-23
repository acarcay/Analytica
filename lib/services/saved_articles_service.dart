import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/article.dart';
import '../utils/logging.dart';

class SavedArticlesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Kullanıcının kaydettiği haberleri getir
  Future<List<Article>> getSavedArticles() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final querySnapshot = await _firestore
          .collection('saved_articles')
          .where('userId', isEqualTo: user.uid)
          .orderBy('savedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Article.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLog.e('Kaydedilen haberler alınırken hata: $e');
      return [];
    }
  }

  // Kategoriye göre kaydedilen haberleri getir
  Future<List<Article>> getSavedArticlesByCategory(String category) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final querySnapshot = await _firestore
          .collection('saved_articles')
          .where('userId', isEqualTo: user.uid)
          .where('category', isEqualTo: category)
          .orderBy('savedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Article.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLog.e('Kategoriye göre kaydedilen haberler alınırken hata: $e');
      return [];
    }
  }

  // Haberi kaydet
  Future<bool> saveArticle(Article article, String category) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // Aynı haberi daha önce kaydetmiş mi kontrol et
      final existingQuery = await _firestore
          .collection('saved_articles')
          .where('userId', isEqualTo: user.uid)
          .where('link', isEqualTo: article.link)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        // Zaten kaydedilmiş, kategori güncelle
        await existingQuery.docs.first.reference.update({
          'category': category,
          'savedAt': DateTime.now(),
        });
        return true;
      }

      // Yeni kayıt oluştur
      final articleToSave = article.copyWith(
        category: category,
        savedAt: DateTime.now(),
        userId: user.uid,
      );

      await _firestore
          .collection('saved_articles')
          .add(articleToSave.toFirestore());

      return true;
    } catch (e) {
      AppLog.e('Haber kaydedilirken hata: $e');
      return false;
    }
  }

  // Haberi kaydedilenlerden çıkar
  Future<bool> removeArticle(String articleId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await _firestore
          .collection('saved_articles')
          .doc(articleId)
          .delete();
      return true;
    } catch (e) {
      AppLog.e('Haber silinirken hata: $e');
      return false;
    }
  }

  // Haberin kaydedilip kaydedilmediğini kontrol et
  Future<bool> isArticleSaved(String articleLink) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final querySnapshot = await _firestore
          .collection('saved_articles')
          .where('userId', isEqualTo: user.uid)
          .where('link', isEqualTo: articleLink)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      AppLog.e('Haber kayıt durumu kontrol edilirken hata: $e');
      return false;
    }
  }

  // Kullanıcının kayıtlı haber sayısını getir
  Future<int> getSavedArticlesCount() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      final querySnapshot = await _firestore
          .collection('saved_articles')
          .where('userId', isEqualTo: user.uid)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      AppLog.e('Kayıtlı haber sayısı alınırken hata: $e');
      return 0;
    }
  }

  // Kategori istatistiklerini getir
  Future<Map<String, int>> getCategoryStats() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    try {
      final querySnapshot = await _firestore
          .collection('saved_articles')
          .where('userId', isEqualTo: user.uid)
          .get();

      final Map<String, int> stats = {};
      for (final doc in querySnapshot.docs) {
        final category = doc.data()['category'] as String? ?? 'diger';
        stats[category] = (stats[category] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      AppLog.e('Kategori istatistikleri alınırken hata: $e');
      return {};
    }
  }
}
