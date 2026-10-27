# Traffic Escape – Oyun Tasarımı ve Yol Haritası

Bu belge oyunun yayına kadar ve sonrasındaki yapısını tek yerde toplar.
Her geliştirme adımı bu belgedeki fazlara göre ilerler; karar değişirse önce
burası güncellenir.

---

## 1. Hedef ve ilkeler

**Hedef:** Play Store'da yüksek puanlı (4,5+), uzun süre oynanan, reklam ve
uygulama içi satın almayla gelir getiren bir bulmaca oyunu.

**Tasarım ilkeleri**

1. **Kısa ve tatmin edici oturumlar.** Bir bölüm 1–3 dakika. Her dokunuş net
   bir sonuç verir (çıkış ya da çarpışma).
2. **Adil zorluk.** Her bölüm çözücüyle doğrulanır; kaybetmek her zaman
   oyuncunun hatasıdır, şansa bağlı değildir.
3. **Saygılı monetizasyon.** Oyun ortasında asla reklam yok. Ödüllü reklam
   her zaman isteğe bağlı. Reklamsız paket gerçekten reklamsız hissettirir.
4. **Kalite hissi.** 60 FPS, akıcı geçişler, tutarlı görsel dil, ses ve
   titreşim geri bildirimi (mevcut çarpışma hissi korunur).
5. **Her şey veriyle ayarlanır.** Bölüm zorluğu, ödüller ve reklam sıklığı
   koddan değil yapılandırmadan gelir; yayından sonra ölçülerek ince ayar
   yapılır.

---

## 2. Oyun döngüleri

### Çekirdek döngü (bir bölüm)
Bölümü aç → araçları doğru sırayla çıkar (combo, ipucu, kurtarmalar) →
sonuç ekranı (yıldız, jeton, combo, süre) → sonraki bölüm.

### Meta döngü (oturumlar arası)
- **Jeton** → kurtarmalar (güçlendiriciler) ve garaj kozmetikleri.
- **Yıldız** → yeni dünyaların kilidini açar.
- **Günlük bulmaca + seri** → her gün geri gelme nedeni.
- **Günlük hediye takvimi (7 gün)** → ilk haftayı tutar.
- **Başarımlar** → uzun vadeli hedefler.

---

## 3. İçerik yapısı

### Dünyalar
Her dünya 20 bölüm; kendi çevresi, müziği ve **bir yeni mekaniği** vardır.
Dünya içinde gün sabahtan akşama ilerler (mevcut günün saati sistemi).

| Dünya | Ortam | Yeni mekanik | Açılış |
|---|---|---|---|
| 1 | Şehir otoparkı | Temel kurallar, koniler | Başta açık |
| 2 | Sahil kasabası | **Tek yönlü şerit oku**: araç çıkınca yolda zorunlu yöne döner | 40 ★ |
| 3 | Karlı dağ köyü | **Kilitli araç**: anahtar rengindeki araç çıkmadan hareket etmez | 80 ★ |
| 4 | Gece şehri | **Zamanlı bariyer**: belirli araç çıkınca otopark içindeki kapı açılır | 120 ★ |
| 5 | Havalimanı / liman | **Çoklu çıkış**: iki çıkış kapısı, araç en yakın kapıya gider | 160 ★ |

Yayında 5 dünya × 20 = **100 bölüm**. Yayından sonra her 3–4 haftada bir
yeni dünya (güncelleme = oyuncuyu geri getirir).

### Zorluk eğrisi (testere dişi)
- Dünya içinde zorluk artar; her 5. bölüm bir "nefes" bölümü (kolay, çok
  combo yapılabilir).
- Her dünyanın 10. ve 20. bölümü **zor bölüm** (rozetli, daha fazla jeton).
- Yeni mekanik ilk kez çıktığında 2 bölümlük kısa öğretici + ipucu.
- Zorluk ölçüleri: çözüm derinliği (dalga sayısı), başta serbest araç
  sayısı, araç sayısı, mekanik yoğunluğu. Hepsi bölüm üreticisinde
  parametre.

### Hamle hakkı
Standart 3. Zor bölümlerde 3 kalır ama dizilim daha sıkıdır. Kaybetmek
bölümün başına döndürür (ilerleme kaybı yok).

---

## 4. Kurtarmalar (güçlendiriciler)

| Kurtarma | Ne yapar | Nasıl alınır |
|---|---|---|
| **İpucu** | Doğru aracı hemen parlatır | Günde 3 ücretsiz, sonra 30 jeton veya ödüllü reklam |
| **Geri al** | Son çarpışmayı geri alır, hakkı iade eder | 50 jeton |
| **Vinç** | Seçilen bir aracı yukarı kaldırıp çıkarır | 120 jeton veya ödüllü reklam (günde 2) |
| **Devam et (+2 hak)** | Kaybedince bölüm kaldığı yerden devam eder | Ödüllü reklam veya 100 jeton |

- İlk kez 6. bölümde ücretsiz 1 vinç hediye edilir ve kısa bir öğreticiyle
  tanıtılır.
- Kurtarmalar bölüm içinde altta küçük bir çubukta durur; oyunu
  kalabalıklaştırmaz.

---

## 5. Ekonomi

| Kaynak | Jeton |
|---|---|
| Bölüm tamamlama | 10 |
| Yıldız bonusu | ★★ +5, ★★★ +10 |
| Combo bonusu | En uzun combo × 2 (en fazla +10) |
| Zor bölüm | ×2 |
| Bölüm sonu "jetonları 2 katına çıkar" | Ödüllü reklam |
| Günlük hediye takvimi | 20 → 100 (7. gün + vinç) |
| Günlük bulmaca | 30 + seri bonusu |

**Yıldız:** hatasız ★★★, 1 hata ★★, 2 hata ★.

**Harcama:** kurtarmalar, garaj (araç renkleri, kaplamalar, korna sesleri:
100–1000 jeton), dünya temaları (ileride).

Değerler `data/economy.json` benzeri bir yapılandırmada tutulur; yayından
sonra ölçümlere göre ayarlanır.

---

## 6. Oyuncuyu tutan sistemler

- **İlk 5 dakika:** eğitim kartı (var) → 1–3. bölümler kural öğretir → 5.
  bölüme kadar hiçbir reklam yok → 6. bölümde ilk kurtarma hediye.
- **Günlük hediye takvimi** (7 gün, kaçırılırsa baştan).
- **Günlük bulmaca:** her gün tarihten üretilen tek bölüm (herkes aynı
  bölümü oynar) + seri sayacı.
- **Başarımlar:** "10 bölümü hatasız bitir", "x5 combo", "100 araç çıkar",
  dünya tamamlama vb. Sonra Google Play Games'e bağlanır.
- **Garaj:** kozmetik hedefler (oynanışı etkilemez, adil).
- **Yerel bildirim (isteğe bağlı, varsayılan kapalı değil ama nazik):**
  "Günlük bulmacan hazır" günde en fazla 1.
- **Sonuç ekranı:** süre, en uzun combo, kazanılan jeton sayaç gibi dolar;
  rekor kırılınca kutlama.

---

## 7. Monetizasyon

### Ödüllü reklam (isteğe bağlı, ana gelir)
- Kaybedince **devam et (+2 hak)**
- Bölüm sonunda **jetonları 2 katına çıkar**
- **Ücretsiz ipucu / vinç** (günlük sınırlı)
- **Günlük hediyeyi 2 katına çıkar**
- Günlük toplam sınır (ör. 15) — oyuncu yorulmasın.

### Geçiş reklamı (interstitial, kurallı)
- **Asla** oyun sırasında veya bir dokunuşun ortasında değil; yalnızca bölüm
  sonu ekranından sonraki bölüme geçerken.
- İlk **8 bölümde hiç** yok.
- En az **2 bölümde bir** ve en az **120 saniye** arayla.
- Oyuncu son 3 dakikada ödüllü reklam izlediyse gösterilmez.
- Kaybedip tekrar denerken gösterilmez (sinir bozucu).

### Banner
**Yok.** Tablet ve bulmaca deneyimini bozar, getirisi düşük, puanı düşürür.

### Uygulama içi satın alma
| Ürün | Tür | İçerik |
|---|---|---|
| **Reklamsız (ömür boyu)** | Tek seferlik | Tüm geçiş reklamları kalkar; ödüllü reklam teklifleri reklamsız ödüle dönüşür (günlük sınır içinde) + 500 jeton |
| **Başlangıç paketi** | Tek seferlik, 15. bölümden sonra 48 saat | Reklamsız + 3 vinç + 1000 jeton, indirimli |
| Jeton paketleri | Tüketilebilir | 500 / 1500 / 4000 |

Önerilen fiyat seviyeleri: Reklamsız ≈ 2,99 $, başlangıç paketi ≈ 4,99 $.
Play Console fiyatları ülkeye göre yerelleştirir.
"Satın alımları geri yükle" ayarlarda bulunur.

### Teknik
- **AdMob** (Godot 4 Android eklentisi) + **UMP rıza formu** (GDPR/KVKK).
- **Google Play Billing** (Godot 4 resmi eklentisi).
- İkisi de Android Gradle derlemesi gerektirir (Faz 4).
- Reklam kararları tek bir `AdManager` içinde, kurallar yapılandırmada.

---

## 8. Kalite çıtası (Play Store)

- **Performans:** orta segment tablette 60 FPS; en kalabalık bölüm ≤ 250
  çizim çağrısı (şu an ~195); indirme boyutu < 150 MB; soğuk açılış < 3 sn.
- **Diller:** yayında Türkçe + İngilizce (çeviri altyapısı Godot CSV).
- **Ayarlar ekranı:** dil, ses, müzik, titreşim, hız, satın alımları geri
  yükle, gizlilik politikası, künye (CC-BY yazarları – zorunlu).
- **Kayıt:** sürüm numaralı kayıt dosyası, bozulmaya dayanıklı; ileride Play
  Games bulut kaydı.
- **Erişilebilirlik:** büyük dokunma alanları, renge bağlı olmayan bilgi
  (oklar), titreşim/ses ayrı ayrı kapatılabilir.
- **Ölçümleme:** bölüm başla/bitir/kaybet, kurtarma kullanımı, reklam
  izleme. Zorluk ve ekonomi buna göre ayarlanır (Firebase Analytics veya
  GameAnalytics).
- **Uyum:** gizlilik politikası, Play "Veri güvenliği" formu, IARC yaş
  derecelendirmesi, hedef kitle 13+ (çocuk programı reklam kısıtlarından
  kaçınmak için).

---

## 9. Fazlar

Her faz sonunda: testler + oynanış senaryosu + ekran görüntüsüyle onay.

### Faz 1 – Temel yapı ve meta iskeleti
- Kayıt v2 (jeton, yıldız, dünya ilerlemesi, kurtarma envanteri, ayarlar).
- Bölüm sonu ekranı: yıldızlar, jeton, combo, süre (sayaç animasyonlu).
- Dünya haritası + dünya içinde bölüm seçimi (yıldız kilitleri).
- Ayarlar ekranı (künye, dil, satın alımları geri yükle yeri).
- TR/EN çeviri altyapısı.
- Ekonomi yapılandırma dosyası.

### Faz 2 – İçerik
- 4 yeni mekanik: kurallar + çözücü + testler + görseller + öğretici.
- Bölüm üreticisi dünya/mekanik parametreleriyle; 100 bölüm, testere dişi
  zorluk, zor bölüm işaretleri.
- 5 dünya ortamı (tema, çevre modelleri, müzik).

### Faz 3 – Kurtarmalar ve tutundurma
- İpucu, geri al, vinç, devam et + bölüm içi kurtarma çubuğu.
- Mağaza (jeton harcama) ve garaj.
- Günlük hediye takvimi, günlük bulmaca + seri, başarımlar.

### Faz 4 – Monetizasyon ve Android
- Android Gradle dışa aktarma (titreşim izni, tam ekran, uyarlanabilir
  simge, JSON dosyaları pakette).
- AdMob + UMP rıza, AdManager kuralları.
- Play Billing: reklamsız, başlangıç paketi, jeton paketleri, geri yükleme.
- Gizlilik politikası, veri güvenliği.

### Faz 5 – Yayın
- Ölçümleme, mağaza görselleri (ekran görüntüleri, tanıtım videosu, öne
  çıkan görsel), ASO metinleri.
- **Kapalı test:** yeni kişisel geliştirici hesaplarında Google, üretime
  çıkmadan önce **en az 12 test kullanıcısıyla 14 gün** kapalı test ister.
- Hata düzeltme → üretim yayını.

### Yayın sonrası
- Her 3–4 haftada yeni dünya, mevsimsel etkinlikler, ölçümlere göre denge.
