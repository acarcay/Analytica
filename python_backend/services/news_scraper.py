"""
Haber Scraping Modülü
Google News ve BeautifulSoup4 kullanarak haber çekme servisi.
"""

import time
from typing import List, Dict, Any, Optional
from dataclasses import dataclass
from datetime import datetime
import requests
from bs4 import BeautifulSoup

try:
    from GoogleNews import GoogleNews
    GOOGLE_NEWS_AVAILABLE = True
except ImportError:
    GOOGLE_NEWS_AVAILABLE = False
    print("⚠️ GoogleNews paketi bulunamadı. pip install GoogleNews ile yükleyin.")


@dataclass
class NewsItem:
    """Ham haber verisi."""
    title: str
    url: str
    source: Optional[str] = None
    date: Optional[str] = None
    description: Optional[str] = None
    content: Optional[str] = None  # Sayfa içeriği (scraping sonrası)


class NewsScraper:
    """Google News ve web scraping servisi."""
    
    def __init__(self, language: str = 'tr', region: str = 'TR'):
        """
        Scraper'ı initialize et.
        
        Args:
            language: Haber dili (varsayılan: Türkçe)
            region: Bölge kodu (varsayılan: Türkiye)
        """
        self.language = language
        self.region = region
        self.request_delay = 1.0  # İstekler arası bekleme süresi (saniye)
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
        }
    
    def search_news_for_mp(
        self, 
        mp_name: str, 
        max_results: int = 10,
        period: str = '7d'
    ) -> List[NewsItem]:
        """
        Milletvekili için Google News'te haber ara.
        
        Args:
            mp_name: Milletvekili adı
            max_results: Maksimum sonuç sayısı
            period: Zaman aralığı ('1d', '7d', '1m', '1y')
            
        Returns:
            List[NewsItem]: Bulunan haberler
        """
        if not GOOGLE_NEWS_AVAILABLE:
            print("⚠️ GoogleNews paketi mevcut değil. Simüle edilmiş veri döndürülüyor.")
            return self._get_simulated_news(mp_name, max_results)
        
        try:
            googlenews = GoogleNews(lang=self.language, region=self.region)
            googlenews.set_period(period)
            googlenews.get_news(mp_name)
            
            results = googlenews.results()
            news_items = []
            
            for item in results[:max_results]:
                news_item = NewsItem(
                    title=item.get('title', ''),
                    url=item.get('link', ''),
                    source=item.get('media', ''),
                    date=item.get('date', ''),
                    description=item.get('desc', ''),
                )
                news_items.append(news_item)
            
            googlenews.clear()
            return news_items
            
        except Exception as e:
            print(f"❌ Google News arama hatası ({mp_name}): {str(e)}")
            return self._get_simulated_news(mp_name, max_results)
    
    def scrape_article_content(self, url: str) -> Optional[str]:
        """
        Haber URL'sinden makale içeriğini çek.
        
        Args:
            url: Haber URL'si
            
        Returns:
            str veya None: Makale metni
        """
        try:
            time.sleep(self.request_delay)  # Rate limiting
            
            response = requests.get(url, headers=self.headers, timeout=10)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.content, 'lxml')
            
            # Ortak içerik containerlarını ara
            content_selectors = [
                'article',
                '.article-content',
                '.post-content',
                '.entry-content',
                '.content-body',
                '.story-body',
                '[itemprop="articleBody"]',
                '.news-content',
                '.haberMetni',  # Türk haber siteleri için
                '.detay-icerik',
            ]
            
            article_text = ""
            
            for selector in content_selectors:
                element = soup.select_one(selector)
                if element:
                    # Script ve style etiketlerini kaldır
                    for script in element(['script', 'style', 'aside', 'nav']):
                        script.decompose()
                    
                    paragraphs = element.find_all('p')
                    article_text = ' '.join([p.get_text().strip() for p in paragraphs])
                    
                    if len(article_text) > 100:  # En az 100 karakter
                        break
            
            # Eğer hala içerik bulunamadıysa, tüm paragrafları dene
            if len(article_text) < 100:
                all_paragraphs = soup.find_all('p')
                article_text = ' '.join([p.get_text().strip() for p in all_paragraphs[:20]])
            
            return article_text.strip() if article_text else None
            
        except Exception as e:
            print(f"⚠️ Makale scraping hatası ({url}): {str(e)}")
            return None
    
    def search_and_scrape(
        self, 
        mp_name: str, 
        max_results: int = 5,
        scrape_content: bool = True
    ) -> List[NewsItem]:
        """
        Haber ara ve içeriklerini çek.
        
        Args:
            mp_name: Milletvekili adı
            max_results: Maksimum sonuç sayısı
            scrape_content: İçerik scraping yapılsın mı
            
        Returns:
            List[NewsItem]: İçerikleri çekilmiş haberler
        """
        news_items = self.search_news_for_mp(mp_name, max_results)
        
        if scrape_content:
            for i, item in enumerate(news_items):
                print(f"  📰 Scraping {i+1}/{len(news_items)}: {item.title[:50]}...")
                item.content = self.scrape_article_content(item.url)
        
        return news_items
    
    def _get_simulated_news(self, mp_name: str, count: int = 5) -> List[NewsItem]:
        """
        Test amaçlı simüle edilmiş haber verisi döndür.
        
        Args:
            mp_name: Milletvekili adı
            count: Haber sayısı
            
        Returns:
            List[NewsItem]: Simüle edilmiş haberler
        """
        simulated_titles = [
            f"{mp_name}, yeni kanun teklifini meclise sundu",
            f"{mp_name}'den ekonomi politikalarına sert eleştiri",
            f"TBMM'de {mp_name} ile ilgili önemli gelişme",
            f"{mp_name}, seçim bölgesinde halkla buluştu",
            f"{mp_name}'nin sosyal medya paylaşımı gündem oldu",
            f"Komisyonda {mp_name}'nin önerisi kabul edildi",
            f"{mp_name}: 'Reform şart'",
            f"{mp_name} basın toplantısı düzenledi",
        ]
        
        news_items = []
        for i in range(min(count, len(simulated_titles))):
            news_items.append(NewsItem(
                title=simulated_titles[i],
                url=f"https://example.com/haber/{i+1}",
                source="Simüle Haber Kaynağı",
                date=datetime.now().strftime("%Y-%m-%d"),
                description=f"{mp_name} hakkında önemli gelişmeler...",
                content=f"Bu {mp_name} hakkında simüle edilmiş bir haber içeriğidir. "
                        f"Gerçek haberler çekilemediğinde test amaçlı kullanılır. "
                        f"Milletvekili {mp_name}, son dönemde aktif bir şekilde "
                        f"siyasi çalışmalarını sürdürmektedir."
            ))
        
        return news_items


# Singleton instance
_scraper_instance: Optional[NewsScraper] = None


def get_news_scraper() -> NewsScraper:
    """NewsScraper singleton instance döndür."""
    global _scraper_instance
    if _scraper_instance is None:
        _scraper_instance = NewsScraper()
    return _scraper_instance


if __name__ == "__main__":
    # Test
    scraper = get_news_scraper()
    news = scraper.search_news_for_mp("Kemal Kılıçdaroğlu", max_results=3)
    
    print(f"\n📰 {len(news)} haber bulundu:")
    for item in news:
        print(f"  - {item.title}")
        print(f"    Kaynak: {item.source}")
        print(f"    URL: {item.url}")
        print()
