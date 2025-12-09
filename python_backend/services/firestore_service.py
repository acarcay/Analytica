"""
Firestore Servis Modülü
Firestore CRUD operasyonlarını yöneten servis.
"""

from typing import List, Optional, Dict, Any
from datetime import datetime
import sys
import os

# Proje kök dizinini path'e ekle
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from config.firebase_config import get_firestore_client
from models.mp_models import MP, NewsAnalysis, SystemLog


# Koleksiyon isimleri
COLLECTION_MPS = 'mps'
COLLECTION_NEWS_ANALYSIS = 'news_analysis'
COLLECTION_LOGS = 'logs'


class FirestoreService:
    """Firestore veritabanı işlemleri için servis sınıfı."""
    
    def __init__(self):
        """Firestore client'ı initialize et."""
        self.db = get_firestore_client()
    
    # =========================================================================
    # MP (Milletvekili) İşlemleri
    # =========================================================================
    
    def get_all_mps(self) -> List[MP]:
        """
        Tüm milletvekillerini getir.
        
        Returns:
            List[MP]: Milletvekili listesi
        """
        docs = self.db.collection(COLLECTION_MPS).stream()
        return [MP.from_dict({**doc.to_dict(), 'id': doc.id}) for doc in docs]
    
    def get_mp_by_id(self, mp_id: str) -> Optional[MP]:
        """
        ID'ye göre milletvekili getir.
        
        Args:
            mp_id: Milletvekili ID'si
            
        Returns:
            MP veya None
        """
        doc = self.db.collection(COLLECTION_MPS).document(mp_id).get()
        if doc.exists:
            return MP.from_dict({**doc.to_dict(), 'id': doc.id})
        return None
    
    def create_mp(self, mp: MP) -> str:
        """
        Yeni milletvekili ekle.
        
        Args:
            mp: Milletvekili nesnesi
            
        Returns:
            str: Oluşturulan dokümanın ID'si
        """
        doc_ref = self.db.collection(COLLECTION_MPS).document(mp.id)
        doc_ref.set(mp.to_dict())
        return mp.id
    
    def update_mp_score(self, mp_id: str, new_score: float) -> bool:
        """
        Milletvekili puanını güncelle.
        
        Args:
            mp_id: Milletvekili ID'si
            new_score: Yeni puan
            
        Returns:
            bool: Güncelleme başarılıysa True
        """
        try:
            doc_ref = self.db.collection(COLLECTION_MPS).document(mp_id)
            doc_ref.update({
                'current_score': new_score,
                'last_updated': datetime.now()
            })
            return True
        except Exception as e:
            print(f"❌ Puan güncelleme hatası ({mp_id}): {str(e)}")
            return False
    
    def update_mp(self, mp_id: str, updates: Dict[str, Any]) -> bool:
        """
        Milletvekili bilgilerini güncelle.
        
        Args:
            mp_id: Milletvekili ID'si
            updates: Güncellenecek alanlar
            
        Returns:
            bool: Güncelleme başarılıysa True
        """
        try:
            doc_ref = self.db.collection(COLLECTION_MPS).document(mp_id)
            updates['last_updated'] = datetime.now()
            doc_ref.update(updates)
            return True
        except Exception as e:
            print(f"❌ MP güncelleme hatası ({mp_id}): {str(e)}")
            return False
    
    def batch_update_mp_scores(self, updates: List[Dict[str, Any]]) -> int:
        """
        Toplu puan güncelleme.
        
        Args:
            updates: [{'mp_id': str, 'score': float}, ...] formatında liste
            
        Returns:
            int: Başarılı güncelleme sayısı
        """
        batch = self.db.batch()
        count = 0
        
        for item in updates:
            mp_id = item.get('mp_id')
            score = item.get('score')
            
            if mp_id and score is not None:
                doc_ref = self.db.collection(COLLECTION_MPS).document(mp_id)
                batch.update(doc_ref, {
                    'current_score': score,
                    'last_updated': datetime.now()
                })
                count += 1
        
        batch.commit()
        return count
    
    # =========================================================================
    # News Analysis (Haber Analizi) İşlemleri
    # =========================================================================
    
    def add_news_analysis(self, analysis: NewsAnalysis) -> str:
        """
        Yeni haber analizi ekle.
        
        Args:
            analysis: NewsAnalysis nesnesi
            
        Returns:
            str: Oluşturulan dokümanın ID'si
        """
        doc_ref = self.db.collection(COLLECTION_NEWS_ANALYSIS).add(analysis.to_dict())
        return doc_ref[1].id
    
    def get_news_by_mp(self, mp_id: str, limit: int = 20) -> List[NewsAnalysis]:
        """
        Belirli bir milletvekiline ait haberleri getir.
        
        Args:
            mp_id: Milletvekili ID'si
            limit: Maksimum haber sayısı
            
        Returns:
            List[NewsAnalysis]: Haber analizleri listesi
        """
        docs = (self.db.collection(COLLECTION_NEWS_ANALYSIS)
                .where('mp_id', '==', mp_id)
                .order_by('created_at', direction='DESCENDING')
                .limit(limit)
                .stream())
        
        return [NewsAnalysis.from_dict({**doc.to_dict(), 'id': doc.id}) for doc in docs]
    
    def get_recent_news_analysis(self, limit: int = 50) -> List[NewsAnalysis]:
        """
        En son eklenen haber analizlerini getir.
        
        Args:
            limit: Maksimum haber sayısı
            
        Returns:
            List[NewsAnalysis]: Haber analizleri listesi
        """
        docs = (self.db.collection(COLLECTION_NEWS_ANALYSIS)
                .order_by('created_at', direction='DESCENDING')
                .limit(limit)
                .stream())
        
        return [NewsAnalysis.from_dict({**doc.to_dict(), 'id': doc.id}) for doc in docs]
    
    def batch_add_news_analysis(self, analyses: List[NewsAnalysis]) -> int:
        """
        Toplu haber analizi ekle.
        
        Args:
            analyses: NewsAnalysis nesneleri listesi
            
        Returns:
            int: Eklenen kayıt sayısı
        """
        batch = self.db.batch()
        count = 0
        
        for analysis in analyses:
            doc_ref = self.db.collection(COLLECTION_NEWS_ANALYSIS).document()
            batch.set(doc_ref, analysis.to_dict())
            count += 1
        
        batch.commit()
        return count
    
    # =========================================================================
    # System Log İşlemleri
    # =========================================================================
    
    def add_log(self, log: SystemLog) -> str:
        """
        Sistem logu ekle.
        
        Args:
            log: SystemLog nesnesi
            
        Returns:
            str: Oluşturulan dokümanın ID'si
        """
        doc_ref = self.db.collection(COLLECTION_LOGS).add(log.to_dict())
        return doc_ref[1].id
    
    def log_info(self, message: str, **kwargs) -> str:
        """Kısayol: INFO logu ekle."""
        log = SystemLog.info(message, **kwargs)
        return self.add_log(log)
    
    def log_error(self, message: str, **kwargs) -> str:
        """Kısayol: ERROR logu ekle."""
        log = SystemLog.error(message, **kwargs)
        return self.add_log(log)
    
    def log_warning(self, message: str, **kwargs) -> str:
        """Kısayol: WARNING logu ekle."""
        log = SystemLog.warning(message, **kwargs)
        return self.add_log(log)
    
    def get_recent_logs(self, limit: int = 100, level: Optional[str] = None) -> List[SystemLog]:
        """
        En son logları getir.
        
        Args:
            limit: Maksimum log sayısı
            level: Opsiyonel log seviyesi filtresi
            
        Returns:
            List[SystemLog]: Sistem logları listesi
        """
        query = self.db.collection(COLLECTION_LOGS)
        
        if level:
            query = query.where('level', '==', level)
        
        docs = (query
                .order_by('timestamp', direction='DESCENDING')
                .limit(limit)
                .stream())
        
        return [SystemLog.from_dict({**doc.to_dict(), 'id': doc.id}) for doc in docs]


# Singleton instance
_service_instance: Optional[FirestoreService] = None


def get_firestore_service() -> FirestoreService:
    """FirestoreService singleton instance döndür."""
    global _service_instance
    if _service_instance is None:
        _service_instance = FirestoreService()
    return _service_instance
