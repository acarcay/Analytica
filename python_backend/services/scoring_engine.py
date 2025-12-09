"""
Puanlama Motoru Modülü
Milletvekili puanlarını hesaplayan ve güncelleyen servis.
"""

import sys
import os
from typing import List, Dict, Any, Optional
from dataclasses import dataclass
from datetime import datetime

# Proje kök dizinini path'e ekle
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from models.mp_models import MP, NewsAnalysis
from services.firestore_service import get_firestore_service
from services.news_scraper import get_news_scraper, NewsItem
from services.gemini_analyzer import get_gemini_analyzer, AnalysisResult


@dataclass
class ScoringResult:
    """Puanlama sonucu."""
    mp_id: str
    mp_name: str
    old_score: float
    new_score: float
    law_bonus: float
    question_bonus: float
    speech_bonus: float
    news_impact: float
    news_count: int
    is_passive: bool
    success: bool
    error_message: Optional[str] = None


class ScoringEngine:
    """Milletvekili puanlama motoru."""
    
    # Puanlama formülü ağırlıkları (Mecliste.org raporu bazlı)
    # Revize Formül: Puan = (T_ilk × 15) + (T_imza × 2) + (S × 3) + (A × 4) + (H × 1)
    FIRST_SIGNATURE_WEIGHT = 15.0   # T_ilk: İlk İmza Sahibi (asıl yazar)
    SUPPORT_SIGNATURE_WEIGHT = 2.0  # T_imza: Destek imzası
    QUESTION_WEIGHT = 3.0           # S: Yazılı Soru Önergesi
    RESEARCH_WEIGHT = 4.0           # A: Araştırma Önergesi
    NEWS_IMPACT_WEIGHT = 1.0        # H: Haber Etki Puanı
    
    def __init__(self, dry_run: bool = False):
        """
        Puanlama motorunu initialize et.
        
        Args:
            dry_run: True ise Firestore'a yazmaz, sadece simülasyon yapar
        """
        self.dry_run = dry_run
        self.firestore = get_firestore_service()
        self.scraper = get_news_scraper()
        self.analyzer = get_gemini_analyzer()
    
    def calculate_score(
        self, 
        first_signature: int = 0,
        support_signature: int = 0,
        written_questions: int = 0,
        research_proposals: int = 0,
        news_impact_avg: float = 5.0
    ) -> float:
        """
        Revize puanlama formülünü uygula.
        
        Formül: Puan = (T_ilk × 15) + (T_imza × 2) + (S × 3) + (A × 4) + (H × 1)
        
        Args:
            first_signature: T_ilk - İlk imza sahibi olduğu teklifler
            support_signature: T_imza - Destek imzası verdiği teklifler
            written_questions: S - Yazılı soru önergesi sayısı
            research_proposals: A - Araştırma önergesi sayısı
            news_impact_avg: H - Haber etki puanı ortalaması (1-10)
            
        Returns:
            float: Hesaplanan puan
        """
        t_ilk = first_signature * self.FIRST_SIGNATURE_WEIGHT
        t_imza = support_signature * self.SUPPORT_SIGNATURE_WEIGHT
        s_bonus = written_questions * self.QUESTION_WEIGHT
        a_bonus = research_proposals * self.RESEARCH_WEIGHT
        h_bonus = news_impact_avg * self.NEWS_IMPACT_WEIGHT
        
        return round(t_ilk + t_imza + s_bonus + a_bonus + h_bonus, 2)
    
    def check_passivity(
        self,
        first_signature: int = 0,
        written_questions: int = 0,
        research_proposals: int = 0
    ) -> bool:
        """
        Pasiflik kontrolü yap.
        
        3 ana kriterden 2 veya daha fazlasında 0 = Pasif
        
        Returns:
            bool: True ise vekil pasif
        """
        zero_count = sum([
            first_signature == 0,
            written_questions == 0,
            research_proposals == 0
        ])
        return zero_count >= 2
    
    def process_mp(
        self, 
        mp: MP, 
        max_news: int = 5
    ) -> ScoringResult:
        """
        Tek bir milletvekilini işle.
        
        Args:
            mp: Milletvekili nesnesi
            max_news: Çekilecek maksimum haber sayısı
            
        Returns:
            ScoringResult: İşlem sonucu
        """
        print(f"\n👤 İşleniyor: {mp.name} ({mp.party})")
        
        try:
            # 1. Haberleri çek
            print(f"  📰 Haberler çekiliyor...")
            news_items = self.scraper.search_and_scrape(
                mp_name=mp.name,
                max_results=max_news,
                scrape_content=True
            )
            print(f"  ✅ {len(news_items)} haber bulundu")
            
            # 2. Haberleri analiz et
            print(f"  🤖 AI analizi yapılıyor...")
            analyses: List[NewsAnalysis] = []
            impact_scores: List[float] = []
            
            for item in news_items:
                result = self.analyzer.analyze_news_impact(
                    mp_name=mp.name,
                    news_title=item.title,
                    news_content=item.content
                )
                
                impact_scores.append(result.impact_score)
                
                # NewsAnalysis modeli oluştur
                analysis = NewsAnalysis(
                    mp_id=mp.id,
                    title=item.title,
                    url=item.url,
                    sentiment_score=result.sentiment_score,
                    impact_score=result.impact_score,
                    source=item.source,
                    summary=result.summary,
                    keywords=result.keywords,
                    raw_analysis=result.raw_response
                )
                analyses.append(analysis)
            
            # 3. Puanı hesapla
            news_impact_avg = sum(impact_scores) / len(impact_scores) if impact_scores else 5.0
            law_bonus = mp.law_proposals * self.LAW_PROPOSAL_WEIGHT
            new_score = self.calculate_score(mp.law_proposals, news_impact_avg)
            
            print(f"  📊 Puan: {mp.current_score} → {new_score}")
            print(f"     Kanun Bonusu: {law_bonus} ({mp.law_proposals} teklif)")
            print(f"     Haber Etkisi: {news_impact_avg:.1f}")
            
            # 4. Firestore'a yaz (dry_run değilse)
            if not self.dry_run:
                # MP puanını güncelle
                self.firestore.update_mp_score(mp.id, new_score)
                
                # Haber analizlerini kaydet
                for analysis in analyses:
                    self.firestore.add_news_analysis(analysis)
                
                print(f"  💾 Firestore güncellendi")
            else:
                print(f"  ⏭️ DRY-RUN: Firestore'a yazılmadı")
            
            return ScoringResult(
                mp_id=mp.id,
                mp_name=mp.name,
                old_score=mp.current_score,
                new_score=new_score,
                law_bonus=law_bonus,
                news_impact=news_impact_avg,
                news_count=len(news_items),
                success=True
            )
            
        except Exception as e:
            error_msg = str(e)
            print(f"  ❌ Hata: {error_msg}")
            
            return ScoringResult(
                mp_id=mp.id,
                mp_name=mp.name,
                old_score=mp.current_score,
                new_score=mp.current_score,
                law_bonus=0,
                news_impact=0,
                news_count=0,
                success=False,
                error_message=error_msg
            )
    
    def process_all_mps(self, max_news_per_mp: int = 5) -> List[ScoringResult]:
        """
        Tüm milletvekillerini işle.
        
        Args:
            max_news_per_mp: Her vekil için çekilecek maksimum haber sayısı
            
        Returns:
            List[ScoringResult]: Tüm işlem sonuçları
        """
        print("\n" + "="*60)
        print("🚀 Toplu Puanlama Başlatılıyor")
        print("="*60)
        
        # Tüm vekilleri getir
        mps = self.firestore.get_all_mps()
        
        if not mps:
            print("⚠️ Hiç milletvekili kaydı bulunamadı!")
            print("💡 Önce örnek veriler ekleyin veya seed_sample_data() fonksiyonunu çalıştırın.")
            return []
        
        print(f"📋 Toplam {len(mps)} milletvekili işlenecek")
        
        results = []
        for i, mp in enumerate(mps, 1):
            print(f"\n[{i}/{len(mps)}]", end="")
            result = self.process_mp(mp, max_news_per_mp)
            results.append(result)
        
        # Özet
        self._print_summary(results)
        
        return results
    
    def process_single_mp(self, mp_id: str, max_news: int = 5) -> Optional[ScoringResult]:
        """
        Belirli bir milletvekilini işle.
        
        Args:
            mp_id: Milletvekili ID'si
            max_news: Çekilecek maksimum haber sayısı
            
        Returns:
            ScoringResult veya None
        """
        mp = self.firestore.get_mp_by_id(mp_id)
        
        if not mp:
            print(f"❌ Milletvekili bulunamadı: {mp_id}")
            return None
        
        return self.process_mp(mp, max_news)
    
    def _print_summary(self, results: List[ScoringResult]):
        """İşlem özetini yazdır."""
        print("\n" + "="*60)
        print("📊 İŞLEM ÖZETİ")
        print("="*60)
        
        success_count = sum(1 for r in results if r.success)
        fail_count = len(results) - success_count
        
        print(f"✅ Başarılı: {success_count}")
        print(f"❌ Başarısız: {fail_count}")
        
        if results:
            # En yüksek puanlı vekiller
            sorted_results = sorted(
                [r for r in results if r.success], 
                key=lambda x: x.new_score, 
                reverse=True
            )[:5]
            
            print("\n🏆 En Yüksek Puanlı 5 Vekil:")
            for i, r in enumerate(sorted_results, 1):
                print(f"  {i}. {r.mp_name}: {r.new_score}")
        
        if self.dry_run:
            print("\n⚠️ DRY-RUN modu aktifti - Firestore'a herhangi bir veri yazılmadı!")


def seed_sample_data(firestore_service=None):
    """
    Örnek milletvekili verisi ekle (test amaçlı).
    """
    if firestore_service is None:
        firestore_service = get_firestore_service()
    
    sample_mps = [
        MP(
            id="mv_001",
            name="Ahmet Yılmaz",
            party="AKP",
            current_score=0,
            constituency="İstanbul",
            term_count=3,
            law_proposals=5
        ),
        MP(
            id="mv_002",
            name="Mehmet Demir",
            party="CHP",
            current_score=0,
            constituency="Ankara",
            term_count=2,
            law_proposals=8
        ),
        MP(
            id="mv_003",
            name="Fatma Kaya",
            party="MHP",
            current_score=0,
            constituency="İzmir",
            term_count=1,
            law_proposals=3
        ),
        MP(
            id="mv_004",
            name="Ali Öztürk",
            party="İYİ",
            current_score=0,
            constituency="Bursa",
            term_count=2,
            law_proposals=6
        ),
        MP(
            id="mv_005",
            name="Zeynep Arslan",
            party="HDP",
            current_score=0,
            constituency="Diyarbakır",
            term_count=1,
            law_proposals=4
        ),
    ]
    
    print("\n📝 Örnek milletvekili verileri ekleniyor...")
    
    for mp in sample_mps:
        firestore_service.create_mp(mp)
        print(f"  ✅ {mp.name} ({mp.party}) eklendi")
    
    print(f"\n✅ Toplam {len(sample_mps)} milletvekili eklendi!")


# Singleton instance
_engine_instance: Optional[ScoringEngine] = None


def get_scoring_engine(dry_run: bool = False) -> ScoringEngine:
    """ScoringEngine singleton instance döndür."""
    global _engine_instance
    if _engine_instance is None or _engine_instance.dry_run != dry_run:
        _engine_instance = ScoringEngine(dry_run=dry_run)
    return _engine_instance


if __name__ == "__main__":
    # Test
    import argparse
    
    parser = argparse.ArgumentParser(description='Scoring Engine Test')
    parser.add_argument('--dry-run', action='store_true', help='Firestore yazma')
    parser.add_argument('--seed', action='store_true', help='Örnek veri ekle')
    args = parser.parse_args()
    
    if args.seed:
        seed_sample_data()
    else:
        engine = get_scoring_engine(dry_run=args.dry_run)
        engine.process_all_mps(max_news_per_mp=3)
