import { Controller } from "@hotwired/stimulus"
import * as L from "leaflet"

export default class extends Controller {
  static targets = ["container"]
  static values = {
    vehicles: Array,
    shipments: Array,
    incidents: Array
  }

  connect() {
    if (!this.hasContainerTarget) return
    this.initializeMap()
    this.renderFleetElements()
  }

  disconnect() {
    if (this.map) {
      this.map.remove()
      this.map = null
    }
  }

  initializeMap() {
    const center = [26.2, 92.5]
    this.map = L.map(this.containerTarget, {
      zoomControl: true,
      attributionControl: false
    }).setView(center, 7)

    L.tileLayer("https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png", {
      maxZoom: 19,
      subdomains: "abcd"
    }).addTo(this.map)
  }

  renderFleetElements() {
    const bounds = []

    // 1. Active Shipment Corridors
    if (this.shipmentsValue) {
      this.shipmentsValue.forEach(sh => {
        if (sh.geometry && sh.geometry.length >= 2) {
          const poly = L.polyline(sh.geometry, {
            color: "#6366f1",
            weight: 4,
            opacity: 0.6,
            dashArray: "6, 6"
          }).bindPopup(`
            <div class="p-1 font-sans text-xs">
              <strong>${sh.tracking}</strong><br/>
              <span>${sh.origin} &rarr; ${sh.destination}</span><br/>
              <span>Progress: <strong>${sh.progress || 0}%</strong></span><br/>
              <span>ETA: ${sh.eta || '—'}</span>
            </div>
          `).addTo(this.map)
          bounds.push(poly.getBounds())
        }
      })
    }

    // 2. Incident Hazard Markers
    if (this.incidentsValue) {
      this.incidentsValue.forEach(inc => {
        if (inc.lat && inc.lon) {
          const incIcon = L.divIcon({
            className: "custom-leaflet-icon",
            html: `<div class="w-6 h-6 rounded-full bg-red-600 border-2 border-white shadow-md flex items-center justify-center text-white text-[10px]"><i class="fas fa-exclamation-triangle"></i></div>`,
            iconSize: [24, 24],
            iconAnchor: [12, 12]
          })
          L.marker([inc.lat, inc.lon], { icon: incIcon })
            .bindPopup(`<div class="p-1 text-xs"><strong>${inc.type.toUpperCase()} Hazard</strong><br/>${inc.desc}</div>`)
            .addTo(this.map)
        }
      })
    }

    // 3. Vehicles Markers
    if (this.vehiclesValue) {
      this.vehiclesValue.forEach(v => {
        if (v.lat && v.lon) {
          const colorClass = v.status === "in_transit" ? "bg-blue-600" : (v.status === "delayed" ? "bg-amber-500" : "bg-emerald-600")
          const vIcon = L.divIcon({
            className: "custom-leaflet-icon",
            html: `<div class="relative flex items-center justify-center">
                     <div class="w-8 h-8 rounded-full ${colorClass} border-2 border-white shadow-lg flex items-center justify-center text-white text-xs">
                       <i class="fas fa-truck"></i>
                     </div>
                   </div>`,
            iconSize: [32, 32],
            iconAnchor: [16, 16]
          })

          L.marker([v.lat, v.lon], { icon: vIcon })
            .bindPopup(`
              <div class="p-2 font-sans text-xs space-y-1">
                <div class="font-mono font-bold text-sm text-slate-900">${v.reg}</div>
                <div class="text-[11px] text-slate-500">${v.type} &bull; <span class="uppercase font-bold">${v.status}</span></div>
                <div class="font-mono text-xs">Speed: <strong>${v.speed || 0} km/h</strong></div>
                ${v.shipment ? `<div class="pt-1 text-[11px] border-t border-slate-200"><strong>Shipment:</strong> ${v.shipment} (${v.progress || 0}%)</div>` : ''}
                <div class="pt-1"><a href="/vehicles/${v.id}" class="text-indigo-600 font-bold hover:underline">View Vehicle Details &rarr;</a></div>
              </div>
            `)
            .addTo(this.map)

          bounds.push(L.latLngBounds([[v.lat, v.lon]]))
        }
      })
    }

    if (bounds.length > 0) {
      const combined = bounds.reduce((acc, b) => acc.extend(b), L.latLngBounds(bounds[0]))
      this.map.fitBounds(combined, { padding: [50, 50] })
    }
  }
}
