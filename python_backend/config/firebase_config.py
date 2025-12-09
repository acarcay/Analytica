"""
Firebase Konfigürasyon Modülü
Firestore bağlantısını yöneten singleton pattern implementasyonu.

KURULUM:
1. Firebase Console'dan serviceAccountKey.json dosyasını indirin
2. Bu dosyayı python_backend/ klasörüne koyun
3. .env dosyasında FIREBASE_SERVICE_ACCOUNT_PATH ayarlayın
"""

import os
from typing import Optional
import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv

# Environment variables yükle
load_dotenv()

# Singleton instance
_firestore_client: Optional[firestore.Client] = None
_app: Optional[firebase_admin.App] = None


def get_firestore_client() -> firestore.Client:
    """
    Firestore client instance döndürür.
    İlk çağrıda Firebase'i initialize eder, sonraki çağrılarda aynı instance'ı döndürür.
    
    Returns:
        firestore.Client: Firestore veritabanı client'ı
        
    Raises:
        FileNotFoundError: Service account key dosyası bulunamazsa
        ValueError: Firebase initialization başarısız olursa
    """
    global _firestore_client, _app
    
    if _firestore_client is not None:
        return _firestore_client
    
    # Service account key dosya yolunu al
    service_account_path = os.getenv(
        'FIREBASE_SERVICE_ACCOUNT_PATH', 
        './serviceAccountKey.json'
    )
    
    # Göreceli yolları mutlak yola çevir
    if not os.path.isabs(service_account_path):
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        service_account_path = os.path.join(base_dir, service_account_path)
    
    # Dosyanın varlığını kontrol et
    if not os.path.exists(service_account_path):
        raise FileNotFoundError(
            f"Firebase service account key dosyası bulunamadı: {service_account_path}\n"
            f"Lütfen Firebase Console'dan indirip bu konuma koyun.\n"
            f"Detaylı bilgi için README.md dosyasını okuyun."
        )
    
    try:
        # Firebase credentials oluştur
        cred = credentials.Certificate(service_account_path)
        
        # Firebase app'i initialize et (henüz yapılmadıysa)
        if not firebase_admin._apps:
            _app = firebase_admin.initialize_app(cred)
        
        # Firestore client'ı oluştur
        _firestore_client = firestore.client()
        
        print("✅ Firebase bağlantısı başarılı!")
        return _firestore_client
        
    except Exception as e:
        raise ValueError(f"Firebase initialization hatası: {str(e)}")


def close_firebase_connection():
    """Firebase bağlantısını kapat ve kaynakları serbest bırak."""
    global _firestore_client, _app
    
    if _app is not None:
        firebase_admin.delete_app(_app)
        _app = None
        _firestore_client = None
        print("🔌 Firebase bağlantısı kapatıldı.")


# Test için kullanılabilecek fonksiyon
def test_connection() -> bool:
    """
    Firebase bağlantısını test eder.
    
    Returns:
        bool: Bağlantı başarılıysa True, değilse False
    """
    try:
        client = get_firestore_client()
        # Basit bir koleksiyon referansı al (veri çekmeden)
        _ = client.collection('_test_connection')
        return True
    except Exception as e:
        print(f"❌ Bağlantı testi başarısız: {str(e)}")
        return False


if __name__ == "__main__":
    # Modül doğrudan çalıştırılırsa bağlantıyı test et
    print("Firebase bağlantısı test ediliyor...")
    if test_connection():
        print("✅ Test başarılı!")
    else:
        print("❌ Test başarısız!")
