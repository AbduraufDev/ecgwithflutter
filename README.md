# HRV (Heart Rate Variability) O'lchash Aplikatsiyasi

Professional Flutter aplikatsiyasi - smartfon kamerasida barmoq qo'yib yurak variabilligini (HRV) o'lchasish.

## Xususiyatlari

✅ **Photoplethysmography (PPG)** - barmoq qonidan HRV o'lchash
✅ **Real-time signal processing** - 30 FPS'da signal analizi
✅ **HRV Metrikalari**: SDNN, RMSSD, pNN50, LF/HF ratio
✅ **Stress Index** - stress darajasi 1-10 scale'da
✅ **Recovery Potential** - fisik qayta tiklanish salohiyati
✅ **Tarix va Analytics** - o'lchashlarning grafiklari va trendu
✅ **SQLite Database** - barcha natijalarni saqlash
✅ **Signal Quality Assessment** - signal sifatini real-time baholash

## Faylu Tuzilimi

```
hrv_app/
├── lib/
│   ├── main.dart                          # App entry point
│   ├── screens/
│   │   ├── hrv_measurement_screen.dart   # Asosiy o'lchash ekrani
│   │   └── history_screen.dart           # Tarix va analytics
│   └── services/
│       ├── hrv_calculator.dart           # HRV hisob-kitoblar
│       ├── camera_signal_processor.dart  # Kamera signal processing
│       └── hrv_database.dart             # SQLite database
├── android/
│   └── app/src/main/AndroidManifest.xml  # Android ruxsatlar
├── ios/
│   └── Runner/Info.plist                 # iOS ruxsatlar
└── pubspec.yaml                          # Dependencies
```

## Installation

### Talabalar
- Flutter SDK (3.0 yoki undan yuqori)
- Xonali kamera va chiroqli smartfon
- Minimal iOS 11.0, Android 5.0

### Qadamlar

1. **Flutter project yaratish** (Agar boshlangi yo'q bo'lsa):
```bash
flutter create hrv_app
cd hrv_app
```

2. **pubspec.yaml ni yangilash**:
Yuqoridagi pubspec.yaml dan barcha dependencies ni nusxalang

3. **Dependencies o'rnatish**:
```bash
flutter pub get
```

4. **Project tuzing**:
```bash
flutter clean
flutter pub get
```

5. **Android setup** (Android uchun):
- `android/app/src/main/AndroidManifest.xml` ni yuklidagi file bilan almashtiring
- Minimum Android 5.0 talab qiladi

6. **iOS setup** (iOS uchun):
- `ios/Runner/Info.plist` ni yuklidagi file bilan almashtiring
- Xcode'da team signing o'rnatish kerak bo'ladi

7. **Ishga tushirish**:
```bash
flutter run
```

## Qanday Ishlaydi

### HRV O'lchash Jarayoni

1. **Signal Topish**:
   - Barmoqni kamera va flashga to'liq qo'ying
   - LED chiroq barmoqdagi qonni yoritadi
   - Kamera o'zgarishlari kuzatadi

2. **Signal Processing** (30 soniya):
   - Har frame'dan brightness qiymatini chiqarish
   - Bandpass filter (0.4-4.0 Hz) qo'llash
   - Qalb urushlarini (peaks) topish

3. **RR Intervals Hisoblash**:
   - Har bir beat orasidagi vaqtni ms'da hisoblash
   - Minimal 30 beats kerak bo'ladi

4. **HRV Metrikalari**:
   - **SDNN** = RR intervals ning standart chetlanishi (variability)
   - **RMSSD** = Ketma-ket intervals farqining RMS'i (parasympathetic)
   - **pNN50** = 50ms dan ko'p farq bo'lgan intervals foizi
   - **LF/HF** = Frequency domain analysis (sympathetic/parasympathetic)

5. **Stress Index**:
   ```
   Stress = (1 - RMSSD/SDNN) * 10
   ```
   - 1-3: Yuqori recovery potensiali
   - 4-6: Balansli
   - 7-10: Yuqori stress

## Kod Qismlar

### 1. HRV Hisoblash (`hrv_calculator.dart`)

```dart
// Signal qo'shish
_hrvCalculator.addRawSignalValue(brightness);

// Natijalarni olish
int bpm = _hrvCalculator.getHeartRate();
double sdnn = _hrvCalculator.getSDNN();
double rmssd = _hrvCalculator.getRMSSD();
int stressIndex = _hrvCalculator.getStressIndex();

// To'liq report
Map report = _hrvCalculator.getFullReport();
```

### 2. Kamera Signal (`camera_signal_processor.dart`)

```dart
// Frame'dan signal chiqarish (PPG)
double brightness = CameraSignalProcessor.processFrame(image);

// Signal sifatini baholash (0-100%)
int quality = CameraSignalProcessor.assessSignalQuality(signals);
```

### 3. Database (`hrv_database.dart`)

```dart
// O'lchashni saqlash
await HRVDatabase().saveMeasurement(measurement);

// Tarixni olish
List<HRVMeasurement> history = await HRVDatabase().getLast7DaysMeasurements();

// Analytics
Map stats = await HRVDatabase().getAverageStats(measurements);
```

## Signal Processing Tafsilotlar

### Photoplethysmography (PPG)

PPG - barmoq qonining o'zgarishlarini o'lchash usuli:

```
LED yonib turadi
    ↓
Barmoqdagi qon oq'ni o'zgaradi
    ↓
Kamera rangda o'zgarishlarni ko'radi
    ↓
Signal: Qalb urishi = Brightness o'zgarishi
```

### Signal Filterlash

1. **Moving Average** - 5-pixel oyna
2. **Peak Detection** - Adaptive threshold
3. **Anomaly Filter** - 300-2000ms RR intervals

### Frequency Analysis

- **FFT** yordamida frequency spectrum
- **LF (0.04-0.15 Hz)**: Sympathetic (stress)
- **HF (0.15-0.4 Hz)**: Parasympathetic (relaksatsiya)
- **LF/HF Ratio**: Autonomic balance

## Tipik Qiymatlar

| Metrika | Tipik Range | Yaxshi Ko'rsatka |
|---------|------------|-----------------|
| Heart Rate | 40-200 BPM | 60-100 BPM |
| SDNN | 20-200 ms | > 100 ms |
| RMSSD | 10-200 ms | > 50 ms |
| pNN50 | 0-100% | > 30% |
| Stress Index | 1-10 | 1-5 |

## Masalalarni Hal Qilish

### "Signal sifati past"
- Barmoqni oz o'tkazing, flashni to'liq qo'ying
- Barmoqni hatto harakatlantirmang
- Juda oyog'i, yo juda qorong'i joyni tekshiring

### "Yetarli ma'lumot yo'q"
- Minimal 30 beats kerak (1+ daqiqa)
- Barmoq o'n to'liq bo'lishi kerak
- O'lchashni yana qayta urinib ko'ring

### "Anomaliy qiymatlar"
- Barmoqni yana qo'ying
- Tish 30+ sekund uchun o'lchang
- Stressli bo'lmang, tinch o'tiring

## Texnik Tafsilotlar

### Algoritm Parametrlari
- **Buffer Size**: 256 frames
- **Camera FPS**: 30
- **Min RR Interval**: 300 ms
- **Max RR Interval**: 2000 ms
- **Filter Window**: 5 pixels

### Performance
- Processing: ~50ms per buffer
- Memory: ~10-15MB
- Database: SQLite with indexing

## Keyingi Versiya

- [ ] Apple Health / Google Fit integration
- [ ] Smartwatch support
- [ ] Cloud backup
- [ ] AI-based anomaly detection
- [ ] Wellness recommendations
- [ ] Multi-language support

## Litsenziya

MIT License

## Yordam va Savollari

Agar xatolikka duch kelsangiz yoki savollishingiz bo'lsa:
1. Signal sifatini tekshiring (screen'da yashil bo'lishi kerak)
2. Barmoqning pozitsiyasini o'zgartiring
3. Flashning ishlayotganini tekshiring
4. App'ni restart qiling

---

**Sog'liq qayta tiklanishingiz davom etsin!** 🏥❤️
