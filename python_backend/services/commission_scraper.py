"""
Komisyon Üyelikleri Scraper
TBMM İhtisas Komisyonları üyeliklerini çeker.
"""

import json
import logging
import time
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import List, Dict

from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeout

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class CommissionMember:
    """Komisyon üyesi bilgisi."""
    commission: str        # Komisyon adı
    role: str              # Rol (BAŞKAN, BAŞKANVEKİLİ, SÖZCÜ, ÜYE)
    name: str              # Üye adı
    party: str = ""        # Parti (varsa)


class CommissionScraper:
    """TBMM Komisyon Üyelikleri Scraper."""
    
    BASE_URL = "https://www.tbmm.gov.tr/ihtisas-komisyonlari/liste"
    
    # İhtisas Komisyonları URL'leri
    COMMISSIONS = {
        "Adalet Komisyonu": "adalet-komisyonu",
        "Anayasa Komisyonu": "anayasa-komisyonu", 
        "Dışişleri Komisyonu": "disisleri-komisyonu",
        "Dilekçe Komisyonu": "dilekce-komisyonu",
        "Eğitim Komisyonu": "kamu-iktisadi-tesebbuslerini-denetleme-komisyonu",
        "İçişleri Komisyonu": "icisleri-komisyonu",
        "İnsan Hakları Komisyonu": "insan-haklarini-inceleme-komisyonu",
        "Kadın Erkek Fırsat Eşitliği Komisyonu": "kadin-erkek-firsat-esitligi-komisyonu",
        "Kamu İktisadi Teşebbüsleri Komisyonu": "kamu-iktisadi-tesebbuslerini-denetleme-komisyonu",
        "Milli Eğitim Komisyonu": "milli-egitim-kultur-genclik-ve-spor-komisyonu",
        "Milli Savunma Komisyonu": "milli-savunma-komisyonu",
        "Plan ve Bütçe Komisyonu": "plan-ve-butce-komisyonu",
        "Sağlık Komisyonu": "saglik-aile-calisma-ve-sosyal-isler-komisyonu",
        "Sanayi Komisyonu": "sanayi-ticaret-enerji-tabii-kaynaklar-bilgi-ve-teknoloji-komisyonu",
        "Tarım Komisyonu": "tarim-orman-ve-koyisleri-komisyonu",
        "Çevre Komisyonu": "cevre-komisyonu",
    }
    
    def __init__(self):
        self.playwright = None
        self.browser = None
        self.page = None
    
    def __enter__(self):
        self.playwright = sync_playwright().start()
        self.browser = self.playwright.chromium.launch(headless=True)
        self.page = self.browser.new_page()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.browser:
            self.browser.close()
        if self.playwright:
            self.playwright.stop()
    
    def fetch_commission_members(self, commission_name: str, commission_slug: str) -> List[CommissionMember]:
        """Tek bir komisyonun üyelerini çek."""
        members = []
        url = f"https://www.tbmm.gov.tr/ihtisas-komisyonlari/KomisyonUyeleri/{commission_slug}"
        
        try:
            logger.info(f"  📋 {commission_name} üyeleri çekiliyor...")
            self.page.goto(url, wait_until='networkidle', timeout=30000)
            time.sleep(2)
            
            # Tablo satırlarını bul
            rows = self.page.query_selector_all('table tbody tr')
            
            if not rows:
                # Alternatif: Kart yapısı
                cards = self.page.query_selector_all('.card, .member-card, .uye-card')
                if cards:
                    for card in cards:
                        name_el = card.query_selector('h5, .name, .isim')
                        role_el = card.query_selector('.role, .gorev, small')
                        if name_el:
                            member = CommissionMember(
                                commission=commission_name,
                                role=role_el.inner_text().strip() if role_el else "ÜYE",
                                name=name_el.inner_text().strip()
                            )
                            members.append(member)
            else:
                for row in rows:
                    cells = row.query_selector_all('td')
                    if len(cells) >= 2:
                        role = cells[0].inner_text().strip() if cells[0] else "ÜYE"
                        name = cells[1].inner_text().strip() if cells[1] else ""
                        
                        if name:
                            member = CommissionMember(
                                commission=commission_name,
                                role=role,
                                name=name
                            )
                            members.append(member)
            
            logger.info(f"    ✅ {len(members)} üye bulundu")
            
        except PlaywrightTimeout:
            logger.warning(f"    ⚠️ Timeout: {commission_name}")
        except Exception as e:
            logger.error(f"    ❌ Hata: {e}")
        
        return members
    
    def fetch_all_commissions(self) -> Dict[str, List[CommissionMember]]:
        """Tüm komisyon üyeliklerini çek."""
        all_members = {}
        
        logger.info("🏛️ TBMM Komisyon Üyelikleri Çekiliyor...")
        
        for commission_name, slug in self.COMMISSIONS.items():
            members = self.fetch_commission_members(commission_name, slug)
            all_members[commission_name] = members
            time.sleep(1)  # Rate limiting
        
        return all_members
    
    def save_to_json(self, members: Dict[str, List[CommissionMember]], filepath: Path):
        """Üyelikleri JSON'a kaydet."""
        # Dict formatına çevir
        data = {}
        for commission, member_list in members.items():
            data[commission] = [asdict(m) for m in member_list]
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        
        total = sum(len(m) for m in members.values())
        logger.info(f"✅ {len(members)} komisyon, {total} üyelik kaydedildi: {filepath}")


def create_mp_commission_mapping(members_data: Dict[str, List[dict]]) -> Dict[str, List[str]]:
    """
    MP ismi -> Komisyon listesi mapping'i oluştur.
    
    Returns:
        {'ÖZGÜR ÖZEL': ['Adalet Komisyonu'], 'X Y': ['Plan ve Bütçe', 'Anayasa']}
    """
    mp_commissions = {}
    
    for commission, members in members_data.items():
        for member in members:
            name = member.get('name', '').strip().upper()
            if name:
                if name not in mp_commissions:
                    mp_commissions[name] = []
                mp_commissions[name].append(commission)
    
    return mp_commissions


if __name__ == "__main__":
    output_file = Path(__file__).parent.parent / "data" / "commission_members.json"
    
    with CommissionScraper() as scraper:
        members = scraper.fetch_all_commissions()
        scraper.save_to_json(members, output_file)
    
    # Mapping oluştur
    with open(output_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    mapping = create_mp_commission_mapping(data)
    print(f"\n📊 Komisyon üyesi olan vekil sayısı: {len(mapping)}")
    
    # Örnek çıktı
    for name, commissions in list(mapping.items())[:5]:
        print(f"  {name}: {commissions}")
