import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';

class AIService {
  String? get _apiKey => dotenv.maybeGet('GEMINI_API_KEY');
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const Duration _cacheTtl = Duration(hours: 12);

  Future<String?> getAnalysis(String newsText, {String? cacheKey}) async {
    try {
      // .env yüklenmiş mi ve anahtar mevcut mu kontrol et
      final isEnvLoaded = dotenv.isInitialized;
      if (!isEnvLoaded) {
        return "Analiz yapılamıyor: Ortam değişkenleri yüklenemedi (.env). Uygulamayı tamamen kapatıp yeniden başlatmayı deneyin.";
      }
      if (_apiKey == null || _apiKey!.isEmpty) {
        return "Analiz yapılamıyor: API anahtarı yapılandırılmadı (GEMINI_API_KEY).";
      }

      // 1) Önbellekten dene
      if (cacheKey != null && cacheKey.isNotEmpty) {
        final cached = await _getCached(cacheKey);
        if (cached != null) {
          return cached;
        }
      }
      // Modeli ve API anahtarını kullanarak servisi başlat
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey!);

      // Yapay zekaya göndereceğimiz komut (prompt)
      final prompt =
        'Sen Türkiye siyaseti ve ekonomisi üzerine uzmanlaşmış bir siyasi analistsin. Şu anki tarih Eylül 2025. Türkiye\'nin, son seçimlerin ardından oluşan yeni siyasi dengeler, yüksek enflasyonla mücadele ve bölgesel dış politika gelişmeleri gibi güncel dinamiklerini göz önünde bulundurarak, aşağıda verilen haber metnini analiz et. Bu haberin; temel aktörler için ne anlama geldiğini, olası kısa ve orta vadeli sonuçlarını ve satır aralarında yatan önemli detayları tarafsız bir şekilde, 3-4 maddelik bir özet halinde sun.\n\n---\n\nHaber Metni:\n$newsText';
      
      final content = [Content.text(prompt)];

      // İsteği gönder ve cevabı bekle (retry/backoff ve timeout ile)
      final response = await _generateWithRetry(model, content);
      final text = response?.text ?? "Analiz şu anda üretilemiyor. Lütfen daha sonra tekrar deneyin.";

      // 2) Önbelleğe yaz
      if (cacheKey != null && cacheKey.isNotEmpty) {
        unawaited(_setCached(cacheKey, text));
      }
      return text;
    } catch (e) {
      // Hata olursa konsola yazdır ve null döndür
      print("Yapay zeka analizi sırasında hata oluştu: $e");
      return "Analiz sırasında bir hata oluştu. Lütfen daha sonra tekrar deneyin.";
    }
  }

  Future<GenerateContentResponse?> _generateWithRetry(GenerativeModel model, List<Content> content) async {
    const int maxAttempts = 3;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final resp = await model.generateContent(content).timeout(const Duration(seconds: 25));
        return resp;
      } on TimeoutException {
        if (attempt == maxAttempts) {
          return null;
        }
      } on NotInitializedError {
        // Paket tarafında zaman zaman bu hata gelebilir: API anahtarı veya istemci hazır değil
        if (attempt == maxAttempts) return null;
      } catch (e) {
        final message = e.toString().toLowerCase();
        final isOverloaded = message.contains('503') || message.contains('unavailable') || message.contains('overloaded');
        if (!isOverloaded && attempt == 1) {
          // 503 dışındaki hatalarda tek deneme daha yapalım
        }
        if (attempt == maxAttempts) {
          return null;
        }
      }

      // Artan bekleme süresi (exponential backoff: 500ms, 1s)
      final waitMs = 500 * attempt;
      await Future.delayed(Duration(milliseconds: waitMs));
    }
    return null;
  }

  // Firestore Cache Helpers
  Future<String?> _getCached(String cacheKey) async {
    try {
      final docId = _encodeKey(cacheKey);
      final doc = await _db.collection('analyses').doc(docId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      final Timestamp? updatedAt = data['updatedAt'] as Timestamp?;
      final String? text = data['text'] as String?;
      if (updatedAt == null || text == null) return null;
      final isFresh = DateTime.now().difference(updatedAt.toDate()) < _cacheTtl;
      return isFresh ? text : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _setCached(String cacheKey, String text) async {
    try {
      final docId = _encodeKey(cacheKey);
      await _db.collection('analyses').doc(docId).set({
        'text': text,
        'updatedAt': FieldValue.serverTimestamp(),
        'key': cacheKey,
      }, SetOptions(merge: true));
    } catch (_) {
      // sessizce yoksay
    }
  }

  String _encodeKey(String input) {
    final bytes = utf8.encode(input);
    return base64UrlEncode(bytes);
  }
}