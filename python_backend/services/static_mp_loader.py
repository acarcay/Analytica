"""
Static MP Data Loader

Statik JSON dosyasından milletvekili verilerini yükler.
Web scraping'e gerek kalmadan güvenilir veri sağlar.
"""

import json
import hashlib
import re
import logging
from pathlib import Path
from typing import List, Dict, Optional
from dataclasses import dataclass, field

logger = logging.getLogger(__name__)


@dataclass
class StaticMP:
    """Statik milletvekili verisi."""
    name: str
    party: str
    city: str
    
    @property
    def id(self) -> str:
        """Benzersiz ID oluştur."""
        name_normalized = self.name.lower().replace(' ', '_')
        name_normalized = re.sub(r'[^a-z0-9_]', '', name_normalized)
        hash_suffix = hashlib.sha256(self.name.encode()).hexdigest()[:8]
        return f"mv_{name_normalized[:20]}_{hash_suffix}"
    
    @property
    def normalized_party(self) -> str:
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
        return party_map.get(self.party, self.party)


def get_static_data_path() -> Path:
    """Statik veri dosyasının yolunu döndür."""
    return Path(__file__).parent.parent / "data" / "mps_static.json"


def load_all_mps() -> List[StaticMP]:
    """
    Tüm milletvekillerini statik JSON dosyasından yükle.
    
    Returns:
        List[StaticMP]: Milletvekili listesi
    """
    data_path = get_static_data_path()
    
    if not data_path.exists():
        logger.error("Statik veri dosyası bulunamadı: %s", data_path)
        return []
    
    try:
        with open(data_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        mps = []
        cities = data.get('cities', {})
        
        for city, members in cities.items():
            for member in members:
                mp = StaticMP(
                    name=member['name'],
                    party=member['party'],
                    city=city.title()
                )
                mps.append(mp)
        
        logger.info("✅ %d milletvekili yüklendi (%d şehir)", len(mps), len(cities))
        return mps
        
    except json.JSONDecodeError as e:
        logger.error("JSON parse hatası: %s", e)
        return []
    except Exception as e:
        logger.error("Veri yükleme hatası: %s", e)
        return []


def load_mps_by_city() -> Dict[str, List[StaticMP]]:
    """
    Milletvekillerini şehirlere göre grupla.
    
    Returns:
        Dict[str, List[StaticMP]]: Şehir -> MP listesi
    """
    mps = load_all_mps()
    result = {}
    
    for mp in mps:
        if mp.city not in result:
            result[mp.city] = []
        result[mp.city].append(mp)
    
    return result


def load_mps_by_party() -> Dict[str, List[StaticMP]]:
    """
    Milletvekillerini partilere göre grupla.
    
    Returns:
        Dict[str, List[StaticMP]]: Parti -> MP listesi
    """
    mps = load_all_mps()
    result = {}
    
    for mp in mps:
        party = mp.normalized_party
        if party not in result:
            result[party] = []
        result[party].append(mp)
    
    return result


def get_party_distribution() -> Dict[str, int]:
    """
    Parti dağılımını al.
    
    Returns:
        Dict[str, int]: Parti -> Vekil sayısı
    """
    mps_by_party = load_mps_by_party()
    return {party: len(members) for party, members in mps_by_party.items()}


def search_mp(query: str) -> List[StaticMP]:
    """
    İsimle milletvekili ara.
    
    Args:
        query: Arama terimi
        
    Returns:
        List[StaticMP]: Eşleşen milletvekilleri
    """
    mps = load_all_mps()
    query_lower = query.lower()
    
    return [mp for mp in mps if query_lower in mp.name.lower()]


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    # Test
    mps = load_all_mps()
    print(f"\n📊 Toplam {len(mps)} milletvekili")
    
    # Parti dağılımı
    distribution = get_party_distribution()
    print("\n🏛️ Parti Dağılımı:")
    for party, count in sorted(distribution.items(), key=lambda x: -x[1]):
        print(f"  {party}: {count}")
    
    # İlk 5 vekil
    print("\n📋 İlk 5 Milletvekili:")
    for mp in mps[:5]:
        print(f"  - {mp.name} ({mp.normalized_party}) - {mp.city}")
