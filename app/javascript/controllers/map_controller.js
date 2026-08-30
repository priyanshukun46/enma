import { Controller } from "@hotwired/stimulus"
import * as L from "leaflet"

export default class extends Controller {
  static targets = [ "container", "searchQuery", "searchResults" ]
  static values = {
    locations: Array,
    warehouses: Array,
    emergencies: Array
  }

  connect() {
    this.handleResize = () => {
      if (this.map) {
        this.map.invalidateSize()
      }
    }

    this.initializeMap()
    this.renderAllMarkers()

    // Trigger map redraw to ensure full container width coverage
    setTimeout(() => {
      if (this.map) {
        this.map.invalidateSize()
      }
    }, 150)

    window.addEventListener("resize", this.handleResize)

    // Setup ResizeObserver for responsive flex/grid resizing
    if (window.ResizeObserver && this.hasContainerTarget) {
      this.resizeObserver = new ResizeObserver(() => {
        if (this.map) {
          this.map.invalidateSize()
        }
      })
      this.resizeObserver.observe(this.containerTarget)
    }
  }

  disconnect() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
    window.removeEventListener("resize", this.handleResize)
    if (this.map) {
      this.map.remove()
      this.map = null
    }
  }

  initializeMap() {
    // 1. Initialize Leaflet Map centered on North East India (~26.0° N, 92.8° E)
    const centerLatLng = [26.0, 92.8]
    const defaultZoom = 7

    this.map = L.map(this.containerTarget, {
      zoomControl: true,
      scrollWheelZoom: true
    }).setView(centerLatLng, defaultZoom)

    // 2. Add OpenStreetMap Tile Layer
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 18,
      attribution: '© OpenStreetMap contributors'
    }).addTo(this.map)

    // 3. Initialize Layer Groups / Collections for filtering
    this.markers = {
      locations: [],
      warehouses: [],
      emergencies: [],
      critical: []
    }

    // Map to find markers by Location ID for the search feature
    this.locationMarkerMap = {}

    // State of active filters
    this.activeFilters = {
      locations: true,
      warehouses: true,
      emergencies: true,
      critical: true
    }
  }

  renderAllMarkers() {
    // Render Locations with 4-tier Accessibility Intelligence colors
    this.locationsValue.forEach(loc => {
      const score = Number(loc.accessibility_score) || 0
      const isCritical = score < 40

      let iconHtml = ""
      let statusText = loc.accessibility_category || ""
      let badgeClass = ""
      let scoreColorClass = ""

      if (score >= 80) {
        statusText = statusText || "Highly Accessible"
        badgeClass = "bg-green-100 text-green-800 border-green-300"
        scoreColorClass = "text-green-600"
        iconHtml = `<div class="flex items-center justify-center w-8 h-8 rounded-full bg-green-600 text-white shadow-md border-2 border-white"><i class="fas fa-check text-xs"></i></div>`
      } else if (score >= 60) {
        statusText = statusText || "Moderately Accessible"
        badgeClass = "bg-yellow-100 text-yellow-800 border-yellow-300"
        scoreColorClass = "text-yellow-600"
        iconHtml = `<div class="flex items-center justify-center w-8 h-8 rounded-full bg-yellow-500 text-white shadow-md border-2 border-white"><i class="fas fa-shield-alt text-xs"></i></div>`
      } else if (score >= 40) {
        statusText = statusText || "Difficult Access"
        badgeClass = "bg-orange-100 text-orange-800 border-orange-300"
        scoreColorClass = "text-orange-600"
        iconHtml = `<div class="flex items-center justify-center w-8 h-8 rounded-full bg-orange-500 text-white shadow-md border-2 border-white"><i class="fas fa-mountain text-xs"></i></div>`
      } else {
        statusText = statusText || "Critical Accessibility"
        badgeClass = "bg-red-100 text-red-800 border-red-300 font-bold"
        scoreColorClass = "text-red-600 font-black"
        iconHtml = `<div class="flex items-center justify-center w-8 h-8 rounded-full bg-red-600 text-white shadow-lg border-2 border-white animate-pulse"><i class="fas fa-exclamation-triangle text-xs"></i></div>`
      }

      const icon = L.divIcon({
        html: iconHtml,
        className: 'custom-leaflet-icon',
        iconSize: [32, 32],
        iconAnchor: [16, 32],
        popupAnchor: [0, -32]
      })

      const primaryRisk = loc.primary_risk_factor ? `
        <div class="mt-2 pt-2 border-t border-gray-100">
          <div class="text-[10px] text-gray-500 font-semibold uppercase tracking-wider">Primary Risk Driver</div>
          <div class="text-xs font-bold text-gray-900 mt-0.5">${loc.primary_risk_factor}</div>
        </div>
      ` : ""

      const popupContent = `
        <div class="p-2 min-w-[220px]">
          <div class="flex items-center justify-between border-b pb-1 mb-1">
            <h4 class="font-black text-base text-gray-900">${loc.name}</h4>
            <span class="text-[10px] font-semibold uppercase px-1.5 py-0.5 rounded bg-gray-100 text-gray-600">${loc.location_type || 'Location'}</span>
          </div>

          <p class="text-xs text-gray-600 mt-1"><strong>State:</strong> ${loc.state}</p>
          <p class="text-xs text-gray-600"><strong>District:</strong> ${loc.district}</p>
          <p class="text-xs text-gray-600"><strong>Population:</strong> ${Number(loc.population).toLocaleString()}</p>

          <div class="mt-2 pt-1 border-t border-gray-100 flex items-center justify-between">
            <span class="text-xs font-semibold text-gray-700">Score:</span>
            <span class="text-base font-black ${scoreColorClass}">${score}/100</span>
          </div>

          <div class="mt-1">
            <span class="inline-block px-2 py-0.5 text-[11px] font-bold rounded-full border ${badgeClass}">
              ${statusText}
            </span>
          </div>

          ${primaryRisk}

          <div class="mt-3 pt-2 border-t border-gray-200 text-center">
            <a href="/accessibility/${loc.id}" class="inline-block w-full py-1 px-2 rounded bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold transition-colors">
              View Intelligence Report &rarr;
            </a>
          </div>
        </div>
      `

      const marker = L.marker([loc.latitude, loc.longitude], { icon: icon }).bindPopup(popupContent)
      marker.addTo(this.map)

      // Store in respective filter arrays
      if (isCritical) {
        this.markers.critical.push(marker)
      } else {
        this.markers.locations.push(marker)
      }

      // Save reference for search lookups
      this.locationMarkerMap[loc.id] = marker
    })

    // Render Warehouses
    this.warehousesValue.forEach(wh => {
      const icon = L.divIcon({
        html: `<div class="flex items-center justify-center w-8 h-8 rounded-full bg-emerald-600 text-white shadow-lg border-2 border-white"><i class="fas fa-warehouse text-xs"></i></div>`,
        className: 'custom-leaflet-icon',
        iconSize: [32, 32],
        iconAnchor: [16, 32],
        popupAnchor: [0, -32]
      })

      const popupContent = `
        <div class="p-2 min-w-[200px]">
          <h4 class="font-bold text-base text-gray-900 border-b pb-1 mb-1">${wh.name}</h4>
          <p class="text-xs text-gray-600"><strong>Capacity:</strong> ${Number(wh.capacity).toLocaleString()} units</p>
          <p class="text-xs text-gray-500 mt-2">Lat: ${wh.latitude.toFixed(4)}, Lng: ${wh.longitude.toFixed(4)}</p>
          <span class="mt-2 inline-block px-2 py-0.5 text-xs font-semibold rounded-full bg-green-100 text-green-800">
            Operational Relief Node
          </span>
        </div>
      `

      const marker = L.marker([wh.latitude, wh.longitude], { icon: icon }).bindPopup(popupContent)
      marker.addTo(this.map)
      this.markers.warehouses.push(marker)
    })

    // Render Emergencies
    this.emergenciesValue.forEach(em => {
      const icon = L.divIcon({
        html: `<div class="flex items-center justify-center w-8 h-8 rounded-full bg-amber-500 text-white shadow-lg border-2 border-white animate-bounce"><i class="fas fa-bell text-xs"></i></div>`,
        className: 'custom-leaflet-icon',
        iconSize: [32, 32],
        iconAnchor: [16, 32],
        popupAnchor: [0, -32]
      })

      const popupContent = `
        <div class="p-2 min-w-[200px]">
          <h4 class="font-bold text-base text-red-600 border-b pb-1 mb-1">${em.title}</h4>
          <p class="text-xs text-gray-600"><strong>Type:</strong> ${em.emergency_type}</p>
          <p class="text-xs text-gray-600"><strong>Severity:</strong> <span class="font-bold text-red-600">${em.severity}</span></p>
          <span class="mt-2 inline-block px-2 py-0.5 text-xs font-semibold rounded-full bg-red-100 text-red-800 animate-pulse">
            Status: ${em.status}
          </span>
        </div>
      `

      const marker = L.marker([em.latitude, em.longitude], { icon: icon }).bindPopup(popupContent)
      marker.addTo(this.map)
      this.markers.emergencies.push(marker)
    })
  }

  // Handle Layer Filtering (Show/Hide Marker categories)
  toggleFilter(event) {
    const filterType = event.currentTarget.dataset.filter
    const isChecked = event.currentTarget.checked

    this.activeFilters[filterType] = isChecked

    // Apply visibility to markers of this category
    const categoryMarkers = this.markers[filterType]
    if (categoryMarkers) {
      categoryMarkers.forEach(marker => {
        if (isChecked) {
          marker.addTo(this.map)
        } else {
          this.map.removeLayer(marker)
        }
      })
    }
  }

  // Handle Location Search
  search(event) {
    const query = event.target.value.trim().toLowerCase()

    if (query.length < 1) {
      this.searchResultsTarget.classList.add("hidden")
      this.searchResultsTarget.innerHTML = ""
      return
    }

    // Filter location matches
    const matches = this.locationsValue.filter(loc => {
      return (loc.name && loc.name.toLowerCase().includes(query)) ||
             (loc.state && loc.state.toLowerCase().includes(query)) ||
             (loc.district && loc.district.toLowerCase().includes(query))
    })

    this.showSearchResults(matches)
  }

  showSearchResults(matches) {
    if (matches.length === 0) {
      this.searchResultsTarget.innerHTML = `<div class="p-3 text-xs text-gray-500">No matching locations found</div>`
      this.searchResultsTarget.classList.remove("hidden")
      return
    }

    // Populate search list
    const html = matches.map(loc => {
      const score = Number(loc.accessibility_score) || 0
      let scoreClass = 'text-green-600 font-bold'
      if (score < 40) scoreClass = 'text-red-600 font-black'
      else if (score < 60) scoreClass = 'text-orange-600 font-bold'
      else if (score < 80) scoreClass = 'text-yellow-600 font-bold'

      return `
        <button type="button"
                data-action="click->map#goToLocation"
                data-location-id="${loc.id}"
                class="w-full text-left p-3 hover:bg-indigo-50/70 flex flex-col transition-colors duration-150 border-b border-gray-100 last:border-0 cursor-pointer">
          <div class="flex justify-between items-center">
            <span class="font-bold text-xs text-gray-900">${loc.name}</span>
            <span class="text-xs ${scoreClass}">${score}/100</span>
          </div>
          <span class="text-[11px] text-gray-500">${loc.district}, ${loc.state}</span>
        </button>
      `
    }).join("")

    this.searchResultsTarget.innerHTML = html
    this.searchResultsTarget.classList.remove("hidden")
  }

  goToLocation(event) {
    const locId = event.currentTarget.dataset.locationId
    const location = this.locationsValue.find(loc => loc.id == locId)

    if (location) {
      const marker = this.locationMarkerMap[locId]

      if (marker) {
        // Ensure category's layer is active so marker is visible
        const isCritical = Number(location.accessibility_score) < 40
        const filterType = isCritical ? "critical" : "locations"

        // If currently filtered out, add it back
        if (!this.map.hasLayer(marker)) {
          marker.addTo(this.map)
        }

        // Center map & zoom in
        this.map.setView([location.latitude, location.longitude], 12)

        // Open popup
        marker.openPopup()

        // Hide search dropdown
        this.searchResultsTarget.classList.add("hidden")
        this.searchQueryTarget.value = location.name
      }
    }
  }
}
