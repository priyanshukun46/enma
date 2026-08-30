import { Controller } from "@hotwired/stimulus"
import * as L from "leaflet"

export default class extends Controller {
  static targets = [ "container" ]
  static values = {
    origin: Object,
    destination: Object,
    routes: Object,
    emergencies: Array,
    activeRoute: { type: String, default: "fastest" }
  }

  connect() {
    if (!this.hasContainerTarget || !this.hasOriginValue || !this.hasDestinationValue) return
    this.initializeMap()
    this.renderMapElements()
  }

  disconnect() {
    if (this.map) {
      this.map.remove()
      this.map = null
    }
  }

  initializeMap() {
    const orig = this.originValue
    const dest = this.destinationValue

    // Calculate midpoint
    const midLat = (orig.latitude + dest.latitude) / 2.0
    const midLon = (orig.longitude + dest.longitude) / 2.0

    this.map = L.map(this.containerTarget).setView([midLat, midLon], 7)

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 18,
      attribution: '© OpenStreetMap contributors'
    }).addTo(this.map)

    this.polylines = {}
  }

  renderMapElements() {
    const orig = this.originValue
    const dest = this.destinationValue
    const routes = this.routesValue
    const bounds = L.latLngBounds()

    // 1. Origin Marker (Green Pin)
    const originIcon = L.divIcon({
      html: `<div class="flex items-center justify-center w-9 h-9 rounded-full bg-emerald-600 text-white shadow-xl border-2 border-white ring-4 ring-emerald-100 font-bold"><i class="fas fa-play text-xs"></i></div>`,
      className: 'custom-leaflet-icon',
      iconSize: [36, 36],
      iconAnchor: [18, 18],
      popupAnchor: [0, -18]
    })

    const origMarker = L.marker([orig.latitude, orig.longitude], { icon: originIcon })
      .bindPopup(`
        <div class="p-2 min-w-[180px]">
          <div class="text-[10px] font-bold uppercase tracking-wider text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded inline-block mb-1">Origin Point</div>
          <h4 class="font-black text-sm text-gray-900">${orig.name}</h4>
          <p class="text-xs text-gray-600">${orig.district || ''}, ${orig.state}</p>
          <div class="mt-2 text-xs font-semibold text-gray-700 border-t pt-1">
            Accessibility: <span class="font-bold text-emerald-600">${orig.accessibility_score}/100</span>
          </div>
        </div>
      `)
      .addTo(this.map)

    bounds.extend([orig.latitude, orig.longitude])

    // 2. Destination Marker (Red Target Pin)
    const destIcon = L.divIcon({
      html: `<div class="flex items-center justify-center w-9 h-9 rounded-full bg-red-600 text-white shadow-xl border-2 border-white ring-4 ring-red-100 font-bold"><i class="fas fa-flag-checkered text-xs"></i></div>`,
      className: 'custom-leaflet-icon',
      iconSize: [36, 36],
      iconAnchor: [18, 18],
      popupAnchor: [0, -18]
    })

    const destMarker = L.marker([dest.latitude, dest.longitude], { icon: destIcon })
      .bindPopup(`
        <div class="p-2 min-w-[180px]">
          <div class="text-[10px] font-bold uppercase tracking-wider text-red-700 bg-red-50 px-2 py-0.5 rounded inline-block mb-1">Destination</div>
          <h4 class="font-black text-sm text-gray-900">${dest.name}</h4>
          <p class="text-xs text-gray-600">${dest.district || ''}, ${dest.state}</p>
          <div class="mt-2 text-xs font-semibold text-gray-700 border-t pt-1">
            Accessibility: <span class="font-bold text-red-600">${dest.accessibility_score}/100</span>
          </div>
        </div>
      `)
      .addTo(this.map)

    bounds.extend([dest.latitude, dest.longitude])

    // 3. Render Active Emergencies (if any near corridor)
    if (this.hasEmergenciesValue) {
      this.emergenciesValue.forEach(em => {
        const emIcon = L.divIcon({
          html: `<div class="flex items-center justify-center w-7 h-7 rounded-full bg-amber-500 text-white shadow-lg border-2 border-white animate-pulse"><i class="fas fa-exclamation text-[10px]"></i></div>`,
          className: 'custom-leaflet-icon',
          iconSize: [28, 28],
          iconAnchor: [14, 14],
          popupAnchor: [0, -14]
        })

        L.marker([em.latitude, em.longitude], { icon: emIcon })
          .bindPopup(`
            <div class="p-2">
              <span class="text-[10px] font-bold uppercase text-amber-700">Hazard Zone</span>
              <h5 class="font-bold text-xs text-red-600">${em.title}</h5>
              <p class="text-[11px] text-gray-600">${em.emergency_type} • ${em.severity}</p>
            </div>
          `)
          .addTo(this.map)

        bounds.extend([em.latitude, em.longitude])
      })
    }

    // 4. Render 3 Route Polylines
    if (routes) {
      const routeConfigs = [
        { key: "fastest", color: "#2563eb", weight: 5, dashArray: null },
        { key: "safest", color: "#059669", weight: 5, dashArray: null },
        { key: "efficient", color: "#d97706", weight: 5, dashArray: null }
      ]

      routeConfigs.forEach(cfg => {
        const rData = routes[cfg.key]
        if (rData && rData.waypoints) {
          const latlngs = rData.waypoints.map(p => [p[0], p[1]])
          latlngs.forEach(p => bounds.extend(p))

          const polyline = L.polyline(latlngs, {
            color: cfg.color,
            weight: cfg.weight,
            opacity: cfg.key === this.activeRouteValue ? 0.95 : 0.45,
            smoothFactor: 1.2
          }).bindPopup(`
            <div class="p-2">
              <h4 class="font-bold text-xs" style="color: ${cfg.color}">${rData.title}</h4>
              <p class="text-xs text-gray-600 mt-1"><strong>Distance:</strong> ${rData.distance_km} km</p>
              <p class="text-xs text-gray-600"><strong>Est. Time:</strong> ${rData.estimated_time_formatted}</p>
              <p class="text-xs text-gray-600"><strong>Risk Score:</strong> ${rData.risk_score}/100 (${rData.risk_level})</p>
            </div>
          `).addTo(this.map)

          this.polylines[cfg.key] = polyline
        }
      })
    }

    // Fit map to encompass all points comfortably with padding
    this.map.fitBounds(bounds, { padding: [50, 50] })
  }

  highlightRoute(event) {
    const routeType = event.currentTarget.dataset.routeType
    if (!routeType || !this.polylines) return

    this.activeRouteValue = routeType

    Object.entries(this.polylines).forEach(([type, poly]) => {
      if (type === routeType) {
        poly.setStyle({ weight: 7, opacity: 1.0 })
        poly.bringToFront()
      } else {
        poly.setStyle({ weight: 4, opacity: 0.35 })
      }
    })
  }
}
