"""
TBMM Kanun Teklifleri (Law Proposals) Scraper

TBMM sitesindeki kanun tekliflerini çeker ve milletvekillerine eşleştirir.
Browser session gerektirdiği için Playwright kullanır.
"""

import json
import logging
import time
import re
from pathlib import Path
from typing import Dict, List, Optional
from dataclasses import dataclass, field
from datetime import datetime

from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeout

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


# 28. Dönem Yasama Yılları (2023-2027)
LEGISLATIVE_PERIODS = {
    "28_4": "5fe9e5a3-3938-4c1d-b8c0-01999e72f7b6",  # 28.DÖNEM 4.Yasama Yılı (En güncel)
    "28_3": "17556400-abaa-4bf5-a162-019246ebebe9",  # 28.DÖNEM 3.Yasama Yılı
    "28_2": "9df377e5-6541-4b16-93aa-018aea6d52f5",  # 28.DÖNEM 2.Yasama Yılı
    "28_1": "b0a3e586-c5ce-4900-9d1a-3a8607a05123",  # 28.DÖNEM 1.Yasama Yılı
    "all":  "00000000-0000-0000-0000-000000000000",  # Son Dönem Tüm Yasama Yılları
}


@dataclass
class LawProposal:
    """Kanun teklifi."""
    esas_no: str
    summary: str
    date: str
    period: str
    proposers: List[str] = field(default_factory=list)


class LawProposalsScraper:
    """TBMM Kanun Teklifleri Scraper."""
    
    QUERY_URL = "https://www.tbmm.gov.tr/Yasama/Kanun-Teklifleri"
    RESULT_URL = "https://www.tbmm.gov.tr/Yasama/Kanun-Teklifleri-Sonuc"
    API_URL = "https://www.tbmm.gov.tr/Yasama/Kanun-Teklifleri-Sonuc-Sayfa"
    
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
    
    def fetch_all_proposals(
        self, 
        period_key: str = "all",
        max_pages: int = 100
    ) -> List[LawProposal]:
        """
        Tüm kanun tekliflerini çek.
        
        Args:
            period_key: Dönem anahtarı ("28_4", "28_3", "28_2", "28_1", "all")
            max_pages: Maksimum sayfa sayısı
            
        Returns:
            List[LawProposal]: Kanun teklifleri listesi
        """
        period_id = LEGISLATIVE_PERIODS.get(period_key, LEGISLATIVE_PERIODS["all"])
        logger.info(f"📋 Kanun teklifleri çekiliyor (Dönem: {period_key})...")
        
        # 1. Sorgu formuna git ve session oluştur
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
            self.page.wait_for_url("**/Kanun-Teklifleri-Sonuc**", timeout=10000)
            time.sleep(3)
            logger.info("  ✅ Sorgu başarılı, sonuçlar yükleniyor...")
        except PlaywrightTimeout:
            logger.warning("  ⚠️ Sonuç sayfası yüklenemedi")
            return []
        
        # 4. Tablodan verileri çek
        proposals = []
        page_num = 0
        
        while page_num < max_pages:
            # Tablodaki satırları parse et
            rows = self.page.query_selector_all('table tbody tr')
            
            if not rows:
                logger.warning("  ⚠️ Tablo satırları bulunamadı")
                break
            
            page_proposals = []
            for row in rows:
                cells = row.query_selector_all('td')
                if len(cells) >= 4:
                    proposal = LawProposal(
                        period=cells[0].inner_text().strip() if cells[0] else "",
                        esas_no=cells[1].inner_text().strip() if cells[1] else "",
                        date=cells[2].inner_text().strip() if cells[2] else "",
                        summary=cells[3].inner_text().strip() if cells[3] else ""
                    )
                    page_proposals.append(proposal)
            
            proposals.extend(page_proposals)
            logger.info(f"  � Sayfa {page_num+1}: {len(page_proposals)} teklif ({len(proposals)} toplam)")
            
            if len(page_proposals) == 0:
                break
            
            # Sonraki sayfa var mı?
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
        
        logger.info(f"✅ Toplam {len(proposals)} kanun teklifi çekildi")
        return proposals

    
    def count_proposals_by_mp(self, proposals: List[LawProposal]) -> Dict[str, int]:
        """
        Milletvekillerine göre teklif sayısını hesapla.
        
        Not: Bu fonksiyon proposers alanına ihtiyaç duyar.
        """
        counts = {}
        for proposal in proposals:
            for mp in proposal.proposers:
                counts[mp] = counts.get(mp, 0) + 1
        return counts


def fetch_proposal_count_from_table() -> Dict[str, int]:
    """
    Browser ile tablodaki kanun tekliflerini parse et.
    MP ismi -> teklif sayısı dictionary döner.
    """
    mp_proposals = {}
    
    with LawProposalsScraper(headless=True) as scraper:
        proposals = scraper.fetch_all_proposals(period_key="all")
        
        # Şimdilik sadece toplam sayıyı döndürüyoruz
        # Gerçek eşleştirme için proposers bilgisi gerekli
        logger.info(f"📊 {len(proposals)} kanun teklifi bulundu")
    
    return mp_proposals


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='TBMM Kanun Teklifleri Scraper')
    parser.add_argument('--period', default='all', choices=list(LEGISLATIVE_PERIODS.keys()),
                       help='Yasama dönemi')
    parser.add_argument('--headless', action='store_true', default=True,
                       help='Headless mod')
    parser.add_argument('--output', type=str, help='JSON çıktı dosyası')
    args = parser.parse_args()
    
    with LawProposalsScraper(headless=args.headless) as scraper:
        proposals = scraper.fetch_all_proposals(period_key=args.period)
        
        print(f"\n📊 Toplam {len(proposals)} kanun teklifi")
        
        if proposals:
            print("\n📋 İlk 5 Teklif:")
            for i, prop in enumerate(proposals[:5], 1):
                print(f"  {i}. [{prop.esas_no}] {prop.summary[:80]}...")
        
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
