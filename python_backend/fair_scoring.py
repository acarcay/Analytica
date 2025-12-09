"""
Adil ve Bağlam-Duyarlı Puanlama Sistemi
======================================

İktidar-muhalefet dinamiklerini anlayan, prosedürel işlemleri filtreleyen
ve rol bazlı ağırlıklandırma yapan gelişmiş puanlama sistemi.

Algoritma Kuralları:
1. Prosedür Filtresi - Uluslararası anlaşmalar 0 puan
2. Rol Bazlı Strateji - İktidar yasama, muhalefet denetim ağırlıklı
3. Hayalet Vekil Cezası - Sıfır aktivite = -15 puan
"""

import json
import logging
import re
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import Dict, List, Optional, Tuple
from collections import defaultdict

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# ============================================================================
# SABITLER
# ============================================================================

# İktidar Bloğu
GOVERNMENT_PARTIES = {"AKP", "MHP", "ADALET VE KALKINMA PARTİSİ", "MİLLİYETÇİ HAREKET PARTİSİ"}

# Muhalefet Bloğu
OPPOSITION_PARTIES = {"CHP", "DEM", "İYİ", "YENİ YOL", "TİP", "EMEP", "DBP", "DSP", "DP", 
                      "HÜDA PAR", "YENİDEN REFAH", "BAĞIMSIZ", "SP"}

# Prosedürel Teklif Anahtar Kelimeleri (0 puan verilecek)
PROCEDURAL_KEYWORDS = [
    "Onaylanmasının Uygun Bulunduğuna Dair",
    "Anlaşmanın Onaylanması",
    "Anlaşmasının Onaylanması",
    "Mutabakat Zaptı",
    "Protokolün Onaylanması",
    "Sözleşmenin Onaylanması",
    "Tadil Edilmesine İlişkin",
    "Milletlerarası Andlaşma",
]

# Torba Kanun Anahtar Kelimeleri
OMNIBUS_KEYWORDS = [
    "Bazı Kanunlarda Değişiklik",
    "Çeşitli Kanunlarda Değişiklik",
    "Değişiklik Yapılmasına Dair",
]


# ============================================================================
# PUANLAMA AĞIRLIKLARI
# ============================================================================

@dataclass
class ScoringWeights:
    """Rol bazlı puanlama ağırlıkları."""
    first_signature: float      # Kanun Teklifi İlk İmza
    support_signature: float    # Kanun Teklifi Destek
    question: float             # Yazılı Soru
    research: float             # Meclis Araştırma Önergesi
    commission_bonus: float     # Komisyon Üyeliği Bonusu
    passed_law_bonus: float     # Yasalaşan Teklif Bonusu
    news_weight: float          # Haber Etkisi
    ghost_penalty: float        # Hayalet Vekil Cezası


# İktidar Ağırlıkları
GOVERNMENT_WEIGHTS = ScoringWeights(
    first_signature=15.0,
    support_signature=3.0,
    question=0.5,               # İktidar için düşük (parti disiplini)
    research=2.0,
    commission_bonus=15.0,
    passed_law_bonus=20.0,      # Sadece iktidar yasalaştırabilir
    news_weight=1.0,
    ghost_penalty=-15.0,
)

# Muhalefet Ağırlıkları
OPPOSITION_WEIGHTS = ScoringWeights(
    first_signature=10.0,       # Reddedilse bile efordur
    support_signature=2.0,
    question=3.0,               # Muhalefet için yüksek (denetim)
    research=4.0,               # Meclis Araştırma Önergesi
    commission_bonus=0.0,       # Komisyon üyeliği genelde iktidardan
    passed_law_bonus=0.0,       # Muhalefet yasası geçmez
    news_weight=1.0,
    ghost_penalty=-15.0,
)


# ============================================================================
# YARDIMCI FONKSİYONLAR
# ============================================================================

def normalize_name(name: str) -> str:
    """İsmi normalize et - Türkçe karakterleri ASCII'ye çevir."""
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
    return ' '.join(name.split())


def get_scoring_strategy(party: str) -> Tuple[str, ScoringWeights]:
    """Parti bazlı puanlama stratejisi belirle."""
    party_upper = party.upper().strip()
    
    if party_upper in GOVERNMENT_PARTIES or any(g in party_upper for g in GOVERNMENT_PARTIES):
        return "GOVERNMENT", GOVERNMENT_WEIGHTS
    else:
        return "OPPOSITION", OPPOSITION_WEIGHTS


def is_procedural_proposal(summary: str) -> bool:
    """Uluslararası anlaşma/prosedürel teklif mi?"""
    summary_upper = summary.upper()
    for keyword in PROCEDURAL_KEYWORDS:
        if keyword.upper() in summary_upper:
            return True
    return False


def is_omnibus_proposal(summary: str) -> bool:
    """Torba kanun mu?"""
    summary_upper = summary.upper()
    for keyword in OMNIBUS_KEYWORDS:
        if keyword.upper() in summary_upper:
            return True
    return False


# ============================================================================
# PUANLAMA MOTORU
# ============================================================================

@dataclass
class FairScoreResult:
    """Adil puanlama sonucu."""
    mp_id: str
    calculated_score: float
    role_strategy: str              # "GOVERNMENT" | "OPPOSITION"
    valid_proposals: int            # Prosedürel olmayan teklifler
    treaty_count: int               # Filtrelenen prosedürel teklifler
    omnibus_count: int              # Torba kanun sayısı
    question_count: int
    research_count: int
    impact_label: str               # "High" | "Medium" | "Low" | "Ghost"
    explanation: str


def calculate_fair_score(
    mp_name: str,
    party: str,
    proposals: List[dict],          # İlgili kanun teklifleri
    question_count: int = 0,
    research_count: int = 0,
    news_score: float = 5.0,
    commission_count: int = 0,
) -> FairScoreResult:
    """
    Adil ve bağlam-duyarlı puan hesapla.
    
    Args:
        mp_name: Milletvekili adı
        party: Parti
        proposals: Vekilin imza attığı kanun teklifleri
        question_count: Yazılı soru sayısı
        research_count: Meclis araştırma önergesi sayısı
        news_score: Haber sentiment skoru (0-10)
        commission_count: Komisyon üyeliği sayısı
    
    Returns:
        FairScoreResult
    """
    strategy, weights = get_scoring_strategy(party)
    
    # Prosedürel filtreleme
    valid_proposals = []
    treaty_count = 0
    omnibus_count = 0
    
    for prop in proposals:
        summary = prop.get('summary', '')
        if is_procedural_proposal(summary):
            treaty_count += 1
        elif is_omnibus_proposal(summary):
            omnibus_count += 1
            valid_proposals.append(prop)  # Torba da sayılır ama tek olarak
        else:
            valid_proposals.append(prop)
    
    # İlk imza vs destek ayrımı (şimdilik hepsi ilk imza kabul)
    first_sig_count = len(valid_proposals)
    support_sig_count = 0
    
    # Puan hesaplama
    score = 0.0
    
    # 1. Kanun Teklifleri
    score += first_sig_count * weights.first_signature
    score += support_sig_count * weights.support_signature
    
    # 2. Yazılı Sorular
    score += question_count * weights.question
    
    # 3. Araştırma Önergeleri
    score += research_count * weights.research
    
    # 4. Komisyon Bonusu (doğrudan puan olarak eklenir, weight çarpılmaz)
    score += commission_count  # Zaten hesaplanmış bonus
    
    # 5. Haber Etkisi
    score += news_score * weights.news_weight
    
    # 6. Hayalet Vekil Cezası
    total_activity = first_sig_count + question_count + research_count
    if total_activity == 0:
        score += weights.ghost_penalty
    
    # Negatif puan olmasın
    score = max(0, score)
    
    # Etki etiketi
    if total_activity == 0:
        impact_label = "Ghost"
    elif score >= 100:
        impact_label = "High"
    elif score >= 30:
        impact_label = "Medium"
    else:
        impact_label = "Low"
    
    # Açıklama
    if strategy == "GOVERNMENT":
        if total_activity == 0:
            explanation = "İktidar vekili, hiçbir bireysel faaliyeti tespit edilemedi."
        else:
            explanation = f"İktidar vekili, {first_sig_count} kanun teklifi ağırlıklı puanlandı."
    else:
        if total_activity == 0:
            explanation = "Muhalefet vekili, hiçbir bireysel faaliyeti tespit edilemedi."
        else:
            explanation = f"Muhalefet vekili, {question_count} soru ve {research_count} araştırma önergesi ağırlıklı puanlandı."
    
    return FairScoreResult(
        mp_id=mp_name,
        calculated_score=round(score, 1),
        role_strategy=strategy,
        valid_proposals=first_sig_count,
        treaty_count=treaty_count,
        omnibus_count=omnibus_count,
        question_count=question_count,
        research_count=research_count,
        impact_label=impact_label,
        explanation=explanation,
    )


# ============================================================================
# VERİ YÜKLEME
# ============================================================================

def load_proposals_by_mp(proposals_file: Path) -> Dict[str, List[dict]]:
    """
    Kanun tekliflerini MP bazında grupla.
    
    Returns:
        {'ÖZGÜR ÖZEL': [proposal1, proposal2, ...], ...}
    """
    if not proposals_file.exists():
        logger.warning(f"Dosya bulunamadı: {proposals_file}")
        return {}
    
    with open(proposals_file, 'r', encoding='utf-8') as f:
        proposals = json.load(f)
    
    mp_proposals = defaultdict(list)
    
    for prop in proposals:
        summary = prop.get('summary', '')
        first_line = summary.split('\n')[0]
        
        # "Milletvekili" pattern'i bul
        pattern = r'Milletvekili\s+([^,]+?)(?:,|$|\s+ve\s+\d+)'
        matches = re.findall(pattern, first_line)
        
        for i, match in enumerate(matches):
            name = ' '.join(match.split()).strip()
            words = [w for w in name.split() if w and w[0].isupper()]
            if len(words) >= 2:
                clean_name = normalize_name(' '.join(words))
                mp_proposals[clean_name].append(prop)
    
    return dict(mp_proposals)


def load_questions_by_mp(questions_file: Path) -> Dict[str, int]:
    """Yazılı soruları MP bazında say."""
    if not questions_file.exists():
        return {}
    
    with open(questions_file, 'r', encoding='utf-8') as f:
        questions = json.load(f)
    
    mp_counts = defaultdict(int)
    
    for q in questions:
        subject = q.get('subject', '')
        if 'Milletvekili' in subject:
            parts = subject.split('Milletvekili')
            if len(parts) > 1:
                name = parts[1].strip().split('\n')[0]
                name = re.sub(r'\s+ve\s+\d+.*', '', name).strip()
                mp_counts[normalize_name(name)] += 1
    
    return dict(mp_counts)


def load_research_by_mp(research_file: Path) -> Dict[str, int]:
    """Araştırma önergelerini MP bazında say."""
    if not research_file.exists():
        return {}
    
    with open(research_file, 'r', encoding='utf-8') as f:
        research = json.load(f)
    
    mp_counts = defaultdict(int)
    
    for r in research:
        summary = r.get('summary', '')
        if 'Milletvekili' in summary:
            first_line = summary.split('\n')[0]
            parts = first_line.split('Milletvekili')
            if len(parts) > 1:
                name = parts[1].strip().split('\n')[0]
                name = re.sub(r'\s+ve\s+\d+.*', '', name).strip()
                mp_counts[normalize_name(name)] += 1
    
    return dict(mp_counts)


# Komisyon Rol Bonusları
COMMISSION_ROLE_BONUS = {
    "BAŞKAN": 25,
    "BAŞKANVEKİLİ": 20,
    "SÖZCÜ": 18,
    "KATİP": 18,
    "ÜYE": 15,
}

def load_commission_memberships(commissions_file: Path) -> Dict[str, int]:
    """
    Komisyon üyeliklerini MP bazında puanla.
    
    Puanlama:
    - BAŞKAN: 25 puan
    - BAŞKANVEKİLİ: 20 puan
    - SÖZCÜ/KATİP: 18 puan
    - ÜYE: 15 puan
    
    Returns:
        {'CÜNEYT YÜKSEL': 25, 'SÜLEYMAN SOYLU': 25, ...}
    """
    if not commissions_file.exists():
        logger.warning(f"Komisyon dosyası bulunamadı: {commissions_file}")
        return {}
    
    with open(commissions_file, 'r', encoding='utf-8') as f:
        commissions = json.load(f)
    
    mp_bonuses = defaultdict(int)
    
    for commission_name, members in commissions.items():
        for member in members:
            name = member.get('name', '')
            role = member.get('role', 'ÜYE')
            
            normalized = normalize_name(name)
            bonus = COMMISSION_ROLE_BONUS.get(role, 15)
            
            # Birden fazla komisyon üyeliği varsa topla
            mp_bonuses[normalized] += bonus
    
    logger.info(f"  📋 {len(mp_bonuses)} vekil komisyon üyeliği bulundu")
    return dict(mp_bonuses)


# ============================================================================
# MAIN
# ============================================================================

if __name__ == "__main__":
    data_dir = Path(__file__).parent / "data"
    
    # Veri yükle
    logger.info("📥 Veriler yükleniyor...")
    
    mp_proposals = load_proposals_by_mp(data_dir / "law_proposals_28.json")
    mp_questions = load_questions_by_mp(data_dir / "written_questions_28.json")
    mp_research = load_research_by_mp(data_dir / "research_proposals_28.json")
    
    logger.info(f"  📋 {len(mp_proposals)} vekil kanun teklifi verdi")
    logger.info(f"  ❓ {len(mp_questions)} vekil soru önergesi verdi")
    logger.info(f"  🔍 {len(mp_research)} vekil araştırma önergesi verdi")
    
    # Örnek hesaplama - CHP Lideri Özgür Özel
    test_mp = "OZGUR OZEL"
    test_party = "CHP"
    
    result = calculate_fair_score(
        mp_name=test_mp,
        party=test_party,
        proposals=mp_proposals.get(test_mp, []),
        question_count=mp_questions.get(test_mp, 0),
        research_count=mp_research.get(test_mp, 0),
    )
    
    print(f"\n🎯 TEST: {test_mp} ({test_party})")
    print(f"   Strateji: {result.role_strategy}")
    print(f"   Geçerli Teklif: {result.valid_proposals}")
    print(f"   Prosedürel (Filtrelenen): {result.treaty_count}")
    print(f"   Soru: {result.question_count}")
    print(f"   Araştırma: {result.research_count}")
    print(f"   PUAN: {result.calculated_score}")
    print(f"   Etki: {result.impact_label}")
    print(f"   Açıklama: {result.explanation}")
    
    # Numan Kurtulmuş testi
    test_mp2 = "NUMAN KURTULMUS"
    test_party2 = "AKP"
    
    result2 = calculate_fair_score(
        mp_name=test_mp2,
        party=test_party2,
        proposals=mp_proposals.get(test_mp2, []),
        question_count=mp_questions.get(test_mp2, 0),
        research_count=mp_research.get(test_mp2, 0),
    )
    
    print(f"\n🎯 TEST: {test_mp2} ({test_party2})")
    print(f"   Strateji: {result2.role_strategy}")
    print(f"   Geçerli Teklif: {result2.valid_proposals}")
    print(f"   Prosedürel (Filtrelenen): {result2.treaty_count}")
    print(f"   PUAN: {result2.calculated_score}")
    print(f"   Etki: {result2.impact_label}")
    print(f"   Açıklama: {result2.explanation}")
