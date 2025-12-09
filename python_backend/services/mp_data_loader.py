"""
TBMM Milletvekilleri - Hibrit Veri Kaynağı
1. Curated data (parti bilgisi doğru)
2. TBMM scraper (isimler tam)
3. İkisini birleştir
"""

import re
import hashlib
import time
from typing import List, Optional
from dataclasses import dataclass
from datetime import datetime
from playwright.sync_api import sync_playwright


@dataclass
class TBMMMember:
    """TBMM Milletvekili verisi."""
    name: str
    party: str
    city: str
    
    @property
    def id(self) -> str:
        name_normalized = self.name.lower().replace(' ', '_')
        name_normalized = re.sub(r'[^a-z0-9_]', '', name_normalized)
        hash_suffix = hashlib.md5(self.name.encode()).hexdigest()[:6]
        return f"mv_{name_normalized[:20]}_{hash_suffix}"


# ========== CURATED DATA (Parti Bilgisi Doğru) ==========
CURATED_MPS = [
    # Parti Liderleri
    ("Recep Tayyip Erdoğan", "AKP", "İstanbul"),
    ("Özgür Özel", "CHP", "Manisa"),
    ("Devlet Bahçeli", "MHP", "Osmaniye"),
    ("Müsavat Dervişoğlu", "İYİ", "İzmir"),
    ("Temel Karamollaoğlu", "SP", "Sivas"),
    ("Ali Babacan", "DEVA", "Ankara"),
    ("Ahmet Davutoğlu", "GP", "Konya"),
    
    # AKP Bakanlar ve Önemli İsimler
    ("Binali Yıldırım", "AKP", "İzmir"),
    ("Numan Kurtulmuş", "AKP", "İstanbul"),
    ("Mustafa Şentop", "AKP", "Tekirdağ"),
    ("Fuat Oktay", "AKP", "Yozgat"),
    ("Süleyman Soylu", "AKP", "İstanbul"),
    ("Mevlüt Çavuşoğlu", "AKP", "Antalya"),
    ("Hakan Fidan", "AKP", "Ankara"),
    ("Mehmet Şimşek", "AKP", "Gaziantep"),
    ("Cevdet Yılmaz", "AKP", "Bingöl"),
    ("Yılmaz Tunç", "AKP", "Bartın"),
    ("Abdulkadir Uraloğlu", "AKP", "Trabzon"),
    ("Vedat Işıkhan", "AKP", "Ankara"),
    ("Bekir Bozdağ", "AKP", "Yozgat"),
    ("Nurettin Canikli", "AKP", "Giresun"),
    ("Hayati Yazıcı", "AKP", "Rize"),
    ("Hamza Dağ", "AKP", "İzmir"),
    ("Mehmet Muş", "AKP", "Trabzon"),
    ("Murat Kurum", "AKP", "Konya"),
    ("Yusuf Tekin", "AKP", "Ankara"),
    ("Fatih Şahin", "AKP", "Ankara"),
    ("Ömer Çelik", "AKP", "Adana"),
    ("Mahir Ünal", "AKP", "Kahramanmaraş"),
    ("Bülent Turan", "AKP", "Çanakkale"),
    ("Mustafa Elitaş", "AKP", "Kayseri"),
    ("Efkan Ala", "AKP", "Trabzon"),
    ("Hulusi Akar", "AKP", "Kayseri"),
    ("Derya Yanık", "AKP", "Ankara"),
    ("Fatma Betül Sayan Kaya", "AKP", "İstanbul"),
    ("Mahinur Özdemir Göktaş", "AKP", "İstanbul"),
    ("Zehra Taşkesenlioğlu", "AKP", "Erzurum"),
    ("Cahit Özkan", "AKP", "Denizli"),
    ("Abdullah Güler", "AKP", "İstanbul"),
    ("Osman Aşkın Bak", "AKP", "Rize"),
    ("Ahmet Aydın", "AKP", "Adıyaman"),
    ("Resul Kurt", "AKP", "Adıyaman"),
    ("Ali Özkaya", "AKP", "Afyonkarahisar"),
    ("Cengiz Aydoğdu", "AKP", "Aksaray"),
    ("Haluk İpek", "AKP", "Amasya"),
    ("Vedat Bilgin", "AKP", "Ankara"),
    ("Faruk Çelik", "AKP", "Şanlıurfa"),
    ("Yusuf Ziya Aldatmaz", "AKP", "Balıkesir"),
    ("Selen Yenişehirlioğlu", "AKP", "Manisa"),
    
    # CHP Milletvekilleri
    ("Kemal Kılıçdaroğlu", "CHP", "İstanbul"),
    ("Engin Altay", "CHP", "Sinop"),
    ("Özgür Karabat", "CHP", "İstanbul"),
    ("Gökhan Günaydın", "CHP", "Ankara"),
    ("Murat Emir", "CHP", "Ankara"),
    ("Selin Sayek Böke", "CHP", "İzmir"),
    ("Aykut Erdoğdu", "CHP", "İstanbul"),
    ("Mahmut Tanal", "CHP", "İstanbul"),
    ("Enis Berberoğlu", "CHP", "İstanbul"),
    ("Sezgin Tanrıkulu", "CHP", "İstanbul"),
    ("Ali Mahir Başarır", "CHP", "Mersin"),
    ("Utku Çakırözer", "CHP", "Eskişehir"),
    ("Gamze Taşcıer", "CHP", "İstanbul"),
    ("İlhan Cihaner", "CHP", "İstanbul"),
    ("Tuncay Özkan", "CHP", "İzmir"),
    ("Burhanettin Bulut", "CHP", "Adana"),
    ("Deniz Yavuzyılmaz", "CHP", "Zonguldak"),
    ("Bülent Kuşoğlu", "CHP", "Ankara"),
    ("Alpay Antmen", "CHP", "Mersin"),
    ("Müzeyyen Şevkin", "CHP", "Adana"),
    ("Veli Ağbaba", "CHP", "Malatya"),
    ("Yıldırım Kaya", "CHP", "Ankara"),
    ("Faik Öztrak", "CHP", "Tekirdağ"),
    ("Bülent Tezcan", "CHP", "Aydın"),
    ("Gökçe Gökçen", "CHP", "İstanbul"),
    ("Orhan Sümer", "CHP", "Adana"),
    ("Ayhan Barut", "CHP", "Adana"),
    ("Ahmet Önal", "CHP", "Balıkesir"),
    ("Burcu Köksal", "CHP", "Afyonkarahisar"),
    
    # MHP Milletvekilleri
    ("Semih Yalçın", "MHP", "Ankara"),
    ("Erkan Akçay", "MHP", "Manisa"),
    ("İsmail Faruk Aksu", "MHP", "İstanbul"),
    ("Yaşar Yıldırım", "MHP", "Antalya"),
    ("Olcay Kılavuz", "MHP", "Adana"),
    ("Celal Adan", "MHP", "İstanbul"),
    ("Feti Yıldız", "MHP", "Kayseri"),
    ("Zühal Topcu", "MHP", "Ankara"),
    ("Ahmet Erbaş", "MHP", "Afyonkarahisar"),
    ("Hidayet Vahapoğlu", "MHP", "Bursa"),
    ("Muharrem Varlı", "MHP", "Adana"),
    ("Halil Eldemir", "MHP", "Bilecik"),
    
    # İYİ Parti Milletvekilleri
    ("Tolga Akaltın", "İYİ", "Balıkesir"),
    ("Ümit Özlale", "İYİ", "İzmir"),
    ("Turhan Çömez", "İYİ", "Balıkesir"),
    ("Koray Aydın", "İYİ", "Trabzon"),
    ("Lütfü Türkkan", "İYİ", "Kocaeli"),
    ("Yavuz Ağıralioğlu", "İYİ", "İstanbul"),
    ("İsmail Tatlıoğlu", "İYİ", "Bursa"),
    ("Aylin Cesur", "İYİ", "Isparta"),
    ("Erhan Usta", "İYİ", "Samsun"),
    ("Bilal Bilici", "İYİ", "Adana"),
    ("İsmail Ok", "İYİ", "Balıkesir"),
    
    # DEM Parti Milletvekilleri
    ("Pervin Buldan", "DEM", "İstanbul"),
    ("Tuncer Bakırhan", "DEM", "Van"),
    ("Sırrı Süreyya Önder", "DEM", "İstanbul"),
    ("Ahmet Türk", "DEM", "Mardin"),
    ("Meral Danış Beştaş", "DEM", "Şırnak"),
    ("Sezai Temelli", "DEM", "İstanbul"),
    ("Feleknas Uca", "DEM", "Gaziantep"),
    ("Hüda Kaya", "DEM", "İstanbul"),
    ("Garo Paylan", "DEM", "Diyarbakır"),
    ("Ömer Faruk Gergerlioğlu", "DEM", "Kocaeli"),
    ("Sırrı Sakık", "DEM", "Ağrı"),
    ("Tülay Hatimoğulları Oruç", "DEM", "Adana"),
    ("Ayşe Acar Başaran", "DEM", "Batman"),
    ("Hişyar Özsoy", "DEM", "Diyarbakır"),
    ("Pero Dundar", "DEM", "Şırnak"),
    ("Serpil Kemalbay", "DEM", "İstanbul"),
    ("Nevroz Uysal", "DEM", "Şanlıurfa"),
    ("Salihe Aydeniz", "DEM", "Mardin"),
    
    # TİP Milletvekilleri
    ("Erkan Baş", "TİP", "İstanbul"),
    ("Ahmet Şık", "TİP", "İstanbul"),
    ("Sera Kadıgil", "TİP", "İstanbul"),
    ("Barış Atay", "TİP", "Hatay"),
    
    # DEVA ve GP
    ("Mustafa Yeneroğlu", "DEVA", "İstanbul"),
    ("İdris Şahin", "DEVA", "Çankırı"),
    ("Selçuk Özdağ", "GP", "Manisa"),
    
    # SP
    ("Cihangir İslam", "SP", "İstanbul"),
    ("Lütfi Kaşıkçı", "SP", "Kayseri"),
    
    # Bağımsız
    ("Ümit Özdağ", "ZP", "Ankara"),
    ("Cemal Enginyurt", "BAĞIMSIZ", "Ordu"),
    ("Mustafa Sarıgül", "BAĞIMSIZ", "İstanbul"),
]


def get_curated_members() -> List[TBMMMember]:
    """Curated veri setini döndür."""
    members = []
    for name, party, city in CURATED_MPS:
        members.append(TBMMMember(name=name, party=party, city=city))
    return members


def scrape_tbmm_names() -> List[str]:
    """TBMM sitesinden tüm milletvekili isimlerini çek."""
    url = "https://www.tbmm.gov.tr/milletvekili/liste"
    
    print("🌐 TBMM sitesinden isimler çekiliyor...")
    
    names = []
    
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            page = browser.new_page()
            page.goto(url, wait_until='networkidle', timeout=30000)
            
            # Tüm listeye tıkla
            try:
                page.click('text=TÜM LİSTE', timeout=5000)
                page.wait_for_load_state('networkidle')
                time.sleep(2)
            except:
                pass
            
            # Scroll down
            for _ in range(10):
                page.evaluate('window.scrollTo(0, document.body.scrollHeight)')
                time.sleep(0.3)
            
            # Tüm isimleri çek
            names = page.evaluate('''() => {
                const names = [];
                const links = document.querySelectorAll('a');
                
                links.forEach(link => {
                    const href = link.getAttribute('href') || '';
                    if (href.toLowerCase().includes('/milletvekili/') && 
                        (href.toLowerCase().includes('detay') || href.toLowerCase().includes('ozgecmis'))) {
                        const name = link.innerText.trim();
                        if (name && name.length > 3 && 
                            !['Liste', 'Özgeçmiş', 'E-Posta', 'Telefon'].includes(name)) {
                            names.push(name);
                        }
                    }
                });
                
                return [...new Set(names)];
            }''')
            
            browser.close()
    except Exception as e:
        print(f"❌ Hata: {e}")
    
    print(f"✅ {len(names)} isim çekildi")
    return names


def get_all_mps() -> List[TBMMMember]:
    """Tüm milletvekillerini döndür (curated + TBMM)."""
    
    # 1. Curated data
    curated = get_curated_members()
    curated_names = {m.name.lower() for m in curated}
    
    print(f"📋 {len(curated)} curated milletvekili yüklendi")
    
    # 2. TBMM'den isimleri çek
    tbmm_names = scrape_tbmm_names()
    
    # 3. Eksik olanları ekle
    added = 0
    for name in tbmm_names:
        if name.lower() not in curated_names:
            curated.append(TBMMMember(
                name=name,
                party="Bilinmiyor",
                city="Bilinmiyor"
            ))
            curated_names.add(name.lower())
            added += 1
    
    print(f"➕ {added} ek milletvekili eklendi")
    print(f"✅ Toplam {len(curated)} milletvekili")
    
    return curated


def save_to_firestore(members: List[TBMMMember]) -> int:
    """Firestore'a kaydet."""
    import sys
    import os
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    
    from services.firestore_service import get_firestore_service
    from models.mp_models import MP
    
    firestore = get_firestore_service()
    count = 0
    skipped = 0
    
    print(f"\n💾 {len(members)} milletvekili Firestore'a kaydediliyor...")
    
    for member in members:
        try:
            mp = MP(
                id=member.id,
                name=member.name,
                party=member.party,
                current_score=0.0,
                last_updated=datetime.now(),
                constituency=member.city,
                term_count=1,
                law_proposals=0,
                profile_image_url=None
            )
            firestore.create_mp(mp)
            count += 1
            
            if count % 50 == 0:
                print(f"  ✅ {count} milletvekili kaydedildi...")
            
        except Exception as e:
            err_msg = str(e).lower()
            if "already exists" in err_msg or "duplicate" in err_msg:
                skipped += 1
            else:
                print(f"  ⚠️ Kayıt hatası ({member.name}): {str(e)[:40]}")
    
    print(f"\n✅ Toplam {count} yeni milletvekili kaydedildi!")
    if skipped > 0:
        print(f"ℹ️  {skipped} milletvekili zaten kayıtlı (atlandı)")
    return count


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='TBMM MP Data Loader')
    parser.add_argument('--save', action='store_true', help='Firestore\'a kaydet')
    parser.add_argument('--curated-only', action='store_true', help='Sadece curated data')
    args = parser.parse_args()
    
    if args.curated_only:
        members = get_curated_members()
    else:
        members = get_all_mps()
    
    # Sonuçları göster
    print(f"\n📋 İlk 20 milletvekili:")
    for i, m in enumerate(members[:20], 1):
        print(f"  {i}. {m.name} ({m.party}) - {m.city}")
    
    # Parti dağılımı
    parties = {}
    for m in members:
        parties[m.party] = parties.get(m.party, 0) + 1
    
    print(f"\n📊 Parti Dağılımı:")
    for party, count in sorted(parties.items(), key=lambda x: -x[1]):
        print(f"  {party}: {count}")
    
    # Firestore'a kaydet
    if args.save and members:
        save_to_firestore(members)
