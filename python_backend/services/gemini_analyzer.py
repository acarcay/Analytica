"""
Gemini AI Analiz Modülü
Google Gemini API kullanarak haber analizi ve siyasi etki puanlama servisi.
"""

import os
import json
from typing import Dict, Any, Optional, List
from dataclasses import dataclass
from dotenv import load_dotenv

# Environment variables yükle
load_dotenv()

try:
    import google.generativeai as genai
    GENAI_AVAILABLE = True
except ImportError:
    GENAI_AVAILABLE = False
    print("⚠️ google-generativeai paketi bulunamadı. pip install google-generativeai ile yükleyin.")


@dataclass
class AnalysisResult:
    """AI analiz sonucu."""
    sentiment_score: float  # -1.0 ile 1.0 arası
    impact_score: float  # 1-10 arası
    summary: str
    keywords: List[str]
    raw_response: str


class GeminiAnalyzer:
    """Google Gemini AI analiz servisi."""
    
    def __init__(self, api_key: Optional[str] = None):
        """
        Gemini API'yi initialize et.
        
        Args:
            api_key: Gemini API key (None ise environment'tan alınır)
        """
        self.api_key = api_key or os.getenv('GEMINI_API_KEY')
        self.model = None
        self._initialized = False
        
        if GENAI_AVAILABLE and self.api_key:
            try:
                genai.configure(api_key=self.api_key)
                self.model = genai.GenerativeModel('gemini-1.5-flash')
                self._initialized = True
                print("✅ Gemini API bağlantısı başarılı!")
            except Exception as e:
                print(f"❌ Gemini API initialization hatası: {str(e)}")
    
    def is_available(self) -> bool:
        """Gemini API kullanılabilir mi kontrol et."""
        return self._initialized and self.model is not None
    
    def analyze_news_impact(
        self, 
        mp_name: str, 
        news_title: str, 
        news_content: Optional[str] = None
    ) -> AnalysisResult:
        """
        Haber içeriğini analiz et ve siyasi etki puanı ver.
        
        Args:
            mp_name: Milletvekili adı
            news_title: Haber başlığı
            news_content: Haber içeriği (opsiyonel)
            
        Returns:
            AnalysisResult: Analiz sonucu
        """
        if not self.is_available():
            print("⚠️ Gemini API mevcut değil. Simüle edilmiş analiz döndürülüyor.")
            return self._get_simulated_analysis(mp_name, news_title)
        
        prompt = self._build_analysis_prompt(mp_name, news_title, news_content)
        
        try:
            response = self.model.generate_content(prompt)
            return self._parse_analysis_response(response.text)
        except Exception as e:
            print(f"❌ Gemini analiz hatası: {str(e)}")
            return self._get_simulated_analysis(mp_name, news_title)
    
    def batch_analyze(
        self, 
        mp_name: str, 
        news_items: List[Dict[str, str]]
    ) -> List[AnalysisResult]:
        """
        Birden fazla haberi toplu analiz et.
        
        Args:
            mp_name: Milletvekili adı
            news_items: [{'title': str, 'content': str}, ...] formatında liste
            
        Returns:
            List[AnalysisResult]: Analiz sonuçları
        """
        results = []
        for item in news_items:
            result = self.analyze_news_impact(
                mp_name=mp_name,
                news_title=item.get('title', ''),
                news_content=item.get('content')
            )
            results.append(result)
        return results
    
    def _build_analysis_prompt(
        self, 
        mp_name: str, 
        news_title: str, 
        news_content: Optional[str]
    ) -> str:
        """Analiz için Gemini prompt'u oluştur."""
        content_section = ""
        if news_content:
            # İçeriği kısalt (max 2000 karakter)
            truncated_content = news_content[:2000] + "..." if len(news_content) > 2000 else news_content
            content_section = f"\n\nHaber İçeriği:\n{truncated_content}"
        
        return f"""Sen bir Türk siyasi analiz uzmanısın. Aşağıdaki haberi {mp_name} isimli milletvekili açısından analiz et.

Haber Başlığı: {news_title}{content_section}

Lütfen aşağıdaki formatta JSON yanıt ver (sadece JSON, başka açıklama yok):

{{
    "sentiment_score": <-1.0 ile 1.0 arası float, -1=çok negatif, 0=nötr, 1=çok pozitif>,
    "impact_score": <1-10 arası integer, siyasi etki puanı, 10=çok yüksek etki>,
    "summary": "<haberin 1-2 cümlelik özeti>",
    "keywords": ["<anahtar kelime 1>", "<anahtar kelime 2>", "<anahtar kelime 3>"]
}}

Puanlama kriterleri:
- Sentiment: Haberin milletvekili için olumlu/olumsuz olması
- Impact: Haberin kamuoyundaki etkisi, medya kapsamı, siyasi önemi

Sadece JSON formatında yanıt ver, başka metin ekleme."""
    
    def _parse_analysis_response(self, response_text: str) -> AnalysisResult:
        """Gemini yanıtını parse et."""
        try:
            # JSON bloğunu bul
            json_start = response_text.find('{')
            json_end = response_text.rfind('}') + 1
            
            if json_start != -1 and json_end > json_start:
                json_str = response_text[json_start:json_end]
                data = json.loads(json_str)
                
                return AnalysisResult(
                    sentiment_score=float(data.get('sentiment_score', 0)),
                    impact_score=float(data.get('impact_score', 5)),
                    summary=data.get('summary', ''),
                    keywords=data.get('keywords', []),
                    raw_response=response_text
                )
        except json.JSONDecodeError as e:
            print(f"⚠️ JSON parse hatası: {str(e)}")
        
        # Parse başarısız olursa varsayılan değerler
        return AnalysisResult(
            sentiment_score=0.0,
            impact_score=5.0,
            summary="Analiz yapılamadı",
            keywords=[],
            raw_response=response_text
        )
    
    def _get_simulated_analysis(
        self, 
        mp_name: str, 
        news_title: str
    ) -> AnalysisResult:
        """
        Test amaçlı simüle edilmiş analiz sonucu döndür.
        
        Args:
            mp_name: Milletvekili adı
            news_title: Haber başlığı
            
        Returns:
            AnalysisResult: Simüle edilmiş analiz
        """
        import random
        
        # Basit sentiment analizi (anahtar kelime bazlı)
        positive_words = ['başarı', 'destek', 'onay', 'kabul', 'övgü', 'alkış']
        negative_words = ['eleştiri', 'tepki', 'kriz', 'skandal', 'sorun', 'protesto']
        
        title_lower = news_title.lower()
        sentiment = 0.0
        
        for word in positive_words:
            if word in title_lower:
                sentiment += 0.3
        
        for word in negative_words:
            if word in title_lower:
                sentiment -= 0.3
        
        # Değerleri sınırla
        sentiment = max(-1.0, min(1.0, sentiment + random.uniform(-0.2, 0.2)))
        impact = random.uniform(4.0, 8.0)
        
        return AnalysisResult(
            sentiment_score=round(sentiment, 2),
            impact_score=round(impact, 1),
            summary=f"{mp_name} hakkındaki bu haber {'olumlu' if sentiment > 0 else 'olumsuz' if sentiment < 0 else 'nötr'} bir içerik taşımaktadır.",
            keywords=[mp_name.split()[0], 'siyaset', 'TBMM'],
            raw_response="[Simüle edilmiş analiz]"
        )


# Singleton instance
_analyzer_instance: Optional[GeminiAnalyzer] = None


def get_gemini_analyzer() -> GeminiAnalyzer:
    """GeminiAnalyzer singleton instance döndür."""
    global _analyzer_instance
    if _analyzer_instance is None:
        _analyzer_instance = GeminiAnalyzer()
    return _analyzer_instance


if __name__ == "__main__":
    # Test
    analyzer = get_gemini_analyzer()
    
    if analyzer.is_available():
        result = analyzer.analyze_news_impact(
            mp_name="Test Vekil",
            news_title="Test Vekil mecliste önemli bir konuşma yaptı",
            news_content="Milletvekili bugün mecliste ekonomi hakkında kapsamlı bir konuşma gerçekleştirdi."
        )
        
        print(f"\n📊 Analiz Sonucu:")
        print(f"  Sentiment: {result.sentiment_score}")
        print(f"  Impact: {result.impact_score}")
        print(f"  Özet: {result.summary}")
        print(f"  Anahtar Kelimeler: {result.keywords}")
    else:
        print("⚠️ Gemini API kullanılamıyor. GEMINI_API_KEY ayarlandığından emin olun.")
