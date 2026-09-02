import { Controller } from "@hotwired/stimulus"
import * as L from "leaflet"

export default class extends Controller {
  static targets = ["container"]
  static values = {
    plannedRoute: Array,
    currentPosition: Array,
    origin: Object,
    destination: Object,
    locations: Array
  }

  connect() {
    if (!this.hasContainerTarget) return
    this.initializeMap()
    this.renderRouteElements()
  }

  disconnect() {
    if (this.map) {
      this.map.remove()
      this.map = null
    }
  }

  initializeMap() {
    const center = this.currentPositionValue || [26.14, 91.73]
    this.map = L.map(this.containerTarget, {
      zoomControl: true,
      attributionControl: false
    }).setView(center, 9)

    L.tileLayer("https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png", {
      maxZoom: 19,
      subdomains: "abcd"
    }).addTo(this.map)
  }

  renderRouteElements() {
    const bounds = []

    // 1. Planned Route Polyline
    if (this.plannedRouteValue && this.plannedRouteValue.length >= 2) {
      const poly = L.polyline(this.plannedRouteValue, {
        color: "#E95420",
        weight: 6,
        opacity: 0.85,
        lineCap: "round",
        lineJoin: "round"
      }).addTo(this.map)
      bounds.push(poly.getBounds())
    }

    // 2. Breadcrumbs History
    if (this.locationsValue && this.locationsValue.length > 0) {
      const crumbCoords = this.locationsValue.map(l => [l.lat, l.lon])
      L.polyline(crumbCoords, {
        color: "#3b82f6",
        weight: 3,
        opacity: 0.7,
        dashArray: "4, 6"
      }).addTo(this.map)

      this.locationsValue.forEach(l => {
        L.circleMarker([l.lat, l.lon], {
          radius: 3,
          fillColor: "#3b82f6",
          color: "#ffffff",
          weight: 1,
          opacity: 0.9,
          fillOpacity: 0.9
        }).bindPopup(`<div class="font-mono text-xs"><strong>${l.recorded_at}</strong><br/>Speed: ${l.speed} km/h</div>`).addTo(this.map)
      })
    }

    // 3. Origin & Destination Markers
    if (this.originValue && this.originValue.lat) {
      const origIcon = L.divIcon({
        className: "custom-leaflet-icon",
        html: `<div class="w-7 h-7 rounded-full bg-emerald-600 border-2 border-white shadow-md flex items-center justify-center text-white text-xs font-bold"><i class="fas fa-play text-[10px]"></i></div>`,
        iconSize: [28, 28],
        iconAnchor: [14, 14]
      })
      L.marker([this.originValue.lat, this.originValue.lon], { icon: origIcon })
        .bindPopup(`<strong>Origin:</strong> ${this.originValue.name}`)
        .addTo(this.map)
    }

    if (this.destinationValue && this.destinationValue.lat) {
      const destIcon = L.divIcon({
        className: "custom-leaflet-icon",
        html: `<div class="w-7 h-7 rounded-full bg-rose-600 border-2 border-white shadow-md flex items-center justify-center text-white text-xs font-bold"><i class="fas fa-flag text-[10px]"></i></div>`,
        iconSize: [28, 28],
        iconAnchor: [14, 14]
      })
      L.marker([this.destinationValue.lat, this.destinationValue.lon], { icon: destIcon })
        .bindPopup(`<strong>Destination:</strong> ${this.destinationValue.name}`)
        .addTo(this.map)
    }

    // 4. Live Vehicle Marker
    if (this.currentPositionValue && this.currentPositionValue.length === 2) {
      const truckIcon = L.divIcon({
        className: "custom-leaflet-icon",
        html: `<div class="relative flex items-center justify-center">
                 <div class="w-10 h-10 rounded-full bg-indigo-600/30 animate-ping absolute"></div>
                 <div class="w-8 h-8 rounded-full bg-indigo-600 border-2 border-white shadow-xl flex items-center justify-center text-white text-sm relative z-10">
                   <i class="fas fa-truck text-xs"></i>
                 </div>
               </div>`,
        iconSize: [40, 40],
        iconAnchor: [20, 20]
      })

      L.marker(this.currentPositionValue, { icon: truckIcon })
        .bindPopup(`<div class="p-1 font-sans text-xs"><strong>Live Vehicle Position</strong><br/>Tracking actively</div>`)
        .addTo(this.map)

      bounds.push(L.latLngBounds([this.currentPositionValue]))
    }

    if (bounds.length > 0) {
      const combined = bounds.reduce((acc, b) => acc.extend(b), L.latLngBounds(bounds[0]))
      this.map.fitBounds(combined, { padding: [40, 40] })
    }
  }
}
