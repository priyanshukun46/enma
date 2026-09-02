class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip

    if @query.present?
      q_wildcard = "%#{@query}%"
      @locations = Location.where("name ILIKE :q OR state ILIKE :q OR district ILIKE :q", q: q_wildcard).limit(10)
      @roads = Road.where("name ILIKE :q OR road_number ILIKE :q OR district ILIKE :q OR state ILIKE :q", q: q_wildcard).limit(6)
      @warehouses = Warehouse.where("name ILIKE :q OR district ILIKE :q OR state ILIKE :q", q: q_wildcard).limit(5)
      @emergencies = Emergency.where("title ILIKE :q OR emergency_type ILIKE :q OR severity ILIKE :q", q: q_wildcard).limit(5)
    else
      @locations = Location.none
      @roads = Road.none
      @warehouses = Warehouse.none
      @emergencies = Emergency.none
    end

    @total_results = @locations.size + @roads.size + @warehouses.size + @emergencies.size
  end

  def suggestions
    query = params[:q].to_s.strip

    if query.blank?
      # Default quick suggestion presets when search is empty/focused
      presets = [
        { title: "Tawang Outpost", subtitle: "High altitude settlement (Arunachal)", category: "Location", url: "/accessibility", icon: "fa-map-pin" },
        { title: "NH-13 Trans-Arunachal", subtitle: "Strategic lifeline highway corridor", category: "Road", url: "/routes", icon: "fa-road" },
        { title: "Guwahati Central Depot", subtitle: "Strategic relief staging hub", category: "Warehouse", url: "/warehouses", icon: "fa-warehouse" },
        { title: "Monsoon Landslide Detour", subtitle: "Active severe disruption corridor", category: "Emergency", url: "/emergencies", icon: "fa-triangle-exclamation" },
        { title: "Interactive GIS Radar", subtitle: "Live geospatial radar map", category: "App", url: "/map", icon: "fa-compass" }
      ]
      return render json: { suggestions: presets, query: "", total: presets.size }
    end

    q_wildcard = "%#{query}%"
    suggestions = []

    # 1. Locations
    Location.where("name ILIKE :q OR district ILIKE :q OR state ILIKE :q", q: q_wildcard).limit(3).each do |loc|
      suggestions << {
        id: "loc_#{loc.id}",
        title: loc.name,
        subtitle: "#{loc.district}, #{loc.state} • Score: #{loc.accessibility_score&.round(0)}/100",
        category: "Location",
        url: accessibility_location_path(loc),
        icon: "fa-map-pin",
        badge: loc.accessibility_tier
      }
    end

    # 2. Roads
    Road.where("name ILIKE :q OR road_number ILIKE :q OR district ILIKE :q OR state ILIKE :q", q: q_wildcard).limit(3).each do |road|
      suggestions << {
        id: "road_#{road.id}",
        title: "#{road.road_number} - #{road.name}",
        subtitle: "#{road.district}, #{road.state} • Risk: #{road.risk_score&.round(0)}/100",
        category: "Road",
        url: routes_path,
        icon: "fa-road",
        badge: road.risk_level.to_s.upcase
      }
    end

    # 3. Warehouses
    Warehouse.where("name ILIKE :q OR district ILIKE :q OR state ILIKE :q", q: q_wildcard).limit(2).each do |wh|
      suggestions << {
        id: "wh_#{wh.id}",
        title: wh.name,
        subtitle: "#{wh.district.presence || 'Staging Base'} • #{wh.available_capacity} units available",
        category: "Warehouse",
        url: warehouse_path(wh),
        icon: "fa-warehouse",
        badge: wh.dynamic_status
      }
    end

    # 4. Emergencies
    Emergency.where("title ILIKE :q OR emergency_type ILIKE :q", q: q_wildcard).limit(2).each do |em|
      suggestions << {
        id: "em_#{em.id}",
        title: em.title,
        subtitle: "#{em.emergency_type} • #{em.severity.to_s.upcase}",
        category: "Emergency",
        url: emergency_path(em),
        icon: "fa-triangle-exclamation",
        badge: em.severity.to_s.upcase
      }
    end

    # 5. Fast App Navigation Actions
    pages = [
      { title: "Smart Route Optimization", subtitle: "Multi-hazard Dijkstra & terrain routing", category: "App", url: routes_path, icon: "fa-route", keywords: ["route", "smart", "optimizer", "dijkstra", "plan"] },
      { title: "Intelligence GIS Radar Map", subtitle: "Live satellite & hazard overlays", category: "App", url: map_path, icon: "fa-compass", keywords: ["map", "gis", "radar", "satellite"] },
      { title: "Live Fleet Dispatch & GPS", subtitle: "Real-time convoy telemetry & rerouting", category: "App", url: shipments_path, icon: "fa-truck-fast", keywords: ["fleet", "vehicle", "truck", "shipment", "gps"] },
      { title: "Accessibility Intelligence", subtitle: "Settlement isolation risk & index", category: "App", url: accessibility_path, icon: "fa-chart-pie", keywords: ["accessibility", "settlement", "risk", "terrain"] },
      { title: "Relief Depot Intelligence", subtitle: "Warehouse stock levels & readiness", category: "App", url: warehouses_path, icon: "fa-boxes-stacked", keywords: ["depot", "warehouse", "stockpile", "inventory"] },
      { title: "Disruption Analytics & ML", subtitle: "Trained XGBoost environmental models", category: "App", url: analytics_path, icon: "fa-chart-line", keywords: ["analytics", "model", "prediction", "ml", "metrics"] }
    ]

    matched_pages = pages.select do |p|
      p[:title].downcase.include?(query.downcase) || p[:keywords].any? { |k| k.include?(query.downcase) }
    end

    matched_pages.each do |page|
      suggestions << {
        id: "page_#{page[:title].parameterize}",
        title: page[:title],
        subtitle: page[:subtitle],
        category: "Navigation",
        url: page[:url],
        icon: page[:icon],
        badge: "GO"
      }
    end

    render json: { suggestions: suggestions.first(8), query: query, total: suggestions.size }
  end
end
