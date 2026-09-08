import { Controller } from "@hotwired/stimulus"
import * as L from "leaflet"

export default class extends Controller {
  static targets = [ "container", "filterButton" ]
  static values = {
    graph: Object
  }

  connect() {
    if (!this.hasContainerTarget) return
    this.currentFilter = "all"
    this.handleResize = () => { if (this.map) this.map.invalidateSize() }

    this.initializeMap()
    this.renderGraph()

    setTimeout(() => { if (this.map) this.map.invalidateSize() }, 200)
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
    this.map = L.map(this.containerTarget, {
      zoomControl: true,
      scrollWheelZoom: true
    }).setView([26.0, 92.5], 7)

    const isDark = document.documentElement.dataset.theme === 'dark' || document.documentElement.classList.contains('dark')
    const tileUrl = isDark
      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
      : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png'

    L.tileLayer(tileUrl, {
      maxZoom: 18,
      attribution: '© CartoDB, © OpenStreetMap'
    }).addTo(this.map)

    this.edgeLayer = L.layerGroup().addTo(this.map)
    this.nodeLayer = L.layerGroup().addTo(this.map)
  }

  filterGraph(event) {
    const filter = event.currentTarget.dataset.filter
    if (!filter || filter === this.currentFilter) return
    this.currentFilter = filter

    this.filterButtonTargets.forEach(btn => {
      const active = btn.dataset.filter === filter
      if (active) {
        btn.classList.remove('bg-surface', 'text-sketch')
        btn.classList.add('bg-ink', 'text-paper', 'font-black')
      } else {
        btn.classList.remove('bg-ink', 'text-paper', 'font-black')
        btn.classList.add('bg-surface', 'text-sketch')
      }
    })

    this.renderGraph()
  }

  renderGraph() {
    if (!this.map || !this.graphValue) return

    this.edgeLayer.clearLayers()
    this.nodeLayer.clearLayers()

    const graph = this.graphValue
    const nodes = graph.nodes || []
    const edges = graph.edges || []
    const isolatedSet = new Set(graph.isolated_node_ids || [])
    const criticalSet = new Set(graph.critical_road_ids || [])
    const bridgeSet = new Set(graph.bridge_road_ids || [])
    const simulatedSet = new Set(graph.simulated_closed_ids || [])

    const nodeMap = {}
    nodes.forEach(n => { nodeMap[n.id] = n })

    // 1. Draw Edges
    edges.forEach(edge => {
      const isSimClosed = simulatedSet.has(edge.road_id)
      const isBlocked = edge.status === 'blocked' || isSimClosed
      const isBridge = bridgeSet.has(edge.road_id)
      const isCritical = criticalSet.has(edge.road_id)

      if (this.currentFilter === 'critical' && !isCritical && !isBridge) return
      if (this.currentFilter === 'blocked' && !isBlocked) return

      let latlngs = []
      if (edge.coordinates && edge.coordinates.length >= 2) {
        latlngs = edge.coordinates.map(pt => [pt[0], pt[1]])
      } else {
        const u = nodeMap[edge.origin_id]
        const v = nodeMap[edge.destination_id]
        if (u && v) {
          latlngs = [[u.latitude, u.longitude], [v.latitude, v.longitude]]
        }
      }

      if (latlngs.length < 2) return

      let color = '#10b981' // Green
      let dashArray = null
      let weight = 4
      let opacity = 0.85

      if (isBlocked) {
        color = '#ef4444' // Red
        dashArray = '6, 6'
        weight = 5
      } else if (isBridge || isCritical) {
        color = '#f97316' // Orange / Amber
        weight = 5
      } else if (edge.risk_score >= 50) {
        color = '#eab308' // Yellow
      }

      const polyline = L.polyline(latlngs, {
        color: color,
        weight: weight,
        opacity: opacity,
        dashArray: dashArray,
        lineCap: 'round'
      }).addTo(this.edgeLayer)

      const statusBadge = isSimClosed
        ? '<span class="px-1.5 py-0.5 text-[9px] bg-red-100 text-red-800 rounded font-black">SIMULATED CLOSED</span>'
        : (isBlocked
            ? '<span class="px-1.5 py-0.5 text-[9px] bg-red-100 text-red-800 rounded font-bold">BLOCKED</span>'
            : '<span class="px-1.5 py-0.5 text-[9px] bg-emerald-100 text-emerald-800 rounded font-bold">PASSABLE</span>')

      const bridgeBadge = isBridge
        ? '<span class="px-1.5 py-0.5 text-[9px] bg-amber-100 text-amber-800 rounded font-black">SINGLE POINT OF FAILURE</span>'
        : ''

      polyline.bindPopup(`
        <div class="font-sans text-xs p-1 space-y-1">
          <div class="font-black text-sm text-slate-900 dark:text-white flex items-center justify-between gap-2">
            <span>${edge.road_number}</span>
            <div class="flex gap-1">${statusBadge} ${bridgeBadge}</div>
          </div>
          <div class="text-[11px] text-slate-600 dark:text-slate-300 font-medium">${edge.name}</div>
          <div class="grid grid-cols-2 gap-1.5 pt-1 border-t border-slate-200 dark:border-slate-700 text-[10px]">
            <div><span class="text-slate-400">Length:</span> <strong>${edge.distance} km</strong></div>
            <div><span class="text-slate-400">Risk Score:</span> <strong>${edge.risk_score}/100</strong></div>
            <div><span class="text-slate-400">Disruption Prob:</span> <strong>${Math.round(edge.disruption_probability * 100)}%</strong></div>
            <div><span class="text-slate-400">Cost Factor:</span> <strong>${edge.travel_cost}</strong></div>
          </div>
        </div>
      `)
    })

    // 2. Draw Nodes
    nodes.forEach(node => {
      const isIsolated = isolatedSet.has(node.id)
      const isWh = node.is_warehouse

      let markerHtml = ''
      if (isIsolated) {
        markerHtml = `
          <div class="relative flex items-center justify-center">
            <span class="absolute inline-flex h-8 w-8 rounded-full bg-red-500 opacity-75 animate-ping"></span>
            <div class="w-6 h-6 rounded-full bg-red-600 border-2 border-white shadow-md flex items-center justify-center text-white text-[10px] font-black">
              <i class="fas fa-triangle-exclamation"></i>
            </div>
          </div>
        `
      } else if (isWh) {
        markerHtml = `
          <div class="w-6 h-6 rounded-full bg-indigo-600 border-2 border-white shadow-md flex items-center justify-center text-white text-[10px] font-black">
            <i class="fas fa-warehouse"></i>
          </div>
        `
      } else {
        markerHtml = `
          <div class="w-4 h-4 rounded-full bg-emerald-500 border-2 border-white shadow-sm flex items-center justify-center text-white text-[8px]">
            <i class="fas fa-circle"></i>
          </div>
        `
      }

      const customIcon = L.divIcon({
        html: markerHtml,
        className: 'custom-network-node',
        iconSize: [24, 24],
        iconAnchor: [12, 12]
      })

      const marker = L.marker([node.latitude, node.longitude], { icon: customIcon }).addTo(this.nodeLayer)

      const isoBadge = isIsolated
        ? '<span class="px-2 py-0.5 text-[9px] bg-red-100 text-red-800 rounded-full font-black animate-pulse">ISOLATED / STRANDED</span>'
        : '<span class="px-2 py-0.5 text-[9px] bg-emerald-100 text-emerald-800 rounded-full font-bold">CONNECTED</span>'

      const whBadge = isWh
        ? '<span class="px-2 py-0.5 text-[9px] bg-indigo-100 text-indigo-800 rounded-full font-bold"><i class="fas fa-warehouse text-[8px] mr-1"></i>DEPOT</span>'
        : ''

      marker.bindPopup(`
        <div class="font-sans text-xs p-1 space-y-1.5 min-w-[200px]">
          <div class="flex items-center justify-between gap-1.5 border-b pb-1">
            <strong class="text-sm text-slate-900">${node.name}</strong>
            ${isoBadge}
          </div>
          <div class="text-[11px] text-slate-500">${node.district}, ${node.state}</div>
          <div class="text-[10px] space-y-0.5">
            <div>Population: <strong>${node.population.toLocaleString()}</strong></div>
            <div>Classification: <strong>${node.location_type || 'Settlement'}</strong></div>
            ${whBadge ? `<div>Staging Hub: ${whBadge}</div>` : ''}
          </div>
        </div>
      `)
    })
  }
}
