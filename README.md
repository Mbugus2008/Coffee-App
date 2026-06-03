# ☕ Coffee App

[![CI — Analyze & Test](https://github.com/$(echo $GITHUB_REPOSITORY 2>/dev/null || echo "your-org/coffee-app")/actions/workflows/ci.yml/badge.svg)](https://github.com/$(echo $GITHUB_REPOSITORY 2>/dev/null || echo "your-org/coffee-app")/actions/workflows/ci.yml)
[![CD — Build & Release](https://github.com/$(echo $GITHUB_REPOSITORY 2>/dev/null || echo "your-org/coffee-app")/actions/workflows/cd.yml/badge.svg)](https://github.com/$(echo $GITHUB_REPOSITORY 2>/dev/null || echo "your-org/coffee-app")/actions/workflows/cd.yml)

A Flutter app for managing coffee farmer collections, stores, and daily production data — with Bluetooth thermal printer support and Microsoft Business Central integration.

## ✨ Features

- 📋 **Farmers Management** — Add, edit, and track coffee farmers
- 📦 **Daily Collections** — Record and manage daily coffee collections
- 🏪 **Store Management** — Manage store headers and line items
- 🖨️ **Bluetooth Printing** — Print receipts via thermal printer
- ☁️ **Business Central Sync** — OData integration with Microsoft BC
- 👥 **User Management** — Role-based access with login/password
- 📱 **Multi-Platform** — Android, iOS, Windows, Linux, macOS, Web

## 📋 Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.x stable)
- A code editor (VS Code recommended)

## 🚀 Getting Started

### 1. Clone & Install

```bash
git clone <repo-url>
cd coffee
flutter pub get
```

### 2. Run the app

```bash
# Run on connected device / emulator
flutter run

# Run for a specific platform
flutter run -d chrome       # Web
flutter run -d windows      # Windows Desktop
```

### 3. Build for release

```bash
flutter build apk --release          # Android APK
flutter build appbundle --release    # Android AppBundle (Play Store)
flutter build ios --release          # iOS (macOS only)
```

## 🤖 CI/CD Pipelines

### CI — Continuous Integration (`.github/workflows/ci.yml`)

Triggers on **push/PR to `main` or `develop`**:

| Stage | What it does |
|-------|-------------|
| `analyze` | Runs `flutter analyze` (linter) |
| `test` | Runs `flutter test` with coverage |
| `build-android-debug` | Builds a debug APK as a build artifact |

### CD — Continuous Delivery (`.github/workflows/cd.yml`)

Triggers on **tag push** (e.g., `v1.0.2`) or **manual trigger**:

| Stage | What it does |
|-------|-------------|
| `version` | Reads version from `pubspec.yaml` |
| `analyze` | Runs linting + tests (gate) |
| `build-android` | Builds release APK (split by ABI) + AppBundle |
| `release` | Creates a GitHub Release with downloadable APKs |

To create a release:
```bash
git tag v1.0.2
git push origin v1.0.2
```

### Daily Auto-Update (`.github/workflows/daily-auto-update.yml`)

Runs daily at 3:00 AM UTC to keep dependencies up to date.

## 🗂️ Project Structure

```
lib/
├── main.dart                 # App entry point
├── data/                     # Data layer (models, APIs, repositories)
│   ├── daily_collection_*    # Daily collection data
│   ├── farmer_*              # Farmer data
│   ├── store_*               # Store data
│   ├── user_*                # User data
│   └── *_model.dart         # Data models
├── services/                 # Business logic & services
│   ├── bc/                   # Business Central OData integration
│   ├── bluetooth_*           # Bluetooth printer/scale services
│   └── ...
└── ui/                       # UI screens & widgets
    ├── login_page.dart
    ├── dashboard.dart
    ├── daily_collections_page.dart
    ├── farmers_page.dart
    └── ...
```

## 🔧 Tech Stack

| Technology | Purpose |
|------------|---------|
| **Flutter** | Cross-platform UI framework |
| **SQLite (sqflite)** | Local database |
| **Provider** | State management |
| **blue_thermal_printer** | Bluetooth thermal printing |
| **flutter_blue_plus** | Bluetooth LE support |
| **OData (BC)** | Microsoft Business Central sync |
| **GitHub Actions** | CI/CD automation |

## 📱 Google Play Publishing Checklist

### ✅ Prerequisites

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | **Google Play Developer account** | ❌ | Register at [play.google.com/console](https://play.google.com/console) ($25 one-time fee) |
| 2 | **Privacy Policy URL** | ✅ Done | `docs/PRIVACY_POLICY.md` — host via GitHub Pages |
| 3 | **Signed release build** | ✅ Done | Keystore generated + CI/CD configured |
| 4 | **App icon** (512x512 PNG) | ❌ | Use the coffee bean SVG as base |
| 5 | **Feature graphic** (1024x500 PNG) | ❌ | Required for store listing |
| 6 | **Screenshots** (2+ phone + 1 tablet) | ❌ | Capture app screens on a device |

### 📝 How to Host Your Privacy Policy Online

1. Push code to GitHub
2. Go to your repo → **Settings** → **Pages**
3. Under **Branch**, select `main` → `/docs` folder → **Save**
4. Your policy will be at:
   `https://<your-org>.github.io/<repo-name>/PRIVACY_POLICY.md`
5. Copy that URL into the Google Play Console when asked

### 🚀 Publishing Steps

```
1. Create developer account ────── $25, 24-48h approval
2. Complete store listing ──────── Name, desc, screenshots, icon
3. Fill Data Safety section ────── Explain data usage honestly
4. Upload signed AppBundle ─────── Push tag v1.0.x
5. Set content rating ──────────── Questionnaire (likely Everyone)
6. Internal test ───────────────── Share with a few testers
7. Closed test (if new account) ── 20 testers × 14 days required
8. Production release ──────────── Roll out to all users
```

### 🔑 App Name & Identifiers

| Property | Value |
|----------|-------|
| **App name** | Coffee Tracker |
| **Package ID** (Android) | `com.trimline.coffee` |
| **Version** | `1.0.1+2` |

---

## 📄 License

Private project.
