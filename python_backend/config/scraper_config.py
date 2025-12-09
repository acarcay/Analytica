"""
TBMM Scraper Configuration

Scraper için merkezi konfigürasyon sınıfı.
Tüm timeout, retry ve diğer ayarlar bu modülden yönetilir.
"""

from dataclasses import dataclass
from typing import Optional
import os


@dataclass
class ScraperConfig:
    """TBMM Scraper konfigürasyonu."""
    
    # Timeout ayarları (milisaniye)
    default_timeout: int = 30000
    button_click_timeout: int = 5000
    navigation_timeout: int = 20000
    
    # Bekleme süreleri (saniye)
    page_load_wait: float = 2.0
    rate_limit_wait: float = 0.5
    scroll_wait: float = 0.5
    
    # Scroll ayarları
    max_scroll_attempts: int = 10
    
    # Tarayıcı ayarları
    headless: bool = True
    
    # URL ayarları
    base_url: str = "https://www.tbmm.gov.tr"
    
    # Retry ayarları
    max_retries: int = 3
    retry_delay: float = 1.0
    retry_backoff_multiplier: float = 2.0
    
    # Detay çekme limiti
    max_details_fetch: int = 600
    
    @property
    def mp_list_url(self) -> str:
        """Milletvekili liste URL'i."""
        return f"{self.base_url}/milletvekili/liste"
    
    @classmethod
    def from_env(cls) -> "ScraperConfig":
        """Environment variables'dan config oluştur."""
        return cls(
            headless=os.getenv("SCRAPER_HEADLESS", "true").lower() == "true",
            default_timeout=int(os.getenv("SCRAPER_DEFAULT_TIMEOUT", "30000")),
            max_retries=int(os.getenv("SCRAPER_MAX_RETRIES", "3")),
            rate_limit_wait=float(os.getenv("SCRAPER_RATE_LIMIT", "0.5")),
        )


# Default global config instance
default_config = ScraperConfig()
