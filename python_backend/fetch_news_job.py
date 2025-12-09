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
from services.newsapi_service import run_news_aggregation


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
