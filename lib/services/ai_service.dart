import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import '../utils/logging.dart';

class AIService {
  String? get _apiKey => dotenv.maybeGet('GEMINI_API_KEY');
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const Duration _cacheTtl = Duration(hours: 12);

  Stream<String> getAnalysisStream(String newsText, {String? cacheKey}) async* {
    try {
      // .env yüklenmiş mi ve anahtar mevcut mu kontrol et
      final isEnvLoaded = dotenv.isInitialized;
      if (!isEnvLoaded) {
        yield "Analiz yapılamıyor: Ortam değişkenleri yüklenemedi (.env). Uygulamayı tamamen kapatıp yeniden başlatmayı deneyin.";
        return;
      }
      if (_apiKey == null || _apiKey!.isEmpty) {
        yield "Analiz yapılamıyor: API anahtarı yapılandırılmadı (GEMINI_API_KEY).";
        return;
      }

      // Debug: anahtarın varlığını güvenli şekilde logla (anahtarı yazdırma!)
      AppLog.d('AIService: GEMINI_API_KEY present=${_apiKey != null && _apiKey!.isNotEmpty}');

      // 1) Önbellekten dene
      if (cacheKey != null && cacheKey.isNotEmpty) {
        final cached = await _getCached(cacheKey);
        if (cached != null) {
          // Cached result'u karakter karakter yield et (typewriter effect için)
          for (int i = 0; i < cached.length; i++) {
            yield cached.substring(0, i + 1);
            // Smooth typewriter effect için küçük bir delay
            await Future.delayed(const Duration(milliseconds: 10));
          }
          return;
        }
      }

      // Modeli ve API anahtarını kullanarak servisi başlat
      final model = GenerativeModel(model: 'gemini-2.5-flash-lite', apiKey: _apiKey!);
      // Yapay zekaya göndereceğimiz komut (prompt) - detaylı, yapılandırılmış versiyon
      final prompt = '''
Rol ve Hedef Kitle:
Sen, uluslararası yatırımcılara ve diplomatik misyonlara danışmanlık yapan, Türkiye siyaseti ve ekonomisi üzerine uzmanlaşmış kıdemli bir risk analistisin. Hazırlayacağın analiz, karmaşık durumları netleştirmeyi ve stratejik karar alma süreçlerine ışık tutmayı amaçlamaktadır.

Zaman Çerçevesi ve Bağlam:
Tarih: Eylül 2025. Analizini, Türkiye'nin son genel seçimler sonrası oluşan hassas siyasi dengeleri, kronikleşmiş yüksek enflasyonla mücadelesi ve bölgesel dış politika hamleleri ekseninde şekillenen güncel atmosferi temel alarak yap.

Ana Görev:
Aşağıda sunulan haber metnini ($newsText) analiz ederek kapsamlı bir stratejik değerlendirme raporu hazırla. Raporun aşağıdaki yapıya sadık kalmalıdır:

1) Yönetici Özeti (Executive Summary):
Haberin en kritik çıkarımını ve en olası sonucunu 2-3 cümleyle özetle.

2) Kilit Paydaş Analizi (Stakeholder Analysis):
- Hükümet ve İktidar Bloğu: Bu gelişmeyi neden şimdi gündeme getiriyorlar? Amaçları ne? Olası sonraki adımlar ne olabilir?
- Muhalefet: Bu hamle karşısında nasıl bir strateji izleyebilirler? Bu durum onlar için tehdit mi yoksa fırsat mı?
- Yargı Sistemi: Haberde yargının tutumu nasıl yansıtılıyor? Bu, yargı bağımsızlığı tartışmalarını nasıl etkiler?
- Kamuoyu ve Seçmen Davranışı: Farklı seçmen grupları bu haberi nasıl yorumlayabilir? Algıyı şekillendirme potansiyeli nedir?

3) Senaryo Analizi ve Olası Sonuçlar:
- Kısa Vade (1-6 ay): Siyasi gerilim, piyasa tepkileri, hukuki süreçteki muhtemel gelişmeler.
- Orta Vade (6-24 ay): Bu olayın siyasi dengeler, ittifaklar ve lider pozisyonları üzerindeki potansiyel etkileri.

4) Makro Etkiler ve "Satır Arası" Okuması:
- Ekonomik Yansımalar: Yabancı yatırım, kredi risk primi (CDS), döviz kuru ve enflasyon beklentilerine muhtemel etkiler.
- Sistemsel Anlamı: Güçler ayrılığı, hukukun üstünlüğü ve demokratik normlar çerçevesinde bu haberin ne ifade ettiğine dair değerlendirme.

Analiz İlkeleri:
Analizini tamamen tarafsız, objektif bir dille ve kanıtlara dayalı bir akıl yürütmeyle yap. Spekülatif ifadelerden kaçın; olası sonuçları gerekçelendirerek sun.

Haber Metni:
$newsText
''';

      // Maksimum karakter sınırlaması (uygulama tarafında garanti)
      const int maxResponseChars = 3500;
      final limitedPrompt = '$prompt\n\nLütfen çıktıyı en fazla $maxResponseChars karakter ile sınırla.';
      final content = [Content.text(limitedPrompt)];

      // Stream'den gelen chunk'ları biriktir
      String accumulatedText = '';

      // Stream'i dinle ve chunk'ları yield et
      await for (final response in model.generateContentStream(content)) {
        final chunk = response.text;
        if (chunk != null && chunk.isNotEmpty) {
          accumulatedText += chunk;
          yield accumulatedText;
        }
      }

      // 2) Önbelleğe yaz (stream tamamlandıktan sonra)
      if (cacheKey != null && cacheKey.isNotEmpty && accumulatedText.isNotEmpty) {
        unawaited(_setCached(cacheKey, accumulatedText));
      }
    } catch (e) {
      // Hata olursa konsola yazdır ve hata mesajı yield et
      AppLog.e("Yapay zeka analizi sırasında hata oluştu: $e");
      yield "Analiz sırasında bir hata oluştu. Lütfen daha sonra tekrar deneyin.";
    }
  }

  Future<GenerateContentResponse?> _generateWithRetry(GenerativeModel model, List<Content> content) async {
    const int maxAttempts = 3;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final resp = await model.generateContent(content).timeout(const Duration(seconds: 25));
        return resp;
      } on TimeoutException {
  AppLog.d('AIService: generateContent attempt $attempt timed out');
        if (attempt == maxAttempts) {
    AppLog.d('AIService: generateWithRetry giving up after timeout attempts');
          return null;
        }
      } on NotInitializedError {
        // Paket tarafında zaman zaman bu hata gelebilir: API anahtarı veya istemci hazır değil
  AppLog.d('AIService: NotInitializedError on attempt $attempt');
        if (attempt == maxAttempts) {
          AppLog.d('AIService: generateWithRetry giving up after NotInitializedError');
          return null;
        }
      } catch (e) {
  AppLog.d('AIService: generateContent attempt $attempt error: $e');
        final message = e.toString().toLowerCase();
        final isOverloaded = message.contains('503') || message.contains('unavailable') || message.contains('overloaded');
        if (!isOverloaded && attempt == 1) {
          // 503 dışındaki hatalarda tek deneme daha yapalım
        }
        if (attempt == maxAttempts) {
          AppLog.d('AIService: generateWithRetry giving up after error: $e');
          return null;
        }
      }

      // Artan bekleme süresi (exponential backoff: 500ms, 1s)
      final waitMs = 500 * attempt;
      await Future.delayed(Duration(milliseconds: waitMs));
    }
  AppLog.d('AIService: generateWithRetry finished without success (all attempts exhausted)');
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