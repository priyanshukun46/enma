# ⚡ ENMA AI — Smart Logistics, Accessibility Intelligence & Disaster Response Platform

> **"Intelligence That Reaches Where Roads Don't."**  
> *Built for Smart India Hackathon 2026 — North Eastern Region Smart Logistics & Disaster Management Challenge.*

---

## 📖 Executive Overview

The **North Eastern Region (NER) of India** comprises 8 states characterized by rugged Himalayan terrain, high-altitude passes, extreme monsoon rainfall (>2,500 mm annually), and chronic landslides. During seasonal emergencies, critical transport corridors fail, isolating remote communities and cutting off food, water, and emergency medical convoys.

**ENMA AI** is an AI-assisted smart logistics, accessibility intelligence, and disaster response platform. It autonomously monitors regional settlements, evaluates road hazard telemetry, routes emergency relief convoys along the safest terrain corridors, analyzes warehouse stockpiles, and triages vulnerable populations for rapid humanitarian intervention.

---

## 🌟 System Architecture & Intelligence Engines

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                  ENMA AI ARCHITECTURE                                  │
├────────────────────────┬───────────────────────────────┬───────────────────────────────┤
│   1. SENSORY INGEST    │      2. AI DECISION CORE      │      3. TACTICAL ACTION       │
├────────────────────────┼───────────────────────────────┼───────────────────────────────┤
│ • GPS Field Incidents  │ • Hybrid Road Risk Engine     │ • Dynamic Corridor Detours    │
│ • Photo Evidence       │ • Explainable AI Reasoner     │ • Safest Convoy Dispatch      │
│ • Rainfall & Weather   │ • Settlement Accessibility    │ • Priority Community Triage   │
│ • Road Degradation     │ • Route Intelligence (OSRM)   │ • Relief Warehouse Staging    │
│ • Historical Hazards   │ • Logistics Readiness Index   │ • Government Briefings & Maps │
└────────────────────────┴───────────────────────────────┴───────────────────────────────┘
```

---

### 1. 🧠 Hybrid Road Risk Intelligence Engine (`/map`, `/`)
- **Continuous Multi-Factor Evaluation**: Evaluates road corridor disruption probability using a weighted multi-dimensional pipeline:
  - **🌧 Weather Risk ($30\%$)**: Real-time rainfall surges, cloudburst warnings, and flood inundation.
  - **🪨 Recent Field Incidents ($25\%$)**: Active landslides, bridge damage, and road collapses reported within $45\text{ km}$.
  - **📜 Historical Vulnerability ($20\%$)**: Historical disaster frequency, terrain fragility, and seasonal closures.
  - **🚧 Road Condition ($15\%$)**: Structural pavement status (`excellent`, `good`, `moderate`, `poor`, `critical`).
  - **⛰ Geographic Vulnerability ($10\%$)**: High-altitude passes, gorge switchbacks, and steep-slope mass wasting zones.
- **4-Tier Risk Classification**:
  - `LOW RISK` ($0-25$): 🟢 Stable — Nominal highway logistics flow.
  - `MODERATE RISK` ($26-50$): 🟡 Attention — Caution advised for heavy freight.
  - `HIGH RISK` ($51-75$): 🟠 Warning — Active hazard alert, tactical detour recommended.
  - `CRITICAL RISK` ($76-100$): 🔴 Emergency — Impassable / Blocked corridor.
- **Explainable AI Reasoner (`Enma::RiskExplanationService`)**: Generates clear, human-readable primary risk driver cards and narrative reasoning explaining *why* a corridor is at risk.
- **Historical Audit Trail (`RoadRiskAssessment`)**: Tracks snapshot time-series assessments for risk trend analysis.
- **Future ML Provider Strategy**: Modular architecture (`Enma::MlPredictionProvider`) ready to integrate external Python/FastAPI ML disruption prediction models.

---

### 2. 📱 Mobile-First Field Incident Reporting (`/incidents`, `/incidents/new`)
- **Designed for Field Officers**: Enables rapid reporting of road hazards, landslides, and floods in **under 60 seconds** from smartphones or laptops.
- **1-Tap Visual Hazard Selector**: Touch-friendly cards (🪨 Landslide, 🌊 Flood, 🚧 Road Damage, 🌉 Bridge Damage, 🚗 Traffic Blockage, 💥 Accident, 🌧 Weather Disruption).
- **3-State GPS Location Capture**:
  - **Loading**: Radar pulse acquisition via browser Geolocation API (`navigator.geolocation`).
  - **Success**: Auto-tagged latitude, longitude, and $\pm\text{accuracy}$ badge with "Refresh GPS".
  - **Failed / Fallback**: Graceful manual coordinate and landmark input accordion.
  - *Hotwire Native Bridge Ready* for native iOS CoreLocation / Android LocationServices.
- **Photographic Evidence Gallery**:
  - Direct mobile camera lens trigger (`capture="environment"`).
  - Multi-file gallery picker with Active Storage validation (JPG, PNG, WebP $\le 10\text{ MB}$, max 5 photos).
  - Instant client-side thumbnail previews with deletion via `DataTransfer`.
- **Live Verification Summary**: Dynamic card summarizing Hazard Type, Severity, Coordinates, and Photos before submission.
- **Automatic Recalculation Hook**: Submitting an incident immediately recalculates risk scores of all road corridors within proximity.
- **Evidence Dossier & Lightbox (`/incidents/:id`)**: High-res incident view with photo modal zoom.

---

### 3. 🗺 Interactive GIS Accessibility & Corridor Intelligence Map (`/map`)
- **Geospatial Polylines**: Visualizes major North Eastern national highways (NH-27, NH-13, NH-229 Sela Pass, NH-10 Teesta, NH-06, NH-02, etc.) dynamically color-coded by calculated risk (Green, Yellow, Orange, Red dashed).
- **AI Risk Dossier Panel**: Inspects any selected road corridor showing composite risk meters, 5-factor percentage bars, and explainable AI primary factors.
- **Live Field Incident Pins**: Interactive hazard markers with photo previews, severity badges, and direct dossier links.
- **Multi-Layer Controls**: Toggle settlements, relief depots, road corridors, and field incidents with State, Status, and Risk sliders.

---

### 4. 📍 Accessibility Intelligence Engine (`/accessibility`)
- Calculates a multi-factor **Accessibility Score ($0-100$)** for every settlement across all 8 NER states.
- **6 Explainable Deduction Factors**: Road Surface Quality, Monsoon Rainfall Intensity, Slope Landslide Hazard, Hospital Reachability, Warehouse Proximity, and Mountain Isolation.
- 4-Tier Categorization: *Highly Accessible* ($80-100$), *Moderately Accessible* ($60-79$), *Difficult Access* ($40-59$), and *Critical Vulnerability* ($0-39$).

---

### 5. 🛣 Smart Multi-Route Navigation & Tactical Detours (`/routes`)
- **OSRM Road Routing Integration**: Real navigable road geometries, distances, durations, and turn-by-turn maneuvers via OpenStreetMap.
- **6-Dimension Multi-Criteria Scoring**: Safety Score, Travel Time Score, Accessibility Score, Distance Score, Environmental Score, and Overall Intelligence Score.
- **Vehicle Profile Adaptation**: Custom weightings for Ambulances, Disaster Response Units, Freight Trucks, Relief Supply Convoys, and Personal Vehicles.
- **3-Strategy Classification**: `⚡ Fastest Route`, `🛡 Safest Route`, and `⚖ Most Efficient Route`.
- **Turn-by-Turn HUD Navigation Mode**: Interactive navigation mode with maneuver icons, next turn distance, ETA, and live GPS tracking.

---

### 6. 🚨 Disaster Response Command Center (`/emergencies`)
- **Spatial Radius Buffering**: Computes disaster impact zones using the Haversine formula to detect isolated communities.
- **Emergency Priority Score ($0-100$)**: Prioritizes isolated villages combining baseline accessibility deficit ($50\%$), population exposure ($30\%$), and epicenter proximity ($20\%$).
- **Optimal Warehouse Selection**: Multi-criteria ranking (Stock Capacity $35\%$, Distance $35\%$, Route Reliability $30\%$) with transparent justification.
- **Autonomous Tactical Directives**: Generates a 6-step multi-agency response timeline for NDRF, SDRF, and district collectors.

---

### 7. 🏬 Warehouse & Resource Intelligence (`/warehouses`)
- **Strategic Staging Bases**: Detailed readiness analysis for major relief hubs across Guwahati, Itanagar, Shillong, Imphal, Agartala, and Gangtok.
- **Inventory Tracking**: Stock levels for Medical Kits, Food Packages, Water Supply, Emergency Shelters, Fuel Reserves, and Rescue Equipment.
- **Dynamic Operational Status**: Real-time capacity utilization tracking (`OPERATIONAL`, `LIMITED`, `OVERLOADED`).

---

### 8. 📊 Intelligence Analytics Center (`/analytics`)
- **Regional Logistics Readiness Index ($0-100$)**: 4-pillar evaluation across Accessibility, Warehouse Coverage, Response Readiness, and Hazard Mitigation.
- **Rule-Based AI Insights**: Actionable *Critical*, *Positive*, *Alert*, and *Directive* recommendations.
- **Printable Briefings (`/analytics/report`)**: Clean, formatted reports for government disaster briefings.

---

## 🏛 Dedicated SIH 2026 Presentation Tools

| Route | Page | Purpose |
| :--- | :--- | :--- |
| **`/landing`** | **Public Showcase** | High-impact hero page presenting The Challenge, Solution, 5-Stage Pipeline, QR code mobile access, and live telemetry counters. |
| **`/demo`** | **7-Step Guided Demo** | Interactive evaluation scenario simulating the Tawang Sela Pass Mudslide with step-by-step decision controls. |
| **`/overview`** | **2-Minute Judge Overview** | Executive briefing summarizing Problem, Solution, AI Engines, and Real-World Impact. |
| **`/architecture`** | **System Architecture** | Visual 3-tier blueprint from sensor ingestion to tactical action. |
| **`/search`** | **Global Search** | Instant multi-table fuzzy search querying settlements, warehouses, and disaster records. |

---

## 🔐 Authentication & Role-Based Access Control

- **Built with Rails conventions**: `has_secure_password`, thread-safe `Current.user`, and session management.
- **Single Sign-On (SSO)**: Google OAuth2 and GitHub OAuth support.
- **Roles**:
  - `admin` — Full platform access + User Administration console (`/admin/users`) with role management safeguards.
  - `operator` — Access to Dashboard, Maps, Routes, Field Incidents, Emergencies, and Analytics.
- **Account Management**: User Profile (`/profile`), Account Security & Password Settings (`/settings`), and signed token Password Reset (`/passwords/new`).

### Default Demo Credentials:
- **Administrator**: `admin@enma.ai` / `password123`
- **Field Operator**: `operator@enma.ai` / `password123`
- *(Or use the 1-Click Fast Login buttons on the `/login` page)*

---

## 💻 Tech Stack

- **Backend**: Ruby on Rails 8.1.3, Ruby 3.3+
- **Database**: PostgreSQL (with PostGIS extensions)
- **Frontend / Styling**: Tailwind CSS (Dark pitch-black canvas `#000000`, charcoal `#0d0d0f`, Ubuntu orange/indigo accents), Hotwire (Turbo 8 & Stimulus)
- **Mapping & GIS**: Leaflet.js, OpenStreetMap (OSM)
- **Road Routing**: Open Source Routing Machine (OSRM) driving API
- **File Storage**: Active Storage (Disk in dev, cloud S3/GCS in prod)
- **QR Codes**: `rqrcode` SVG generation for mobile transitions
- **Authentication**: `bcrypt`, `omniauth`, `omniauth-google-oauth2`, `omniauth-github`
- **Testing**: Rails Minitest (**173 tests, 808 assertions, 100% passing**)

---

## 🚀 Quick Start & Installation

### 1. Prerequisites
- Ruby `>= 3.2.0`
- PostgreSQL `>= 14`
- Node.js / Yarn (optional; Propshaft + Importmap asset pipeline)

### 2. Clone and Setup
```bash
# Clone the repository
git clone https://github.com/your-username/enma.git
cd enma

# Install Ruby gems
bundle install

# Setup database and run migrations
bin/rails db:create
bin/rails db:migrate

# Seed North East India geospatial data, warehouses, field incidents, and run intelligence engine
bin/rails db:seed
```

### 3. Environment Variables (Optional)
Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```
Key variables:
```bash
# Google & GitHub OAuth (Optional for local development)
GOOGLE_CLIENT_ID=your_client_id
GOOGLE_CLIENT_SECRET=your_client_secret
GITHUB_CLIENT_ID=your_client_id
GITHUB_CLIENT_SECRET=your_client_secret

# Custom OSRM Routing Endpoint (Optional, defaults to public demo endpoint)
OSRM_API_URL=https://router.project-osrm.org
```

### 4. Start the Application
```bash
bin/rails server
```
Open your browser and navigate to:
```
http://localhost:3000
```

---

## 🧪 Running the Test Suite

Execute the full automated test suite:
```bash
bin/rails test
```

**Test Results**:
```
173 runs, 808 assertions, 0 failures, 0 errors, 0 skips (100% passing)
```

---

## 👥 Team & Acknowledgments

- **Platform**: ENMA AI (AI-Powered Logistics & Accessibility Intelligence Platform)
- **Event**: Smart India Hackathon 2026
- **Focus Region**: North Eastern Region of India (Assam, Arunachal Pradesh, Meghalaya, Manipur, Mizoram, Nagaland, Tripura, Sikkim)
- **Mission**: Ensuring no remote community is left behind during environmental crises through explainable AI logistics intelligence.

---
*Developed with pride for Smart India Hackathon 2026.*
