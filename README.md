# 📊 Analytica

**Analytica**, yapay zeka destekli bir siyasi analiz ve haber takip platformudur. Türkiye'deki milletvekillerinin performansını veri odaklı algoritmalarla analiz eder, meclis faaliyetlerini takip eder ve güncel haberleri kategorize ederek sunar.

![Analytica Banner](assets/images/banner_placeholder.png)

## 🌟 Özellikler

### 🤖 AI Destekli Puanlama Sistemi
Milletvekillerini sadece oylamalara katılımıyla değil, meclis kürsüsündeki performanslarına göre değerlendiriyoruz.
- **Fair Scoring Algoritması**: Habercilik ve popülist söylemlerden arındırılmış, veri odaklı puanlama.
- **Komisyon Bonusları**: Başkan, başkan vekili ve üye milletvekillerine ekstra puanlar.
- **Penaltı Sistemi**: Meclis faaliyetlerine katılmayan "Hayalet Vekiller" için puan düşümü.

### 📰 Akıllı Haber Akışı
- **Hibrit Haber Motoru**: NewsAPI.org entegrasyonu ile 9 farklı kategoride (Gündem, Politika, Ekonomi, Eğitim vb.) zengin içerik.
- **Cache Sistemi**: Firestore tabanlı önbellekleme sayesinde hızlı yükleme ve düşük API maliyeti.
- **Duygu Analizi**: Haber metinleri üzerinde AI tabanlı sentiment analizi (Pozitif/Negatif/Nötr).

### 📈 Veri Görselleştirme
- **Parti Sıralamaları**: Partilerin ortalama performans grafikleri.
- **Milletvekili Sıralaması**: Vekillerin performans puanına göre sıralı listesi (Detaylı profiller yakında).
- **Finansal Veriler**: Yan menüde (Drawer) anlık döviz ve altın kurları.

---

## 🏗️ Mimari

Proje modern ve ölçeklenebilir bir mimari üzerine kurulmuştur:

- **Frontend**: Flutter (Dart) - Cross-platform mobil uygulama.
- **Backend**: Python - Veri kazıma (scraping), analiz ve skorlama motoru.
- **Database**: Firebase Firestore - Gerçek zamanlı veri tabanı ve önbellek.
- **AI/ML**: Google Gemini API & NLP kütüphaneleri - Metin analizi ve özetleme.

---

## 🚀 Kurulum

### Gereksinimler
- Flutter SDK (3.0+)
- Python (3.11+)
- Firebase CLI
- NewsAPI Key

### 1. Projeyi Klonlayın
```bash
git clone https://github.com/username/analytica.git
cd analytica
```

### 2. Python Backend Kurulumu
Backend servislerini ve scraping araçlarını kurun:
```bash
cd python_backend
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

#### Environment Ayarları
`python_backend/.env` dosyasını oluşturun:
```ini
NEWSAPI_KEY=your_newsapi_key
GEMINI_API_KEY=your_google_gemini_key
FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccountKey.json
```

### 3. Flutter Kurulumu
```bash
cd ..
flutter pub get
flutter run
```

---

## 🔄 Veri Güncelleme İşlemleri (Backend)

Haberleri ve milletvekili puanlarını güncellemek için aşağıdaki scriptleri kullanabilirsiniz:

**Haberleri Güncelle (Cache'le):**
```bash
# python_backend klasöründe
python fetch_news_job.py --force
```

**Milletvekili Puanlarını Hesapla ve Veritabanına Yaz:**
```bash
python rebuild_mps_collection.py
```

---

## 📁 Proje Yapısı

```
analytica/
├── lib/                 # Flutter uygulama kodu
│   ├── models/          # Veri modelleri (Article, MP, vb.)
│   ├── screens/         # UI Ekranları
│   ├── services/        # Frontend servisleri (NewsService, vb.)
│   └── providers/       # State management (Riverpod/Provider)
├── python_backend/      # Backend & Veri İşleme
│   ├── services/        # Python servisleri (Scrapers, Scoring)
│   ├── data/            # JSON veri kaynakları
│   └── cron_jobs/       # Zamanlanmış görev scriptleri
└── firebase/            # Firebase konfigürasyonları
```

## 🔒 Lisans

Bu proje [MIT Lisansı](LICENSE) ile lisanslanmıştır.
