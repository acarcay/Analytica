"""
TBMM Kapsamlı Scraper - Playwright
Tüm milletvekillerini ve yasama faaliyetlerini çeker.

Çekilen veriler:
- Tüm 600 milletvekili (isim, parti, şehir)
- Her vekil için kanun teklifleri
- Yazılı soru önergeleri
- Komisyon üyelikleri
"""

import re
import hashlib
import time
import logging
from typing import List, Dict, Optional, Any
from dataclasses import dataclass, field
from datetime import datetime
from playwright.sync_api import sync_playwright, Page, Browser, TimeoutError as PlaywrightTimeout

# Config import
from config.scraper_config import ScraperConfig, default_config

# Logger setup
logger = logging.getLogger(__name__)


@dataclass
class LegislativeActivity:
    """Yasama faaliyeti (kanun teklifi, soru önergesi vb.)"""
    title: str
    type: str  # 'kanun_teklifi', 'soru_onergesi', 'meclis_arastirmasi'
    date: Optional[str] = None
    status: Optional[str] = None
    url: Optional[str] = None


@dataclass
class TBMMMember:
    """TBMM Milletvekili verisi."""
    name: str
    party: str
    city: str
    detail_url: Optional[str] = None
    profile_image_url: Optional[str] = None
    law_proposals: int = 0
    written_questions: int = 0
    commissions: List[str] = field(default_factory=list)
    activities: List[LegislativeActivity] = field(default_factory=list)
    
    @property
    def id(self) -> str:
        """Benzersiz ID oluştur."""
        name_normalized = self.name.lower().replace(' ', '_')
        name_normalized = re.sub(r'[^a-z0-9_]', '', name_normalized)
        hash_suffix = hashlib.sha256(self.name.encode()).hexdigest()[:8]
        return f"mv_{name_normalized[:20]}_{hash_suffix}"


class TBMMPlaywrightScraper:
    """Playwright ile TBMM scraper."""
    
    BASE_URL = "https://www.tbmm.gov.tr"
    MP_LIST_URL = f"{BASE_URL}/milletvekili/liste"
    
    PARTY_MAP = {
        'ak parti': 'AKP',
        'adalet ve kalkınma partisi': 'AKP',
        'chp': 'CHP',
        'cumhuriyet halk partisi': 'CHP',
        'mhp': 'MHP',
        'milliyetçi hareket partisi': 'MHP',
        'iyi parti': 'İYİ',
        'İyİ parti': 'İYİ',
        'dem parti': 'DEM',
        'halkların demokratik partisi': 'DEM',
        'hdp': 'DEM',
        'saadet partisi': 'SP',
        'deva partisi': 'DEVA',
        'gelecek partisi': 'GP',
        'tip': 'TİP',
        'türkiye işçi partisi': 'TİP',
        'zafer partisi': 'ZP',
        'bağımsız': 'BAĞIMSIZ',
    }
    
    def __init__(self, config: Optional[ScraperConfig] = None):
        self.config = config or default_config
        self.headless = self.config.headless
        self.browser: Optional[Browser] = None
        self.page: Optional[Page] = None
        self._playwright = None  # Store playwright reference for proper cleanup
    
    def __enter__(self):
        """Context manager entry - start browser."""
        self._start_browser()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit - ensure proper cleanup."""
        self._close_browser()
        return False  # Don't suppress exceptions
    
    def _normalize_party(self, party_raw: str) -> str:
        """Parti ismini standartlaştır."""
        party_lower = party_raw.lower().strip()
        return self.PARTY_MAP.get(party_lower, party_raw.strip().upper())
    
    def _start_browser(self):
        """Tarayıcıyı başlat."""
        logger.info("🌐 Tarayıcı başlatılıyor...")
        self._playwright = sync_playwright().start()
        self.browser = self._playwright.chromium.launch(headless=self.headless)
        self.page = self.browser.new_page()
        self.page.set_default_timeout(self.config.default_timeout)
    
    def _close_browser(self):
        """Tarayıcıyı kapat ve kaynakları temizle."""
        if self.browser:
            self.browser.close()
            self.browser = None
        if self._playwright:
            self._playwright.stop()
            self._playwright = None
        logger.info("🔒 Tarayıcı kapatıldı")
    
    def fetch_all_mps(self) -> List[TBMMMember]:
        """
        TBMM sitesinden tüm milletvekillerini çek.
        
        Returns:
            List[TBMMMember]: Milletvekili listesi
        """
        members = []
        
        try:
            self._start_browser()
            
            logger.info("📡 TBMM sitesine bağlanılıyor: %s", self.config.mp_list_url)
            self.page.goto(self.MP_LIST_URL, wait_until='networkidle')
            
            # "TÜM LİSTE" butonuna tıkla
            try:
                logger.debug("🔘 'Tüm Liste' butonuna tıklanıyor...")
                self.page.click('text=TÜM LİSTE', timeout=5000)
                self.page.wait_for_load_state('networkidle')
                time.sleep(2)
            except PlaywrightTimeout:
                logger.warning("⚠️ 'Tüm Liste' butonu bulunamadı, devam ediliyor...")
            
            # Sayfanın sonuna kadar scroll yap
            logger.debug("📜 Sayfa yükleniyor...")
            self._scroll_to_bottom()
            
            # Şehir gruplarını bul
            members = self._parse_mp_list()
            
            logger.info("✅ Toplam %d milletvekili bulundu!", len(members))
            
        except Exception as e:
            logger.error("❌ Hata: %s", str(e))
            import traceback
            traceback.print_exc()
        finally:
            self._close_browser()
        
        return members
    
    def _scroll_to_bottom(self):
        """Sayfanın sonuna kadar scroll et."""
        previous_height = 0
        for _ in range(10):  # Max 10 scroll
            self.page.evaluate('window.scrollTo(0, document.body.scrollHeight)')
            time.sleep(0.5)
            current_height = self.page.evaluate('document.body.scrollHeight')
            if current_height == previous_height:
                break
            previous_height = current_height
    
    def _parse_mp_list(self) -> List[TBMMMember]:
        """Sayfa içeriğinden milletvekillerini parse et."""
        members = []
        
        logger.debug("📋 Milletvekili linkleri taranıyor...")
        
        # TBMM sitesinde vekil linkleri: a[href*='/milletvekili/milletvekilidetay']
        # veya a[href*='/Milletvekili/'] formatında
        
        # JavaScript ile tüm vekilleri çek
        mp_data = self.page.evaluate('''() => {
            const results = [];
            let currentCity = "Bilinmiyor";
            
            // Tüm elementleri sırayla tara
            const walker = document.createTreeWalker(
                document.body,
                NodeFilter.SHOW_ELEMENT,
                null,
                false
            );
            
            let node;
            while (node = walker.nextNode()) {
                // Şehir başlığı kontrolü (büyük harfle yazılmış h3/h4 veya span)
                if (['H3', 'H4', 'STRONG', 'B'].includes(node.tagName)) {
                    const text = node.innerText.trim();
                    if (text && text === text.toUpperCase() && text.length < 25 && !/\\d/.test(text)) {
                        currentCity = text;
                    }
                }
                
                // Milletvekili linki kontrolü
                if (node.tagName === 'A') {
                    const href = node.getAttribute('href') || '';
                    if (href.toLowerCase().includes('/milletvekili/') && 
                        (href.toLowerCase().includes('detay') || href.toLowerCase().includes('ozgecmis'))) {
                        
                        const name = node.innerText.trim();
                        if (name && name.length > 3 && !['Liste', 'Özgeçmiş', 'E-Posta', 'Telefon'].includes(name)) {
                            // Parti bilgisini bul (link sonrası metin)
                            let party = "Bilinmiyor";
                            let nextNode = node.nextSibling;
                            while (nextNode) {
                                if (nextNode.nodeType === Node.TEXT_NODE) {
                                    const partyText = nextNode.textContent.trim();
                                    if (partyText && partyText.length > 1 && partyText.length < 30) {
                                        party = partyText;
                                        break;
                                    }
                                }
                                if (nextNode.nodeType === Node.ELEMENT_NODE && nextNode.tagName === 'SPAN') {
                                    const partyText = nextNode.innerText.trim();
                                    if (partyText && partyText.length > 1 && partyText.length < 30) {
                                        party = partyText;
                                        break;
                                    }
                                }
                                nextNode = nextNode.nextSibling;
                            }
                            
                            results.push({
                                name: name,
                                party: party,
                                city: currentCity,
                                href: href
                            });
                        }
                    }
                }
            }
            
            return results;
        }''')
        
        logger.debug("  📊 JavaScript ile %d vekil bulundu", len(mp_data))
        
        for data in mp_data:
            member = TBMMMember(
                name=data['name'],
                party=self._normalize_party(data['party']),
                city=data['city'].title() if data['city'] else "Bilinmiyor",
                detail_url=f"{self.BASE_URL}{data['href']}" if not data['href'].startswith('http') else data['href']
            )
            members.append(member)
        
        # Tekrar eden isimleri filtrele
        seen = set()
        unique_members = []
        for m in members:
            key = m.name.lower()
            if key not in seen:
                seen.add(key)
                unique_members.append(m)
        
        return unique_members
    
    def _parse_table_structure(self) -> List[TBMMMember]:
        """Tablo yapısından verileri parse et."""
        members = []
        
        # Tablo satırlarını bul
        rows = self.page.query_selector_all('tr, .mv-item, .milletvekili-card, [class*="vekil"]')
        
        current_city = "Bilinmiyor"
        
        for row in rows:
            try:
                text = row.inner_text().strip()
                
                if not text:
                    continue
                
                # Şehir başlığı mı?
                if text.isupper() and len(text) < 25 and not any(c.isdigit() for c in text):
                    current_city = text.title()
                    continue
                
                # Milletvekili satırı mı?
                lines = text.split('\n')
                if len(lines) >= 1:
                    name = lines[0].strip()
                    party = lines[1].strip() if len(lines) > 1 else "Bilinmiyor"
                    
                    # Link bul
                    link = row.query_selector('a[href*="/milletvekili/"]')
                    href = link.get_attribute('href') if link else None
                    
                    if name and len(name) > 3:
                        member = TBMMMember(
                            name=name,
                            party=self._normalize_party(party),
                            city=current_city,
                            detail_url=f"{self.BASE_URL}{href}" if href and not href.startswith('http') else href
                        )
                        members.append(member)
                        
            except Exception:
                continue
        
        return members
    
    def fetch_mp_details(self, mp: TBMMMember, fetch_activities: bool = True) -> TBMMMember:
        """
        Milletvekilinin detay sayfasından bilgi çek.
        
        Args:
            mp: TBMMMember nesnesi
            fetch_activities: Yasama faaliyetlerini de çek
            
        Returns:
            Güncellenmiş TBMMMember
        """
        if not mp.detail_url:
            return mp
        
        try:
            self.page.goto(mp.detail_url, wait_until='networkidle', timeout=20000)
            time.sleep(0.5)
            
            # JavaScript ile tüm bilgileri çek
            details = self.page.evaluate('''() => {
                const result = {
                    party: null,
                    city: null,
                    profile_image: null,
                    law_proposals: 0
                };
                
                // Profil resmi
                const img = document.querySelector('img.mv-foto, img[src*="milletvekili"], .profile-photo img, .mv-detay img');
                if (img) {
                    result.profile_image = img.src;
                }
                
                // Parti ve Şehir bilgisi - genellikle tablo veya liste yapısında
                const allText = document.body.innerText;
                
                // Parti arama
                const partyPatterns = [
                    /Parti\\s*:\\s*([^\\n]+)/i,
                    /Siyasi Parti\\s*:\\s*([^\\n]+)/i,
                    /(AK Parti|CHP|MHP|İYİ Parti|DEM Parti|HDP|DEVA Partisi|Gelecek Partisi|Saadet Partisi|TİP|Zafer Partisi|Bağımsız)/i
                ];
                
                for (const pattern of partyPatterns) {
                    const match = allText.match(pattern);
                    if (match) {
                        result.party = match[1].trim();
                        break;
                    }
                }
                
                // Şehir (seçim çevresi) arama
                const cityPatterns = [
                    /Seçim Çevresi\\s*:\\s*([^\\n]+)/i,
                    /İl\\s*:\\s*([A-ZÇĞİÖŞÜa-zçğıöşü]+)/i
                ];
                
                for (const pattern of cityPatterns) {
                    const match = allText.match(pattern);
                    if (match) {
                        result.city = match[1].trim();
                        break;
                    }
                }
                
                // Tablolardan bilgi çek
                const tables = document.querySelectorAll('table');
                tables.forEach(table => {
                    const rows = table.querySelectorAll('tr');
                    rows.forEach(row => {
                        const cells = row.querySelectorAll('td, th');
                        if (cells.length >= 2) {
                            const label = cells[0].innerText.trim().toLowerCase();
                            const value = cells[1].innerText.trim();
                            
                            if (label.includes('parti') || label.includes('siyasi')) {
                                result.party = value;
                            }
                            if (label.includes('seçim çevresi') || label.includes('il')) {
                                result.city = value;
                            }
                        }
                    });
                });
                
                // Definition list'ten bilgi çek
                const dts = document.querySelectorAll('dt');
                dts.forEach(dt => {
                    const dd = dt.nextElementSibling;
                    if (dd && dd.tagName === 'DD') {
                        const label = dt.innerText.trim().toLowerCase();
                        const value = dd.innerText.trim();
                        
                        if (label.includes('parti')) {
                            result.party = value;
                        }
                        if (label.includes('seçim çevresi') || label.includes('il')) {
                            result.city = value;
                        }
                    }
                });
                
                // Kanun teklifleri sayısını bul
                const lawLink = document.querySelector('a[href*="kanun"], a[href*="teklif"]');
                if (lawLink) {
                    const lawText = lawLink.innerText;
                    const numMatch = lawText.match(/\\d+/);
                    if (numMatch) {
                        result.law_proposals = parseInt(numMatch[0]);
                    }
                }
                
                return result;
            }''')
            
            # Bilgileri güncelle
            if details.get('party'):
                mp.party = self._normalize_party(details['party'])
            
            if details.get('city'):
                mp.city = details['city'].title()
            
            if details.get('profile_image'):
                mp.profile_image_url = details['profile_image']
            
            if details.get('law_proposals'):
                mp.law_proposals = details['law_proposals']
            
        except Exception as e:
            logger.warning("    ⚠️ Detay çekilemedi (%s): %s", mp.name, str(e)[:50])
        
        return mp
    
    def _fetch_legislative_activities(self, mp: TBMMMember):
        """Milletvekilinin yasama faaliyetlerini çek."""
        try:
            # Kanun teklifleri linki
            proposal_link = self.page.query_selector('a[href*="kanun"], a:has-text("Kanun Teklif")')
            if proposal_link:
                href = proposal_link.get_attribute('href')
                if href:
                    # Kanun teklifleri sayfasına git
                    self.page.goto(href if href.startswith('http') else f"{self.BASE_URL}{href}")
                    time.sleep(1)
                    
                    # Teklif sayısını bul
                    proposals = self.page.query_selector_all('tr.teklif, .kanun-teklif-item, table tbody tr')
                    mp.law_proposals = len([p for p in proposals if p.inner_text().strip()])
                    
                    # İlk 5 teklifi kaydet
                    for i, prop in enumerate(proposals[:5]):
                        text = prop.inner_text().strip()
                        if text:
                            mp.activities.append(LegislativeActivity(
                                title=text[:200],
                                type='kanun_teklifi'
                            ))
                    
                    # Geri dön
                    self.page.go_back()
                    
        except Exception as e:
            logger.warning("    ⚠️ Yasama faaliyetleri çekilemedi: %s", str(e))
    
    def fetch_all_with_details(self, max_details: int = 50) -> List[TBMMMember]:
        """
        Tüm vekilleri çek ve detaylarını al.
        
        Args:
            max_details: En fazla kaç vekilin detayını çekecek (performans için)
        """
        try:
            self._start_browser()
            
            # Ana listeyi çek
            logger.info("📡 TBMM sitesine bağlanılıyor: %s", self.config.mp_list_url)
            self.page.goto(self.MP_LIST_URL, wait_until='networkidle')
            
            try:
                self.page.click('text=TÜM LİSTE', timeout=5000)
                self.page.wait_for_load_state('networkidle')
                time.sleep(2)
            except PlaywrightTimeout:
                logger.warning("⚠️ 'Tüm Liste' butonu bulunamadı, devam ediliyor...")
            
            self._scroll_to_bottom()
            members = self._parse_mp_list()
            
            logger.info("📊 %d milletvekili bulundu. Detaylar çekiliyor...", len(members))
            
            # Detayları çek (limit ile)
            for i, member in enumerate(members[:max_details]):
                logger.debug("  [%d/%d] %s", i+1, min(len(members), max_details), member.name)
                self.fetch_mp_details(member, fetch_activities=True)
                time.sleep(0.5)  # Rate limiting
            
            return members
            
        finally:
            self._close_browser()


def save_mps_to_firestore(members: List[TBMMMember]) -> int:
    """Milletvekillerini Firestore'a kaydet."""
    import sys
    import os
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    
    from services.firestore_service import get_firestore_service
    from models.mp_models import MP
    
    firestore = get_firestore_service()
    count = 0
    
    logger.info("💾 %d milletvekili Firestore'a kaydediliyor...", len(members))
    
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
                law_proposals=member.law_proposals,
                profile_image_url=member.profile_image_url
            )
            
            firestore.create_mp(mp)
            count += 1
            
            if count % 50 == 0:
                logger.info("  ✅ %d milletvekili kaydedildi...", count)
            
        except Exception as e:
            if "already exists" not in str(e).lower():
                logger.warning("  ⚠️ Kayıt hatası (%s): %s", member.name, str(e))
    
    logger.info("✅ Toplam %d milletvekili kaydedildi!", count)
    return count


if __name__ == "__main__":
    import argparse
    
    # Configure logging for CLI usage
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    parser = argparse.ArgumentParser(description='TBMM Playwright Scraper')
    parser.add_argument('--save', action='store_true', help='Firestore\'a kaydet')
    parser.add_argument('--details', action='store_true', help='Detaylı bilgi çek')
    parser.add_argument('--max', type=int, default=600, help='Maksimum vekil sayısı')
    parser.add_argument('--headless', action='store_true', default=True, help='Headless mod')
    parser.add_argument('--verbose', '-v', action='store_true', help='Debug log seviyesi')
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Use config with CLI arguments
    config = ScraperConfig(headless=args.headless)
    
    # Use context manager for proper resource cleanup
    with TBMMPlaywrightScraper(config=config) as scraper:
        if args.details:
            members = scraper.fetch_all_with_details(max_details=args.max)
        else:
            members = scraper.fetch_all_mps()
    
    # Sonuçları göster
    logger.info("📋 İlk 10 milletvekili:")
    for i, m in enumerate(members[:10], 1):
        logger.info("  %d. %s (%s) - %s - %d teklif", i, m.name, m.party, m.city, m.law_proposals)
    
    # Parti dağılımı
    parties = {}
    for m in members:
        parties[m.party] = parties.get(m.party, 0) + 1
    
    logger.info("📊 Parti Dağılımı:")
    for party, count in sorted(parties.items(), key=lambda x: -x[1]):
        logger.info("  %s: %d", party, count)
    
    # Firestore'a kaydet
    if args.save and members:
        save_mps_to_firestore(members)
