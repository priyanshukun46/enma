# ⚡ ENMA AI — Smart Logistics, Accessibility Intelligence & Disaster Response Platform

> **"Intelligence That Reaches Where Roads Don't."**  
> *Built for Smart India Hackathon 2026 — North Eastern Region Smart Logistics & Disaster Management Challenge.*

---

## 📖 Executive Overview

The **North Eastern Region (NER) of India** comprises 8 states characterized by rugged Himalayan terrain, high-altitude passes, extreme monsoon rainfall (>2,500 mm annually), and chronic landslides. During seasonal emergencies, critical transport corridors fail, isolating remote communities and cutting off food, water, and emergency medical convoys.

**ENMA AI** is an AI-assisted smart logistics, accessibility intelligence, and disaster response platform. It autonomously monitors regional settlements, evaluates road hazard telemetry, routes emergency relief convoys along the safest terrain corridors, and triages vulnerable populations for rapid humanitarian intervention.

---

## 🌟 Core Intelligence Engines

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                               ENMA AI ARCHITECTURE                               │
├──────────────────────┬─────────────────────────────┬─────────────────────────────┤
│  1. SENSORY INGEST   │    2. AI DECISION CORE      │     3. TACTICAL ACTION      │
├──────────────────────┼─────────────────────────────┼─────────────────────────────┤
│ • Rainfall Telemetry │ • Accessibility Engine      │ • Safest Convoy Dispatch    │
│ • Landslide Risk     │ • Predictive Risk Engine    │ • Priority Community Triage │
│ • Road Conditions    │ • Smart Route Optimizer     │ • Warehouse Staging Base    │
│ • Active Emergencies │ • Logistics Readiness Index │ • Government Briefings      │
└──────────────────────┴─────────────────────────────┴─────────────────────────────┘
```

### 1. 📍 Accessibility Intelligence Engine (`/accessibility`)
- Calculates a multi-factor **Accessibility Score ($0-100$)** for every settlement.
- Features **6 explainable deduction factors**: Road Surface Quality, Monsoon Rainfall Intensity, Slope Landslide Hazard, Hospital Reachability, Warehouse Proximity, and Mountain Isolation.
- 4-Tier Categorization: *Highly Accessible* ($80-100$), *Moderately Accessible* ($60-79$), *Difficult Access* ($40-59$), and *Critical Vulnerability* ($0-39$).

### 2. 🗺 Real Multi-Route Navigation & Recommendation System (`/routes`)
- **OSRM Road Routing Integration**: Generates real navigable road geometries, distances, durations, and turn-by-turn maneuvers via OpenStreetMap.
- **6-Dimension Multi-Criteria Scoring**: Safety Score, Travel Time Score, Accessibility Score, Distance Score, Environmental Score, and Overall Intelligence Score.
- **Vehicle Profile Adaptation**: Custom weightings for Ambulances, Disaster Response Units, Freight Trucks, Relief Supply Convoys, and Personal Vehicles.
- **3-Strategy Classification**: `⚡ Fastest Route`, `🛡 Safest Route`, and `⚖ Most Efficient Route`.
- **Explainable Recommendation**: Dynamic "Why ENMA AI Recommends This Route" reasons and strategic trade-off analysis.
- **Turn-by-Turn Follow Mode (HUD)**: Interactive navigation mode with maneuver icons, next turn distance, ETA, and live GPS geolocation tracking (`navigator.geolocation`).

### 3. 🚨 Disaster Response Command Center (`/emergencies`)
- **Spatial Radius Buffering**: Computes disaster impact zones using the Haversine formula to detect isolated communities.
- **Emergency Priority Score ($0-100$)**: Prioritizes isolated villages by combining baseline accessibility deficit ($50\%$), population exposure ($30\%$), and epicenter proximity ($20\%$).
- **Optimal Warehouse Selection**: Multi-criteria ranking (Stock Capacity $35\%$, Distance $35\%$, Route Reliability $30\%$) with transparent justification.
- **Autonomous Tactical Directives**: Generates a 6-step multi-agency response timeline for NDRF, SDRF, and district collectors.

### 4. 📊 Intelligence Analytics Center (`/analytics`)
- **Regional Logistics Readiness Index ($0-100$)**: 4-pillar evaluation across Accessibility, Warehouse Coverage, Response Readiness, and Hazard Mitigation.
- **Rule-Based AI Insights**: Generates actionable *Critical*, *Positive*, *Alert*, and *Directive* recommendations.
- **Printable Briefings (`/analytics/report`)**: Clean, formatted reports for government disaster briefings.

---

## 🏛 Dedicated SIH 2026 Presentation Tools

| Route | Page | Purpose |
| :--- | :--- | :--- |
| **`/landing`** | **Public Showcase** | High-impact hero page presenting The Challenge, Solution, 5-Stage Pipeline, and live counters. |
| **`/demo`** | **7-Step Guided Demo** | Interactive evaluation scenario simulating the Tawang Mudslide with step-by-step decision controls. |
| **`/overview`** | **2-Minute Judge Overview** | Executive briefing summarizing Problem, Solution, AI Engines, and Real-World Impact. |
| **`/architecture`** | **System Architecture** | Visual 3-tier blueprint from sensor ingestion to tactical action. |
| **`/search`** | **Global Search** | Instant multi-table fuzzy search querying settlements, warehouses, and disaster records. |

---

## 🔐 Authentication & Role-Based Access Control

- **Built with Rails conventions**: `has_secure_password`, thread-safe `Current.user`, and session management.
- **Single Sign-On (SSO)**: Google OAuth2 and GitHub OAuth support.
- **Roles**:
  - `admin` — Full platform access + User Administration console (`/admin/users`) with role promotion/demotion and safeguard preventing last admin demotion.
  - `operator` — Access to Dashboard, Maps, Routes, Emergencies, and Analytics.
- **Account Management**: User Profile (`/profile`), Account Security & Password Settings (`/settings`), and 20-minute signed token Password Reset (`/passwords/new`).

### Default Demo Credentials:
- **Administrator**: `admin@enma.ai` / `password123`
- **Field Operator**: `operator@enma.ai` / `password123`
- *(Or use the 1-Click Fast Login buttons on the `/login` page)*

---

## 💻 Tech Stack

- **Backend**: Ruby on Rails 8.1.0, Ruby 3.3+
- **Database**: PostgreSQL
- **Frontend / Styling**: Tailwind CSS, Hotwire (Turbo & Stimulus)
- **Mapping & GIS**: Leaflet.js, OpenStreetMap (OSM)
- **Road Routing**: Open Source Routing Machine (OSRM) driving API
- **Authentication**: `bcrypt`, `omniauth`, `omniauth-google-oauth2`, `omniauth-github`
- **Testing**: Rails Minitest (75 tests, 380 assertions, 100% passing)

---

## 🚀 Quick Start & Installation

### 1. Prerequisites
- Ruby `>= 3.2.0`
- PostgreSQL `>= 14`
- Node.js & Yarn / npm (optional, Tailwind delivered via CDN/Asset Pipeline)

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

# Seed North East India geospatial data, warehouses, hazards, and default accounts
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
75 runs, 380 assertions, 0 failures, 0 errors, 0 skips
```

---

## 👥 Team & Acknowledgments

- **Platform**: ENMA AI (Formerly AccessAI)
- **Event**: Smart India Hackathon 2026
- **Focus Region**: North Eastern Region of India (Assam, Arunachal Pradesh, Meghalaya, Manipur, Mizoram, Nagaland, Tripura, Sikkim)
- **Mission**: Ensuring no remote community is left behind during environmental crises through AI-assisted logistics intelligence.

---
*Developed with pride for Smart India Hackathon 2026.*
