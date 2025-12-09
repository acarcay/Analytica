"""
MP Law Proposal Counter

Kanun tekliflerini milletvekillerine eşleştirir ve Firestore'u günceller.
"""

import json
import re
import logging
from pathlib import Path
from collections import defaultdict
from typing import Dict, List, Tuple

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


def normalize_name(name: str) -> str:
    """İsmi normalize et (büyük/küçük harf, Türkçe karakterler)."""
    return name.strip().upper()


def extract_mp_names(summary: str) -> List[str]:
    """
    Kanun teklifi özetinden milletvekili isimlerini çıkar.
    
    Format örnekleri:
    - "İstanbul Milletvekili Elif ESEN"
    - "CHP Genel Başkanı Manisa Milletvekili Özgür ÖZEL"
    - "Tokat Milletvekili Mustafa ARSLAN, Samsun Milletvekili Orhan KIRCALI ve 54 Milletvekili"
    """
    names = []
    
    # Pattern: "ŞEHIR Milletvekili İSİM SOYAD"
    pattern = r'(\w+)\s+Milletvekili\s+([A-ZÇĞİÖŞÜa-zçğıöşü]+(?:\s+[A-ZÇĞİÖŞÜa-zçğıöşü]+)*)\s+([A-ZÇĞİÖŞÜ]+)'
    
    matches = re.findall(pattern, summary)
    for match in matches:
        city, first_name, last_name = match
        full_name = f"{first_name} {last_name}"
        names.append(normalize_name(full_name))
    
    # Alternatif pattern: direkt isim bulma (BÜYÜK HARF SOYAD)
    if not names:
        # Örn: "Özgür ÖZEL" - bir veya iki kelime isim + TÜM BÜYÜK soyad
        alt_pattern = r'([A-ZÇĞİÖŞÜa-zçğıöşü]+)\s+([A-ZÇĞİÖŞÜ]{2,})\b'
        alt_matches = re.findall(alt_pattern, summary[:200])  # İlk 200 karakter
        for first, last in alt_matches:
            if first.lower() not in ['sayılı', 'kanun', 'dair', 'yapılmasına', 'hakkında', 'ile', 'bazı']:
                names.append(normalize_name(f"{first} {last}"))
    
    return list(set(names))  # Unique


def load_static_mps() -> Dict[str, dict]:
    """Statik MP listesini yükle ve isim -> mp dict'i oluştur."""
    mp_file = Path(__file__).parent / "data" / "mps_static.json"
    
    with open(mp_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    mp_dict = {}
    for city, members in data['cities'].items():
        for member in members:
            name = normalize_name(member['name'])
            mp_dict[name] = {
                'name': member['name'],
                'party': member['party'],
                'city': city
            }
    
    logger.info(f"✅ {len(mp_dict)} milletvekili yüklendi")
    return mp_dict


def count_proposals_per_mp(proposals_file: str) -> Dict[str, int]:
    """Her MP için kanun teklifi sayısını hesapla."""
    
    with open(proposals_file, 'r', encoding='utf-8') as f:
        proposals = json.load(f)
    
    logger.info(f"📋 {len(proposals)} kanun teklifi okundu")
    
    # MP isimlerini yükle
    mp_dict = load_static_mps()
    
    # Sayaç
    proposal_counts = defaultdict(int)
    unmatched = []
    matched_count = 0
    
    for prop in proposals:
        summary = prop.get('summary', '')
        extracted_names = extract_mp_names(summary)
        
        for name in extracted_names:
            if name in mp_dict:
                proposal_counts[name] += 1
                matched_count += 1
            else:
                # Fuzzy match dene - soyad eşleşmesi
                matched = False
                surname = name.split()[-1] if ' ' in name else name
                
                for mp_name in mp_dict.keys():
                    if surname in mp_name:
                        proposal_counts[mp_name] += 1
                        matched = True
                        matched_count += 1
                        break
                
                if not matched:
                    unmatched.append(name)
    
    logger.info(f"✅ {matched_count} eşleşme bulundu")
    logger.info(f"⚠️ {len(set(unmatched))} benzersiz isim eşleştirilemedi")
    
    if unmatched:
        logger.debug(f"Eşleştirilemeyen örnekler: {list(set(unmatched))[:10]}")
    
    return dict(proposal_counts)


def update_firestore_with_counts(counts: Dict[str, int], dry_run: bool = True):
    """Firestore'daki MP'lerin law_proposals alanını güncelle."""
    
    import firebase_admin
    from firebase_admin import credentials, firestore
    
    # Firebase init
    if not firebase_admin._apps:
        cred_path = Path(__file__).parent / "serviceAccountKey.json"
        cred = credentials.Certificate(str(cred_path))
        firebase_admin.initialize_app(cred)
    
    db = firestore.client()
    mps_ref = db.collection('mps')
    
    # Get all mps
    docs = mps_ref.stream()
    
    updated = 0
    for doc in docs:
        data = doc.to_dict()
        mp_name = normalize_name(data.get('name', ''))
        
        if mp_name in counts:
            new_count = counts[mp_name]
            
            if not dry_run:
                doc.reference.update({'law_proposals': new_count})
            
            logger.info(f"  📝 {data['name']}: {new_count} teklif")
            updated += 1
    
    if dry_run:
        logger.info(f"\n⏭️ DRY-RUN: {updated} vekil güncellenecek (Firestore'a yazılmadı)")
    else:
        logger.info(f"\n✅ {updated} vekil güncellendi")
    
    return updated


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='MP Law Proposal Counter')
    parser.add_argument('--proposals', default='data/law_proposals_28.json',
                       help='Kanun teklifleri JSON dosyası')
    parser.add_argument('--update-firestore', action='store_true',
                       help='Firestore\'u güncelle')
    parser.add_argument('--dry-run', action='store_true', default=False,
                       help='Sadece simülasyon yap (varsayılan: gerçek güncelleme)')
    args = parser.parse_args()
    
    # Sayımları hesapla
    counts = count_proposals_per_mp(args.proposals)
    
    # En aktif vekiller
    sorted_counts = sorted(counts.items(), key=lambda x: -x[1])[:20]
    
    print("\n🏆 En Aktif 20 Milletvekili:")
    print("-" * 50)
    for i, (name, count) in enumerate(sorted_counts, 1):
        print(f"  {i:2}. {name}: {count} teklif")
    
    print(f"\n📊 Toplam: {len(counts)} vekil, {sum(counts.values())} teklif eşleşmesi")
    
    # Firestore güncelle
    if args.update_firestore:
        update_firestore_with_counts(counts, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
