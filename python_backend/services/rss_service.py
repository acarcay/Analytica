"""
RSS Haber Servisi
Belirtilen RSS kaynaklarından haberleri çeker ve parse eder.
"""

import feedparser
import requests
from bs4 import BeautifulSoup
from datetime import datetime
from typing import List, Dict, Any, Optional
import time

class RssNewsService:
    """RSS feed'lerinden haber çeken servis."""
    
    # RSS Kaynakları Konfigürasyonu
    RSS_SOURCES = [
        # Gündem (Türkçe Kaynaklar)
        {
            'name': 'BBC Türkçe',
            'url': 'http://feeds.bbci.co.uk/turkce/rss.xml',
            'category': 'gundem',
            'lang': 'tr'
        },
        {
            'name': 'TRT Haber',
            'url': 'https://www.trthaber.com/sondakika.rss',
            'category': 'gundem',
            'lang': 'tr'
        },
        {
            'name': 'Cumhuriyet',
            'url': 'https://www.cumhuriyet.com.tr/rss/son_dakika.xml',
            'category': 'gundem',
            'lang': 'tr'
        },
        # Dünya (Global Kaynaklar)
        {
            'name': 'New York Times',
            'url': 'https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml',
            'category': 'dunya',
            'lang': 'en'
        },
        {
            'name': 'The Guardian',
            'url': 'https://www.theguardian.com/world/rss',
            'category': 'dunya',
            'lang': 'en'
        }
    ]
    
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (compatible; Analytica/1.0; +http://analyticanews.com)'
        })

    def fetch_all_rss_news(self) -> Dict[str, List[Dict[str, Any]]]:
        """
        Tüm tanımlı RSS kaynaklarından haberleri çeker.
        
        Returns:
            Dict[str, List[Dict]]: Kategoriye göre gruplanmış haber listesi
        """
        all_news = {}
        
        for source in self.RSS_SOURCES:
            category = source['category']
            if category not in all_news:
                all_news[category] = []
                
            print(f"📡 RSS Çekiliyor: {source['name']} ({source['url']})...")
            articles = self._fetch_feed(source)
            all_news[category].extend(articles)
            print(f"   ✅ {len(articles)} haber alındı.")
            
        return all_news

    def _fetch_feed(self, source_config: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Tek bir RSS feed'ini çeker ve parse eder."""
        try:
            feed = feedparser.parse(source_config['url'])
            articles = []
            
            for entry in feed.entries[:20]: # Her kaynaktan en son 20 haber
                article = self._parse_entry(entry, source_config)
                if article:
                    articles.append(article)
                    
            return articles
        except Exception as e:
            print(f"❌ RSS Hatası ({source_config['name']}): {str(e)}")
            return []

    def _parse_entry(self, entry: Any, source_config: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """RSS entry'sini standart haber formatına dönüştürür."""
        try:
            title = entry.get('title', '')
            link = entry.get('link', '')
            
            if not title or not link:
                return None
                
            # Tarih parse etme
            published_at = None
            if hasattr(entry, 'published_parsed') and entry.published_parsed:
                published_at = datetime(*entry.published_parsed[:6]).isoformat()
            elif hasattr(entry, 'updated_parsed') and entry.updated_parsed:
                published_at = datetime(*entry.updated_parsed[:6]).isoformat()
            else:
                published_at = datetime.now().isoformat()

            # Görsel bulma
            image_url = self._extract_image(entry)
            
            # Eğer RSS'te görsel yoksa, sayfaya gidip OG tag'ine bak (Opsiyonel, yavaş olabilir)
            # Performans için sadece görsel bulunamadıysa ve çok yavaşlatmamak adına basit bir request atılabilir.
            # Şimdilik sadece RSS verisi ile yetinelim, scripten istenirse aktif edilebilir.
            if not image_url:
                image_url = self._fetch_og_image(link)

            description = entry.get('summary', '') or entry.get('description', '')
            # HTML taglerini temizle (basitçe)
            if description:
                soup = BeautifulSoup(description, 'html.parser')
                description = soup.get_text()[:200] + '...'

            return {
                'title': title,
                'description': description,
                'url': link,
                'source': source_config['name'],
                'imageUrl': image_url,
                'publishedAt': published_at,
                'category': source_config['category']
            }
        except Exception as e:
            print(f"⚠️ Entry parse hatası: {str(e)}")
            return None

    def _extract_image(self, entry: Any) -> Optional[str]:
        """RSS entrysinden görsel URL'i çıkarmaya çalışır."""
        # 1. Media content (Yahoo RSS, vb.)
        if hasattr(entry, 'media_content'):
            for media in entry.media_content:
                if media.get('type', '').startswith('image/') or media.get('medium') == 'image':
                    return media.get('url')
        
        # 2. Media thumbnail
        if hasattr(entry, 'media_thumbnail'):
             if isinstance(entry.media_thumbnail, list) and len(entry.media_thumbnail) > 0:
                 return entry.media_thumbnail[0].get('url')
        
        # 3. Enclosure (Podcast/Media)
        if hasattr(entry, 'enclosures'):
            for enclosure in entry.enclosures:
                if enclosure.get('type', '').startswith('image/'):
                    return enclosure.get('href')

        # 4. Description içindeki img tagi
        if hasattr(entry, 'summary'):
            soup = BeautifulSoup(entry.summary, 'html.parser')
            img = soup.find('img')
            if img and img.get('src'):
                return img['src']
                
        if hasattr(entry, 'description'):
            soup = BeautifulSoup(entry.description, 'html.parser')
            img = soup.find('img')
            if img and img.get('src'):
                return img['src']

        return None

    def _fetch_og_image(self, url: str) -> Optional[str]:
        """Verilen URL'e gidip og:image meta tagini çeker."""
        try:
            # Kısa timeout ile deneme
            response = self.session.get(url, timeout=3)
            if response.status_code == 200:
                soup = BeautifulSoup(response.content, 'html.parser')
                og_image = soup.find('meta', property='og:image')
                if og_image and og_image.get('content'):
                    return og_image['content']
        except Exception:
            pass # Sessizce başarısız ol, görsel yok say
        return None

if __name__ == "__main__":
    # Test bloğu
    service = RssNewsService()
    news = service.fetch_all_rss_news()
    for cat, articles in news.items():
        print(f"\n--- {cat.upper()} ---")
        for article in articles[:3]:
            print(f"- {article['title']}")
            print(f"  Img: {article['imageUrl']}")
