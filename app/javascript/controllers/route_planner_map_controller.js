import { Controller } from "@hotwired/stimulus"
import * as L from "leaflet"

export default class extends Controller {
  static targets = [
    "container",
    "routeCard",
    "detailsPanel",
    "navHud",
    "navInstruction",
    "navDistance",
    "navEta",
    "navManeuverIcon",
    "navStepCounter",
    "turnList",
    "originSelect",
    "destinationSelect",
    "vehicleInput",
    "voiceToggle",
    "searchForm",
    "originLat",
    "originLon"
  ]

  static values = {
    origin: Object,
    destination: Object,
    routes: Object,
    emergencies: Array,
    allLocations: Array,
    activeRoute: { type: String, default: "safest" }
  }

  connect() {
    if (!this.hasContainerTarget) return

    this.currentNavStep = 0
    this.isNavigating = false
    this.voiceEnabled = true
    this.watchId = null
    this.userLocationMarker = null
    this.userAccuracyCircle = null

    this.handleResize = () => { if (this.map) this.map.invalidateSize() }

    this.initializeMap()
    if (this.hasOriginValue && this.hasDestinationValue && this.hasRoutesValue) {
      this.renderMapElements()
    }

    setTimeout(() => { if (this.map) this.map.invalidateSize() }, 50)
    setTimeout(() => { if (this.map) this.map.invalidateSize() }, 250)
    setTimeout(() => { if (this.map) this.map.invalidateSize() }, 600)
    window.addEventListener("resize", this.handleResize)

    if (window.ResizeObserver && this.hasContainerTarget) {
      this.resizeObserver = new ResizeObserver(() => {
        if (this.map) this.map.invalidateSize()
      })
      this.resizeObserver.observe(this.containerTarget)
    }
  }

  disconnect() {
    this.stopGeolocation()
    if (this.resizeObserver) this.resizeObserver.disconnect()
    window.removeEventListener("resize", this.handleResize)
    if (this.map) {
      this.map.remove()
      this.map = null
    }
  }

  initializeMap() {
    const defaultCenter = [26.0, 92.8] // North East India
    const defaultZoom = 7

    this.map = L.map(this.containerTarget, {
      zoomControl: true,
      scrollWheelZoom: true
    }).setView(defaultCenter, defaultZoom)

    // Standard OpenStreetMap base layer
    const osmLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '© OpenStreetMap contributors'
    }).addTo(this.map)

    // Topo Terrain layer
    const topoLayer = L.tileLayer('https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png', {
      maxZoom: 17,
      attribution: '© OpenTopoMap contributors'
    })

    // Base Maps Layer Controller
    const baseMaps = {
      "Google OSM Style": osmLayer,
      "Topographic Terrain": topoLayer
    }
    L.control.layers(baseMaps, null, { position: 'topright' }).addTo(this.map)

    this.polylines = {}
    this.routeMarkers = []
    this.layerGroups = {
      emergencies: L.layerGroup().addTo(this.map),
      hazardBuffers: L.layerGroup().addTo(this.map)
    }
  }

  renderMapElements() {
    const orig = this.originValue
    const dest = this.destinationValue
    const routes = this.routesValue
    const bounds = L.latLngBounds()

    // 1. Origin Marker (Google Maps A Style)
    const originIcon = L.divIcon({
      html: `
        <div class="relative flex items-center justify-center">
          <div class="w-9 h-9 rounded-full bg-emerald-600 text-white shadow-2xl border-2 border-white ring-4 ring-emerald-200 flex items-center justify-center font-black text-xs">
            A
          </div>
          <span class="absolute -bottom-5 bg-slate-900 text-white text-[10px] font-bold px-1.5 py-0.2 rounded shadow whitespace-nowrap">${orig.name}</span>
        </div>
      `,
      className: 'custom-leaflet-icon',
      iconSize: [36, 36],
      iconAnchor: [18, 18],
      popupAnchor: [0, -18]
    })

    const origMarker = L.marker([orig.latitude, orig.longitude], { icon: originIcon })
      .bindPopup(`
        <div class="p-2 min-w-[180px]">
          <span class="text-[10px] font-black uppercase text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded">Point A (Origin)</span>
          <h4 class="font-black text-base text-gray-900 mt-1">${orig.name}</h4>
          <p class="text-xs text-gray-600">${orig.district}, ${orig.state}</p>
          <p class="text-xs text-gray-500 mt-1">Accessibility: <strong>${orig.accessibility_score}/100</strong></p>
        </div>
      `)
      .addTo(this.map)
    
    bounds.extend([orig.latitude, orig.longitude])
    this.routeMarkers.push(origMarker)

    // 2. Destination Marker (Google Maps B Style)
    const destIcon = L.divIcon({
      html: `
        <div class="relative flex items-center justify-center">
          <div class="w-9 h-9 rounded-full bg-rose-600 text-white shadow-2xl border-2 border-white ring-4 ring-rose-200 flex items-center justify-center font-black text-xs">
            B
          </div>
          <span class="absolute -bottom-5 bg-slate-900 text-white text-[10px] font-bold px-1.5 py-0.2 rounded shadow whitespace-nowrap">${dest.name}</span>
        </div>
      `,
      className: 'custom-leaflet-icon',
      iconSize: [36, 36],
      iconAnchor: [18, 18],
      popupAnchor: [0, -18]
    })

    const destMarker = L.marker([dest.latitude, dest.longitude], { icon: destIcon })
      .bindPopup(`
        <div class="p-2 min-w-[180px]">
          <span class="text-[10px] font-black uppercase text-rose-600 bg-rose-50 px-2 py-0.5 rounded">Point B (Destination)</span>
          <h4 class="font-black text-base text-gray-900 mt-1">${dest.name}</h4>
          <p class="text-xs text-gray-600">${dest.district}, ${dest.state}</p>
          <p class="text-xs text-gray-500 mt-1">Accessibility: <strong>${dest.accessibility_score}/100</strong></p>
        </div>
      `)
      .addTo(this.map)
    
    bounds.extend([dest.latitude, dest.longitude])
    this.routeMarkers.push(destMarker)

    // 3. Active Emergency Hazard Overlays
    if (this.hasEmergenciesValue && this.emergenciesValue.length > 0) {
      this.emergenciesValue.forEach(em => {
        const radiusMeters = (em.affected_radius || 30.0) * 1000.0

        const buffer = L.circle([em.latitude, em.longitude], {
          radius: radiusMeters,
          color: '#ef4444',
          fillColor: '#ef4444',
          fillOpacity: 0.15,
          weight: 1.5,
          dashArray: '4, 4'
        }).bindPopup(`<strong>Hazard Buffer:</strong> ${em.title} (${em.affected_radius} km)`)
        this.layerGroups.hazardBuffers.addLayer(buffer)

        const hazardIcon = L.divIcon({
          html: `<div class="flex items-center justify-center w-7 h-7 rounded-full bg-red-600 text-white shadow-lg border border-white text-xs animate-bounce"><i class="fas fa-exclamation-triangle text-[10px]"></i></div>`,
          className: 'custom-leaflet-icon',
          iconSize: [28, 28],
          iconAnchor: [14, 14]
        })

        const hazardMarker = L.marker([em.latitude, em.longitude], { icon: hazardIcon })
          .bindPopup(`<strong>Active Hazard:</strong> ${em.title}<br><span class="text-xs text-red-600 font-bold">${em.severity} Severity</span>`)
        this.layerGroups.emergencies.addLayer(hazardMarker)
      })
    }

    // 4. Multi-Route Polylines
    if (routes) {
      const config = {
        fastest:   { color: '#2563eb', weight: 6, zIndex: 400, label: 'Fastest' },
        safest:    { color: '#059669', weight: 8, zIndex: 500, label: 'Safest' },
        efficient: { color: '#E95420', weight: 6, zIndex: 400, label: 'Balanced' },
        balanced:  { color: '#E95420', weight: 6, zIndex: 400, label: 'Balanced' }
      }

      Object.entries(routes).forEach(([typeKey, rData]) => {
        const cfg = config[typeKey] || { color: '#6366f1', weight: 6, zIndex: 400 }
        const coords = rData.coordinates || []

        if (coords.length > 0) {
          coords.forEach(pt => bounds.extend(pt))

          const isActive = (typeKey === this.activeRouteValue)

          const polyline = L.polyline(coords, {
            color: cfg.color,
            weight: isActive ? 8 : 4,
            opacity: isActive ? 0.95 : 0.35,
            dashArray: isActive ? null : '6, 6',
            smoothFactor: 1.2
          }).bindPopup(`
            <div class="p-2 min-w-[200px]">
              <span class="text-[10px] font-black uppercase" style="color: ${cfg.color}">${rData.title}</span>
              <h4 class="font-bold text-sm text-gray-900 mt-0.5">${rData.summary || rData.name}</h4>
              <div class="mt-2 space-y-1 text-xs text-gray-600">
                <p><strong>Distance:</strong> ${rData.distance_km} km</p>
                <p><strong>Est. Time:</strong> ${rData.estimated_time_formatted}</p>
                <p><strong>Risk Score:</strong> ${rData.risk_score}/100 (${rData.risk_level})</p>
                <p><strong>Safety Score:</strong> ${rData.scores?.safety || 85}/100</p>
              </div>
            </div>
          `).addTo(this.map)

          polyline.on('click', () => {
            this.selectRoute(typeKey)
          })

          this.polylines[typeKey] = polyline
        }
      })
    }

    this.map.fitBounds(bounds, { padding: [50, 50] })
  }

  // Swap Point A and Point B
  swapLocations() {
    if (!this.hasOriginSelectTarget || !this.hasDestinationSelectTarget) return
    const origVal = this.originSelectTarget.value
    const destVal = this.destinationSelectTarget.value

    this.originSelectTarget.value = destVal
    this.destinationSelectTarget.value = origVal

    // Automatically submit form
    this.originSelectTarget.form.submit()
  }

  // Switch Vehicle Mode Tab
  selectVehicle(event) {
    const vtype = event.currentTarget.dataset.vehicleType
    if (this.hasVehicleInputTarget) {
      this.vehicleInputTarget.value = vtype
      this.vehicleInputTarget.form.submit()
    }
  }

  // Switch Active Route
  selectRoute(eventOrTypeKey) {
    let typeKey = (typeof eventOrTypeKey === 'string') ? eventOrTypeKey : null

    if (!typeKey && eventOrTypeKey) {
      typeKey = eventOrTypeKey.currentTarget?.dataset?.routeType ||
                eventOrTypeKey.target?.closest('[data-route-type]')?.dataset?.routeType
    }

    if (!typeKey) return

    this.activeRouteValue = typeKey

    if (this.polylines) {
      Object.entries(this.polylines).forEach(([key, poly]) => {
        if (key === typeKey) {
          poly.setStyle({ weight: 9, opacity: 1.0, dashArray: null })
          poly.bringToFront()
          if (this.map) {
            this.map.fitBounds(poly.getBounds(), { padding: [50, 50] })
          }
        } else {
          poly.setStyle({ weight: 4, opacity: 0.30, dashArray: '6, 6' })
        }
      })
    }

    if (this.hasRouteCardTargets) {
      this.routeCardTargets.forEach(card => {
        const isMatch = card.dataset.routeType === typeKey
        if (isMatch) {
          card.classList.add("border-indigo-600", "bg-indigo-50/30", "dark:bg-indigo-950/40", "ring-2", "ring-indigo-500/30", "shadow-md")
          card.classList.remove("opacity-60", "border-slate-200", "dark:border-slate-800")
        } else {
          card.classList.remove("border-indigo-600", "bg-indigo-50/30", "dark:bg-indigo-950/40", "ring-2", "ring-indigo-500/30", "shadow-md")
          card.classList.add("opacity-60", "border-slate-200", "dark:border-slate-800")
        }
      })
    }

    this.renderTurnListFor(typeKey)
  }

  highlightRoute(event) {
    const routeType = event.currentTarget.dataset.routeType
    this.selectRoute(routeType)
  }

  // =========================================================================
  // Google Maps Style Turn-by-Turn Navigation Mode
  // =========================================================================
  startNavigation() {
    this.isNavigating = true
    this.currentNavStep = 0

    if (this.hasNavHudTarget) {
      this.navHudTarget.classList.remove("hidden")
    }

    this.renderCurrentNavStep()
    this.startGeolocation()
  }

  exitNavigation() {
    this.isNavigating = false
    this.stopGeolocation()

    if (this.hasNavHudTarget) {
      this.navHudTarget.classList.add("hidden")
    }

    if (this.polylines[this.activeRouteValue]) {
      this.map.fitBounds(this.polylines[this.activeRouteValue].getBounds(), { padding: [50, 50] })
    }
  }

  nextNavStep() {
    const activeRouteData = this.routesValue[this.activeRouteValue]
    const steps = activeRouteData?.steps || []
    if (this.currentNavStep < steps.length - 1) {
      this.currentNavStep += 1
      this.renderCurrentNavStep()
    }
  }

  prevNavStep() {
    if (this.currentNavStep > 0) {
      this.currentNavStep -= 1
      this.renderCurrentNavStep()
    }
  }

  renderCurrentNavStep() {
    const activeRouteData = this.routesValue[this.activeRouteValue]
    const steps = activeRouteData?.steps || []
    
    if (steps.length === 0) {
      if (this.hasNavInstructionTarget) {
        this.navInstructionTarget.textContent = "Proceed along the highlighted corridor."
      }
      return
    }

    const step = steps[this.currentNavStep] || steps[0]

    if (this.hasNavInstructionTarget) {
      this.navInstructionTarget.textContent = step.instruction
    }

    if (this.hasNavDistanceTarget) {
      this.navDistanceTarget.textContent = step.distance_km ? `${step.distance_km} km` : `${step.distance_m} m`
    }

    if (this.hasNavStepCounterTarget) {
      this.navStepCounterTarget.textContent = `Step ${this.currentNavStep + 1} of ${steps.length}`
    }

    if (this.hasNavManeuverIconTarget) {
      this.navManeuverIconTarget.className = this.getManeuverIconClass(step.maneuver_type, step.modifier)
    }

    // Voice announcement (Text to Speech if supported)
    if (this.voiceEnabled && "speechSynthesis" in window) {
      window.speechSynthesis.cancel()
      const utterance = new SpeechSynthesisUtterance(step.instruction)
      utterance.rate = 1.0
      window.speechSynthesis.speak(utterance)
    }

    if (step.location && this.map) {
      this.map.setView(step.location, 14, { animate: true })
    }
  }

  toggleVoice() {
    this.voiceEnabled = !this.voiceEnabled
    if (this.hasVoiceToggleTarget) {
      this.voiceToggleTarget.innerHTML = this.voiceEnabled ? `<i class="fas fa-volume-up"></i>` : `<i class="fas fa-volume-mute"></i>`
    }
  }

  renderTurnListFor(typeKey) {
    if (!this.hasTurnListTarget) return
    const route = this.routesValue[typeKey]
    const steps = route?.steps || []

    if (steps.length === 0) {
      this.turnListTarget.innerHTML = `<p class="text-xs text-gray-500 p-4 text-center">Standard highway corridor route active.</p>`
      return
    }

    const html = steps.map((st, i) => `
      <div class="p-3 border-b border-gray-100 hover:bg-gray-50/80 transition-colors flex items-start space-x-3 text-xs">
        <div class="w-6 h-6 rounded-full bg-indigo-50 text-indigo-700 font-bold flex items-center justify-center flex-shrink-0 mt-0.5">
          ${st.step_number}
        </div>
        <div class="flex-1">
          <p class="font-bold text-gray-900">${st.instruction}</p>
          <span class="text-[11px] text-gray-500">${st.road_name} • ${st.distance_km || (st.distance_m / 1000.0).toFixed(1)} km</span>
        </div>
      </div>
    `).join("")

    this.turnListTarget.innerHTML = html
  }

  getManeuverIconClass(type, modifier) {
    if (type === "arrive") return "fas fa-flag-checkered text-rose-500"
    if (type === "depart") return "fas fa-play text-emerald-400"
    if (modifier && modifier.includes("left")) return "fas fa-arrow-left text-white"
    if (modifier && modifier.includes("right")) return "fas fa-arrow-right text-white"
    if (modifier && modifier.includes("slight left")) return "fas fa-arrow-up-left text-white"
    if (modifier && modifier.includes("slight right")) return "fas fa-arrow-up-right text-white"
    return "fas fa-arrow-up text-white"
  }

  // =========================================================================
  // Geolocation Follow Marker
  // =========================================================================
  startGeolocation() {
    if (!("geolocation" in navigator)) return

    const options = {
      enableHighAccuracy: true,
      maximumAge: 4000,
      timeout: 10000
    }

    this.watchId = navigator.geolocation.watchPosition(
      (position) => {
        const lat = position.coords.latitude
        const lon = position.coords.longitude
        const accuracy = position.coords.accuracy

        this.updateUserLocationOnMap(lat, lon, accuracy)
      },
      (error) => {
        console.log("Geolocation info:", error.message)
      },
      options
    )
  }

  updateUserLocationOnMap(lat, lon, accuracy) {
    if (!this.map) return

    if (!this.userLocationMarker) {
      const userDotIcon = L.divIcon({
        html: `<div class="w-4 h-4 rounded-full bg-blue-600 border-2 border-white shadow-lg ring-4 ring-blue-300 animate-pulse"></div>`,
        className: 'custom-leaflet-icon',
        iconSize: [16, 16],
        iconAnchor: [8, 8]
      })

      this.userLocationMarker = L.marker([lat, lon], { icon: userDotIcon, zIndexOffset: 1000 }).addTo(this.map)
      this.userAccuracyCircle = L.circle([lat, lon], {
        radius: accuracy,
        color: '#3b82f6',
        fillColor: '#3b82f6',
        fillOpacity: 0.1,
        weight: 1
      }).addTo(this.map)
    } else {
      this.userLocationMarker.setLatLng([lat, lon])
      this.userAccuracyCircle.setLatLng([lat, lon]).setRadius(accuracy)
    }

    if (this.isNavigating) {
      this.map.panTo([lat, lon], { animate: true })
    }
  }

  stopGeolocation() {
    if (this.watchId !== null) {
      navigator.geolocation.clearWatch(this.watchId)
      this.watchId = null
    }
    if (this.userLocationMarker && this.map) {
      this.map.removeLayer(this.userLocationMarker)
      this.userLocationMarker = null
    }
    if (this.userAccuracyCircle && this.map) {
      this.map.removeLayer(this.userAccuracyCircle)
      this.userAccuracyCircle = null
    }
  }

  locateUser() {
    if (!("geolocation" in navigator)) {
      alert("Geolocation is not supported by your browser.")
      return
    }

    navigator.geolocation.getCurrentPosition(
      (position) => {
        const lat = position.coords.latitude
        const lon = position.coords.longitude

        if (this.hasOriginLatTarget && this.hasOriginLonTarget) {
          this.originLatTarget.value = lat
          this.originLonTarget.value = lon
        }

        if (this.hasOriginSelectTarget) {
          // Set origin select value to user_location
          let userOpt = this.originSelectTarget.querySelector('option[value="user_location"]')
          if (!userOpt) {
            userOpt = document.createElement("option")
            userOpt.value = "user_location"
            userOpt.textContent = `📍 My Current Location (${lat.toFixed(2)}, ${lon.toFixed(2)})`
            this.originSelectTarget.prepend(userOpt)
          }
          this.originSelectTarget.value = "user_location"
        }

        if (this.hasSearchFormTarget) {
          this.searchFormTarget.submit()
        }
      },
      (error) => {
        let msg = "Unable to retrieve your current location."
        if (error.code === error.PERMISSION_DENIED) {
          msg = "Location permission denied. Please allow location access in your browser."
        } else if (error.code === error.TIMEOUT) {
          msg = "Location request timed out. Please try again."
        }
        alert(msg)
      },
      {
        enableHighAccuracy: true,
        timeout: 10000,
        maximumAge: 60000
      }
    )
  }
}
