import { Controller } from "@hotwired/stimulus"
import * as L from "leaflet"

export default class extends Controller {
  static targets = [ "container", "modeButton" ]
  static values = {
    locations: Array,
    warehouses: Array,
    emergencies: Array
  }

  connect() {
    if (!this.hasContainerTarget) return
    this.currentMode = "accessibility"
    this.handleResize = () => { if (this.map) this.map.invalidateSize() }
    this.initializeMap()
    this.renderCurrentMode()

    setTimeout(() => { if (this.map) this.map.invalidateSize() }, 150)
    window.addEventListener("resize", this.handleResize)

    if (window.ResizeObserver && this.hasContainerTarget) {
      this.resizeObserver = new ResizeObserver(() => {
        if (this.map) this.map.invalidateSize()
      })
      this.resizeObserver.observe(this.containerTarget)
    }
  }

  disconnect() {
    if (this.resizeObserver) this.resizeObserver.disconnect()
    window.removeEventListener("resize", this.handleResize)
    if (this.map) {
      this.map.remove()
      this.map = null
    }
  }

  initializeMap() {
    this.map = L.map(this.containerTarget).setView([26.0, 92.5], 7)

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 18,
      attribution: '© OpenStreetMap contributors'
    }).addTo(this.map)

    this.layerGroup = L.layerGroup().addTo(this.map)
  }

  switchMode(event) {
    const mode = event.currentTarget.dataset.mode
    if (!mode || mode === this.currentMode) return

    this.currentMode = mode

    // Update active button state
    this.modeButtonTargets.forEach(btn => {
      if (btn.dataset.mode === mode) {
        btn.classList.remove('bg-white', 'dark:bg-slate-900', 'text-slate-700', 'dark:text-slate-300')
        btn.classList.add('bg-indigo-600', 'text-white', 'shadow-sm')
      } else {
        btn.classList.remove('bg-indigo-600', 'text-white', 'shadow-sm')
        btn.classList.add('bg-white', 'dark:bg-slate-900', 'text-slate-700', 'dark:text-slate-300')
      }
    })

    this.renderCurrentMode()
  }

  renderCurrentMode() {
    this.layerGroup.clearLayers()
    const bounds = L.latLngBounds()

    if (this.currentMode === "accessibility") {
      this.renderAccessibilityLayer(bounds)
    } else if (this.currentMode === "risk") {
      this.renderRiskLayer(bounds)
    } else if (this.currentMode === "emergencies") {
      this.renderEmergenciesLayer(bounds)
    } else if (this.currentMode === "warehouses") {
      this.renderWarehousesLayer(bounds)
    }

    if (bounds.isValid()) {
      this.map.fitBounds(bounds, { padding: [30, 30] })
    }
  }

  renderAccessibilityLayer(bounds) {
    this.locationsValue.forEach(loc => {
      const score = Number(loc.accessibility_score) || 0
      let colorClass = "bg-green-500"
      let borderClass = "border-green-600"
      let badgeClass = "bg-green-100 text-green-800"

      if (score < 40) {
        colorClass = "bg-red-600 ring-4 ring-red-200"
        borderClass = "border-red-700"
        badgeClass = "bg-red-100 text-red-800"
      } else if (score < 60) {
        colorClass = "bg-orange-500 ring-2 ring-orange-200"
        borderClass = "border-orange-600"
        badgeClass = "bg-orange-100 text-orange-800"
      } else if (score < 80) {
        colorClass = "bg-yellow-500"
        borderClass = "border-yellow-600"
        badgeClass = "bg-yellow-100 text-yellow-800"
      }

      const icon = L.divIcon({
        html: `<div class="w-6 h-6 rounded-full ${colorClass} text-white flex items-center justify-center font-bold text-[10px] shadow-md border border-white">${Math.round(score)}</div>`,
        className: 'custom-leaflet-icon',
        iconSize: [24, 24],
        iconAnchor: [12, 12]
      })

      L.marker([loc.latitude, loc.longitude], { icon: icon })
        .bindPopup(`
          <div class="p-2 min-w-[180px]">
            <h4 class="font-bold text-sm text-ink">${loc.name}</h4>
            <p class="text-xs text-sketch">${loc.state}</p>
            <div class="mt-2 pt-1 border-t flex justify-between items-center text-xs">
              <span class="text-mute">Accessibility:</span>
              <span class="font-bold text-sm ${score < 40 ? 'text-red-600' : 'text-ink'}">${score}/100</span>
            </div>
            <span class="mt-1 inline-block text-[10px] px-2 py-0.5 rounded ${badgeClass} font-bold">${loc.accessibility_category}</span>
          </div>
        `)
        .addTo(this.layerGroup)

      bounds.extend([loc.latitude, loc.longitude])
    })
  }

  renderRiskLayer(bounds) {
    this.locationsValue.forEach(loc => {
      const risk = Number(loc.risk_score) || (100 - Number(loc.accessibility_score || 50))
      let colorClass = "bg-green-500"
      let threatLevel = "LOW RISK"
      let badgeClass = "bg-green-100 text-green-800"

      if (risk >= 75) {
        colorClass = "bg-red-600 ring-4 ring-red-200"
        threatLevel = "CRITICAL RISK"
        badgeClass = "bg-red-100 text-red-800"
      } else if (risk >= 50) {
        colorClass = "bg-orange-500 ring-2 ring-orange-200"
        threatLevel = "HIGH RISK"
        badgeClass = "bg-orange-100 text-orange-800"
      } else if (risk >= 25) {
        colorClass = "bg-yellow-500"
        threatLevel = "MODERATE RISK"
        badgeClass = "bg-yellow-100 text-yellow-800"
      }

      const icon = L.divIcon({
        html: `<div class="w-6 h-6 rounded-full ${colorClass} text-white flex items-center justify-center font-bold text-[10px] shadow-md border border-white"><i class="fas fa-biohazard text-[9px]"></i></div>`,
        className: 'custom-leaflet-icon',
        iconSize: [24, 24],
        iconAnchor: [12, 12]
      })

      L.marker([loc.latitude, loc.longitude], { icon: icon })
        .bindPopup(`
          <div class="p-2 min-w-[180px]">
            <h4 class="font-bold text-sm text-ink">${loc.name}</h4>
            <p class="text-xs text-sketch">${loc.state}</p>
            <div class="mt-2 pt-1 border-t flex justify-between items-center text-xs">
              <span class="text-mute">Predicted Risk:</span>
              <span class="font-black text-sm text-red-600">${Math.round(risk)}/100</span>
            </div>
            <p class="text-[11px] text-mute mt-0.5"><strong>Primary Threat:</strong> ${loc.primary_risk_factor || 'Landslide'}</p>
            <span class="mt-1 inline-block text-[10px] px-2 py-0.5 rounded ${badgeClass} font-bold">${threatLevel}</span>
          </div>
        `)
        .addTo(this.layerGroup)

      bounds.extend([loc.latitude, loc.longitude])
    })
  }

  renderEmergenciesLayer(bounds) {
    this.emergenciesValue.forEach(em => {
      const icon = L.divIcon({
        html: `<div class="w-8 h-8 rounded-full bg-red-600 text-white flex items-center justify-center font-black text-xs shadow-xl border-2 border-white animate-pulse"><i class="fas fa-radiation"></i></div>`,
        className: 'custom-leaflet-icon',
        iconSize: [32, 32],
        iconAnchor: [16, 16]
      })

      L.marker([em.latitude, em.longitude], { icon: icon })
        .bindPopup(`
          <div class="p-2 min-w-[200px]">
            <span class="px-2 py-0.5 rounded text-[10px] font-black uppercase bg-red-100 text-red-800 border border-red-300">
              ${em.severity} SEVERITY
            </span>
            <h4 class="font-black text-sm text-ink mt-1">${em.title}</h4>
            <p class="text-xs text-mute"><strong>Type:</strong> ${em.emergency_type}</p>
            <p class="text-xs text-mute"><strong>Affected Radius:</strong> ${em.affected_radius || 50} km</p>
            <p class="text-xs text-red-600 font-bold mt-1">Status: ${em.status}</p>
          </div>
        `)
        .addTo(this.layerGroup)

      const radiusMeters = (Number(em.affected_radius) || 50.0) * 1000
      L.circle([em.latitude, em.longitude], {
        radius: radiusMeters,
        color: '#dc2626',
        weight: 1.5,
        dashArray: '4, 4',
        fillColor: '#ef4444',
        fillOpacity: 0.15
      }).addTo(this.layerGroup)

      bounds.extend([em.latitude, em.longitude])
    })
  }

  renderWarehousesLayer(bounds) {
    this.warehousesValue.forEach(wh => {
      const icon = L.divIcon({
        html: `<div class="w-8 h-8 rounded-full bg-emerald-600 text-white flex items-center justify-center font-bold text-xs shadow-xl border-2 border-white ring-2 ring-emerald-200"><i class="fas fa-warehouse text-xs"></i></div>`,
        className: 'custom-leaflet-icon',
        iconSize: [32, 32],
        iconAnchor: [16, 16]
      })

      L.marker([wh.latitude, wh.longitude], { icon: icon })
        .bindPopup(`
          <div class="p-2 min-w-[190px]">
            <span class="px-2 py-0.5 rounded text-[10px] font-black uppercase bg-emerald-100 text-emerald-800 border border-emerald-300">
              LOGISTICS DEPOT
            </span>
            <h4 class="font-black text-sm text-ink mt-1">${wh.name}</h4>
            <p class="text-xs text-mute mt-1"><strong>Stock Capacity:</strong> ${Number(wh.capacity).toLocaleString()} units</p>
            <p class="text-xs text-emerald-700 font-semibold mt-1">Status: Operational Staging Hub</p>
          </div>
        `)
        .addTo(this.layerGroup)

      bounds.extend([wh.latitude, wh.longitude])
    })
  }
}
