"""
TBMM Meclis Araştırma Önergeleri (Research Proposals) Scraper

TBMM sitesindeki meclis araştırma önergelerini çeker.
Kanun teklifleri ile aynı yapıda çalışır.
"""

import json
import logging
import time
from pathlib import Path
from typing import Dict, List
from dataclasses import dataclass
from collections import defaultdict

from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeout

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


# 28. Dönem Yasama Yılları
LEGISLATIVE_PERIODS = {
    "28_4": "5fe9e5a3-3938-4c1d-b8c0-01999e72f7b6",
    "28_3": "17556400-abaa-4bf5-a162-019246ebebe9",
    "28_2": "9df377e5-6541-4b16-93aa-018aea6d52f5",
    "28_1": "b0a3e586-c5ce-4900-9d1a-3a8607a05123",
    "all":  "00000000-0000-0000-0000-000000000000",
}


@dataclass
class ResearchProposal:
    """Meclis araştırma önergesi."""
    esas_no: str
    summary: str
    date: str
    period: str


class ResearchProposalsScraper:
    """TBMM Meclis Araştırma Önergeleri Scraper."""
    
    # Doğru URL (kullanıcı tarafından düzeltildi)
    QUERY_URL = "https://www.tbmm.gov.tr/Denetim/Meclis-Arastirma-Onergeleri"
    
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
        logger.info("🌐 Tarayıcı başlatılıyor...")
        self._playwright = sync_playwright().start()
        self.browser = self._playwright.chromium.launch(headless=self.headless)
        self.page = self.browser.new_page()
        self.page.set_default_timeout(30000)
    
    def _close_browser(self):
        if self.browser:
            self.browser.close()
        if self._playwright:
            self._playwright.stop()
        logger.info("🔒 Tarayıcı kapatıldı")
    
    def fetch_all_proposals(
        self, 
        period_key: str = "all",
        max_pages: int = 100
    ) -> List[ResearchProposal]:
        """Tüm meclis araştırma önergelerini çek."""
        period_id = LEGISLATIVE_PERIODS.get(period_key, LEGISLATIVE_PERIODS["all"])
        logger.info(f"🔍 Meclis araştırma önergeleri çekiliyor (Dönem: {period_key})...")
        
        # 1. Sorgu formuna git
        logger.info(f"  🔗 {self.QUERY_URL}")
        self.page.goto(self.QUERY_URL, wait_until='networkidle')
        time.sleep(2)
        
        # 2. Dönem seç
        try:
            dropdown = self.page.query_selector('select[name="DonemYasamaYili"], #DonemYasamaYili')
            if dropdown:
                dropdown.select_option(value=period_id)
                logger.info(f"  ✅ Dönem seçildi: {period_key}")
        except Exception as e:
            logger.warning(f"  ⚠️ Dönem seçimi hatası: {e}")
        
        # 3. Sorgula butonuna tıkla
        try:
            self.page.click('button:has-text("SORGULA"), input[type="submit"]')
            time.sleep(3)
            self.page.wait_for_load_state('networkidle')
            logger.info("  ✅ Sorgu başarılı, sonuçlar yükleniyor...")
        except PlaywrightTimeout:
            logger.warning("  ⚠️ Timeout, tablo aranıyor...")
        
        # 4. Tablodan veri çek
        proposals = []
        page_num = 0
        
        while page_num < max_pages:
            rows = self.page.query_selector_all('table tbody tr')
            
            if not rows:
                logger.warning("  ⚠️ Tablo satırları bulunamadı")
                break
            
            page_proposals = []
            for row in rows:
                cells = row.query_selector_all('td')
                if len(cells) >= 4:
                    proposal = ResearchProposal(
                        period=cells[0].inner_text().strip() if cells[0] else "",
                        esas_no=cells[1].inner_text().strip() if cells[1] else "",
                        date=cells[2].inner_text().strip() if cells[2] else "",
                        summary=cells[3].inner_text().strip() if cells[3] else ""
                    )
                    page_proposals.append(proposal)
            
            proposals.extend(page_proposals)
            logger.info(f"  📄 Sayfa {page_num+1}: {len(page_proposals)} önerge ({len(proposals)} toplam)")
            
            if len(page_proposals) == 0:
                break
            
            # Sonraki sayfa
            try:
                next_btn = self.page.query_selector('a.paginate_button.next:not(.disabled), .dataTables_paginate .next:not(.disabled)')
                if next_btn:
                    next_btn.click()
                    time.sleep(1)
                    page_num += 1
                else:
                    break
            except Exception:
                break
        
        logger.info(f"✅ Toplam {len(proposals)} meclis araştırma önergesi çekildi")
        return proposals


def count_research_per_mp(proposals: List[ResearchProposal]) -> Dict[str, int]:
    """Her MP için araştırma önergesi sayısını hesapla."""
    counts = defaultdict(int)
    for p in proposals:
        summary = p.summary
        if 'Milletvekili' in summary:
            first_line = summary.split('\n')[0]
            parts = first_line.split('Milletvekili')
            if len(parts) > 1:
                name = parts[1].strip().split('\n')[0].upper()
                counts[name] += 1
        elif 'GRUBU' in summary.upper():
            # Parti grubu önerileri
            pass
    return dict(counts)


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='TBMM Meclis Araştırma Önergeleri Scraper')
    parser.add_argument('--period', default='all', choices=list(LEGISLATIVE_PERIODS.keys()))
    parser.add_argument('--max-pages', type=int, default=100)
    parser.add_argument('--output', type=str, help='JSON çıktı dosyası')
    args = parser.parse_args()
    
    with ResearchProposalsScraper(headless=True) as scraper:
        proposals = scraper.fetch_all_proposals(period_key=args.period, max_pages=args.max_pages)
        
        print(f"\n📊 Toplam {len(proposals)} meclis araştırma önergesi")
        
        if proposals:
            print("\n📋 İlk 5 Önerge:")
            for i, prop in enumerate(proposals[:5], 1):
                print(f"  {i}. [{prop.esas_no}] {prop.summary[:80]}...")
            
            counts = count_research_per_mp(proposals)
            if counts:
                sorted_counts = sorted(counts.items(), key=lambda x: -x[1])[:10]
                print("\n🏆 En Aktif 10 Vekil (Araştırma):")
                for i, (name, count) in enumerate(sorted_counts, 1):
                    print(f"  {i:2}. {name}: {count} önerge")
        
        if args.output:
            output_path = Path(args.output)
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump([{
                    'esas_no': p.esas_no,
                    'summary': p.summary,
                    'date': p.date,
                    'period': p.period
                } for p in proposals], f, ensure_ascii=False, indent=2)
            print(f"\n💾 {output_path} dosyasına kaydedildi")
