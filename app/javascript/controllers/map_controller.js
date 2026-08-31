import { Controller } from "@hotwired/stimulus"
import * as L from "leaflet"

export default class extends Controller {
  static targets = [
    "container",
    "searchQuery",
    "searchResults",
    "detailsPanel",
    "detailTitle",
    "detailSubtitle",
    "detailStatusBadge",
    "detailRiskScore",
    "detailRiskLevel",
    "detailRiskBar",
    "detailWeatherRisk",
    "detailWeatherBar",
    "detailHistoricalRisk",
    "detailHistoricalBar",
    "detailIncidentRisk",
    "detailIncidentBar",
    "detailConditionRisk",
    "detailConditionBar",
    "detailGeographicRisk",
    "detailGeographicBar",
    "detailPrimaryFactors",
    "detailReason",
    "detailLocation",
    "detailUpdated",
    "detailActionLink",
    "stateFilter",
    "statusFilter",
    "riskRange",
    "riskRangeDisplay",
    "roadsCountBadge"
  ]

  static values = {
    locations: Array,
    warehouses: Array,
    emergencies: Array,
    roads: Array,
    incidents: Array
  }

  connect() {
    this.handleResize = () => {
      if (this.map) {
        this.map.invalidateSize()
      }
    }

    this.initializeMap()
    this.renderAllLayers()

    // Trigger map redraw to ensure full container width coverage
    setTimeout(() => {
      if (this.map) {
        this.map.invalidateSize()
      }
    }, 200)

    window.addEventListener("resize", this.handleResize)

    if (window.ResizeObserver && this.hasContainerTarget) {
      this.resizeObserver = new ResizeObserver(() => {
        if (this.map) {
          this.map.invalidateSize()
        }
      })
      this.resizeObserver.observe(this.containerTarget)
    }

    // Close search dropdown on outside click
    this.handleClickOutside = (event) => {
      if (this.hasSearchResultsTarget && this.hasSearchQueryTarget) {
        if (!this.searchResultsTarget.contains(event.target) && event.target !== this.searchQueryTarget) {
          this.searchResultsTarget.classList.add("hidden")
        }
      }
    }
    document.addEventListener("click", this.handleClickOutside)
  }

  disconnect() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
    window.removeEventListener("resize", this.handleResize)
    document.removeEventListener("click", this.handleClickOutside)
    if (this.map) {
      this.map.remove()
      this.map = null
    }
  }

  initializeMap() {
    // Center on North East India
    const centerLatLng = [26.2, 92.9]
    const defaultZoom = 7

    this.map = L.map(this.containerTarget, {
      zoomControl: true,
      scrollWheelZoom: true
    }).setView(centerLatLng, defaultZoom)

    // Base OSM tiles
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 18,
      attribution: '© OpenStreetMap contributors | ENMA AI GIS'
    }).addTo(this.map)

    // Layer groups
    this.layers = {
      roads: L.layerGroup().addTo(this.map),
      locations: L.layerGroup().addTo(this.map),
      warehouses: L.layerGroup().addTo(this.map),
      emergencies: L.layerGroup().addTo(this.map),
      incidents: L.layerGroup().addTo(this.map)
    }

    this.roadPolylines = {}
    this.emergencyMarkers = {}
    this.incidentMarkers = {}
    this.locationMarkers = {}

    this.activeFilters = {
      roads: true,
      locations: true,
      warehouses: true,
      emergencies: true,
      incidents: true,
      state: "all",
      status: "all",
      maxRisk: 100
    }
  }

  renderAllLayers() {
    this.renderRoads()
    this.renderLocations()
    this.renderWarehouses()
    this.renderEmergencies()
    this.renderIncidents()
  }

  // =========================================================================
  // 1. Road Polylines Visualization (Status Colors & Interactive Popups)
  // =========================================================================
  renderRoads() {
    this.layers.roads.clearLayers()
    this.roadPolylines = {}

    const roads = this.hasRoadsValue ? this.roadsValue : []

    roads.forEach((road) => {
      if (!this.matchesFilters(road)) return
      if (!road.coordinates || road.coordinates.length < 2) return

      const color = road.status_color || this.getStatusColor(road.status)
      const weight = road.status === "blocked" ? 6 : 5

      const polyline = L.polyline(road.coordinates, {
        color: color,
        weight: weight,
        opacity: 0.88,
        lineCap: "round",
        lineJoin: "round",
        dashArray: road.status === "blocked" ? "6, 8" : null
      })

      // Interactive Hover & Click
      polyline.on("mouseover", (e) => {
        const layer = e.target
        layer.setStyle({
          weight: weight + 3,
          opacity: 1.0
        })
        layer.bringToFront()
      })

      polyline.on("mouseout", (e) => {
        const layer = e.target
        layer.setStyle({
          weight: weight,
          opacity: 0.88
        })
      })

      polyline.on("click", () => {
        this.displayRoadDetails(road)
      })

      // Popup
      const popupHtml = `
        <div class="p-3 text-slate-900 dark:text-white max-w-xs space-y-2">
          <div class="flex items-center justify-between border-b border-slate-200 dark:border-slate-700 pb-1.5 gap-2">
            <span class="font-black text-xs text-indigo-600 dark:text-indigo-400 uppercase font-mono">${road.road_number}</span>
            <span class="px-2 py-0.5 rounded-full text-[9px] font-black uppercase ${road.status_badge_class}">
              ${road.status_display}
            </span>
          </div>
          <div>
            <h4 class="font-black text-sm text-slate-900 dark:text-white leading-tight">${road.name}</h4>
            <p class="text-[11px] text-slate-500 dark:text-slate-400 mt-0.5">
              ${road.district ? `${road.district}, ` : ""}${road.state} ${road.length_km ? `(${road.length_km} km)` : ""}
            </p>
          </div>
          <div class="space-y-1 pt-1">
            <div class="flex items-center justify-between text-[10px] font-bold">
              <span class="text-slate-500">Risk Factor Score</span>
              <span class="font-mono font-black ${road.risk_score >= 70 ? 'text-red-600' : (road.risk_score >= 40 ? 'text-amber-600' : 'text-emerald-600')}">
                ${road.risk_score}/100
              </span>
            </div>
            <div class="w-full bg-slate-200 dark:bg-slate-700 rounded-full h-1.5 overflow-hidden">
              <div class="h-1.5 rounded-full ${road.risk_score >= 70 ? 'bg-red-500' : (road.risk_score >= 40 ? 'bg-amber-500' : 'bg-emerald-500')}" style="width: ${Math.min(road.risk_score, 100)}%"></div>
            </div>
          </div>
          <p class="text-[11px] text-slate-600 dark:text-slate-300 italic pt-1 leading-snug">
            "${road.reason}"
          </p>
          <div class="flex items-center justify-between text-[9px] text-slate-400 pt-1 border-t border-slate-100 dark:border-slate-800">
            <span>Last Updated: ${road.last_updated}</span>
            <span class="font-bold text-indigo-600 cursor-pointer">Click for telemetry</span>
          </div>
        </div>
      `
      polyline.bindPopup(popupHtml)

      polyline.addTo(this.layers.roads)
      this.roadPolylines[road.id] = polyline
    })
  }

  displayRoadDetails(road) {
    if (!this.hasDetailsPanelTarget) return

    this.detailsPanelTarget.classList.remove("hidden")

    if (this.hasDetailTitleTarget) this.detailTitleTarget.textContent = `${road.road_number} • ${road.name}`
    if (this.hasDetailSubtitleTarget) this.detailSubtitleTarget.textContent = `${road.district ? `${road.district}, ` : ""}${road.state} • ${road.length_km || 0} km Corridor`
    if (this.hasDetailLocationTarget) this.detailLocationTarget.textContent = `${road.district || road.state}, North East`
    if (this.hasDetailUpdatedTarget) this.detailUpdatedTarget.textContent = road.last_updated || "Live Telemetry"

    if (this.hasDetailStatusBadgeTarget) {
      this.detailStatusBadgeTarget.className = `px-2.5 py-0.5 rounded-full text-[10px] font-black uppercase border ${road.status_badge_class}`
      this.detailStatusBadgeTarget.textContent = road.status_display
    }

    if (this.hasDetailRiskScoreTarget) {
      this.detailRiskScoreTarget.textContent = `${road.risk_score}/100`
    }

    if (this.hasDetailRiskLevelTarget) {
      this.detailRiskLevelTarget.textContent = road.risk_level_display || road.risk_level.toUpperCase()
      this.detailRiskLevelTarget.className = `text-[9px] font-black uppercase px-2 py-0.5 rounded-full border ${road.risk_level_badge_class}`
    }

    if (this.hasDetailRiskBarTarget) {
      this.detailRiskBarTarget.style.width = `${Math.min(road.risk_score, 100)}%`
      this.detailRiskBarTarget.className = `h-2 rounded-full ${road.risk_score >= 75 ? 'bg-red-500' : (road.risk_score >= 50 ? 'bg-orange-500' : (road.risk_score >= 25 ? 'bg-amber-500' : 'bg-emerald-500'))}`
    }

    // 5 Factor Scores & Meter Bars
    const factors = road.factors || {}
    const weather = factors.weather || 0
    const historical = factors.historical || 0
    const incidents = factors.incidents || 0
    const condition = factors.condition || 0
    const geographic = factors.geographic || 0

    if (this.hasDetailWeatherRiskTarget) this.detailWeatherRiskTarget.textContent = `${weather}/100`
    if (this.hasDetailWeatherBarTarget) this.detailWeatherBarTarget.style.width = `${Math.min(weather, 100)}%`

    if (this.hasDetailHistoricalRiskTarget) this.detailHistoricalRiskTarget.textContent = `${historical}/100`
    if (this.hasDetailHistoricalBarTarget) this.detailHistoricalBarTarget.style.width = `${Math.min(historical, 100)}%`

    if (this.hasDetailIncidentRiskTarget) this.detailIncidentRiskTarget.textContent = `${incidents}/100`
    if (this.hasDetailIncidentBarTarget) this.detailIncidentBarTarget.style.width = `${Math.min(incidents, 100)}%`

    if (this.hasDetailConditionRiskTarget) this.detailConditionRiskTarget.textContent = `${condition}/100 (${road.road_condition || 'Good'})`
    if (this.hasDetailConditionBarTarget) this.detailConditionBarTarget.style.width = `${Math.min(condition, 100)}%`

    if (this.hasDetailGeographicRiskTarget) this.detailGeographicRiskTarget.textContent = `${geographic}/100`
    if (this.hasDetailGeographicBarTarget) this.detailGeographicBarTarget.style.width = `${Math.min(geographic, 100)}%`

    // Primary Explainability Factors List
    if (this.hasDetailPrimaryFactorsTarget) {
      const primaryList = road.primary_factors || []
      if (primaryList.length > 0) {
        this.detailPrimaryFactorsTarget.innerHTML = primaryList.map(factor => `
          <div class="flex items-start space-x-2 p-1.5 rounded-xl bg-white dark:bg-slate-900 border border-slate-200/70 dark:border-slate-800">
            <span class="text-sm flex-shrink-0">${factor.icon}</span>
            <div class="min-w-0 flex-1">
              <span class="font-bold text-slate-900 dark:text-white block text-[10px] uppercase">${factor.label} (${factor.score || 0}/100)</span>
              <span class="text-slate-600 dark:text-slate-400 text-[10px] leading-tight block">${factor.text}</span>
            </div>
          </div>
        `).join("")
      } else {
        this.detailPrimaryFactorsTarget.innerHTML = `
          <div class="text-[10px] text-slate-400 italic">No critical risk anomalies identified along this corridor.</div>
        `
      }
    }

    if (this.hasDetailReasonTarget) {
      this.detailReasonTarget.textContent = `"${road.summary_reason || road.reason}"`
    }

    if (this.hasDetailActionLinkTarget) {
      this.detailActionLinkTarget.href = `/routes?origin_id=${encodeURIComponent(road.name)}`
      this.detailActionLinkTarget.textContent = `Analyze Tactical Corridors for ${road.road_number} →`
    }
  }

  // =========================================================================
  // 2. Settlement Nodes Visualization
  // =========================================================================
  renderLocations() {
    this.layers.locations.clearLayers()
    this.locationMarkers = {}

    const locations = this.hasLocationsValue ? this.locationsValue : []

    locations.forEach((loc) => {
      if (!loc.latitude || !loc.longitude) return
      if (this.activeFilters.state !== "all" && loc.state !== this.activeFilters.state) return

      const score = loc.accessibility_score || 50
      const isCritical = score < 40

      let markerColor = "#10b981"
      if (score < 40) markerColor = "#ef4444"
      else if (score < 70) markerColor = "#f59e0b"

      const customIcon = L.divIcon({
        className: 'custom-node-icon',
        html: `
          <div class="relative flex items-center justify-center">
            ${isCritical ? '<span class="absolute w-6 h-6 rounded-full bg-red-500/40 animate-ping"></span>' : ''}
            <div class="w-4 h-4 rounded-full border-2 border-white dark:border-slate-900 shadow-md flex items-center justify-center" style="background-color: ${markerColor};">
              <div class="w-1.5 h-1.5 rounded-full bg-white"></div>
            </div>
          </div>
        `,
        iconSize: [20, 20],
        iconAnchor: [10, 10]
      })

      const marker = L.marker([loc.latitude, loc.longitude], { icon: customIcon })

      const popupHtml = `
        <div class="p-2.5 text-slate-900 dark:text-white max-w-xs space-y-1.5">
          <div class="flex items-center justify-between border-b border-slate-200 dark:border-slate-700 pb-1">
            <span class="font-black text-xs text-slate-900 dark:text-white">${loc.name}</span>
            <span class="font-mono text-[10px] font-bold text-indigo-600">${loc.state}</span>
          </div>
          <div class="flex items-center justify-between text-xs pt-1">
            <span class="text-slate-500">Accessibility Score:</span>
            <span class="font-mono font-black ${isCritical ? 'text-red-600' : 'text-emerald-600'}">${score}/100</span>
          </div>
          <div class="text-[10px] text-slate-400">
            Road: <strong class="text-slate-700 dark:text-slate-200">${loc.road_quality || 'Standard'}</strong> • Rainfall: <strong class="text-slate-700 dark:text-slate-200">${loc.rainfall_level || 'Normal'}</strong>
          </div>
          <div class="pt-1">
            <a href="/accessibility/${loc.id}" class="text-[11px] font-bold text-indigo-600 hover:underline">View Accessibility Dossier &rarr;</a>
          </div>
        </div>
      `
      marker.bindPopup(popupHtml)
      marker.addTo(this.layers.locations)
      this.locationMarkers[loc.id] = marker
    })
  }

  // =========================================================================
  // 3. Relief Warehouses
  // =========================================================================
  renderWarehouses() {
    this.layers.warehouses.clearLayers()
    const warehouses = this.hasWarehousesValue ? this.warehousesValue : []

    warehouses.forEach((wh) => {
      if (!wh.latitude || !wh.longitude) return
      if (this.activeFilters.state !== "all" && wh.state !== this.activeFilters.state) return

      const icon = L.divIcon({
        className: 'custom-warehouse-icon',
        html: `
          <div class="w-6 h-6 rounded-lg bg-indigo-600 text-white flex items-center justify-center text-xs shadow-md border border-white dark:border-slate-900">
            <i class="fas fa-warehouse text-[10px]"></i>
          </div>
        `,
        iconSize: [24, 24],
        iconAnchor: [12, 12]
      })

      const marker = L.marker([wh.latitude, wh.longitude], { icon: icon })
      marker.bindPopup(`
        <div class="p-2 text-slate-900 dark:text-white max-w-xs space-y-1">
          <strong class="text-xs font-black block">${wh.name}</strong>
          <p class="text-[11px] text-slate-500">${wh.district ? `${wh.district}, ` : ''}${wh.state}</p>
          <div class="text-[10px] text-emerald-600 font-bold">Status: ${wh.operational_status || 'OPERATIONAL'}</div>
          <a href="/warehouses/${wh.id}" class="text-[10px] text-indigo-600 font-bold hover:underline block pt-1">Warehouse Details &rarr;</a>
        </div>
      `)
      marker.addTo(this.layers.warehouses)
    })
  }

  // =========================================================================
  // 4. Regional Emergency Events
  // =========================================================================
  renderEmergencies() {
    this.layers.emergencies.clearLayers()
    this.emergencyMarkers = {}
    const emergencies = this.hasEmergenciesValue ? this.emergenciesValue : []

    emergencies.forEach((em) => {
      if (!em.latitude || !em.longitude) return

      let iconClass = "fa-mountain text-amber-500"
      if (em.emergency_type && em.emergency_type.toLowerCase().includes("flood")) {
        iconClass = "fa-water text-blue-500"
      } else if (em.severity === "Critical") {
        iconClass = "fa-biohazard text-red-500"
      }

      const icon = L.divIcon({
        className: 'custom-emergency-icon',
        html: `
          <div class="relative flex items-center justify-center">
            <span class="absolute w-7 h-7 rounded-full bg-red-600/40 animate-ping"></span>
            <div class="w-6 h-6 rounded-full bg-red-600 text-white flex items-center justify-center text-xs shadow-lg border-2 border-white">
              <i class="fas ${iconClass} text-[10px] text-white"></i>
            </div>
          </div>
        `,
        iconSize: [28, 28],
        iconAnchor: [14, 14]
      })

      const marker = L.marker([em.latitude, em.longitude], { icon: icon })
      marker.bindPopup(`
        <div class="p-2.5 text-slate-900 dark:text-white max-w-xs space-y-1.5">
          <div class="flex items-center justify-between">
            <span class="px-2 py-0.5 rounded-full text-[9px] font-black uppercase bg-red-100 text-red-800">${em.severity}</span>
            <span class="text-[10px] font-mono text-slate-400">${em.simulated_at || 'Active'}</span>
          </div>
          <strong class="text-xs font-black block">${em.title}</strong>
          <p class="text-[11px] text-slate-600 leading-snug">${em.description || 'Emergency incident recorded.'}</p>
          <a href="/emergencies/${em.id}" class="text-[11px] text-red-600 font-bold hover:underline block pt-1">Command Center &rarr;</a>
        </div>
      `)

      marker.addTo(this.layers.emergencies)
      this.emergencyMarkers[em.id] = marker
    })
  }

  // =========================================================================
  // 5. Field Incident Reports (Geo-tagged Photos & Citizen/Officer Reports)
  // =========================================================================
  renderIncidents() {
    this.layers.incidents.clearLayers()
    this.incidentMarkers = {}
    const incidents = this.hasIncidentsValue ? this.incidentsValue : []

    incidents.forEach((inc) => {
      if (!inc.latitude || !inc.longitude) return
      if (this.activeFilters.state !== "all" && inc.state !== this.activeFilters.state) return

      const isCritical = inc.severity === "critical" || inc.severity === "high"

      const icon = L.divIcon({
        className: 'custom-field-incident-icon',
        html: `
          <div class="relative flex items-center justify-center">
            ${isCritical ? '<span class="absolute w-8 h-8 rounded-full bg-red-600/40 animate-ping"></span>' : ''}
            <div class="w-7 h-7 rounded-2xl bg-white dark:bg-slate-900 text-slate-900 dark:text-white flex items-center justify-center text-sm shadow-xl border-2 border-indigo-600 hover:scale-110 transition-transform">
              <span>${inc.type_emoji || '⚠️'}</span>
            </div>
          </div>
        `,
        iconSize: [28, 28],
        iconAnchor: [14, 14]
      })

      const marker = L.marker([inc.latitude, inc.longitude], { icon: icon })

      const photoThumbnailHtml = inc.first_photo_url ? `
        <div class="w-full h-24 rounded-xl overflow-hidden mb-2 border border-slate-200 dark:border-slate-700">
          <img src="${inc.first_photo_url}" alt="Incident photo" class="w-full h-full object-cover">
        </div>
      ` : ''

      const popupHtml = `
        <div class="p-2.5 text-slate-900 dark:text-white max-w-xs space-y-1.5">
          ${photoThumbnailHtml}
          <div class="flex items-center justify-between border-b border-slate-200 dark:border-slate-700 pb-1">
            <span class="px-2 py-0.5 rounded-full text-[9px] font-black uppercase ${inc.severity_badge_class}">
              ${inc.severity_label}
            </span>
            <span class="text-[10px] font-mono text-slate-400">${inc.reported_at}</span>
          </div>
          <strong class="text-xs font-black block leading-tight">${inc.location_name}</strong>
          <p class="text-[11px] text-slate-600 dark:text-slate-300 leading-snug line-clamp-2">
            ${inc.description}
          </p>
          <div class="flex items-center justify-between pt-1 border-t border-slate-100 dark:border-slate-800 text-[10px]">
            <span class="text-slate-400">By: ${inc.reporter_name}</span>
            <a href="${inc.url}" class="font-bold text-indigo-600 hover:underline">Full Dossier &rarr;</a>
          </div>
        </div>
      `
      marker.bindPopup(popupHtml)
      marker.addTo(this.layers.incidents)
      this.incidentMarkers[inc.id] = marker
    })
  }

  // =========================================================================
  // 6. Interactive Filter Controls
  // =========================================================================
  filterByStatus(event) {
    const status = event.currentTarget.dataset.status
    this.activeFilters.status = status

    // Update active tab styles
    const buttons = this.element.querySelectorAll("[data-status-btn]")
    buttons.forEach((btn) => {
      if (btn.dataset.status === status) {
        btn.className = "px-3 py-1.5 rounded-xl text-xs font-black bg-indigo-600 text-white shadow-sm transition-all"
      } else {
        btn.className = "px-3 py-1.5 rounded-xl text-xs font-bold text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 transition-all"
      }
    })

    this.renderRoads()
  }

  filterByState(event) {
    this.activeFilters.state = event.target.value
    this.renderAllLayers()

    // Adjust map focus if specific state selected
    const stateCoordinates = {
      "Assam": [26.2, 92.9, 7],
      "Arunachal Pradesh": [27.8, 94.5, 7],
      "Meghalaya": [25.5, 91.8, 8],
      "Manipur": [24.8, 93.9, 8],
      "Mizoram": [23.3, 92.8, 8],
      "Nagaland": [26.1, 94.5, 8],
      "Tripura": [23.8, 91.3, 9],
      "Sikkim": [27.5, 88.5, 9]
    }

    if (stateCoordinates[this.activeFilters.state]) {
      const [lat, lng, zoom] = stateCoordinates[this.activeFilters.state]
      this.map.flyTo([lat, lng], zoom, { duration: 1.2 })
    } else {
      this.map.flyTo([26.2, 92.9], 7, { duration: 1.2 })
    }
  }

  filterByRisk(event) {
    const maxRisk = parseInt(event.target.value, 10)
    this.activeFilters.maxRisk = maxRisk

    if (this.hasRiskRangeDisplayTarget) {
      this.riskRangeDisplayTarget.textContent = `≤ ${maxRisk}/100`
    }

    this.renderRoads()
  }

  resetFilters() {
    this.activeFilters = {
      roads: true,
      locations: true,
      warehouses: true,
      emergencies: true,
      incidents: true,
      state: "all",
      status: "all",
      maxRisk: 100
    }

    if (this.hasStateFilterTarget) this.stateFilterTarget.value = "all"
    if (this.hasRiskRangeTarget) this.riskRangeTarget.value = 100
    if (this.hasRiskRangeDisplayTarget) this.riskRangeDisplayTarget.textContent = "≤ 100/100"

    const buttons = this.element.querySelectorAll("[data-status-btn]")
    buttons.forEach((btn) => {
      if (btn.dataset.status === "all") {
        btn.className = "px-3 py-1.5 rounded-xl text-xs font-black bg-indigo-600 text-white shadow-sm transition-all"
      } else {
        btn.className = "px-3 py-1.5 rounded-xl text-xs font-bold text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 transition-all"
      }
    })

    this.renderAllLayers()
    this.map.flyTo([26.2, 92.9], 7, { duration: 1.0 })
  }

  toggleLayer(event) {
    const layerKey = event.target.dataset.layer
    const checked = event.target.checked

    if (this.layers[layerKey]) {
      if (checked) {
        this.map.addLayer(this.layers[layerKey])
      } else {
        this.map.removeLayer(this.layers[layerKey])
      }
    }
  }

  // =========================================================================
  // 7. Navigation Actions (Pan to road/incident from right panel)
  // =========================================================================
  panToRoad(event) {
    const roadId = event.currentTarget.dataset.roadId
    const road = this.roadsValue.find(r => r.id.toString() === roadId.toString())

    if (road && road.coordinates && road.coordinates.length > 0) {
      const midPoint = road.coordinates[Math.floor(road.coordinates.length / 2)]
      this.map.flyTo(midPoint, 10, { duration: 1.2 })

      if (this.roadPolylines[roadId]) {
        this.roadPolylines[roadId].openPopup()
      }
      this.displayRoadDetails(road)
    }
  }

  panToEmergency(event) {
    const emId = event.currentTarget.dataset.emergencyId
    const em = this.emergenciesValue.find(e => e.id.toString() === emId.toString())

    if (em && em.latitude && em.longitude) {
      this.map.flyTo([em.latitude, em.longitude], 11, { duration: 1.2 })
      if (this.emergencyMarkers[emId]) {
        this.emergencyMarkers[emId].openPopup()
      }
    }
  }

  panToIncident(event) {
    const incId = event.currentTarget.dataset.incidentId
    const inc = this.incidentsValue.find(i => i.id.toString() === incId.toString())

    if (inc && inc.latitude && inc.longitude) {
      this.map.flyTo([inc.latitude, inc.longitude], 12, { duration: 1.2 })
      if (this.incidentMarkers[incId]) {
        this.incidentMarkers[incId].openPopup()
      }
    }
  }

  closeDetails() {
    if (this.hasDetailsPanelTarget) {
      this.detailsPanelTarget.classList.add("hidden")
    }
  }

  // =========================================================================
  // Search Bar Autocomplete
  // =========================================================================
  search(event) {
    const query = event.target.value.toLowerCase().trim()
    if (!this.hasSearchResultsTarget) return

    if (query.length < 2) {
      this.searchResultsTarget.classList.add("hidden")
      this.searchResultsTarget.innerHTML = ""
      return
    }

    const matchedLocations = (this.locationsValue || []).filter(l =>
      l.name.toLowerCase().includes(query) || (l.district && l.district.toLowerCase().includes(query)) || (l.state && l.state.toLowerCase().includes(query))
    ).slice(0, 4)

    const matchedRoads = (this.roadsValue || []).filter(r =>
      r.name.toLowerCase().includes(query) || r.road_number.toLowerCase().includes(query) || (r.district && r.district.toLowerCase().includes(query))
    ).slice(0, 4)

    const matchedIncidents = (this.incidentsValue || []).filter(i =>
      (i.location_name && i.location_name.toLowerCase().includes(query)) ||
      (i.type_label && i.type_label.toLowerCase().includes(query)) ||
      (i.description && i.description.toLowerCase().includes(query))
    ).slice(0, 3)

    if (matchedLocations.length === 0 && matchedRoads.length === 0 && matchedIncidents.length === 0) {
      this.searchResultsTarget.innerHTML = `
        <div class="p-3 text-xs text-slate-400 text-center">No monitored roads, settlements or incidents found.</div>
      `
      this.searchResultsTarget.classList.remove("hidden")
      return
    }

    let html = '<div class="divide-y divide-slate-100 dark:divide-slate-800">'

    matchedIncidents.forEach(inc => {
      html += `
        <div class="p-2.5 hover:bg-slate-50 dark:hover:bg-slate-800 cursor-pointer flex items-center justify-between"
             data-action="click->map#selectSearchResult"
             data-type="incident"
             data-id="${inc.id}">
          <div class="flex items-center space-x-2">
            <span class="text-xs">${inc.type_emoji}</span>
            <div>
              <div class="font-bold text-xs text-slate-900 dark:text-white">${inc.location_name}</div>
              <div class="text-[10px] text-slate-400">${inc.type_label} • ${inc.severity_label}</div>
            </div>
          </div>
          <span class="px-2 py-0.5 rounded text-[9px] uppercase font-bold ${inc.severity_badge_class}">${inc.severity}</span>
        </div>
      `
    })

    matchedRoads.forEach(road => {
      html += `
        <div class="p-2.5 hover:bg-slate-50 dark:hover:bg-slate-800 cursor-pointer flex items-center justify-between"
             data-action="click->map#selectSearchResult"
             data-type="road"
             data-id="${road.id}">
          <div class="flex items-center space-x-2">
            <i class="fas fa-road text-indigo-500 text-xs"></i>
            <div>
              <div class="font-bold text-xs text-slate-900 dark:text-white">${road.road_number} • ${road.name}</div>
              <div class="text-[10px] text-slate-400">${road.district ? `${road.district}, ` : ''}${road.state}</div>
            </div>
          </div>
          <span class="px-2 py-0.5 rounded text-[9px] uppercase font-bold ${road.status_badge_class}">${road.status_display}</span>
        </div>
      `
    })

    matchedLocations.forEach(loc => {
      html += `
        <div class="p-2.5 hover:bg-slate-50 dark:hover:bg-slate-800 cursor-pointer flex items-center justify-between"
             data-action="click->map#selectSearchResult"
             data-type="location"
             data-lat="${loc.latitude}"
             data-lon="${loc.longitude}"
             data-name="${loc.name}">
          <div class="flex items-center space-x-2">
            <i class="fas fa-map-marker-alt text-emerald-500 text-xs"></i>
            <div>
              <div class="font-bold text-xs text-slate-900 dark:text-white">${loc.name}</div>
              <div class="text-[10px] text-slate-400">${loc.state} (${loc.district || 'Sector'})</div>
            </div>
          </div>
          <span class="text-xs font-mono font-bold text-indigo-600">${loc.accessibility_score || 50}/100</span>
        </div>
      `
    })

    html += '</div>'
    this.searchResultsTarget.innerHTML = html
    this.searchResultsTarget.classList.remove("hidden")
  }

  selectSearchResult(event) {
    const dataset = event.currentTarget.dataset
    if (this.hasSearchResultsTarget) this.searchResultsTarget.classList.add("hidden")
    if (this.hasSearchQueryTarget) this.searchQueryTarget.value = ""

    if (dataset.type === "incident") {
      const inc = this.incidentsValue.find(i => i.id.toString() === dataset.id.toString())
      if (inc && inc.latitude && inc.longitude) {
        this.map.flyTo([inc.latitude, inc.longitude], 12, { duration: 1.2 })
        if (this.incidentMarkers[inc.id]) {
          this.incidentMarkers[inc.id].openPopup()
        }
      }
    } else if (dataset.type === "road") {
      const road = this.roadsValue.find(r => r.id.toString() === dataset.id.toString())
      if (road && road.coordinates && road.coordinates.length > 0) {
        const midPoint = road.coordinates[Math.floor(road.coordinates.length / 2)]
        this.map.flyTo(midPoint, 10, { duration: 1.2 })
        if (this.roadPolylines[road.id]) {
          this.roadPolylines[road.id].openPopup()
        }
        this.displayRoadDetails(road)
      }
    } else if (dataset.type === "location") {
      const lat = parseFloat(dataset.lat)
      const lon = parseFloat(dataset.lon)
      this.map.flyTo([lat, lon], 11, { duration: 1.2 })
    }
  }

  // =========================================================================
  // Helper Predicates
  // =========================================================================
  matchesFilters(road) {
    if (this.activeFilters.state !== "all" && road.state !== this.activeFilters.state) {
      return false
    }
    if (this.activeFilters.status !== "all" && road.status !== this.activeFilters.status) {
      return false
    }
    if (road.risk_score > this.activeFilters.maxRisk) {
      return false
    }
    return true
  }

  getStatusColor(status) {
    switch (status) {
      case "accessible": return "#10b981"
      case "moderate_risk": return "#eab308"
      case "high_risk": return "#f97316"
      case "blocked": return "#ef4444"
      default: return "#64748b"
    }
  }
}
