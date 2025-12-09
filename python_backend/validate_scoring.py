"""
Puanlama Sistemi Doğrulama Scripti
===================================

Bu script puanlama sisteminin mantıklı çalışıp çalışmadığını kontrol eder.
"""

import json
from pathlib import Path
from collections import defaultdict

import firebase_admin
from firebase_admin import credentials, firestore


def init_firestore():
    """Firebase bağlantısını başlat."""
    if not firebase_admin._apps:
        cred = credentials.Certificate("serviceAccountKey.json")
        firebase_admin.initialize_app(cred)
    return firestore.client()


def validate_scoring():
    """Puanlama sistemini doğrula."""
    
    db = init_firestore()
    
    print("=" * 70)
    print("📊 PUANLAMA SİSTEMİ DOĞRULAMA RAPORU")
    print("=" * 70)
    
    # Tüm vekilleri çek
    mps = []
    docs = db.collection('mps').stream()
    for doc in docs:
        data = doc.to_dict()
        data['id'] = doc.id
        mps.append(data)
    
    print(f"\n📌 Toplam Vekil: {len(mps)}")
    
    # =========================================================================
    # 1. TOP 20 VE BOTTOM 20
    # =========================================================================
    
    sorted_mps = sorted(mps, key=lambda x: x.get('current_score', 0), reverse=True)
    
    print("\n" + "=" * 70)
    print("🏆 EN YÜKSEK PUANLI 20 VEKİL")
    print("=" * 70)
    print(f"{'#':<3} {'İsim':<35} {'Parti':<12} {'Puan':<8} {'Komisyon':<8}")
    print("-" * 70)
    
    for i, mp in enumerate(sorted_mps[:20], 1):
        name = mp.get('name', '')[:33]
        party = mp.get('party', '')[:10]
        score = mp.get('current_score', 0)
        commission = mp.get('commission_bonus', 0)
        print(f"{i:<3} {name:<35} {party:<12} {score:<8.1f} {commission:<8}")
    
    print("\n" + "=" * 70)
    print("📉 EN DÜŞÜK PUANLI 20 VEKİL (Hayalet olmayanlar)")
    print("=" * 70)
    
    # Hayalet olmayanlardan en düşük puanlılar
    non_ghost = [m for m in sorted_mps if m.get('impact_label') != 'Ghost']
    bottom_20 = sorted(non_ghost, key=lambda x: x.get('current_score', 0))[:20]
    
    print(f"{'#':<3} {'İsim':<35} {'Parti':<12} {'Puan':<8} {'Etki':<8}")
    print("-" * 70)
    
    for i, mp in enumerate(bottom_20, 1):
        name = mp.get('name', '')[:33]
        party = mp.get('party', '')[:10]
        score = mp.get('current_score', 0)
        impact = mp.get('impact_label', '')
        print(f"{i:<3} {name:<35} {party:<12} {score:<8.1f} {impact:<8}")
    
    # =========================================================================
    # 2. PARTİ BAZINDA İSTATİSTİKLER
    # =========================================================================
    
    print("\n" + "=" * 70)
    print("📊 PARTİ BAZINDA İSTATİSTİKLER")
    print("=" * 70)
    
    party_stats = defaultdict(lambda: {'scores': [], 'ghost': 0, 'high': 0})
    
    for mp in mps:
        party = mp.get('party', 'Diğer')
        score = mp.get('current_score', 0)
        impact = mp.get('impact_label', '')
        
        party_stats[party]['scores'].append(score)
        if impact == 'Ghost':
            party_stats[party]['ghost'] += 1
        elif impact == 'High':
            party_stats[party]['high'] += 1
    
    print(f"{'Parti':<15} {'Vekil':<7} {'Ortalama':<10} {'Max':<8} {'Min':<8} {'Hayalet':<8} {'Yüksek':<8}")
    print("-" * 70)
    
    for party, stats in sorted(party_stats.items(), key=lambda x: -len(x[1]['scores'])):
        count = len(stats['scores'])
        avg = sum(stats['scores']) / count if count > 0 else 0
        max_s = max(stats['scores']) if stats['scores'] else 0
        min_s = min(stats['scores']) if stats['scores'] else 0
        ghost = stats['ghost']
        high = stats['high']
        
        print(f"{party[:13]:<15} {count:<7} {avg:<10.1f} {max_s:<8.1f} {min_s:<8.1f} {ghost:<8} {high:<8}")
    
    # =========================================================================
    # 3. BİLİNEN ÖRNEKLER KONTROLÜ
    # =========================================================================
    
    print("\n" + "=" * 70)
    print("🔍 BİLİNEN ÖRNEKLER KONTROLÜ")
    print("=" * 70)
    
    known_checks = [
        ("ÖZGÜR ÖZEL", "CHP Genel Başkanı - Yüksek puan beklenir"),
        ("NUMAN KURTULMUŞ", "TBMM Başkanı - Prosedürel filtre, düşük puan"),
        ("SÜLEYMAN SOYLU", "İçişleri Kom. Başkanı - +25 komisyon bonusu"),
        ("MEHMET MUŞ", "Plan ve Bütçe Kom. Başkanı - +25 komisyon bonusu"),
        ("HULUSI AKAR", "Milli Savunma Kom. Başkanı - +25 komisyon bonusu"),
        ("DEVLET BAHÇELİ", "MHP Genel Başkanı"),
        ("MERAL AKŞENER", "İYİ Parti - Yüksek aktivite beklenir"),
    ]
    
    mps_by_name = {mp.get('name', ''): mp for mp in mps}
    
    for name, description in known_checks:
        mp = mps_by_name.get(name)
        if mp:
            score = mp.get('current_score', 0)
            party = mp.get('party', '')
            impact = mp.get('impact_label', '')
            proposals = mp.get('first_signature', 0)
            questions = mp.get('written_questions', 0)
            treaties = mp.get('filtered_treaties', 0)
            commission = mp.get('commission_bonus', 0)
            
            status = "✅" if score > 0 else "⚠️"
            print(f"\n{status} {name}")
            print(f"   📝 {description}")
            print(f"   Parti: {party} | Puan: {score} | Etki: {impact}")
            print(f"   Teklif: {proposals} | Soru: {questions} | Filtrelenen: {treaties} | Komisyon: {commission}")
        else:
            print(f"\n❌ {name} - BULUNAMADI")
    
    # =========================================================================
    # 4. KOMİSYON BAŞKANLARI
    # =========================================================================
    
    print("\n" + "=" * 70)
    print("🏛️ KOMİSYON BAŞKANLARI (+25 BONUS KONTROLÜ)")
    print("=" * 70)
    
    # Komisyon başkanları listesi
    commission_chairs = [
        "CÜNEYT YÜKSEL",        # Adalet
        "SERAP YAZICI ÖZBUDUN", # Anayasa
        "BURHAN KAYATÜRK",      # AB Uyum
        "ADİL KARAİSMAİLOĞLU",  # Bayındırlık
        "MEHMET GALİP ENSARİOĞLU",  # Çevre
        "FUAT OKTAY",           # Dışişleri
        "SUNAY KARAMIK",        # Dilekçe
        "NAZIM ELMAS",          # Dijital Mecralar
        "SÜLEYMAN SOYLU",       # İçişleri
        "DERYA YANIK",          # İnsan Hakları
        "ÇİĞDEM ERDOĞAN",       # KEFEK
        "MUSTAFA SAVAŞ",        # KİT
        "AYŞEN GÜRCAN",         # Milli Eğitim
        "HULUSİ AKAR",          # Milli Savunma
        "MEHMET MUŞ",           # Plan ve Bütçe
        "VEDAT BİLGİN",         # Sağlık
        "MUSTAFA VARANK",       # Sanayi
        "VAHİT KİRİŞCİ",        # Tarım
    ]
    
    chairs_with_bonus = 0
    for name in commission_chairs:
        mp = mps_by_name.get(name)
        if mp:
            bonus = mp.get('commission_bonus', 0)
            if bonus >= 25:
                chairs_with_bonus += 1
                status = "✅"
            else:
                status = "⚠️"
            print(f"{status} {name[:30]:<32} Komisyon Bonusu: {bonus}")
        else:
            print(f"❌ {name[:30]:<32} BULUNAMADI")
    
    print(f"\n📊 {chairs_with_bonus}/{len(commission_chairs)} komisyon başkanı +25 bonus almış")
    
    # =========================================================================
    # 5. ÖZET
    # =========================================================================
    
    print("\n" + "=" * 70)
    print("📋 DOĞRULAMA ÖZETİ")
    print("=" * 70)
    
    total_ghost = sum(1 for m in mps if m.get('impact_label') == 'Ghost')
    total_high = sum(1 for m in mps if m.get('impact_label') == 'High')
    avg_score = sum(m.get('current_score', 0) for m in mps) / len(mps) if mps else 0
    
    print(f"  Toplam Vekil: {len(mps)}")
    print(f"  Ortalama Puan: {avg_score:.1f}")
    print(f"  Hayalet Vekil: {total_ghost} ({100*total_ghost/len(mps):.1f}%)")
    print(f"  Yüksek Etkili: {total_high} ({100*total_high/len(mps):.1f}%)")
    print(f"  Komisyon Başkanı Doğru: {chairs_with_bonus}/{len(commission_chairs)}")


if __name__ == "__main__":
    validate_scoring()
