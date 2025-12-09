"""
Veri Modelleri
Firestore koleksiyonları için Python dataclass tanımlamaları.
"""

from dataclasses import dataclass, field, asdict
from datetime import datetime
from typing import Optional, Dict, Any
from enum import Enum


class Party(Enum):
    """Siyasi parti enum'u"""
    AKP = "AKP"
    CHP = "CHP"
    MHP = "MHP"
    IYI = "İYİ"
    HDP = "HDP"
    DEVA = "DEVA"
    GP = "GP"
    SP = "SP"
    BBP = "BBP"
    TIP = "TİP"
    BAGIMSIZ = "Bağımsız"
    OTHER = "Diğer"


class LogLevel(Enum):
    """Log seviyesi enum'u"""
    DEBUG = "DEBUG"
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"


@dataclass
class MP:
    """
    Milletvekili (MP) veri modeli.
    Firestore 'mps' koleksiyonuna yazılacak yapı.
    """
    id: str
    name: str
    party: str
    current_score: float = 0.0
    last_updated: datetime = field(default_factory=datetime.now)
    
    # Opsiyonel alanlar
    constituency: Optional[str] = None  # Seçim bölgesi
    term_count: int = 1  # Dönem sayısı
    law_proposals: int = 0  # Kanun teklifi sayısı
    profile_image_url: Optional[str] = None
    
    def to_dict(self) -> Dict[str, Any]:
        """Firestore'a yazılacak dictionary formatına çevir."""
        data = {
            'id': self.id,
            'name': self.name,
            'party': self.party,
            'current_score': self.current_score,
            'last_updated': self.last_updated,
            'constituency': self.constituency,
            'term_count': self.term_count,
            'law_proposals': self.law_proposals,
            'profile_image_url': self.profile_image_url,
        }
        # None değerleri filtrele
        return {k: v for k, v in data.items() if v is not None}
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'MP':
        """Firestore'dan okunan dictionary'den MP nesnesi oluştur."""
        return cls(
            id=data.get('id', ''),
            name=data.get('name', ''),
            party=data.get('party', 'Diğer'),
            current_score=data.get('current_score', 0.0),
            last_updated=data.get('last_updated', datetime.now()),
            constituency=data.get('constituency'),
            term_count=data.get('term_count', 1),
            law_proposals=data.get('law_proposals', 0),
            profile_image_url=data.get('profile_image_url'),
        )


@dataclass
class NewsAnalysis:
    """
    Haber Analizi veri modeli.
    Firestore 'news_analysis' koleksiyonuna yazılacak yapı.
    """
    mp_id: str
    title: str
    url: str
    sentiment_score: float  # -1.0 (negatif) ile 1.0 (pozitif) arası
    impact_score: float  # 1-10 arası siyasi etki puanı
    created_at: datetime = field(default_factory=datetime.now)
    
    # Opsiyonel alanlar
    id: Optional[str] = None
    source: Optional[str] = None  # Haber kaynağı
    summary: Optional[str] = None  # AI tarafından oluşturulan özet
    keywords: list = field(default_factory=list)  # Anahtar kelimeler
    raw_analysis: Optional[str] = None  # Gemini'nin ham analiz yanıtı
    
    def to_dict(self) -> Dict[str, Any]:
        """Firestore'a yazılacak dictionary formatına çevir."""
        data = {
            'mp_id': self.mp_id,
            'title': self.title,
            'url': self.url,
            'sentiment_score': self.sentiment_score,
            'impact_score': self.impact_score,
            'created_at': self.created_at,
            'source': self.source,
            'summary': self.summary,
            'keywords': self.keywords,
            'raw_analysis': self.raw_analysis,
        }
        if self.id:
            data['id'] = self.id
        # None değerleri filtrele (boş listeler hariç)
        return {k: v for k, v in data.items() if v is not None}
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'NewsAnalysis':
        """Firestore'dan okunan dictionary'den NewsAnalysis nesnesi oluştur."""
        return cls(
            id=data.get('id'),
            mp_id=data.get('mp_id', ''),
            title=data.get('title', ''),
            url=data.get('url', ''),
            sentiment_score=data.get('sentiment_score', 0.0),
            impact_score=data.get('impact_score', 5.0),
            created_at=data.get('created_at', datetime.now()),
            source=data.get('source'),
            summary=data.get('summary'),
            keywords=data.get('keywords', []),
            raw_analysis=data.get('raw_analysis'),
        )


@dataclass
class SystemLog:
    """
    Sistem Log veri modeli.
    Firestore 'logs' koleksiyonuna yazılacak yapı.
    """
    timestamp: datetime
    level: str
    message: str
    details: Optional[Dict[str, Any]] = None
    
    # Opsiyonel alanlar
    id: Optional[str] = None
    job_id: Optional[str] = None  # Batch job ID
    duration_ms: Optional[int] = None  # İşlem süresi (milisaniye)
    affected_records: int = 0  # Etkilenen kayıt sayısı
    
    def to_dict(self) -> Dict[str, Any]:
        """Firestore'a yazılacak dictionary formatına çevir."""
        data = {
            'timestamp': self.timestamp,
            'level': self.level,
            'message': self.message,
            'details': self.details or {},
            'job_id': self.job_id,
            'duration_ms': self.duration_ms,
            'affected_records': self.affected_records,
        }
        if self.id:
            data['id'] = self.id
        return {k: v for k, v in data.items() if v is not None}
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'SystemLog':
        """Firestore'dan okunan dictionary'den SystemLog nesnesi oluştur."""
        return cls(
            id=data.get('id'),
            timestamp=data.get('timestamp', datetime.now()),
            level=data.get('level', 'INFO'),
            message=data.get('message', ''),
            details=data.get('details'),
            job_id=data.get('job_id'),
            duration_ms=data.get('duration_ms'),
            affected_records=data.get('affected_records', 0),
        )
    
    @classmethod
    def info(cls, message: str, **kwargs) -> 'SystemLog':
        """INFO seviyesinde log oluştur."""
        return cls(
            timestamp=datetime.now(),
            level=LogLevel.INFO.value,
            message=message,
            **kwargs
        )
    
    @classmethod
    def error(cls, message: str, **kwargs) -> 'SystemLog':
        """ERROR seviyesinde log oluştur."""
        return cls(
            timestamp=datetime.now(),
            level=LogLevel.ERROR.value,
            message=message,
            **kwargs
        )
    
    @classmethod
    def warning(cls, message: str, **kwargs) -> 'SystemLog':
        """WARNING seviyesinde log oluştur."""
        return cls(
            timestamp=datetime.now(),
            level=LogLevel.WARNING.value,
            message=message,
            **kwargs
        )
