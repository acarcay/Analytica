#!/usr/bin/env python3
"""
Milletvekili Puanlama Sistemi - Ana Giriş Noktası

Bu script, milletvekili puanlama batch job'ını çalıştırır.
Haber çekme, AI analizi ve Firestore güncelleme işlemlerini yönetir.

Kullanım:
    python main.py                  # Normal çalıştırma
    python main.py --dry-run        # Firestore'a yazmadan test
    python main.py --mp-id mv_001   # Belirli bir vekili güncelle
    python main.py --seed           # Örnek veri ekle
    python main.py --help           # Yardım
"""

import argparse
import sys
import os
from datetime import datetime
from typing import Optional
import uuid

# Proje kök dizinini path'e ekle
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dotenv import load_dotenv

# Environment variables yükle
load_dotenv()

from config.firebase_config import get_firestore_client, close_firebase_connection, test_connection
from services.firestore_service import get_firestore_service
from services.scoring_engine import get_scoring_engine, seed_sample_data
from models.mp_models import SystemLog


def print_banner():
    """Program banner'ını yazdır."""
    print("""
╔══════════════════════════════════════════════════════════════╗
║       MİLLETVEKİLİ PUANLAMA SİSTEMİ - BATCH JOB              ║
║                     Analytica Backend                         ║
╚══════════════════════════════════════════════════════════════╝
    """)


def run_scoring_job(
    dry_run: bool = False,
    mp_id: Optional[str] = None,
    max_news: int = 5
) -> bool:
    """
    Ana puanlama job'ını çalıştır.
    
    Args:
        dry_run: True ise Firestore'a yazmaz
        mp_id: Belirli bir vekil için çalıştır (None ise hepsi)
        max_news: Her vekil için çekilecek maksimum haber sayısı
        
    Returns:
        bool: Job başarılıysa True
    """
    job_id = str(uuid.uuid4())[:8]
    start_time = datetime.now()
    
    print(f"🆔 Job ID: {job_id}")
    print(f"⏰ Başlangıç: {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"🔧 Mod: {'DRY-RUN' if dry_run else 'PRODUCTION'}")
    print(f"📰 Haber/Vekil: {max_news}")
    
    if mp_id:
        print(f"🎯 Hedef Vekil: {mp_id}")
    
    print("-" * 60)
    
    try:
        # Firestore bağlantısını test et
        print("\n🔌 Firebase bağlantısı kontrol ediliyor...")
        if not test_connection():
            print("❌ Firebase bağlantısı başarısız!")
            print("💡 serviceAccountKey.json dosyasını kontrol edin.")
            return False
        
        # Firestore servisini al
        firestore = get_firestore_service()
        
        # Job başlangıç logu
        if not dry_run:
            firestore.log_info(
                f"Puanlama job'ı başlatıldı",
                job_id=job_id,
                details={'dry_run': dry_run, 'mp_id': mp_id, 'max_news': max_news}
            )
        
        # Scoring engine'i al
        engine = get_scoring_engine(dry_run=dry_run)
        
        # Puanlama işlemini çalıştır
        if mp_id:
            result = engine.process_single_mp(mp_id, max_news)
            results = [result] if result else []
        else:
            results = engine.process_all_mps(max_news_per_mp=max_news)
        
        # İşlem istatistikleri
        end_time = datetime.now()
        duration = (end_time - start_time).total_seconds()
        success_count = sum(1 for r in results if r.success)
        fail_count = len(results) - success_count
        
        print("\n" + "=" * 60)
        print("✅ JOB TAMAMLANDI")
        print("=" * 60)
        print(f"⏱️ Süre: {duration:.1f} saniye")
        print(f"📊 Başarılı: {success_count} | Başarısız: {fail_count}")
        
        # Job bitiş logu
        if not dry_run:
            firestore.log_info(
                f"Puanlama job'ı tamamlandı",
                job_id=job_id,
                duration_ms=int(duration * 1000),
                affected_records=success_count,
                details={
                    'success_count': success_count,
                    'fail_count': fail_count
                }
            )
        
        return True
        
    except Exception as e:
        print(f"\n❌ HATA: {str(e)}")
        
        # Hata logu
        try:
            if not dry_run:
                firestore = get_firestore_service()
                firestore.log_error(
                    f"Puanlama job'ı hata ile sonlandı: {str(e)}",
                    job_id=job_id,
                    details={'error': str(e)}
                )
        except:
            pass
        
        return False
    
    finally:
        # Bağlantıyı kapat
        close_firebase_connection()


def main():
    """Ana fonksiyon."""
    print_banner()
    
    parser = argparse.ArgumentParser(
        description='Milletvekili Puanlama Sistemi - Batch Job',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Örnekler:
  python main.py                    Normal çalıştırma (tüm vekiller)
  python main.py --dry-run          Test modu (Firestore yazılmaz)
  python main.py --mp-id mv_001     Belirli bir vekili güncelle
  python main.py --seed             Örnek veri ekle
  python main.py --max-news 10      Her vekil için 10 haber çek
        """
    )
    
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Firestore\'a yazmadan test modu çalıştır'
    )
    
    parser.add_argument(
        '--mp-id',
        type=str,
        default=None,
        help='Belirli bir milletvekilinin ID\'si (örn: mv_001)'
    )
    
    parser.add_argument(
        '--max-news',
        type=int,
        default=5,
        help='Her vekil için çekilecek maksimum haber sayısı (varsayılan: 5)'
    )
    
    parser.add_argument(
        '--seed',
        action='store_true',
        help='Örnek milletvekili verisi ekle'
    )
    
    parser.add_argument(
        '--test-connection',
        action='store_true',
        help='Sadece Firebase bağlantısını test et'
    )
    
    args = parser.parse_args()
    
    # Sadece bağlantı testi
    if args.test_connection:
        print("🔌 Firebase bağlantısı test ediliyor...")
        if test_connection():
            print("✅ Bağlantı başarılı!")
            sys.exit(0)
        else:
            print("❌ Bağlantı başarısız!")
            sys.exit(1)
    
    # Örnek veri ekleme
    if args.seed:
        print("📝 Örnek veri ekleme modu")
        try:
            seed_sample_data()
            print("\n✅ Örnek veriler eklendi!")
            sys.exit(0)
        except Exception as e:
            print(f"\n❌ Hata: {str(e)}")
            sys.exit(1)
    
    # Ana job'ı çalıştır
    success = run_scoring_job(
        dry_run=args.dry_run,
        mp_id=args.mp_id,
        max_news=args.max_news
    )
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
