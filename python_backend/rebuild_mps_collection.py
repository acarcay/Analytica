"""
Firestore MP Collection Düzeltme
================================

1. Tüm eski MP kayıtlarını sil
2. Yeni adil puanlama ile yeniden oluştur
"""

import json
import logging
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, firestore

from fair_scoring import (
    calculate_fair_score,
    load_proposals_by_mp,
    load_questions_by_mp,
    load_research_by_mp,
    load_commission_memberships,
    normalize_name,
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def init_firestore():
    """Firebase bağlantısını başlat."""
    if not firebase_admin._apps:
        cred = credentials.Certificate("serviceAccountKey.json")
        firebase_admin.initialize_app(cred)
    return firestore.client()


def clean_and_rebuild_mps():
    """MP koleksiyonunu temizle ve yeniden oluştur."""
    
    db = init_firestore()
    data_dir = Path(__file__).parent / "data"
    
    # ADIM 1: Tüm eski kayıtları sil
    logger.info("🗑️ Eski MP kayıtları siliniyor...")
    
    mps_ref = db.collection('mps')
    docs = mps_ref.stream()
    
    delete_count = 0
    batch = db.batch()
    batch_count = 0
    
    for doc in docs:
        batch.delete(doc.reference)
        batch_count += 1
        delete_count += 1
        
        if batch_count >= 400:
            batch.commit()
            batch = db.batch()
            batch_count = 0
    
    if batch_count > 0:
        batch.commit()
    
    logger.info(f"  ✅ {delete_count} eski kayıt silindi")
    
    # ADIM 2: Veri yükle
    logger.info("\n📥 Veriler yükleniyor...")
    mp_proposals = load_proposals_by_mp(data_dir / "law_proposals_28.json")
    mp_questions = load_questions_by_mp(data_dir / "written_questions_28.json")
    mp_research = load_research_by_mp(data_dir / "research_proposals_28.json")
    mp_commissions = load_commission_memberships(data_dir / "commission_members.json")
    
    # MP listesi
    with open(data_dir / "mps_static.json", 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    mps = []
    cities = data.get('cities', {})
    for city, city_mps in cities.items():
        for mp in city_mps:
            mp['city'] = city
            mps.append(mp)
    
    logger.info(f"📊 {len(mps)} vekil oluşturulacak...")
    
    # ADIM 3: Yeni kayıtları oluştur
    stats = {
        'created': 0,
        'government': 0,
        'opposition': 0,
        'ghost': 0,
        'high_impact': 0,
    }
    
    batch = db.batch()
    batch_count = 0
    
    for mp in mps:
        mp_name = mp.get('name', '').strip()
        party = mp.get('party', 'Bağımsız')
        city = mp.get('city', '')
        
        if not mp_name:
            continue
        
        # Parti ismi normalize et
        if party == "AK Parti":
            party = "AKP"
        
        # Normalize name for matching
        normalized = normalize_name(mp_name)
        
        # Verileri bul
        proposals = mp_proposals.get(normalized, [])
        questions = mp_questions.get(normalized, 0)
        research = mp_research.get(normalized, 0)
        commission_bonus = mp_commissions.get(normalized, 0)
        
        # Adil puan hesapla
        result = calculate_fair_score(
            mp_name=mp_name,
            party=party,
            proposals=proposals,
            question_count=questions,
            research_count=research,
            commission_count=commission_bonus,  # Komisyon bonusu doğrudan puan olarak
        )
        
        # Firestore'a yaz (SET - yeni doküman oluştur)
        mp_ref = db.collection('mps').document(mp_name)
        
        mp_data = {
            'name': mp_name,
            'party': party,
            'city': city,
            'current_score': result.calculated_score,
            'scoring_strategy': result.role_strategy,
            'first_signature': result.valid_proposals,
            'support_signature': 0,
            'written_questions': result.question_count,
            'research_proposals': result.research_count,
            'filtered_treaties': result.treaty_count,
            'commission_bonus': commission_bonus,
            'impact_label': result.impact_label,
            'score_explanation': result.explanation,
            'is_passive': result.impact_label == 'Ghost',
            'last_updated': firestore.SERVER_TIMESTAMP,
        }
        
        batch.set(mp_ref, mp_data)
        batch_count += 1
        
        # İstatistikler
        stats['created'] += 1
        
        if result.role_strategy == 'GOVERNMENT':
            stats['government'] += 1
        else:
            stats['opposition'] += 1
        
        if result.impact_label == 'Ghost':
            stats['ghost'] += 1
        elif result.impact_label == 'High':
            stats['high_impact'] += 1
        
        # Batch commit
        if batch_count >= 400:
            batch.commit()
            logger.info(f"  ✅ {stats['created']} vekil oluşturuldu...")
            batch = db.batch()
            batch_count = 0
    
    # Son batch
    if batch_count > 0:
        batch.commit()
    
    logger.info(f"\n✅ TAMAMLANDI!")
    logger.info(f"   Oluşturulan: {stats['created']}")
    logger.info(f"   İktidar: {stats['government']}")
    logger.info(f"   Muhalefet: {stats['opposition']}")
    logger.info(f"   Hayalet Vekil: {stats['ghost']}")
    logger.info(f"   Yüksek Etkili: {stats['high_impact']}")


if __name__ == "__main__":
    clean_and_rebuild_mps()
