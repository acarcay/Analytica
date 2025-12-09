"""
TBMM Genel Kurul Konuşmaları (Parliamentary Speeches) Scraper

TBMM sitesindeki genel kurul konuşmalarını çeker.
Tutanaklar dinamik olarak yüklendiği için Playwright gerekli.

Not: Bu scraper milletvekillerinin konuşma sayısını tespit eder.
"""

import json
import logging
import time
import re
from pathlib import Path
from typing import Dict, List, Optional
from dataclasses import dataclass
from datetime import datetime
from collections import defaultdict

from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeout

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


@dataclass
class SpeechRecord:
    """Genel kurul konuşma kaydı."""
    mp_name: str
    date: str
    session_no: str
    topic: str = ""


class SpeechScraper:
    """TBMM Genel Kurul Konuşmaları Scraper."""
    
    # Genel kurul tutanakları URL'leri
    TUTANAK_URL = "https://www.tbmm.gov.tr/genel-kurul/tutanaklar"
    MUZAKERE_URL = "https://www.tbmm.gov.tr/genel-kurul/muzakereler"
    
    def __init__(self, headless: bool = True):
        self.headless = headless
        self.browser = None
        self.page = None
        self._playwright = None
    
    def __enter__(self):
        self._start_browser()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self._close_browser()
        return False
    
    def _start_browser(self):
        """Tarayıcıyı başlat."""
        logger.info("🌐 Tarayıcı başlatılıyor...")
        self._playwright = sync_playwright().start()
        self.browser = self._playwright.chromium.launch(headless=self.headless)
        self.page = self.browser.new_page()
        self.page.set_default_timeout(30000)
    
    def _close_browser(self):
        """Tarayıcıyı kapat."""
        if self.browser:
            self.browser.close()
        if self._playwright:
            self._playwright.stop()
        logger.info("🔒 Tarayıcı kapatıldı")
    
    def fetch_speeches_from_muzakereler(
        self,
        max_sessions: int = 20
    ) -> List[SpeechRecord]:
        """
        Müzakereler sayfasından konuşma kayıtlarını çek.
        """
        logger.info(f"📋 Müzakereler sayfasından konuşmalar çekiliyor...")
        
        self.page.goto(self.MUZAKERE_URL, wait_until='networkidle')
        time.sleep(3)
        
        speeches = []
        
        # Liste elemanlarını bul
        session_links = self.page.query_selector_all('a[href*="muzakere"], .session-link, table tbody tr a')
        
        logger.info(f"  📄 {len(session_links)} oturum linki bulundu")
        
        # Her oturumu ziyaret et ve konuşmacıları çıkar
        for i, link in enumerate(session_links[:max_sessions]):
            try:
                href = link.get_attribute('href')
                session_text = link.inner_text().strip()
                
                if href:
                    full_url = href if href.startswith('http') else f"https://www.tbmm.gov.tr{href}"
                    self.page.goto(full_url, wait_until='networkidle')
                    time.sleep(1)
                    
                    # Konuşmacı isimlerini bul (genellikle bold veya link olarak)
                    speakers = self.page.query_selector_all('strong, b, .speaker-name')
                    
                    for speaker in speakers:
                        text = speaker.inner_text().strip()
                        # Milletvekili pattern'i kontrol et
                        if self._is_mp_name(text):
                            speeches.append(SpeechRecord(
                                mp_name=text,
                                date=session_text[:10] if len(session_text) > 10 else "",
                                session_no=f"Oturum {i+1}"
                            ))
                    
                    logger.info(f"    [{i+1}/{min(len(session_links), max_sessions)}] {len(speeches)} konuşma")
                    
            except Exception as e:
                logger.warning(f"    ⚠️ Oturum {i+1} hatası: {e}")
                continue
        
        logger.info(f"✅ Toplam {len(speeches)} konuşma kaydı çekildi")
        return speeches
    
    def _is_mp_name(self, text: str) -> bool:
        """Metinin milletvekili ismi olup olmadığını kontrol et."""
        # Milletvekili pattern'leri
        patterns = [
            r'[A-ZÇĞİÖŞÜ][a-zçğıöşü]+\s+[A-ZÇĞİÖŞÜ]+',  # "İsim SOYAD"
            r'[A-ZÇĞİÖŞÜ][a-zçğıöşü]+\s+[A-ZÇĞİÖŞÜ][a-zçğıöşü]+\s+[A-ZÇĞİÖŞÜ]+',  # "İsim İkinci SOYAD"
        ]
        
        for pattern in patterns:
            if re.match(pattern, text.strip()):
                # Hariç tutulacak kelimeler
                excludes = ['Genel Kurul', 'Birleşim', 'Oturum', 'Kanun', 'Madde', 'Sayılı']
                if not any(exc in text for exc in excludes):
                    return True
        return False
    
    def count_speeches_per_mp(self, speeches: List[SpeechRecord]) -> Dict[str, int]:
        """Her MP için konuşma sayısını hesapla."""
        counts = defaultdict(int)
        for s in speeches:
            name = s.mp_name.strip().upper()
            if name:
                counts[name] += 1
        return dict(counts)


def simulate_speech_data_from_proposals() -> Dict[str, int]:
    """
    Gerçek veri çekilemezse, kanun tekliflerinden simüle edilmiş konuşma verisi.
    Her teklif = tahmini 2 konuşma (savunma + tartışma)
    """
    proposals_file = Path(__file__).parent.parent / "data" / "law_proposals_28.json"
    
    if not proposals_file.exists():
        logger.warning("⚠️ Kanun teklifleri dosyası bulunamadı")
        return {}
    
    with open(proposals_file, 'r', encoding='utf-8') as f:
        proposals = json.load(f)
    
    # Her tekliften MP isimlerini çıkar ve konuşma simüle et
    counts = defaultdict(int)
    for prop in proposals:
        summary = prop.get('summary', '')
        # İlk satırı al (MP ismi)
        first_line = summary.split('\n')[0] if summary else ""
        if 'Milletvekili' in first_line:
            # Sadece ismi çıkar
            parts = first_line.split('Milletvekili')
            if len(parts) > 1:
                name = parts[1].strip().split('\n')[0].upper()
                counts[name] += 2  # Her teklif için 2 konuşma
    
    return dict(counts)


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='TBMM Konuşma Scraper')
    parser.add_argument('--max-sessions', type=int, default=20, help='Maksimum oturum sayısı')
    parser.add_argument('--simulate', action='store_true', help='Kanun tekliflerinden simüle et')
    parser.add_argument('--output', type=str, help='JSON çıktı dosyası')
    args = parser.parse_args()
    
    if args.simulate:
        print("🔄 Simülasyon modu: Kanun tekliflerinden konuşma tahmini")
        counts = simulate_speech_data_from_proposals()
    else:
        with SpeechScraper(headless=True) as scraper:
            speeches = scraper.fetch_speeches_from_muzakereler(max_sessions=args.max_sessions)
            counts = scraper.count_speeches_per_mp(speeches)
    
    if counts:
        sorted_counts = sorted(counts.items(), key=lambda x: -x[1])[:20]
        
        print(f"\n📊 Toplam {len(counts)} vekil, {sum(counts.values())} konuşma")
        print("\n🏆 En Aktif 20 Vekil (Konuşma):")
        for i, (name, count) in enumerate(sorted_counts, 1):
            print(f"  {i:2}. {name}: {count} konuşma")
    
    if args.output:
        output_path = Path(args.output)
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(counts, f, ensure_ascii=False, indent=2)
        print(f"\n💾 {output_path} dosyasına kaydedildi")
