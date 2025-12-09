"""
NewsAPI.org Servis Modülü
Türkiye haberlerini çeken ve Firestore'a cache'leyen servis.
"""

import os
import requests
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
from dotenv import load_dotenv

# .env dosyasını yükle
load_dotenv()


class NewsApiService:
    """NewsAPI.org haber servisi."""
    
    BASE_URL = "https://newsapi.org/v2"
    
    # Kategori mapping: Uygulama kategorisi -> NewsAPI parametreleri
    # Kategori mapping: Uygulama kategorisi -> NewsAPI parametreleri
    # NOT: top-headlines country=tr çalışmadığı için (0 sonuç), everything endpoint'ine geçildi.
    CATEGORY_CONFIG = {
        'gundem': {
            'endpoint': 'everything',
            'params': {'q': 'türkiye', 'language': 'tr', 'sortBy': 'publishedAt'}
        },
        'ekonomi': {
            'endpoint': 'everything',
            'params': {'q': 'ekonomi AND türkiye', 'language': 'tr', 'sortBy': 'publishedAt'}
        },
        'politika': {
            'endpoint': 'everything',
            'params': {'q': '(siyaset OR politika OR meclis OR hükümet) AND türkiye', 'language': 'tr', 'sortBy': 'publishedAt'}
        },
        'teknoloji': {
            'endpoint': 'everything',
            'params': {'q': 'teknoloji OR yazılım OR yapay zeka', 'language': 'tr', 'sortBy': 'publishedAt'}
        },
        'spor': {
            'endpoint': 'everything',
            'params': {'q': 'spor OR futbol OR basketbol OR voleybol', 'language': 'tr', 'sortBy': 'publishedAt'}
        },
        'saglik': {
            'endpoint': 'everything',
            'params': {'q': 'sağlık OR tıp OR hastane', 'language': 'tr', 'sortBy': 'publishedAt'}
        },
        'egitim': {
            'endpoint': 'everything',
            'params': {'q': '(eğitim OR okul OR üniversite OR öğrenci) AND türkiye', 'language': 'tr', 'sortBy': 'publishedAt'}
        },
        'dunya': {
            'endpoint': 'top-headlines',
            'params': {'category': 'general', 'language': 'en'}
        },
        'kultur': {
            'endpoint': 'everything',
            'params': {'q': 'kültür OR sanat OR sinema OR tiyatro', 'language': 'tr', 'sortBy': 'publishedAt'}
        }
    }
    
    def __init__(self, api_key: Optional[str] = None):
        """
        NewsAPI servisini initialize et.
        
        Args:
            api_key: NewsAPI.org API key (opsiyonel, .env'den okunabilir)
        """
        self.api_key = api_key or os.getenv('NEWSAPI_KEY')
        if not self.api_key:
            raise ValueError("NEWSAPI_KEY environment variable'ı ayarlanmalı veya api_key parametresi verilmeli")
        
        self.session = requests.Session()
        self.session.headers.update({
            'X-Api-Key': self.api_key,
            'User-Agent': 'Analytica/1.0'
        })
    
    def fetch_news(self, category: str, page_size: int = 30) -> List[Dict[str, Any]]:
        """
        Belirtilen kategori için haberleri çek.
        
        Args:
            category: Kategori adı (gundem, ekonomi, politika, vb.)
            page_size: Sayfa başına haber sayısı (max 100)
            
        Returns:
            List[Dict]: Haber listesi
        """
        config = self.CATEGORY_CONFIG.get(category.lower())
        if not config:
            print(f"⚠️ Bilinmeyen kategori: {category}, 'gundem' kullanılıyor")
            config = self.CATEGORY_CONFIG['gundem']
        
        endpoint = config['endpoint']
        params = config['params'].copy()
        params['pageSize'] = min(page_size, 100)  # Max 100
        
        try:
            url = f"{self.BASE_URL}/{endpoint}"
            response = self.session.get(url, params=params, timeout=15)
            response.raise_for_status()
            
            data = response.json()
            
            if data.get('status') != 'ok':
                print(f"❌ API hatası ({category}): {data.get('message', 'Bilinmeyen hata')}")
                return []
            
            articles = data.get('articles', [])
            
            # Normalize article format
            normalized = []
            for article in articles:
                # Skip articles without title or URL
                if not article.get('title') or not article.get('url'):
                    continue
                
                # Skip "[Removed]" articles (NewsAPI returns these for deleted content)
                if article.get('title') == '[Removed]':
                    continue
                    
                normalized.append({
                    'title': article.get('title'),
                    'description': article.get('description') or '',
                    'url': article.get('url'),
                    'source': article.get('source', {}).get('name', 'Bilinmeyen'),
                    'imageUrl': article.get('urlToImage'),
                    'publishedAt': article.get('publishedAt'),
                    'category': category,
                })
            
            print(f"✅ {category}: {len(normalized)} haber çekildi")
            return normalized
            
        except requests.exceptions.RequestException as e:
            print(f"❌ HTTP hatası ({category}): {str(e)}")
            return []
        except Exception as e:
            print(f"❌ Beklenmeyen hata ({category}): {str(e)}")
            return []
    
    def fetch_all_categories(self, page_size: int = 30) -> Dict[str, List[Dict[str, Any]]]:
        """
        Tüm kategoriler için haberleri çek.
        
        Args:
            page_size: Her kategori için haber sayısı
            
        Returns:
            Dict[str, List[Dict]]: Kategori -> haber listesi
        """
        all_news = {}
        
        for category in self.CATEGORY_CONFIG.keys():
            articles = self.fetch_news(category, page_size)
            all_news[category] = articles
        
        total = sum(len(articles) for articles in all_news.values())
        print(f"\n📊 Toplam: {total} haber çekildi ({len(all_news)} kategori)")
        
        return all_news


class NewsCacheService:
    """Firestore haber cache servisi."""
    
    COLLECTION_NAME = 'news_cache'
    CACHE_DURATION_HOURS = 6
    
    def __init__(self):
        """Firestore client'ı initialize et."""
        from config.firebase_config import get_firestore_client
        self.db = get_firestore_client()
    
    def save_news(self, category: str, articles: List[Dict[str, Any]]) -> bool:
        """
        Haberleri Firestore'a kaydet.
        
        Args:
            category: Kategori adı
            articles: Haber listesi
            
        Returns:
            bool: Başarılıysa True
        """
        try:
            doc_ref = self.db.collection(self.COLLECTION_NAME).document(category)
            doc_ref.set({
                'category': category,
                'articles': articles,
                'article_count': len(articles),
                'updated_at': datetime.now(),
                'expires_at': datetime.now() + timedelta(hours=self.CACHE_DURATION_HOURS)
            })
            return True
        except Exception as e:
            print(f"❌ Firestore kayıt hatası ({category}): {str(e)}")
            return False
    
    def get_news(self, category: str) -> Optional[List[Dict[str, Any]]]:
        """
        Firestore'dan haberleri oku.
        
        Args:
            category: Kategori adı
            
        Returns:
            List[Dict] veya None (cache yoksa veya expire olduysa)
        """
        try:
            doc_ref = self.db.collection(self.COLLECTION_NAME).document(category)
            doc = doc_ref.get()
            
            if not doc.exists:
                return None
            
            data = doc.to_dict()
            expires_at = data.get('expires_at')
            
            # Cache expire kontrolü
            if expires_at and expires_at < datetime.now():
                print(f"⚠️ Cache expire olmuş: {category}")
                return None
            
            return data.get('articles', [])
        except Exception as e:
            print(f"❌ Firestore okuma hatası ({category}): {str(e)}")
            return None
    
    def save_all_news(self, all_news: Dict[str, List[Dict[str, Any]]]) -> int:
        """
        Tüm kategorilerdeki haberleri kaydet.
        
        Args:
            all_news: Kategori -> haber listesi mapping
            
        Returns:
            int: Başarıyla kaydedilen kategori sayısı
        """
        success_count = 0
        
        for category, articles in all_news.items():
            if self.save_news(category, articles):
                success_count += 1
        
        print(f"\n💾 {success_count}/{len(all_news)} kategori Firestore'a kaydedildi")
        return success_count
    
    def is_cache_valid(self, category: str) -> bool:
        """
        Cache'in geçerli olup olmadığını kontrol et.
        
        Args:
            category: Kategori adı
            
        Returns:
            bool: Cache geçerliyse True
        """
        try:
            doc_ref = self.db.collection(self.COLLECTION_NAME).document(category)
            doc = doc_ref.get()
            
            if not doc.exists:
                return False
            
            data = doc.to_dict()
            expires_at = data.get('expires_at')
            
            if expires_at and expires_at > datetime.now():
                return True
            
            return False
        except Exception:
            return False


def run_news_aggregation(force: bool = False) -> Dict[str, int]:
    """
    Haber aggregation job'ını çalıştır.
    
    Args:
        force: True ise cache kontrolü yapma, her halükarda güncelle
        
    Returns:
        Dict: İstatistikler
    """
    print("🚀 Haber aggregation başlatılıyor...")
    print(f"   Zaman: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"   Force: {force}")
    print("-" * 50)
    
    stats = {
        'categories_updated': 0,
        'total_articles': 0,
        'skipped': 0,
        'errors': 0
    }
    
    try:
        news_api = NewsApiService()
        cache_service = NewsCacheService()
        
        # Tüm kategorileri kontrol et
        categories_to_update = []
        
        for category in NewsApiService.CATEGORY_CONFIG.keys():
            if force or not cache_service.is_cache_valid(category):
                categories_to_update.append(category)
            else:
                print(f"⏭️ {category}: Cache geçerli, atlanıyor")
                stats['skipped'] += 1
        
        if not categories_to_update:
            print("\n✅ Tüm kategoriler güncel, güncelleme gerekmiyor")
            return stats
        
        print(f"\n📥 {len(categories_to_update)} kategori güncellenecek...")
        
        # Haberleri çek ve kaydet
        for category in categories_to_update:
            articles = news_api.fetch_news(category)
            
            if articles:
                if cache_service.save_news(category, articles):
                    stats['categories_updated'] += 1
                    stats['total_articles'] += len(articles)
                else:
                    stats['errors'] += 1
            else:
                stats['errors'] += 1
        
        print("\n" + "=" * 50)
        print("📊 SONUÇ:")
        print(f"   ✅ Güncellenen: {stats['categories_updated']} kategori")
        print(f"   📰 Toplam haber: {stats['total_articles']}")
        print(f"   ⏭️ Atlanan: {stats['skipped']}")
        print(f"   ❌ Hata: {stats['errors']}")
        
        return stats
        
    except Exception as e:
        print(f"\n❌ Kritik hata: {str(e)}")
        stats['errors'] += 1
        return stats


if __name__ == "__main__":
    # Test: Tek kategori çekme
    import sys
    
    if len(sys.argv) > 1:
        category = sys.argv[1]
        print(f"Test: {category} kategorisi çekiliyor...")
        service = NewsApiService()
        articles = service.fetch_news(category)
        for i, article in enumerate(articles[:3], 1):
            print(f"\n{i}. {article['title'][:60]}...")
            print(f"   Kaynak: {article['source']}")
    else:
        print("Kullanım: python newsapi_service.py <kategori>")
        print("Örnek: python newsapi_service.py gundem")
