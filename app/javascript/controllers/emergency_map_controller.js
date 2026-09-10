import { Controller } from "@hotwired/stimulus"
import * as L from "leaflet"

export default class extends Controller {
  static targets = [ "container" ]
  static values = {
    emergency: Object,
    affectedCommunities: Array,
    recommendedWarehouse: Object,
    emergencyRoute: Object
  }

  connect() {
    if (!this.hasContainerTarget || !this.hasEmergencyValue) return
    this.handleResize = () => { if (this.map) this.map.invalidateSize() }
    this.initializeMap()
    this.renderEmergencyElements()

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
    const em = this.emergencyValue
    this.map = L.map(this.containerTarget).setView([em.latitude, em.longitude], 8)

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 18,
      attribution: '© OpenStreetMap contributors'
    }).addTo(this.map)
  }

  renderEmergencyElements() {
    const em = this.emergencyValue
    const communities = this.affectedCommunitiesValue || []
    const warehouse = this.recommendedWarehouseValue
    const route = this.hasEmergencyRouteValue ? this.emergencyRouteValue : null
    const bounds = L.latLngBounds()

    // 1. Epicenter Marker (Pulsing Red)
    const epicenterIcon = L.divIcon({
      html: `<div class="flex items-center justify-center w-10 h-10 rounded-full bg-red-600 text-white shadow-2xl border-2 border-white animate-ping"><i class="fas fa-radiation text-xs"></i></div>
             <div class="flex items-center justify-center w-10 h-10 rounded-full bg-red-600 text-white shadow-2xl border-2 border-white absolute top-0 left-0"><i class="fas fa-biohazard text-sm"></i></div>`,
      className: 'custom-leaflet-icon',
      iconSize: [40, 40],
      iconAnchor: [20, 20],
      popupAnchor: [0, -20]
    })

    const epicenterMarker = L.marker([em.latitude, em.longitude], { icon: epicenterIcon })
      .bindPopup(`
        <div class="p-2 min-w-[200px]">
          <span class="px-2 py-0.5 rounded text-[10px] font-black uppercase tracking-wider bg-red-100 text-red-800 border border-red-300">
            ${em.severity} SEVERITY
          </span>
          <h4 class="font-black text-sm text-ink mt-1">${em.title}</h4>
          <p class="text-xs text-mute mt-0.5"><strong>Type:</strong> ${em.emergency_type}</p>
          <p class="text-xs text-mute"><strong>Affected Radius:</strong> ${em.affected_radius} km</p>
          <p class="text-xs text-red-600 font-bold mt-1">Status: ${em.status}</p>
        </div>
      `)
      .addTo(this.map)

    bounds.extend([em.latitude, em.longitude])

    // 2. Affected Radius Circle
    const radiusMeters = (em.affected_radius || 50.0) * 1000
    const radiusCircle = L.circle([em.latitude, em.longitude], {
      radius: radiusMeters,
      color: '#dc2626',
      weight: 2,
      dashArray: '6, 6',
      fillColor: '#ef4444',
      fillOpacity: 0.12
    }).addTo(this.map)

    bounds.extend(radiusCircle.getBounds())

    // 3. Affected Communities Markers
    communities.forEach((comm, idx) => {
      const isCritical = comm.priority_level === "CRITICAL" || comm.accessibility_score < 40.0
      const bgColor = isCritical ? 'bg-red-600' : (comm.priority_level === "HIGH" ? 'bg-orange-500' : 'bg-yellow-500')
      const badgeBg = isCritical ? 'bg-red-100 text-red-800' : (comm.priority_level === "HIGH" ? 'bg-orange-100 text-orange-800' : 'bg-yellow-100 text-yellow-800')

      const commIcon = L.divIcon({
        html: `<div class="flex items-center justify-center w-7 h-7 rounded-full ${bgColor} text-white shadow-lg border-2 border-white text-xs font-black">#${idx + 1}</div>`,
        className: 'custom-leaflet-icon',
        iconSize: [28, 28],
        iconAnchor: [14, 14],
        popupAnchor: [0, -14]
      })

      L.marker([comm.latitude, comm.longitude], { icon: commIcon })
        .bindPopup(`
          <div class="p-2 min-w-[200px]">
            <div class="flex items-center justify-between border-b pb-1 mb-1">
              <h4 class="font-black text-sm text-ink">${comm.name}</h4>
              <span class="text-[10px] font-extrabold px-1.5 py-0.5 rounded ${badgeBg}">${comm.priority_level}</span>
            </div>
            <p class="text-xs text-mute"><strong>State:</strong> ${comm.state}</p>
            <p class="text-xs text-mute"><strong>Population:</strong> ${Number(comm.population).toLocaleString()}</p>
            <p class="text-xs text-mute"><strong>Distance from Epicenter:</strong> ${comm.distance_km} km</p>
            <div class="mt-2 pt-1 border-t flex justify-between items-center text-xs">
              <span class="text-mute">Priority Score:</span>
              <span class="font-black text-red-600 text-sm">${comm.priority_score}/100</span>
            </div>
            <div class="text-xs flex justify-between items-center mt-0.5">
              <span class="text-mute">Accessibility:</span>
              <span class="font-bold text-ink">${comm.accessibility_score}/100</span>
            </div>
          </div>
        `)
        .addTo(this.map)

      bounds.extend([comm.latitude, comm.longitude])
    })

    // 4. Recommended Warehouse Marker (Green)
    if (warehouse) {
      const whIcon = L.divIcon({
        html: `<div class="flex items-center justify-center w-9 h-9 rounded-full bg-emerald-600 text-white shadow-2xl border-2 border-white ring-4 ring-emerald-100 font-bold"><i class="fas fa-warehouse text-xs"></i></div>`,
        className: 'custom-leaflet-icon',
        iconSize: [36, 36],
        iconAnchor: [18, 18],
        popupAnchor: [0, -18]
      })

      L.marker([warehouse.latitude, warehouse.longitude], { icon: whIcon })
        .bindPopup(`
          <div class="p-2 min-w-[220px]">
            <span class="px-2 py-0.5 rounded text-[10px] font-black uppercase tracking-wider bg-emerald-100 text-emerald-800 border border-emerald-300">
              ⭐ RECOMMENDED RELIEF HUB
            </span>
            <h4 class="font-black text-sm text-ink mt-1">${warehouse.name}</h4>
            <p class="text-xs text-mute mt-1"><strong>Stock Capacity:</strong> ${Number(warehouse.capacity).toLocaleString()} units</p>
            <p class="text-xs text-mute"><strong>Distance to Epicenter:</strong> ${warehouse.distance_km} km</p>
            <p class="text-xs text-emerald-700 font-semibold mt-1">Status: Operational Staging Node</p>
          </div>
        `)
        .addTo(this.map)

      bounds.extend([warehouse.latitude, warehouse.longitude])
    }

    // 5. Emergency Response Dispatch Route Polyline
    if (route && route.waypoints && route.waypoints.length > 1) {
      const latlngs = route.waypoints.map(p => [p[0], p[1]])
      latlngs.forEach(p => bounds.extend(p))

      L.polyline(latlngs, {
        color: '#059669',
        weight: 5,
        dashArray: '8, 8',
        opacity: 0.95,
        smoothFactor: 1.2
      }).bindPopup(`
        <div class="p-2">
          <span class="text-[10px] font-black uppercase text-emerald-700">Priority Response Corridor</span>
          <h4 class="font-black text-xs text-ink mt-0.5">${route.route_title}</h4>
          <p class="text-xs text-mute mt-1"><strong>From:</strong> ${route.origin_name}</p>
          <p class="text-xs text-mute"><strong>To Target:</strong> ${route.destination_name}</p>
          <p class="text-xs text-mute"><strong>Distance:</strong> ${route.distance_km} km</p>
          <p class="text-xs text-mute"><strong>Est. Time:</strong> ${route.estimated_time}</p>
        </div>
      `).addTo(this.map)
    }

    // Fit map view
    this.map.fitBounds(bounds, { padding: [40, 40] })
  }
}
