"""
Tüm MP'leri Adil Puanlama Sistemi ile Güncelle
==============================================

fair_scoring.py modülünü kullanarak Firestore'u günceller.
"""

import json
import logging
from pathlib import Path
from collections import defaultdict

import firebase_admin
from firebase_admin import credentials, firestore

from fair_scoring import (
    calculate_fair_score,
    load_proposals_by_mp,
    load_questions_by_mp,
    load_research_by_mp,
    normalize_name,
    get_scoring_strategy,
    asdict
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def init_firestore():
    """Firebase bağlantısını başlat."""
    if not firebase_admin._apps:
        cred = credentials.Certificate("serviceAccountKey.json")
        firebase_admin.initialize_app(cred)
    return firestore.client()


def update_all_mps_with_fair_scoring():
    """Tüm MP'leri adil puanlama ile güncelle."""
    
    db = init_firestore()
    data_dir = Path(__file__).parent / "data"
    
    # Veri yükle
    logger.info("📥 Veriler yükleniyor...")
    mp_proposals = load_proposals_by_mp(data_dir / "law_proposals_28.json")
    mp_questions = load_questions_by_mp(data_dir / "written_questions_28.json")
    mp_research = load_research_by_mp(data_dir / "research_proposals_28.json")
    
    # MP listesi - şehir bazlı nested structure
    with open(data_dir / "mps_static.json", 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Tüm MP'leri düz listeye çevir
    mps = []
    cities = data.get('cities', {})
    for city, city_mps in cities.items():
        for mp in city_mps:
            mp['city'] = city
            mps.append(mp)
    
    logger.info(f"📊 {len(mps)} vekil işlenecek...")
    
    # İstatistikler
    stats = {
        'updated': 0,
        'government': 0,
        'opposition': 0,
        'ghost': 0,
        'high_impact': 0,
        'filtered_treaties': 0,
    }
    
    batch = db.batch()
    batch_count = 0
    
    for mp in mps:
        mp_name = mp.get('name', '').strip()
        party = mp.get('party', 'Bağımsız')
        
        if not mp_name:
            continue
        
        # İsmi normalize et
        normalized = normalize_name(mp_name)
        
        # Verileri bul
        proposals = mp_proposals.get(normalized, [])
        questions = mp_questions.get(normalized, 0)
        research = mp_research.get(normalized, 0)
        
        # Adil puan hesapla
        result = calculate_fair_score(
            mp_name=mp_name,
            party=party,
            proposals=proposals,
            question_count=questions,
            research_count=research,
        )
        
        # Firestore güncelle
        mp_ref = db.collection('mps').document(mp_name)
        
        update_data = {
            'current_score': result.calculated_score,
            'fair_score': result.calculated_score,  # Yeni alan
            'scoring_strategy': result.role_strategy,
            'valid_proposals': result.valid_proposals,
            'filtered_treaties': result.treaty_count,
            'question_count': result.question_count,
            'research_count': result.research_count,
            'impact_label': result.impact_label,
            'score_explanation': result.explanation,
            'last_updated': firestore.SERVER_TIMESTAMP,
        }
        
        batch.set(mp_ref, update_data, merge=True)
        batch_count += 1
        
        # İstatistikler
        stats['updated'] += 1
        stats['filtered_treaties'] += result.treaty_count
        
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
            logger.info(f"  ✅ {stats['updated']} vekil güncellendi...")
            batch = db.batch()
            batch_count = 0
    
    # Son batch
    if batch_count > 0:
        batch.commit()
    
    logger.info(f"\n✅ TAMAMLANDI!")
    logger.info(f"   Güncellenen: {stats['updated']}")
    logger.info(f"   İktidar: {stats['government']}")
    logger.info(f"   Muhalefet: {stats['opposition']}")
    logger.info(f"   Hayalet Vekil: {stats['ghost']}")
    logger.info(f"   Yüksek Etkili: {stats['high_impact']}")
    logger.info(f"   Filtrelenen Prosedürel: {stats['filtered_treaties']}")


if __name__ == "__main__":
    update_all_mps_with_fair_scoring()
