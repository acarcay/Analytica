// lib/services/news_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/article.dart';
import '../utils/logging.dart';

/// Firestore cache'den haber okuyan servis.
/// Haberler Python backend tarafından NewsAPI.org'dan çekilip cache'lenir.
class NewsService {
  static const String _collectionName = 'news_cache';
  static const Duration _defaultTimeout = Duration(seconds: 10);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Belirtilen kategori için haberleri Firestore cache'den çek.
  /// 
  /// Python backend'deki `fetch_news_job.py` haberleri NewsAPI.org'dan
  /// çekip bu cache'e yazar. Flutter app buradan okur.
  Future<List<Article>> fetchNews(String category) async {
    try {
      // Kategori adını normalize et
      final normalizedCategory = _normalizeCategory(category);
      
      AppLog.d('NewsService: Fetching news for category: $category (normalized: $normalizedCategory)');

      final docRef = _firestore.collection(_collectionName).doc(normalizedCategory);
      final doc = await docRef.get().timeout(_defaultTimeout);

      if (!doc.exists) {
        AppLog.d('NewsService: No cache found for category: $normalizedCategory');
        return [];
      }

      final data = doc.data();
      if (data == null) {
        AppLog.d('NewsService: Empty data for category: $normalizedCategory');
        return [];
      }

      // Cache geçerlilik kontrolü (opsiyonel - backend zaten kontrol ediyor)
      final expiresAt = data['expires_at'] as Timestamp?;
      if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
        AppLog.d('NewsService: Cache expired for category: $normalizedCategory');
        // Expired olsa bile mevcut veriyi göster (stale data better than no data)
      }

      // Articles array'ini parse et
      final articlesData = data['articles'] as List<dynamic>?;
      if (articlesData == null || articlesData.isEmpty) {
        AppLog.d('NewsService: No articles in cache for category: $normalizedCategory');
        return [];
      }

      final articles = articlesData
          .map((item) {
            try {
              return Article.fromNewsApiCache(item as Map<String, dynamic>);
            } catch (e) {
              AppLog.e('NewsService: Error parsing article: $e');
              return null;
            }
          })
          .whereType<Article>()
          .toList();

      AppLog.d('NewsService: Fetched ${articles.length} articles for category: $category');
      return articles;
    } catch (e) {
      AppLog.e('NewsService: Error fetching news: $e');
      // Hata durumunda boş liste döndür (UI loading state gösterebilir)
      return [];
    }
  }

  /// Kategori adını normalize et
  /// Türkçe karakterler ve büyük/küçük harf uyumluluğu
  String _normalizeCategory(String category) {
    // Python backend'deki kategori adlarıyla eşleşmeli
    final mapping = {
      'gündem': 'gundem',
      'ekonomi': 'ekonomi',
      'politika': 'politika',
      'teknoloji': 'teknoloji',
      'spor': 'spor',
      'sağlık': 'saglik',
      'saglik': 'saglik',
      'eğitim': 'egitim',
      'egitim': 'egitim',
      'dünya': 'dunya',
      'dunya': 'dunya',
      'kültür': 'kultur',
      'kultur': 'kultur',
      'general': 'gundem',
    };

    return mapping[category.toLowerCase()] ?? category.toLowerCase();
  }

  /// Tüm kategoriler için cache durumunu kontrol et
  Future<Map<String, bool>> checkCacheStatus() async {
    final categories = ['gundem', 'ekonomi', 'politika', 'teknoloji', 'spor', 'saglik', 'egitim', 'dunya', 'kultur'];
    final status = <String, bool>{};

    for (final category in categories) {
      try {
        final doc = await _firestore.collection(_collectionName).doc(category).get();
        status[category] = doc.exists;
      } catch (e) {
        status[category] = false;
      }
    }

    return status;
  }
}
