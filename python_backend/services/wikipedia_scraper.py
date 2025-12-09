"""
Wikipedia TBMM 28. Dönem Milletvekilleri Scraper
Wikipedia'dan tüm milletvekillerini parti ve şehir bilgisiyle çeker.
"""

import re
import hashlib
from typing import List, Optional
from dataclasses import dataclass
from datetime import datetime
from playwright.sync_api import sync_playwright
import time


@dataclass
class TBMMMember:
    """TBMM Milletvekili verisi."""
    name: str
    party: str
    city: str
    detail_url: Optional[str] = None
    
    @property
    def id(self) -> str:
        """Benzersiz ID oluştur."""
        name_normalized = self.name.lower().replace(' ', '_')
        name_normalized = re.sub(r'[^a-z0-9_]', '', name_normalized)
        hash_suffix = hashlib.md5(self.name.encode()).hexdigest()[:6]
        return f"mv_{name_normalized[:20]}_{hash_suffix}"


PARTY_MAP = {
    'ak parti': 'AKP',
    'adalet ve kalkınma partisi': 'AKP',
    'akp': 'AKP',
    'chp': 'CHP',
    'cumhuriyet halk partisi': 'CHP',
    'mhp': 'MHP',
    'milliyetçi hareket partisi': 'MHP',
    'iyi parti': 'İYİ',
    'İyi parti': 'İYİ',
    'iyi': 'İYİ',
    'dem parti': 'DEM',
    'halkların demokratik partisi': 'DEM',
    'hdp': 'DEM',
    'ysp': 'DEM',
    'yeşil sol parti': 'DEM',
    'saadet partisi': 'SP',
    'sp': 'SP',
    'deva partisi': 'DEVA',
    'deva': 'DEVA',
    'gelecek partisi': 'GP',
    'gp': 'GP',
    'tip': 'TİP',
    'türkiye işçi partisi': 'TİP',
    'zafer partisi': 'ZP',
    'zp': 'ZP',
    'bağımsız': 'BAĞIMSIZ',
}


def normalize_party(party_raw: str) -> str:
    """Parti ismini standartlaştır."""
    party_lower = party_raw.lower().strip()
    return PARTY_MAP.get(party_lower, party_raw.strip().upper())


def scrape_wikipedia_mps() -> List[TBMMMember]:
    """Wikipedia'dan TBMM 28. dönem milletvekillerini çek."""
    
    url = "https://tr.wikipedia.org/wiki/TBMM_28._d%C3%B6nem_milletvekilleri_listesi"
    
    print(f"🌐 Wikipedia'ya bağlanılıyor...")
    
    members = []
    
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        page.goto(url, wait_until='networkidle', timeout=30000)
        
        print("📋 Milletvekili tabloları taranıyor...")
        
        # JavaScript ile ana tabloyu (Tablo 5) parse et
        # Başlıklar: Seçim bölgesi | Milletvekili | Seçildiği parti | Değişiklik
        mp_data = page.evaluate('''() => {
            const results = [];
            
            // Tüm wikitableları bul
            const tables = document.querySelectorAll('table.wikitable');
            
            // En fazla satırı olan tablo ana tablo
            let mainTable = null;
            let maxRows = 0;
            
            tables.forEach(table => {
                const rowCount = table.querySelectorAll('tr').length;
                if (rowCount > maxRows) {
                    maxRows = rowCount;
                    mainTable = table;
                }
            });
            
            if (!mainTable) return results;
            
            // Başlıkları analiz et
            const headerRow = mainTable.querySelector('tr');
            const headers = [];
            if (headerRow) {
                headerRow.querySelectorAll('th').forEach(th => {
                    headers.push(th.innerText.trim().toLowerCase());
                });
            }
            
            // Sütun indekslerini bul
            let cityIdx = 0, nameIdx = 1, partyIdx = 2;
            headers.forEach((h, i) => {
                if (h.includes('seçim') || h.includes('bölge')) cityIdx = i;
                if (h.includes('milletvekili') || h.includes('isim')) nameIdx = i;
                if (h.includes('parti') || h.includes('seçildiği')) partyIdx = i;
            });
            
            // Satırları işle
            let currentCity = '';
            const rows = mainTable.querySelectorAll('tr');
            
            rows.forEach((row, idx) => {
                if (idx === 0) return; // Başlık satırını atla
                
                const cells = row.querySelectorAll('td, th');
                if (cells.length < 2) return;
                
                // Şehir hücresi (rowspan olabilir)
                const cityCell = cells[cityIdx];
                if (cityCell && cityCell.innerText.trim()) {
                    const cityText = cityCell.innerText.trim().replace(/\\[.*?\\]/g, '');
                    // Şehir değişti mi kontrol et
                    if (cityText && !cityText.includes('parti') && cityText.length < 30) {
                        currentCity = cityText;
                    }
                }
                
                // İsim hücresini bul
                let nameCell = null;
                let partyCell = null;
                
                // cells dizisini tara
                for (let i = 0; i < cells.length; i++) {
                    const cellText = cells[i].innerText.trim();
                    
                    // İsim tespiti: link içeren veya normal metin
                    const link = cells[i].querySelector('a');
                    if (link && !nameCell) {
                        const linkText = link.innerText.trim();
                        // Parti linki değilse isim olabilir
                        if (linkText && !linkText.includes('Parti') && linkText.length > 3 && linkText.length < 50) {
                            nameCell = cells[i];
                            // Sonraki hücre parti olabilir
                            if (cells[i + 1]) {
                                partyCell = cells[i + 1];
                            }
                        }
                    }
                }
                
                // Parti bilgisini çek
                let party = '';
                if (partyCell) {
                    const partyLink = partyCell.querySelector('a');
                    party = partyLink ? partyLink.innerText.trim() : partyCell.innerText.trim();
                    party = party.replace(/\\[.*?\\]/g, '').trim();
                }
                
                // İsim bilgisini çek
                let name = '';
                if (nameCell) {
                    const nameLink = nameCell.querySelector('a');
                    name = nameLink ? nameLink.innerText.trim() : nameCell.innerText.trim();
                    name = name.replace(/\\[.*?\\]/g, '').trim();
                }
                
                // Geçerli veri varsa ekle
                if (name && name.length > 3 && !name.includes('Parti')) {
                    results.push({
                        name: name,
                        party: party || 'Bilinmiyor',
                        city: currentCity || 'Bilinmiyor'
                    });
                }
            });
            
            return results;
        }''')
        
        print(f"  📊 {len(mp_data)} kayıt bulundu")
        
        browser.close()
    
    # Verileri işle ve tekrarları kaldır
    seen = set()
    for data in mp_data:
        name = data['name']
        if not name or name.lower() in seen:
            continue
        
        seen.add(name.lower())
        
        member = TBMMMember(
            name=name,
            party=normalize_party(data['party']) if data['party'] else 'Bilinmiyor',
            city=data['city'].replace('\n', ' ').strip() if data['city'] else 'Bilinmiyor'
        )
        members.append(member)
    
    print(f"✅ Toplam {len(members)} benzersiz milletvekili bulundu!")
    return members


def save_mps_to_firestore(members: List[TBMMMember]) -> int:
    """Milletvekillerini Firestore'a kaydet."""
    import sys
    import os
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    
    from services.firestore_service import get_firestore_service
    from models.mp_models import MP
    
    firestore = get_firestore_service()
    count = 0
    updated = 0
    
    print(f"\n💾 {len(members)} milletvekili Firestore'a kaydediliyor...")
    
    for member in members:
        try:
            mp = MP(
                id=member.id,
                name=member.name,
                party=member.party,
                current_score=0.0,
                last_updated=datetime.now(),
                constituency=member.city,
                term_count=1,
                law_proposals=0,
                profile_image_url=None
            )
            
            # Mevcut kaydı kontrol et
            existing = firestore.get_mp(member.id)
            if existing:
                # Güncelle (parti bilgisi "Bilinmiyor" değilse)
                if member.party != 'Bilinmiyor' and existing.party == 'Bilinmiyor':
                    firestore.update_mp(member.id, {
                        'party': member.party,
                        'constituency': member.city
                    })
                    updated += 1
            else:
                firestore.create_mp(mp)
                count += 1
            
            if (count + updated) % 50 == 0:
                print(f"  ✅ {count} yeni, {updated} güncellendi...")
            
        except Exception as e:
            if "already exists" not in str(e).lower():
                print(f"  ⚠️ Kayıt hatası ({member.name}): {str(e)[:50]}")
    
    print(f"\n✅ Toplam {count} yeni milletvekili kaydedildi, {updated} güncellendi!")
    return count + updated


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Wikipedia MP Scraper')
    parser.add_argument('--save', action='store_true', help='Firestore\'a kaydet')
    args = parser.parse_args()
    
    members = scrape_wikipedia_mps()
    
    # Sonuçları göster
    print(f"\n📋 İlk 20 milletvekili:")
    for i, m in enumerate(members[:20], 1):
        print(f"  {i}. {m.name} ({m.party}) - {m.city}")
    
    # Parti dağılımı
    parties = {}
    for m in members:
        parties[m.party] = parties.get(m.party, 0) + 1
    
    print(f"\n📊 Parti Dağılımı:")
    for party, count in sorted(parties.items(), key=lambda x: -x[1]):
        print(f"  {party}: {count}")
    
    # Firestore'a kaydet
    if args.save and members:
        save_mps_to_firestore(members)
