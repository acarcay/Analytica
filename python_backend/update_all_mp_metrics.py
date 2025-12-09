"""
MP Metrics Update Script (Revize)

Gelişmiş puanlama formülüyle Firestore'u günceller.

Formül: Puan = (T_ilk × 15) + (T_imza × 2) + (S × 3) + (A × 4) + (H × 1)

T_ilk: İlk İmza Sahibi (teklifi hazırlayan)
T_imza: Destek İmzası (sadece imza atan)
S: Yazılı Soru Önergesi
A: Araştırma Önergesi (şimdilik simüle)
H: Haber Etkisi
"""

import json
import logging
import re
from pathlib import Path
from collections import defaultdict
from typing import Dict, Tuple, List
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


# Puanlama ağırlıkları
FIRST_SIGNATURE_WEIGHT = 15.0   # T_ilk
SUPPORT_SIGNATURE_WEIGHT = 2.0  # T_imza
QUESTION_WEIGHT = 3.0           # S
RESEARCH_WEIGHT = 4.0           # A
NEWS_IMPACT_WEIGHT = 1.0        # H
DEFAULT_NEWS_IMPACT = 5.0


def normalize_name(name: str) -> str:
    """İsmi normalize et - Türkçe karakterleri ASCII'ye çevir."""
    # Türkçe karakter dönüşümü
    tr_map = {
        'ı': 'I', 'İ': 'I', 'i': 'I',
        'ğ': 'G', 'Ğ': 'G',
        'ü': 'U', 'Ü': 'U',
        'ş': 'S', 'Ş': 'S',
        'ö': 'O', 'Ö': 'O',
        'ç': 'C', 'Ç': 'C'
    }
    name = name.strip().upper()
    for tr, en in tr_map.items():
        name = name.replace(tr.upper(), en)
        name = name.replace(tr, en)
    # Fazla boşlukları temizle
    name = ' '.join(name.split())
    return name


def extract_all_mps_from_summary(summary: str) -> List[Tuple[str, bool]]:
    """
    Kanun teklifi özetinden TÜM MP isimlerini çıkar.
    
    Format örneği:
    "CHP Genel Başkanı Manisa Milletvekili Özgür ÖZEL, CHP Grup Başkanvekili Ankara Milletvekili Murat EMİR"
    
    Returns:
        List[(mp_name, is_first_signature)] - İlk isim first_signature, diğerleri support
    """
    first_line = summary.split('\n')[0] if summary else ""
    
    mps = []
    
    # Pattern: Milletvekili sonrası virgül veya " ve " e kadar olan tüm karakterler
    # Örnek: "Milletvekili Özgür ÖZEL, CHP" -> "Özgür ÖZEL"
    # Örnek: "Milletvekili Selma Aliye KAVAF, Manisa" -> "Selma Aliye KAVAF"
    
    pattern = r'Milletvekili\s+([^,]+?)(?:,|$|\s+ve\s+\d+)'
    
    matches = re.findall(pattern, first_line)
    
    for i, match in enumerate(matches):
        is_first = (i == 0)
        name = match.strip()
        
        # Fazla boşlukları temizle
        name = ' '.join(name.split())
        
        # Sadece geçerli isimleri al (en az 2 kelime, 5+ karakter)
        words = name.split()
        if len(words) >= 2 and len(name) >= 5:
            # Sadece isim kısımlarını al (büyük harfli kelimeler)
            name_words = []
            for word in words:
                # Eğer kelime büyük harfli veya ilk harfi büyük ise isim olabilir
                if word[0].isupper() and not any(c.islower() for c in word[1:3] if len(word) > 1):
                    name_words.append(word)
                elif word[0].isupper():
                    name_words.append(word)
            
            if len(name_words) >= 2:
                clean_name = ' '.join(name_words)
                mps.append((normalize_name(clean_name), is_first))
    
    return mps


def load_law_proposal_counts() -> Tuple[Dict[str, int], Dict[str, int]]:
    """
    Kanun tekliflerinden ilk imza ve destek imzası sayılarını yükle.
    
    Returns:
        (first_signature_counts, support_signature_counts)
    """
    proposals_file = Path(__file__).parent / "data" / "law_proposals_28.json"
    
    if not proposals_file.exists():
        logger.warning("⚠️ Kanun teklifleri dosyası bulunamadı")
        return {}, {}
    
    with open(proposals_file, 'r', encoding='utf-8') as f:
        proposals = json.load(f)
    
    first_sig = defaultdict(int)
    support_sig = defaultdict(int)
    
    for prop in proposals:
        summary = prop.get('summary', '')
        mps = extract_all_mps_from_summary(summary)
        
        for mp_name, is_first in mps:
            if is_first:
                first_sig[mp_name] += 1
            else:
                support_sig[mp_name] += 1
    
    logger.info(f"📋 İlk İmza: {sum(first_sig.values())} teklif ({len(first_sig)} vekil)")
    logger.info(f"📋 Destek İmza: {sum(support_sig.values())} teklif ({len(support_sig)} vekil)")
    
    return dict(first_sig), dict(support_sig)


def load_question_counts() -> Dict[str, int]:
    """Yazılı soru önergesi sayılarını yükle."""
    questions_file = Path(__file__).parent / "data" / "written_questions_28.json"
    
    if not questions_file.exists():
        logger.warning("⚠️ Yazılı sorular dosyası bulunamadı")
        return {}
    
    with open(questions_file, 'r', encoding='utf-8') as f:
        questions = json.load(f)
    
    counts = defaultdict(int)
    for q in questions:
        subject = q.get('subject', '')
        if 'Milletvekili' in subject:
            first_line = subject.split('\n')[0]
            parts = first_line.split('Milletvekili')
            if len(parts) > 1:
                name = parts[1].strip().split('\n')[0]
                counts[normalize_name(name)] += 1
    
    logger.info(f"❓ {sum(counts.values())} yazılı soru yüklendi ({len(counts)} vekil)")
    return dict(counts)


def load_research_counts() -> Dict[str, int]:
    """
    Gerçek araştırma önergesi sayılarını yükle.
    """
    research_file = Path(__file__).parent / "data" / "research_proposals_28.json"
    
    if not research_file.exists():
        logger.warning("⚠️ Araştırma önergeleri dosyası bulunamadı, simülasyon kullanılacak")
        return {}
    
    with open(research_file, 'r', encoding='utf-8') as f:
        proposals = json.load(f)
    
    counts = defaultdict(int)
    for p in proposals:
        summary = p.get('summary', '')
        if 'Milletvekili' in summary:
            first_line = summary.split('\n')[0]
            parts = first_line.split('Milletvekili')
            if len(parts) > 1:
                # "ve X Milletvekili" kısmını temizle
                name = parts[1].strip().split('\n')[0]
                name = re.sub(r'\s+ve\s+\d+.*', '', name).strip()
                counts[normalize_name(name)] += 1
    
    logger.info(f"🔍 {sum(counts.values())} araştırma önergesi yüklendi ({len(counts)} vekil)")
    return dict(counts)


def calculate_scores(
    first_sig: Dict[str, int],
    support_sig: Dict[str, int],
    question_counts: Dict[str, int],
    research_counts: Dict[str, int]
) -> Dict[str, Tuple[float, bool, dict]]:
    """
    Tüm vekiller için puan hesapla.
    
    Returns:
        Dict[mp_name, (puan, is_passive, metrics_dict)]
    """
    all_mps = set(first_sig.keys()) | set(support_sig.keys()) | set(question_counts.keys()) | set(research_counts.keys())
    
    scores = {}
    for mp_name in all_mps:
        t_ilk = first_sig.get(mp_name, 0)
        t_imza = support_sig.get(mp_name, 0)
        s = question_counts.get(mp_name, 0)
        a = research_counts.get(mp_name, 0)
        h = DEFAULT_NEWS_IMPACT
        
        # Puan hesapla
        score = (t_ilk * FIRST_SIGNATURE_WEIGHT) + (t_imza * SUPPORT_SIGNATURE_WEIGHT) + \
                (s * QUESTION_WEIGHT) + (a * RESEARCH_WEIGHT) + (h * NEWS_IMPACT_WEIGHT)
        
        # Pasiflik kontrolü (ilk imza, soru, araştırmadan 2+ sıfır)
        zero_count = sum([t_ilk == 0, s == 0, a == 0])
        is_passive = zero_count >= 2
        
        metrics = {
            'first_signature': t_ilk,
            'support_signature': t_imza,
            'written_questions': s,
            'research_proposals': a
        }
        
        scores[mp_name] = (round(score, 2), is_passive, metrics)
    
    return scores


def update_firestore(
    scores: Dict[str, Tuple[float, bool, dict]],
    dry_run: bool = True
):
    """Firestore'u güncelle."""
    import firebase_admin
    from firebase_admin import credentials, firestore
    
    if not firebase_admin._apps:
        cred_path = Path(__file__).parent / "serviceAccountKey.json"
        cred = credentials.Certificate(str(cred_path))
        firebase_admin.initialize_app(cred)
    
    db = firestore.client()
    mps_ref = db.collection('mps')
    
    docs = mps_ref.stream()
    
    updated = 0
    passive_count = 0
    
    for doc in docs:
        data = doc.to_dict()
        mp_name = normalize_name(data.get('name', ''))
        
        if mp_name in scores:
            new_score, is_passive, metrics = scores[mp_name]
            
            update_data = {
                'current_score': new_score,
                'first_signature': metrics['first_signature'],
                'support_signature': metrics['support_signature'],
                'written_questions': metrics['written_questions'],
                'research_proposals': metrics['research_proposals'],
                'is_passive': is_passive
            }
            
            if not dry_run:
                doc.reference.update(update_data)
            
            if is_passive:
                passive_count += 1
            
            updated += 1
    
    mode_text = "DRY-RUN" if dry_run else "✅"
    logger.info(f"\n{mode_text}: {updated} vekil güncellenecek ({passive_count} pasif)")
    
    return updated


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='MP Metrics Update (Revize)')
    parser.add_argument('--dry-run', action='store_true', default=False)
    args = parser.parse_args()
    
    logger.info("📥 Veriler yükleniyor...")
    first_sig, support_sig = load_law_proposal_counts()
    question_counts = load_question_counts()
    research_counts = load_research_counts()  # Gerçek veri
    
    logger.info("\n📊 Puanlar hesaplanıyor...")
    scores = calculate_scores(first_sig, support_sig, question_counts, research_counts)
    
    sorted_scores = sorted(scores.items(), key=lambda x: -x[1][0])[:20]
    
    print("\n🏆 En Yüksek Puanlı 20 Milletvekili:")
    print("-" * 60)
    for i, (name, (score, is_passive, metrics)) in enumerate(sorted_scores, 1):
        passive_tag = " ⚠️" if is_passive else ""
        print(f"  {i:2}. {name}: {score} puan (İlk:{metrics['first_signature']}, Soru:{metrics['written_questions']}){passive_tag}")
    
    passive_mps = [n for n, (_, p, _) in scores.items() if p]
    print(f"\n⚠️ Pasif Vekil Sayısı: {len(passive_mps)}")
    
    print(f"\n📤 Firestore güncelleniyor... (dry_run={args.dry_run})")
    update_firestore(scores, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
