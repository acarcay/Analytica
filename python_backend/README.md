# Milletvekili Puanlama Sistemi - Python Backend

Bu Python servisi, Analytica Flutter uygulaması için arka planda çalışarak Firestore veritabanını güncelleyen bir batch job sistemidir.

## 🚀 Kurulum

### 1. Python Ortamını Hazırlayın

```bash
cd python_backend

# Virtual environment oluşturun (önerilen)
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
# veya
.\venv\Scripts\activate  # Windows

# Bağımlılıkları yükleyin
pip install -r requirements.txt
```

### 2. Firebase Service Account Ayarlayın

1. [Firebase Console](https://console.firebase.google.com)'a gidin
2. **analytica-4932f** projesini seçin
3. ⚙️ **Project Settings** > **Service accounts** sekmesi
4. **"Generate new private key"** butonuna tıklayın
5. İndirilen JSON dosyasını `python_backend/` klasörüne taşıyın
6. Dosya adını `serviceAccountKey.json` olarak değiştirin

> ⚠️ **GÜVENLİK UYARISI**: `serviceAccountKey.json` dosyasını asla git'e commit etmeyin!

### 3. Gemini API Key Alın

1. [Google AI Studio](https://aistudio.google.com/app/apikey) adresine gidin
2. **"Create API Key"** butonuna tıklayın
3. API key'i kopyalayın

### 4. Environment Dosyasını Yapılandırın

```bash
# Örnek dosyayı kopyalayın
cp .env.example .env

# .env dosyasını düzenleyin ve API key'inizi ekleyin
# GEMINI_API_KEY=sizin_api_keyiniz
```

## 🎯 Kullanım

### Batch Job Çalıştırma

```bash
# Normal çalıştırma - Firestore'a yazma yapar
python main.py

# Dry-run modu - Sadece simülasyon yapar, Firestore'a yazmaz
python main.py --dry-run

# Belirli bir vekili güncelleme
python main.py --mp-id "vekil_123"
```

### Zamanlanmış Çalıştırma (Cron Job)

```bash
# Her gün saat 03:00'te çalıştır
0 3 * * * /path/to/venv/bin/python /path/to/python_backend/main.py >> /var/log/mp_scoring.log 2>&1
```

## 📁 Proje Yapısı

```
python_backend/
├── config/
│   └── firebase_config.py    # Firebase bağlantı ayarları
├── models/
│   ├── __init__.py
│   └── mp_models.py          # Veri modelleri (MP, NewsAnalysis, Log)
├── services/
│   ├── __init__.py
│   ├── firestore_service.py  # Firestore CRUD operasyonları
│   ├── news_scraper.py       # Google News scraping
│   ├── gemini_analyzer.py    # Gemini AI analiz servisi
│   └── scoring_engine.py     # Puanlama hesaplama motoru
├── main.py                   # Ana giriş noktası
├── requirements.txt          # Python bağımlılıkları
├── .env.example              # Örnek environment dosyası
└── README.md                 # Bu dosya
```

## 📊 Firestore Koleksiyonları

| Koleksiyon | Açıklama |
|------------|----------|
| `mps` | Milletvekili ana verileri ve güncel puanları |
| `news_analysis` | Haber analizleri ve sentiment puanları |
| `logs` | Sistem çalışma logları |

## 🔄 Puanlama Formülü

```
Yeni Puan = (Kanun Teklifi Sayısı × 10) + (Haber Etki Puanı Ortalaması)
```

- **Kanun Teklifi Sayısı**: Simüle edilmiş TBMM verisi
- **Haber Etki Puanı**: Gemini AI tarafından 1-10 arası verilen siyasi etki puanı

## 🐛 Sorun Giderme

### Firebase Bağlantı Hatası
- `serviceAccountKey.json` dosyasının doğru konumda olduğundan emin olun
- Dosya izinlerini kontrol edin

### Gemini API Hatası
- API key'in geçerli olduğunu doğrulayın
- Rate limit'e takılmadığınızdan emin olun

### News Scraping Hatası
- İnternet bağlantınızı kontrol edin
- Google News erişim kısıtlamalarını kontrol edin
