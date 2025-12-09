"""
TBMM Yazılı Soru Önergeleri (Written Questions) Scraper

TBMM sitesindeki yazılı soru önergelerini çeker ve milletvekillerine eşleştirir.
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
    "28_4": "5fe9e5a3-3938-4c1d-b8c0-01999e72f7b6",
    "28_3": "17556400-abaa-4bf5-a162-019246ebebe9",
    "28_2": "9df377e5-6541-4b16-93aa-018aea6d52f5",
    "28_1": "b0a3e586-c5ce-4900-9d1a-3a8607a05123",
    "all":  "00000000-0000-0000-0000-000000000000",
}


@dataclass
class WrittenQuestion:
    """Yazılı soru önergesi."""
    esas_no: str
    mp_name: str
    subject: str
    date: str
    status: str
    period: str = ""


class WrittenQuestionsScraper:
    """TBMM Yazılı Soru Önergeleri Scraper."""
    
    QUERY_URL = "https://www.tbmm.gov.tr/denetim/yazili-soru-onergeleri"
    
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
    
    def fetch_all_questions(
        self, 
        period_key: str = "all",
        max_pages: int = 100
    ) -> List[WrittenQuestion]:
        """
        Tüm yazılı soru önergelerini çek.
        
        Args:
            period_key: Dönem anahtarı
            max_pages: Maksimum sayfa sayısı
            
        Returns:
            List[WrittenQuestion]: Yazılı soru listesi
        """
        period_id = LEGISLATIVE_PERIODS.get(period_key, LEGISLATIVE_PERIODS["all"])
        logger.info(f"📋 Yazılı soru önergeleri çekiliyor (Dönem: {period_key})...")
        
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
            logger.warning("  ⚠️ Sonuç sayfası yüklenemedi")
            return []
        
        # 4. Tablodan verileri çek
        questions = []
        page_num = 0
        
        while page_num < max_pages:
            # Tablodaki satırları parse et
            rows = self.page.query_selector_all('table tbody tr')
            
            if not rows:
                logger.warning("  ⚠️ Tablo satırları bulunamadı")
                break
            
            page_questions = []
            for row in rows:
                cells = row.query_selector_all('td')
                if len(cells) >= 3:
                    # Sütun yapısı: [0] Dönem, [1] Esas No, [2] Tarih, [3] Önerge içeriği (MP + Konu + Durum)
                    raw_content = cells[3].inner_text().strip() if len(cells) > 3 else ""
                    
                    # MP ismini ilk satırdan çıkar (ŞEHIR MİLLETVEKİLİ İSİM SOYAD formatı)
                    mp_name = ""
                    subject = raw_content
                    lines = raw_content.split('\n')
                    
                    if lines:
                        first_line = lines[0].strip()
                        if "MİLLETVEKİLİ" in first_line.upper():
                            mp_name = first_line
                            subject = '\n'.join(lines[1:]).strip() if len(lines) > 1 else ""
                    
                    # Durumu bul
                    status = ""
                    for line in lines:
                        if "SON DURUMU" in line.upper():
                            status = line.strip()
                    
                    question = WrittenQuestion(
                        period=cells[0].inner_text().strip() if len(cells) > 0 else "",
                        esas_no=cells[1].inner_text().strip() if len(cells) > 1 else "",
                        date=cells[2].inner_text().strip() if len(cells) > 2 else "",
                        mp_name=mp_name,
                        subject=subject[:500],  # Truncate long subjects
                        status=status
                    )
                    page_questions.append(question)
            
            questions.extend(page_questions)
            logger.info(f"  📄 Sayfa {page_num+1}: {len(page_questions)} soru ({len(questions)} toplam)")
            
            if len(page_questions) == 0:
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
        
        logger.info(f"✅ Toplam {len(questions)} yazılı soru önergesi çekildi")
        return questions


def count_questions_per_mp(questions: List[WrittenQuestion]) -> Dict[str, int]:
    """Her MP için soru sayısını hesapla."""
    counts = {}
    for q in questions:
        name = q.mp_name.strip().upper()
        if name:
            counts[name] = counts.get(name, 0) + 1
    return counts


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='TBMM Yazılı Soru Önergeleri Scraper')
    parser.add_argument('--period', default='all', choices=list(LEGISLATIVE_PERIODS.keys()),
                       help='Yasama dönemi')
    parser.add_argument('--max-pages', type=int, default=100, help='Maksimum sayfa')
    parser.add_argument('--output', type=str, help='JSON çıktı dosyası')
    args = parser.parse_args()
    
    with WrittenQuestionsScraper(headless=True) as scraper:
        questions = scraper.fetch_all_questions(period_key=args.period, max_pages=args.max_pages)
        
        print(f"\n📊 Toplam {len(questions)} yazılı soru önergesi")
        
        if questions:
            # En aktif vekiller
            counts = count_questions_per_mp(questions)
            sorted_counts = sorted(counts.items(), key=lambda x: -x[1])[:10]
            
            print("\n🏆 En Aktif 10 Vekil (Soru Önergesi):")
            for i, (name, count) in enumerate(sorted_counts, 1):
                print(f"  {i:2}. {name}: {count} soru")
        
        if args.output:
            output_path = Path(args.output)
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump([{
                    'esas_no': q.esas_no,
                    'mp_name': q.mp_name,
                    'subject': q.subject,
                    'date': q.date,
                    'status': q.status,
                    'period': q.period
                } for q in questions], f, ensure_ascii=False, indent=2)
            print(f"\n💾 {output_path} dosyasına kaydedildi")
