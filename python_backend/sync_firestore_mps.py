"""
Firestore MP Data Sync Script

Firestore'daki mps koleksiyonunu temizler ve 
statik JSON'dan doğru vekil verilerini yükler.
"""

import json
import logging
from pathlib import Path
from datetime import datetime

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def get_static_data_path() -> Path:
    """Statik veri dosyasının yolunu döndür."""
    return Path(__file__).parent / "data" / "mps_static.json"


def generate_mp_id(name: str) -> str:
    """MP için benzersiz ID oluştur."""
    import hashlib
    import re
    name_normalized = name.lower().replace(' ', '_')
    name_normalized = re.sub(r'[^a-z0-9_]', '', name_normalized)
    hash_suffix = hashlib.sha256(name.encode()).hexdigest()[:8]
    return f"mv_{name_normalized[:20]}_{hash_suffix}"


def normalize_party(party: str) -> str:
    """Parti ismini standartlaştır."""
    party_map = {
        'AK Parti': 'AKP',
        'CHP': 'CHP',
        'MHP': 'MHP',
        'İYİ Parti': 'İYİ',
        'DEM PARTİ': 'DEM',
        'YENİ YOL': 'YENİ YOL',
        'HÜDA PAR': 'HÜDA PAR',
        'YENİDEN REFAH': 'YENİDEN REFAH',
        'TİP': 'TİP',
        'DBP': 'DBP',
        'EMEP': 'EMEP',
        'DSP': 'DSP',
        'DP': 'DP',
        'SAADET Partisi': 'SP',
        'BAĞIMSIZ': 'BAĞIMSIZ',
    }
    return party_map.get(party, party)


def load_static_mps():
    """Statik JSON'dan vekilleri yükle."""
    data_path = get_static_data_path()
    
    if not data_path.exists():
        raise FileNotFoundError(f"Statik veri dosyası bulunamadı: {data_path}")
    
    with open(data_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    mps = []
    cities = data.get('cities', {})
    
    for city, members in cities.items():
        for member in members:
            mp_data = {
                'id': generate_mp_id(member['name']),
                'name': member['name'],
                'party': normalize_party(member['party']),
                'constituency': city.title(),
                'current_score': 0.0,
                'law_proposals': 0,
                'term_count': 1,
                'last_updated': datetime.now(),
            }
            mps.append(mp_data)
    
    logger.info(f"✅ {len(mps)} vekil statik veriden yüklendi")
    return mps


def clear_firestore_mps(db):
    """Firestore'daki tüm MP'leri sil."""
    mps_ref = db.collection('mps')
    docs = mps_ref.stream()
    
    deleted = 0
    batch = db.batch()
    batch_count = 0
    
    for doc in docs:
        batch.delete(doc.reference)
        batch_count += 1
        deleted += 1
        
        # Firestore batch limit: 500
        if batch_count >= 400:
            batch.commit()
            batch = db.batch()
            batch_count = 0
            logger.info(f"  🗑️ {deleted} kayıt silindi...")
    
    if batch_count > 0:
        batch.commit()
    
    logger.info(f"✅ Toplam {deleted} eski kayıt silindi")
    return deleted


def upload_mps_to_firestore(db, mps: list):
    """MP'leri Firestore'a yükle."""
    mps_ref = db.collection('mps')
    
    uploaded = 0
    batch = db.batch()
    batch_count = 0
    
    for mp in mps:
        doc_ref = mps_ref.document(mp['id'])
        batch.set(doc_ref, mp)
        batch_count += 1
        uploaded += 1
        
        # Firestore batch limit: 500
        if batch_count >= 400:
            batch.commit()
            batch = db.batch()
            batch_count = 0
            logger.info(f"  ✅ {uploaded} kayıt yüklendi...")
    
    if batch_count > 0:
        batch.commit()
    
    logger.info(f"✅ Toplam {uploaded} vekil Firestore'a yüklendi")
    return uploaded


def sync_firestore():
    """Ana senkronizasyon fonksiyonu."""
    import firebase_admin
    from firebase_admin import credentials, firestore
    
    # Firebase'i başlat
    if not firebase_admin._apps:
        cred_path = Path(__file__).parent / "serviceAccountKey.json"
        if not cred_path.exists():
            raise FileNotFoundError(f"Firebase credentials bulunamadı: {cred_path}")
        
        cred = credentials.Certificate(str(cred_path))
        firebase_admin.initialize_app(cred)
    
    db = firestore.client()
    
    logger.info("🚀 Firestore MP senkronizasyonu başlıyor...")
    
    # 1. Statik veriyi yükle
    mps = load_static_mps()
    
    # 2. Eski verileri sil
    logger.info("\n🗑️ Eski veriler siliniyor...")
    clear_firestore_mps(db)
    
    # 3. Yeni verileri yükle
    logger.info("\n📤 Yeni veriler yükleniyor...")
    upload_mps_to_firestore(db, mps)
    
    logger.info(f"\n✅ Senkronizasyon tamamlandı! {len(mps)} vekil Firestore'da.")
    
    return len(mps)


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Firestore MP Sync')
    parser.add_argument('--dry-run', action='store_true', help='Sadece kontrol et, değişiklik yapma')
    args = parser.parse_args()
    
    if args.dry_run:
        mps = load_static_mps()
        print(f"\n📊 Dry run: {len(mps)} vekil yüklenecek")
        
        # Parti dağılımı
        parties = {}
        for mp in mps:
            parties[mp['party']] = parties.get(mp['party'], 0) + 1
        
        print("\n🏛️ Parti Dağılımı:")
        for party, count in sorted(parties.items(), key=lambda x: -x[1]):
            print(f"  {party}: {count}")
    else:
        sync_firestore()
