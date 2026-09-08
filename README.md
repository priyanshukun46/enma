# ENMA AI ⚡
### Smart Logistics, Terrain Intelligence & Disaster Dispatch for North East India

[![Rails Tests](https://img.shields.io/badge/Rails%20Tests-213%20Passing-emerald?style=flat-square&logo=ruby)](test/)
[![FastAPI ML](https://img.shields.io/badge/ML%20Service-FastAPI%20%7C%20XGBoost-orange?style=flat-square&logo=python)](enma-ml/)
[![Design](https://img.shields.io/badge/Theme-Warm%20Parchment%20%26%20Espresso-amber?style=flat-square)](app/views/)

> *"When a landslide takes out NH-13 or the Sela Pass freezes over, you don't just need a map — you need to know which village is cut off, which depot has insulin and blankets, and which corridor is still safe for a relief convoy."*

---

## What is ENMA AI?

Every monsoon, the 8 states of Northeast India face severe environmental isolation. Between cloudbursts in Meghalaya, flash floods in the Brahmaputra valley, and massive rockfalls along high-altitude passes in Arunachal Pradesh, vital road arteries vanish overnight.

We built **ENMA AI** for the **Smart India Hackathon (SIH 2026)** to turn raw weather feeds, field hazard reports, and road condition telemetry into immediate, life-saving logistics decisions.

Rather than giving emergency coordinators a generic map or a simple shortest-path distance, ENMA:
1. **Predicts corridor disruptions** using an XGBoost ML model trained on precipitation, slope angles, soil saturation, and past slide frequency.
2. **Calculates settlement isolation** across remote habitations (Tawang, Haflong, Aizawl, Mon, etc.) with an explainable 0–100 Accessibility Score.
3. **Finds the safest route** (not just the fastest) using multi-criteria OSRM routing with custom vehicle profiles (heavy relief trucks, ambulances, 4x4 convoys).
4. **Recommends the best warehouse staging depot** by weighing current stock (water, medical kits, shelters), road risk, and realistic travel ETA.

---

## Key Features

### 🛣️ Hybrid Road Risk & ML Disruption Prediction
- **Trained Model**: An external Python/FastAPI microservice (`enma-ml`) running an XGBoost classifier that returns disruption probabilities in under 20ms.
- **5-Factor Composite Risk Score (0–100)**: Combines real-time rainfall, active field incident reports within 45 km, historical slide frequency, pavement grade, and steepness into a single clear metric.
- **Corridor Radar**: Color-coded risk telemetry across strategic lifelines like NH-13 (Trans-Arunachal), NH-27 (East-West corridor), and NH-10 (Sikkim lifeline).

### 📍 Accessibility Intelligence (`/accessibility`)
- Monitors settlements across Arunachal Pradesh, Assam, Sikkim, Nagaland, Manipur, Meghalaya, Mizoram, and Tripura.
- Dynamic isolation tiers: *Highly Accessible* (80+), *Moderately Accessible* (60–79), *Difficult Access* (40–59), and *Critical Vulnerability* (<40).
- Detailed drill-down reports showing primary bottlenecks (e.g. single bridge dependency, washed-out culverts, steep slope saturation).

### 🚚 Triple-Buffered Smart Route Optimizer (`/routes`)
- Integrates with Open Source Routing Machine (OSRM) driving engines for turn-by-turn navigation over actual road networks.
- 3 distinct routing strategies:
  - **🛡️ Safest Route**: Actively avoids high-risk mountain passes and flash-flood zones.
  - **⚡ Fastest Route**: Optimizes purely for minimal transit time when emergencies demand speed.
  - **⚖️ Most Efficient**: Balanced compromise for heavy supply convoys.

### 🏢 Warehouse Depot Network & Triage (`/warehouses`)
- Real-time stockpile visibility across strategic hubs (Guwahati Central, Tezpur, Silchar, Itanagar, Shillong, Dimapur).
- Tracks critical resources: medical kits, potable water, food rations, shelters, fuel, and rescue equipment.
- Automatically calculates facility readiness and recommends the ideal dispatch depot when a regional emergency is declared.

### 🔍 Spotlight ⌘K Search & Live Auto-Suggestions
- Global instant search overlay (`⌘K` / `Ctrl+K`) that pops open without navigating away from your active dashboard.
- Live debounced autocomplete matching settlements, highways, depots, and disaster incidents.
- Dedicated `/search` page with clickable suggestion chips (*Tawang Outpost, NH-13 Corridor, Relief Warehouses, Landslide Detours*).

### 📱 Field Hazard Reporting & Mobile QR Sharing
- Mobile-friendly incident reporting with 1-tap hazard selectors (Landslide, Flood, Bridge Collapse, Road Blockage).
- GPS coordinate capture with browser geolocation fallback.
- Camera-ready photo attachments with live client-side previews.
- Instant mobile QR code modal for scanning and handing off field operations to smartphones or tablets.

---

## Design System

ENMA's interface is inspired by the clean, readable editorial aesthetic of **ChaiCode** (`dsa.chaicode.com`):
- **Light Mode**: Warm cream parchment canvas (`#FAF6EE`), soft surface cards (`#FFFCF7`), deep espresso ink text (`#18120E`), and terracotta accents (`#E25438`).
- **Dark Mode**: Roasted dark espresso canvas (`#14100C`), dark surface tiles (`#1B1611`), warm ivory typography (`#ECE5D6`), and glowing coral highlights (`#EC5E42`).
- **No eye-straining blues or generic templates**: Designed for long operational hours in field control rooms.

---

## Tech Stack

| Layer | Technology |
| :--- | :--- |
| **Backend** | Ruby on Rails 8.1.3 (Ruby 3.3+), Devise, OmniAuth (Google & GitHub) |
| **Database** | PostgreSQL 14+ |
| **Frontend** | Hotwire (Turbo 8 + Stimulus), Tailwind CSS, Custom ChaiCode theme tokens |
| **Machine Learning** | Python 3.12+, FastAPI, XGBoost, Scikit-learn, Uvicorn |
| **Mapping & GIS** | Leaflet.js, OpenStreetMap, OSRM (Open Source Routing Machine) |
| **File Storage** | Active Storage (local disk in development, S3-compatible in production) |
| **Testing** | Rails Minitest (213 tests, 100% passing), Pytest (7 tests, 100% passing) |

---

## Getting Started

### 1. Prerequisites
- **Ruby** `>= 3.2.0`
- **PostgreSQL** `>= 14`
- **Python** `>= 3.11` (for the ML service)

### 2. Clone the Repository
```bash
git clone https://github.com/priyanshukun46/enma.git
cd enma
```

### 3. Setup the Rails Application
```bash
# Install Ruby dependencies
bundle install

# Setup database, run migrations, and seed mock Northeast India data
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed
```

### 4. Setup & Start the Python ML Service
In a separate terminal window:
```bash
cd enma-ml

# Create virtual environment and install dependencies
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Train model (if needed) and run FastAPI
python training/train.py
uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```
The ML service will start at `http://127.0.0.1:8000`. You can test its interactive API docs at `http://127.0.0.1:8000/docs`.

### 5. Start the Rails Server
Back in the project root:
```bash
bin/rails server
```
Open your browser and navigate to:
```
http://localhost:3000
```

---

## Demo Credentials & Fast Login

For judging and testing, the seed script provisions pre-configured accounts:

| Role | Email | Password |
| :--- | :--- | :--- |
| **Administrator** | `admin@enma.ai` | `password123` |
| **Field Operator** | `operator@enma.ai` | `password123` |

> 💡 **Tip**: The `/login` page includes 1-click demo login buttons for both roles, as well as adaptive Google/GitHub OAuth sign-in.

---

## Presentation & Judge Shortcuts

If you're evaluating this project for Smart India Hackathon:
- **`/landing`** — High-level platform intro, challenge statement, and feature showcase.
- **`/demo`** — 7-step guided interactive walkthrough simulating the *Tawang Sela Pass Monsoon Landslide*.
- **`/overview`** — 2-minute executive briefing summarizing the architecture, engines, and field impact.
- **`/map`** — Live interactive GIS radar map with route safety vectors and hazard overlays.
- **`/routes`** — Test the double-buffered route optimization algorithm between any two Northeast hubs.

---

## Running the Tests

We take reliability seriously in disaster tech. Both the Rails monolith and Python ML services maintain full test coverage:

```bash
# 1. Run all 213 Rails model, controller, and integration tests
bin/rails test

# 2. Run Python ML microservice tests
cd enma-ml && .venv/bin/pytest tests
```

---

## Project Structure

```
enma/
├── app/
│   ├── controllers/         # Rails controllers (Dashboard, Routes, Search, etc.)
│   ├── helpers/             # View helpers (QR codes, badges, formatting)
│   ├── javascript/
│   │   └── controllers/     # Stimulus controllers (search_modal, flash, map, theme)
│   ├── models/              # ActiveRecord models (Road, Location, Warehouse, Emergency)
│   ├── services/            # Pure Ruby domain logic (RouteOptimizer, RiskExplanation)
│   └── views/               # ERB templates styled with ChaiCode tokens
├── config/                  # Rails routes, initializers, and Devise auth config
├── db/                      # Schema and seed scripts with Northeast India GIS data
├── enma-ml/                 # Standalone Python FastAPI ML disruption service
│   ├── app/                 # FastAPI routes and prediction schemas
│   ├── models/              # Serialized XGBoost model artifacts (.joblib)
│   ├── tests/               # Pytest suite
│   └── training/            # Synthetic training pipeline based on real weather vectors
└── test/                    # Full Minitest suite (213 tests, 0 failures)
```

---

## License

Built with pride by the team for the **Smart India Hackathon 2026**.  
Open-source under the MIT License.
