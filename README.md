# 🛒 Woolies Scanner

> **Woolworths Planogram Scanner** — AI-powered sheet parsing for nightfill workers.

Scan and parse Woolworths **Weekly Sales Plan (Planogram)** sheets using computer vision (Claude / Gemini) to extract products, ref numbers, aisle locations, and promotional data into a structured, searchable database.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Sheet Types Supported](#sheet-types-supported)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Configuration](#configuration)
- [Usage](#usage)
- [Project Structure](#project-structure)
- [Technical Details](#technical-details)
  - [AI Parsing Pipeline](#ai-parsing-pipeline)
  - [OGE vs FGE Routing](#oge-vs-fge-routing)
  - [Data Flow](#data-flow)
- [Scripts & Utilities](#scripts--utilities)
- [Building & Deployment](#building--deployment)

---

## Overview

Woolies Scanner eliminates manual data entry from Woolworths' weekly planogram PDFs/printouts. A nightfill worker snaps a photo of the printed sheet, and the app:

1. Uploads the image to **Claude Opus** (or optionally **Gemini**) for vision-based OCR.
2. Parses the AI response into structured product data with aisle locations.
3. Saves everything to **Supabase** (cloud) with local caching.
4. Surfaces the data in a searchable, filterable interface organised by date and sheet type.

---

## Features

| Feature | Description |
|---|---|
| **📷 AI Sheet Scanning** | Snap a photo or pick from gallery — Claude Opus 4.6/4.7 or Gemini parses it |
| **🔍 Smart Routing** | Auto-detects OGE (Back Gondola Ends) vs FGE (Front Gondola Ends + Entrance) |
| **📅 Date Extraction** | Automatically finds "Sales Plan WC" date from sheet headers |
| **🏷️ ADDED/REMOVED Flags** | Detects small red/blue labels critical for Tuesday night changeovers |
| **🗂️ Date-Folder Browsing** | Browse scanned collections grouped by planogram date |
| **🔎 Full-Text Search** | Search across product names, ref numbers, aisle codes, and sheet names |
| **🔐 Admin Auth** | Supabase auth-gated admin panel; scan functionality locked behind login |
| **🌐 Cross-Platform** | Runs on web, iOS, Android, macOS — uses `go_router` for clean web URLs |
| **⚡ Local Caching** | Supabase data is cached via local in-memory providers for instant search |

---

## Sheet Types Supported

### 🔙 OGE (Back Gondola Ends)

Standard grid of 12 boxes: **OGE001** through **OGE012**.

Each box represents one gondola end at the back of the store. Products are arranged in horizontal shelves (top-to-bottom), with optional column splits on a shelf.

### 🔜 FGE (Front Gondola Ends & Entrance)

Two-zone layout divided by a horizontal divider:

| Zone | Sections |
|---|---|
| **Above Divider** (Special Displays) | `BIN` (Front of Store Bin), `ENT001` (Entrance), `POS` (Flexi Stand) |
| **Below Divider** (Numbered FGE Boxes) | `FGE001` – `FGE015` |

FGE sections have varying **layout types**:
- **`standard_shelved`** — Regular horizontal shelves (most FGE boxes)
- **`vertical_bulk`** — Single full-height column, no shelves (e.g., FGE007 "Bulk End")
- **`side_stack`** — Vertical columns alongside shelves

Each FGE section captures:
- Header / promotion type (e.g., "1/2 PRICE", "40% OFF")
- Product names and Ref numbers
- **ADDED** (blue) / **REMOVED** (red) status flags
- Positional data within the layout

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│                   Flutter App                    │
│  ┌───────────┐  ┌──────────┐  ┌──────────────┐ │
│  │ Home Screen│  │ Scanner  │  │ Product List │ │
│  │ (Date List)│  │ Screen   │  │ (By Aisle)   │ │
│  └─────┬─────┘  └────┬─────┘  └──────┬───────┘ │
│        │              │               │          │
│  ┌─────┴──────────────┴───────────────┴───────┐ │
│  │           Riverpod State Layer              │ │
│  │  (planogramDatesProvider, groupedProducts,  │ │
│  │   totalDatabaseItemsProvider, authProvider) │ │
│  └─────────────────────┬───────────────────────┘ │
│                        │                          │
│  ┌─────────────────────┴───────────────────────┐ │
│  │           Service Layer                     │ │
│  │  ┌─────────────┐  ┌───────────────────┐     │ │
│  │  │ Supabase    │  │ ClaudeService /   │     │ │
│  │  │ Service     │  │ FgeParser /       │     │ │
│  │  │ (CRUD)      │  │ PlanogramParser   │     │ │
│  │  └──────┬──────┘  └────────┬──────────┘     │ │
│  └─────────┼───────────────────┼────────────────┘ │
└────────────┼───────────────────┼──────────────────┘
             │                   │
     ┌───────┴───────┐   ┌──────┴───────┐
     │   Supabase    │   │   Claude /   │
     │   (Postgres)  │   │   Gemini API │
     └───────────────┘   └──────────────┘
```

- **State Management**: Riverpod with `FutureProvider` and `StreamProvider` for reactive auth.
- **Routing**: `go_router` with clean URL strategy (`usePathUrlStrategy`).
- **Backend**: Supabase for auth + database (`scanned_products` table).
- **AI Vision**: Claude Opus 4.6/4.7 via Anthropic API (direct) or Firebase Cloud Function proxy; Google Gemini as alternative scanner.

---

## Getting Started

### Prerequisites

- **Flutter SDK** >=3.3.0
- **Dart** >=3.3.0
- **Supabase Project** — with a `scanned_products` table
- **Anthropic API Key** — for Claude vision (optional if using Gemini)

### Installation

```bash
# Clone the repo
git clone <repository-url>
cd woolies_scanner

# Install dependencies
flutter pub get

# Run (web)
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

### Configuration

Credentials are loaded with this priority:

1. **`--dart-define`** compile-time constants (highest priority — used on web & CI)
2. **`.env` file** via `flutter_dotenv` (fallback for native mobile)

```env
# .env (for local Android/iOS development)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

The `.env` file **must** be included in `pubspec.yaml` assets for `flutter_dotenv` to find it on Android:

```yaml
flutter:
  assets:
    - .env
```

> **Note**: On web, `--dart-define` is the only reliable method. The `.env` file is not available on web in production.

---

## Usage

### 1. Scan a Sheet

1. Tap the **QR code FAB** (admin login required) on the home screen.
2. Choose **Camera** or **Gallery** to select your planogram photo.
3. The app sends the image to **Claude Opus** (default) or **Gemini** (alternative).
4. AI analyses the layout, extracts products/refs/dates, and saves to Supabase.
5. You're returned to the home screen where the new date collection appears.

### 2. Browse by Date

- Each scan creates a **date folder** on the home screen.
- Tap a date to see **OGE** and **FGE** sheet categories.
- Inside each sheet, products are **grouped by aisle** (e.g., OGE001, FGE003, BIN).

### 3. Search

- Use the **search FAB** (magnifying glass) to query across all scanned data.
- Search matches product names, ref numbers, aisle codes, and sheet names.
- Results highlight matching terms in yellow.

### 4. Admin Panel

- Login via the admin icon in the app bar.
- Authenticated admins can:
  - Access the scanner
  - Delete date collections
  - View the admin dashboard

---

## Project Structure

```
lib/
├── main.dart                              # App entry, Supabase init, GoRouter config
├── core/
│   ├── constants/
│   │   └── app_colors.dart                # Black/white/grey design tokens
│   ├── models/
│   │   ├── product_model.dart             # Product data model (local + Supabase)
│   │   ├── planogram_model.dart           # OGE planogram model (aisles/shelves/products)
│   │   └── fge_model.dart                 # FGE planogram model (sections/layouts/flags)
│   ├── providers/
│   │   └── auth_provider.dart             # Auth stream provider
│   └── services/
│       ├── claude_service.dart            # Claude Opus vision API integration
│       ├── fge_parser.dart                # FGE-specific Claude parser (+ADDED/REMOVED)
│       ├── planogram_parser.dart          # OGE-specific Claude parser
│       ├── supabase_service.dart          # Supabase CRUD operations
│       ├── local_product_database.dart    # Legacy sqflite database
│       └── debug_db.dart                  # Debug database utilities
├── features/
│   ├── admin/
│   │   ├── admin_screen.dart              # Admin dashboard
│   │   └── login_screen.dart              # Supabase auth login
│   ├── cage/
│   │   ├── cage_provider.dart             # CAGE feature providers
│   │   └── cage_screen.dart               # CAGE screen
│   ├── fge/
│   │   ├── fge_provider.dart              # FGE data providers
│   │   └── fge_screen.dart                # FGE section viewer
│   ├── home/
│   │   └── home_screen.dart               # Main date-list dashboard
│   ├── planogram/
│   │   ├── planogram_provider.dart        # Planogram data providers
│   │   └── planogram_screen.dart          # OGE planogram viewer
│   ├── products/
│   │   ├── product_database_provider.dart  # Date/sheet/aisle grouping providers
│   │   ├── product_list_screen.dart        # Product list by date & sheet
│   │   └── product_provider.dart           # Product search & DB count providers
│   ├── scanner/
│   │   ├── scanner_screen.dart             # Camera/gallery sheet scanner
│   │   └── gemini_scanner_provider.dart    # Gemini alternative scanner provider
│   └── search/
│       └── search_screen.dart              # Full-text search across all products
└── widgets/
    ├── cage_fab_button.dart                # CAGE quick-action FAB
    ├── search_fab_button.dart              # Search quick-action FAB
    ├── search_result_tile.dart             # Search result display tile
    └── ref_chip.dart                       # Ref number chip widget
```

---

## Technical Details

### AI Parsing Pipeline

#### Claude (Primary — `claude_service.dart`)

1. **Image Preprocessing**: EXIF orientation correction + resize to max 2576px (92% JPEG quality).
2. **Proxy**: Via Firebase Cloud Function (`analyzeSheetProxy`) to keep the Anthropic API key server-side.
3. **Prompt Engineering**: A detailed prompt instructs Claude to:
   - Extract "Sales Plan WC" date from the header
   - Auto-detect OGE vs FGE sheet type
   - Follow strict layout/spatial rules (divider barrier, no sliding, etc.)
   - Output ultra-concise JSON (`[{"n","b","a","d"}]`)
4. **Response Parsing**: Strip markdown fences, extract JSON array, normalise date, apply aisle routing (OGE vs FGE).

#### FGE Parser (Specialised — `fge_parser.dart`)

- Direct Anthropic API call (no proxy) using **Claude Opus 4.7**.
- Dedicated prompt for **Front Gondola Ends** with layout-type detection (`standard_shelved`, `vertical_bulk`, `side_stack`).
- Preserves ADDED/REMOVED status flags.
- Returns structured `FgePlanogram` with sections sorted logically (BIN → ENT → FGE001–FGE012).

#### OGE Parser (`planogram_parser.dart`)

- Direct Anthropic API call using **Claude Opus 4.7**.
- Handles standard 12-box grid with shelf-level grouping.
- Returns structured `Planogram` with aisles → shelves → products.

#### Gemini (Alternative — `gemini_scanner_provider.dart`)

- Uses `google_generative_ai` package as an alternative scanning backend.

### OGE vs FGE Routing

Routing rules (in `claude_service.dart` and `scanner_screen.dart`):

```
OGE: ONLY boxes labeled OGE001–OGE012
FGE: Everything else — FGE boxes, ENT (Entrance), POS (Flexi Stand),
     BIN (Front of Store Bin), FRONT OF STORE, FLEXI
```

The same logic is applied in `supabase_service.dart` for data integrity when querying.

### Data Flow

```
User captures image
       ↓
Image preprocessed (resize, orient)
       ↓
Sent to Claude API (via proxy or direct)
       ↓
JSON response parsed into Product objects
       ↓
Sheet type assigned (OGE / FGE)
       ↓
Products inserted into Supabase `scanned_products` table
       ↓
Riverpod providers invalidated → UI refreshes
       ↓
Data browseable by date → sheet → aisle
```

---

## Scripts & Utilities

| File | Description |
|---|---|
| `delete_fge_ent.dart` | Standalone script to delete all FGE/ENT data from local sqflite DB, preserving OGE data intact |

---

## Building & Deployment

### Web

```bash
# Build with your Supabase credentials
flutter build web \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key

# Deploy to Firebase Hosting (example)
firebase deploy --only hosting
```

### Android

```bash
# Ensure .env exists with credentials for native platforms
flutter build apk --release
```

### iOS

```bash
flutter build ios --release
```

### Environment Variables

| Variable | Required | Description |
|---|---|---|
| `SUPABASE_URL` | ✅ | Supabase project URL |
| `SUPABASE_ANON_KEY` | ✅ | Supabase anonymous API key |
| `ANTHROPIC_API_KEY` | ⚠️ | Needed for direct Claude API calls (FgeParser / PlanogramParser) |

---

## Tech Stack

| Technology | Purpose |
|---|---|
| **Flutter** | Cross-platform UI framework |
| **Riverpod** | Reactive state management |
| **GoRouter** | Declarative routing with clean web URLs |
| **Supabase** | PostgreSQL backend + auth |
| **Claude Opus 4.6/4.7** | Primary AI vision/OCR engine |
| **Google Gemini** | Alternative AI vision engine |
| **Firebase Cloud Functions** | API key proxy for Claude |
| **sqflite** | Legacy local database (migrating to Supabase) |
| **flutter_dotenv** | Environment variable management |
| **intl** | Date formatting & normalisation |

---

## License

Proprietary — internal Woolworths nightfill tool.
