# FişToplama — Android + iOS + Web

Tek kod tabanından çalışan fiş toplama uygulaması.

## Özellikler

- Android'de kameradan fiş çekme
- Android / iOS'ta galeriden fiş seçme
- Web'de bilgisayardan görsel yükleme
- Şube ve açıklama bilgisi ekleme
- Fiş arşivi ve arama
- PDF'e girecek fişleri seçme
- A4 başına 6 fiş: 2 sütun × 3 satır
- PDF önizleme / yazdırma
- PDF paylaşma / kaydetme
- Responsive yönetim paneli
- Cihaz içi yerel arşiv (Hive)

## GitHub'a yükleme

Bu ZIP'i çıkarın ve klasörün içindeki dosyaları GitHub reposunun KÖK dizinine yükleyin.

Kökte şunlar görünmeli:

- `.github/`
- `lib/`
- `pubspec.yaml`
- `.gitignore`
- `README.md`

`android`, `ios` ve `web` klasörlerini elle oluşturmanız gerekmez. GitHub Actions bunları otomatik üretir.

## Otomatik çıktılar

GitHub > Actions çalışması başarılı olduğunda:

- `FisToplama-Android-APK` → Android APK
- `FisToplama-Web` → web build dosyaları
- `FisToplama-iOS-Unsigned` → imzasız iOS build

### iOS hakkında

Apple cihazına native uygulama kurmak için uygulamanın Apple sertifikasıyla imzalanması gerekir.
GitHub Actions bu projede iOS kodunun derlenebilirliğini kontrol eder ve imzasız build üretir.
TestFlight / App Store dağıtımı için Apple Developer hesabı ve signing yapılandırması gerekir.

### iPhone'da Apple Developer hesabı olmadan kullanma

Web sürümü iPhone Safari'de açılabilir ve **Paylaş > Ana Ekrana Ekle** ile uygulama gibi kullanılabilir.

## GitHub Pages

Workflow web sürümünü GitHub Pages'e yayınlamaya çalışır.

İlk kullanımda repo içinde:

`Settings > Pages > Build and deployment > Source`

alanında **GitHub Actions** seçili olmalıdır.

Sonraki build sonrası siteniz yaklaşık olarak:

`https://KULLANICI.github.io/REPO_ADI/`

adresinde açılır.

## Yerel geliştirme

Bilgisayarda Flutter kuruluysa:

```bash
flutter create --project-name fis_toplama --org com.fistoplama --platforms=android,ios,web .
flutter pub get
flutter run
```

## Not

Bu ilk sürümde fişler her cihazın kendi yerel depolamasında tutulur.
Şirket içinde herkesin aynı fişleri görmesi istenirse sonraki aşamada merkezi backend eklenmelidir:
FastAPI / Supabase / Firebase + kullanıcı girişi + yetkilendirme + bulut dosya depolama.
