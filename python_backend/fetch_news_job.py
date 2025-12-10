#!/usr/bin/env python3
"""
Haber Aggregation Job
NewsAPI.org'dan haberleri çekip Firestore'a cache'ler.

Kullanım:
    python fetch_news_job.py          # Normal çalıştırma (cache kontrolü yapar)
    python fetch_news_job.py --force  # Cache'i yoksay, zorla güncelle
"""

import sys
import argparse

from services.newsapi_service import NewsApiService, NewsCacheService
from services.rss_service import RssNewsService


def run_news_aggregation(force: bool = False) -> dict:
    """
    NewsAPI.org ve RSS kaynaklarından haberleri çeker, birleştirir ve Firestore'a cache'ler.
    """
    stats = {
        'categories_updated': 0,
        'total_articles': 0,
        'skipped': 0,
        'errors': 0
    }

    try:
        news_api = NewsApiService()
        rss_service = RssNewsService()
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
        
        # RSS Haberlerini çek (Hızlı olduğu için topluca çekiyoruz)
        print("\n📡 RSS Haberleri toplanıyor...")
        rss_news_map = rss_service.fetch_all_rss_news()
        
        # Haberleri çek ve kaydet
        for category in categories_to_update:
            print(f"\n🔄 Kategori işleniyor: {category}")
            
            # 1. NewsAPI'den çek
            api_articles = news_api.fetch_news(category)
            
            # 2. RSS'den bu kategoriye ait olanları al
            rss_articles = rss_news_map.get(category, [])
            if rss_articles:
                print(f"   ➕ RSS'den eklenen: {len(rss_articles)} haber")
            
            # 3. Birleştir ve Deduplicate et
            all_articles = []
            seen_urls = set()
            
            # Önce RSS haberlerini ekle (daha güncel olabilirler)
            for article in rss_articles:
                url = article.get('url')
                if url and url not in seen_urls:
                    all_articles.append(article)
                    seen_urls.add(url)
            
            # Sonra API haberlerini ekle
            dummy_count = 0
            for article in api_articles:
                url = article.get('url')
                if url and url not in seen_urls:
                    all_articles.append(article)
                    seen_urls.add(url)
                else:
                    dummy_count += 1
            
            if dummy_count > 0:
                 print(f"   🗑️ {dummy_count} mükerrer haber çıkarıldı")

            if all_articles:
                # Tarihe göre yeniden sırala (en yeni en üstte)
                # Basit string karşılaştırması yeterli olmayabilir ama format ISO ise çalışır.
                # Emin olmak için reverse yapmıyoruz, zaten kaynaklar sıralı dönüyor.
                # Ancak birleştirme sonrası sıralamak iyi olur.
                try:
                    all_articles.sort(key=lambda x: x.get('publishedAt', ''), reverse=True)
                except:
                    pass # Sıralama hatası olursa olduğu gibi bırak
                
                if cache_service.save_news(category, all_articles):
                    stats['categories_updated'] += 1
                    stats['total_articles'] += len(all_articles)
                    print(f"   ✅ Kaydedilen toplam: {len(all_articles)}")
                else:
                    stats['errors'] += 1
            else:
                print(f"   ⚠️ Hiç haber bulunamadı")
                stats['errors'] += 1
        
        print("\n" + "=" * 50)
        print("📊 SONUÇ:")
        print(f"   ✅ Güncellenen: {stats['categories_updated']} kategori")
        print(f"   📰 Toplam haber: {stats['total_articles']}")
        print(f"   ⏭️ Atlanan: {stats['skipped']}")
        print(f"   ❌ Hata: {stats['errors']}")
        
        return stats

    except Exception as e:
        print(f"❌ Haber toplama sırasında kritik hata: {e}")
        stats['errors'] += 1
        return stats


def main():
    parser = argparse.ArgumentParser(
        description='NewsAPI.org haberlerini çekip Firestore\'a cache\'ler'
    )
    parser.add_argument(
        '--force', '-f',
        action='store_true',
        help='Cache kontrolü yapma, tüm kategorileri zorla güncelle'
    )
    
    args = parser.parse_args()
    
    try:
        stats = run_news_aggregation(force=args.force)
        
        # Exit code: hata varsa 1, yoksa 0
        if stats.get('errors', 0) > 0:
            sys.exit(1)
        sys.exit(0)
        
    except KeyboardInterrupt:
        print("\n\n⚠️ İşlem kullanıcı tarafından iptal edildi")
        sys.exit(130)
    except Exception as e:
        print(f"\n❌ Kritik hata: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
