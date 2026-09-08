# This file seeds the ENMA AI database with realistic North East India logistics,
# terrain factors, strategic warehouses, and active emergency records.

puts "Seeding North East India data for Phase 4..."

# --- Locations (North East India with Realistic Terrain & Logistics Factors) ---
locations_data = [
  # ASSAM
  {
    name: "Guwahati",
    location_type: "City",
    latitude: 26.1445,
    longitude: 91.7362,
    population: 1100000,
    district: "Kamrup Metropolitan",
    state: "Assam",
    road_quality: "excellent",
    rainfall_level: "low",
    landslide_risk: "low",
    transport_availability: "high",
    distance_to_hospital: 3.5,
    distance_to_warehouse: 8.0
  },
  {
    name: "Jorhat",
    location_type: "Town",
    latitude: 26.7576,
    longitude: 94.2048,
    population: 120000,
    district: "Jorhat",
    state: "Assam",
    road_quality: "good",
    rainfall_level: "moderate",
    landslide_risk: "low",
    transport_availability: "high",
    distance_to_hospital: 6.0,
    distance_to_warehouse: 24.0
  },
  {
    name: "Silchar",
    location_type: "City",
    latitude: 24.8210,
    longitude: 92.8020,
    population: 200000,
    district: "Cachar",
    state: "Assam",
    road_quality: "good",
    rainfall_level: "high",
    landslide_risk: "low",
    transport_availability: "medium",
    distance_to_hospital: 8.0,
    distance_to_warehouse: 28.0
  },
  {
    name: "Haflong",
    location_type: "Hill Station",
    latitude: 25.1764,
    longitude: 93.0177,
    population: 50000,
    district: "Dima Hasao",
    state: "Assam",
    road_quality: "poor",
    rainfall_level: "high",
    landslide_risk: "high",
    transport_availability: "low",
    distance_to_hospital: 45.0,
    distance_to_warehouse: 75.0
  },

  # ARUNACHAL PRADESH
  {
    name: "Itanagar",
    location_type: "Capital City",
    latitude: 27.1023,
    longitude: 93.6146,
    population: 60000,
    district: "Papum Pare",
    state: "Arunachal Pradesh",
    road_quality: "good",
    rainfall_level: "moderate",
    landslide_risk: "medium",
    transport_availability: "high",
    distance_to_hospital: 5.0,
    distance_to_warehouse: 12.0
  },
  {
    name: "Tawang",
    location_type: "Monastery Town",
    latitude: 27.5855,
    longitude: 91.8679,
    population: 15000,
    district: "Tawang",
    state: "Arunachal Pradesh",
    road_quality: "poor",
    rainfall_level: "high",
    landslide_risk: "critical",
    transport_availability: "low",
    distance_to_hospital: 68.0,
    distance_to_warehouse: 110.0
  },
  {
    name: "Bomdila",
    location_type: "Town",
    latitude: 27.2504,
    longitude: 92.4042,
    population: 10000,
    district: "West Kameng",
    state: "Arunachal Pradesh",
    road_quality: "moderate",
    rainfall_level: "high",
    landslide_risk: "medium",
    transport_availability: "medium",
    distance_to_hospital: 28.0,
    distance_to_warehouse: 48.0
  },

  # MEGHALAYA
  {
    name: "Shillong",
    location_type: "Capital City",
    latitude: 25.5788,
    longitude: 91.8933,
    population: 150000,
    district: "East Khasi Hills",
    state: "Meghalaya",
    road_quality: "good",
    rainfall_level: "moderate",
    landslide_risk: "low",
    transport_availability: "high",
    distance_to_hospital: 4.0,
    distance_to_warehouse: 7.5
  },
  {
    name: "Cherrapunjee",
    location_type: "Town",
    latitude: 25.2758,
    longitude: 91.7226,
    population: 10000,
    district: "East Khasi Hills",
    state: "Meghalaya",
    road_quality: "moderate",
    rainfall_level: "extreme",
    landslide_risk: "medium",
    transport_availability: "medium",
    distance_to_hospital: 22.0,
    distance_to_warehouse: 42.0
  },

  # MANIPUR
  {
    name: "Imphal",
    location_type: "Capital City",
    latitude: 24.8170,
    longitude: 93.9532,
    population: 270000,
    district: "Imphal West",
    state: "Manipur",
    road_quality: "good",
    rainfall_level: "moderate",
    landslide_risk: "low",
    transport_availability: "medium",
    distance_to_hospital: 5.5,
    distance_to_warehouse: 14.0
  },
  {
    name: "Ukhrul",
    location_type: "Town",
    latitude: 25.1275,
    longitude: 94.3725,
    population: 50000,
    district: "Ukhrul",
    state: "Manipur",
    road_quality: "poor",
    rainfall_level: "moderate",
    landslide_risk: "high",
    transport_availability: "medium",
    distance_to_hospital: 38.0,
    distance_to_warehouse: 58.0
  },

  # MIZORAM
  {
    name: "Aizawl",
    location_type: "Capital City",
    latitude: 23.7271,
    longitude: 92.7176,
    population: 300000,
    district: "Aizawl",
    state: "Mizoram",
    road_quality: "good",
    rainfall_level: "moderate",
    landslide_risk: "medium",
    transport_availability: "medium",
    distance_to_hospital: 7.0,
    distance_to_warehouse: 22.0
  },
  {
    name: "Lunglei",
    location_type: "Town",
    latitude: 22.8833,
    longitude: 92.7333,
    population: 60000,
    district: "Lunglei",
    state: "Mizoram",
    road_quality: "moderate",
    rainfall_level: "moderate",
    landslide_risk: "medium",
    transport_availability: "medium",
    distance_to_hospital: 18.0,
    distance_to_warehouse: 46.0
  },

  # NAGALAND
  {
    name: "Kohima",
    location_type: "Capital City",
    latitude: 25.6669,
    longitude: 94.1118,
    population: 100000,
    district: "Kohima",
    state: "Nagaland",
    road_quality: "good",
    rainfall_level: "moderate",
    landslide_risk: "medium",
    transport_availability: "medium",
    distance_to_hospital: 6.5,
    distance_to_warehouse: 26.0
  },
  {
    name: "Dimapur",
    location_type: "City",
    latitude: 25.9000,
    longitude: 93.7333,
    population: 380000,
    district: "Dimapur",
    state: "Nagaland",
    road_quality: "good",
    rainfall_level: "low",
    landslide_risk: "low",
    transport_availability: "high",
    distance_to_hospital: 4.5,
    distance_to_warehouse: 9.0
  },

  # TRIPURA
  {
    name: "Agartala",
    location_type: "Capital City",
    latitude: 23.8315,
    longitude: 91.2868,
    population: 400000,
    district: "West Tripura",
    state: "Tripura",
    road_quality: "good",
    rainfall_level: "low",
    landslide_risk: "low",
    transport_availability: "high",
    distance_to_hospital: 3.8,
    distance_to_warehouse: 7.0
  },
  {
    name: "Udaipur",
    location_type: "Town",
    latitude: 23.5333,
    longitude: 91.4833,
    population: 35000,
    district: "Gomati",
    state: "Tripura",
    road_quality: "good",
    rainfall_level: "moderate",
    landslide_risk: "low",
    transport_availability: "medium",
    distance_to_hospital: 11.0,
    distance_to_warehouse: 32.0
  },

  # SIKKIM
  {
    name: "Gangtok",
    location_type: "Capital City",
    latitude: 27.3389,
    longitude: 88.6065,
    population: 100000,
    district: "East Sikkim",
    state: "Sikkim",
    road_quality: "good",
    rainfall_level: "moderate",
    landslide_risk: "medium",
    transport_availability: "medium",
    distance_to_hospital: 6.0,
    distance_to_warehouse: 22.0
  },
  {
    name: "Pelling",
    location_type: "Tourist Town",
    latitude: 27.3197,
    longitude: 88.2393,
    population: 5000,
    district: "West Sikkim",
    state: "Sikkim",
    road_quality: "poor",
    rainfall_level: "high",
    landslide_risk: "high",
    transport_availability: "medium",
    distance_to_hospital: 34.0,
    distance_to_warehouse: 62.0
  },
  {
    name: "Lachung",
    location_type: "Village",
    latitude: 27.6833,
    longitude: 88.7500,
    population: 1000,
    district: "North Sikkim",
    state: "Sikkim",
    road_quality: "critical",
    rainfall_level: "high",
    landslide_risk: "critical",
    transport_availability: "low",
    distance_to_hospital: 78.0,
    distance_to_warehouse: 125.0
  }
]

locations_data.each do |data|
  location = Location.find_or_initialize_by(name: data[:name])
  location.assign_attributes(data)
  
  # Calculate accessibility score dynamically using AccessibilityScoreService
  score_data = AccessibilityScoreService.new(location).calculate
  location.accessibility_score = score_data[:score]
  location.save!
  
  puts "  ✓ [#{score_data[:category].upcase}] #{location.name} (#{location.state}): Score #{location.accessibility_score}/100"
end
puts "Configured #{Location.count} locations with accessibility intelligence scores."

# --- Warehouses (Strategically located with Resource Intelligence) ---
warehouses_data = [
  {
    name: "North East Regional Logistics Hub - Guwahati",
    latitude: 26.1800, longitude: 91.7500, capacity: 50000,
    district: "Kamrup Metropolitan", state: "Assam",
    utilized_capacity: 20000, operational_status: "OPERATIONAL",
    address: "NH-37 Logistics Corridor, Guwahati",
    contact_phone: "+91-361-2540001",
    resources_json: {
      "medical_kits" => 2500, "food_packages" => 8000,
      "water_units" => 15000, "emergency_shelters" => 400,
      "fuel_liters" => 12000, "rescue_equipment" => 180
    }.to_json
  },
  {
    name: "Arunachal Logistics Center - Itanagar",
    latitude: 27.1100, longitude: 93.6200, capacity: 20000,
    district: "Papum Pare", state: "Arunachal Pradesh",
    utilized_capacity: 14400, operational_status: "LIMITED",
    address: "Trans-Arunachal Highway Depot, Itanagar",
    contact_phone: "+91-360-2244001",
    resources_json: {
      "medical_kits" => 600, "food_packages" => 2000,
      "water_units" => 3500, "emergency_shelters" => 120,
      "fuel_liters" => 3000, "rescue_equipment" => 45
    }.to_json
  },
  {
    name: "Meghalaya Forward Relief Depot - Shillong",
    latitude: 25.5800, longitude: 91.8800, capacity: 25000,
    district: "East Khasi Hills", state: "Meghalaya",
    utilized_capacity: 23000, operational_status: "OVERLOADED",
    address: "Laitumkhrah Supply Depot, Shillong",
    contact_phone: "+91-364-2222001",
    resources_json: {
      "medical_kits" => 200, "food_packages" => 800,
      "water_units" => 1500, "emergency_shelters" => 40,
      "fuel_liters" => 1200, "rescue_equipment" => 15
    }.to_json
  },
  {
    name: "Manipur Relief Base - Imphal",
    latitude: 24.8200, longitude: 93.9600, capacity: 18000,
    district: "Imphal West", state: "Manipur",
    utilized_capacity: 8100, operational_status: "OPERATIONAL",
    address: "Imphal Valley Relief Base, NH-2",
    contact_phone: "+91-385-2450001",
    resources_json: {
      "medical_kits" => 1800, "food_packages" => 3500,
      "water_units" => 5000, "emergency_shelters" => 200,
      "fuel_liters" => 4000, "rescue_equipment" => 90
    }.to_json
  },
  {
    name: "Tripura Central Warehouse - Agartala",
    latitude: 23.8400, longitude: 91.2900, capacity: 30000,
    district: "West Tripura", state: "Tripura",
    utilized_capacity: 9000, operational_status: "OPERATIONAL",
    address: "National Highway 8, Agartala Logistics Park",
    contact_phone: "+91-381-2325001",
    resources_json: {
      "medical_kits" => 1200, "food_packages" => 6000,
      "water_units" => 10000, "emergency_shelters" => 350,
      "fuel_liters" => 8000, "rescue_equipment" => 60
    }.to_json
  }
]

all_seeded_locations = Location.all.to_a

warehouses_data.each do |data|
  wh = Warehouse.find_or_initialize_by(name: data[:name])
  wh.assign_attributes(data.except(:resources_json))
  wh.resources_json = data[:resources_json]

  # Link to closest seeded location using preloaded in-memory records
  closest_loc = all_seeded_locations.min_by { |l|
    dlat = (l.latitude - data[:latitude]).abs
    dlon = (l.longitude - data[:longitude]).abs
    dlat + dlon
  }
  wh.location = closest_loc if closest_loc

  wh.save!
  wh.update_readiness!
  puts "  ✓ [#{wh.dynamic_status}] #{wh.name}: Readiness #{wh.readiness_score}/100, Util #{wh.utilization_percentage}%"
end
puts "Configured #{Warehouse.count} warehouses with resource intelligence."

# --- Emergency Records (Phase 6) ---
emergencies_data = [
  {
    title: "Heavy Landslide Blocks NH-6 near Haflong",
    emergency_type: "Landslide",
    severity: "Critical",
    latitude: 25.1764,
    longitude: 93.0177,
    affected_radius: 50.0,
    status: "Active",
    simulated_at: 2.hours.ago,
    description: "Major slope failure on NH-6 has cut off Dima Hasao district arterial access. Heavy rock debris blocking multi-axle freight traffic."
  },
  {
    title: "Massive Flash Flood & Inundation in Cachar Valley",
    emergency_type: "Flood",
    severity: "High",
    latitude: 24.8210,
    longitude: 92.8020,
    affected_radius: 40.0,
    status: "Responding",
    simulated_at: 5.hours.ago,
    description: "Barak river overflow submerging low-elevation transport arteries and isolation of riverside rural settlements."
  },
  {
    title: "Heavy Rainfall Alert for East Khasi Hills",
    emergency_type: "Heavy Rainfall",
    severity: "Medium",
    latitude: 25.5000,
    longitude: 91.8000,
    affected_radius: 35.0,
    status: "Monitoring",
    simulated_at: 12.hours.ago,
    description: "Meteorological warning for torrential cloudburst. Potential flash flood and road drainage overflow in Shillong-Cherrapunjee corridor."
  },
  {
    title: "Road Blockage to Tawang Due to Snowfall & Sela Mudslide",
    emergency_type: "Road Blockage",
    severity: "Critical",
    latitude: 27.5855,
    longitude: 91.8679,
    affected_radius: 60.0,
    status: "Active",
    simulated_at: 1.hour.ago,
    description: "Heavy snow accumulation and sub-zero mudslide blocking high-altitude Sela Pass access to Tawang monastery community."
  },
  {
    title: "Minor Landslide Cleared Near Ukhrul Border",
    emergency_type: "Landslide",
    severity: "Low",
    latitude: 25.1000,
    longitude: 94.3000,
    affected_radius: 20.0,
    status: "Resolved",
    simulated_at: 1.day.ago,
    description: "Debris cleared by local Border Roads Organisation teams; two-way commercial traffic restored."
  }
]

emergencies_data.each do |data|
  emergency = Emergency.find_or_initialize_by(title: data[:title])
  emergency.assign_attributes(data)
  emergency.save!
end
puts "Configured #{Emergency.count} emergencies."

# --- Logistics Route Analysis Seeds (Phase 5) ---
puts "Seeding sample route calculations for Phase 5..."
sample_missions = [
  { orig: "Guwahati", dest: "Tawang", vehicle: "Ambulance" },
  { orig: "Guwahati", dest: "Shillong", vehicle: "Truck" },
  { orig: "Itanagar", dest: "Bomdila", vehicle: "Supply Vehicle" }
]

sample_missions.each do |mission|
  orig_loc = Location.find_by(name: mission[:orig])
  dest_loc = Location.find_by(name: mission[:dest])
  next unless orig_loc && dest_loc

  service = RouteOptimizationService.new(origin: orig_loc, destination: dest_loc, vehicle_type: mission[:vehicle])
  result = service.calculate

  result[:routes].each do |type_key, rdata|
    LogisticsRoute.create!(
      origin: orig_loc,
      destination: dest_loc,
      vehicle_type: mission[:vehicle],
      distance: rdata[:distance_km],
      estimated_time: rdata[:estimated_hours],
      risk_score: rdata[:risk_score],
      route_type: type_key.to_s,
      status: "analyzed",
      recommended: rdata[:is_recommended] || false,
      waypoints_json: rdata[:waypoints].to_json,
      summary: rdata[:description]
    )
  end
end
puts "Configured #{LogisticsRoute.count} initial logistics routes."

# --- User Accounts (Authentication & Roles) ---
puts "Seeding default authentication accounts for ENMA AI..."
if Rails.env.production? && (ENV["ADMIN_PASSWORD"].blank? || ENV["OPERATOR_PASSWORD"].blank?)
  abort("FATAL: In production, ADMIN_PASSWORD and OPERATOR_PASSWORD environment variables MUST be set before running seeds.")
end

admin_email = ENV["ADMIN_EMAIL"].presence || "admin@enma.ai"
admin_pass  = ENV["ADMIN_PASSWORD"].presence || "password123"
operator_email = ENV["OPERATOR_EMAIL"].presence || "operator@enma.ai"
operator_pass  = ENV["OPERATOR_PASSWORD"].presence || "password123"

admin_user = User.find_or_initialize_by(email_address: admin_email.downcase)
admin_user.name = "Priyanshu Kumar (Administrator)"
admin_user.username = "admin"
admin_user.password = admin_pass
admin_user.password_confirmation = admin_pass
admin_user.role = :admin
admin_user.save!

operator_user = User.find_or_initialize_by(email_address: operator_email.downcase)
operator_user.name = "Field Logistics Officer"
operator_user.username = "operator"
operator_user.password = operator_pass
operator_user.password_confirmation = operator_pass
operator_user.role = :operator
operator_user.save!

puts "Configured #{User.count} users (Admin: #{admin_email}, Operator: #{operator_email})."

# =============================================================================
# --- GIS Road Network Intelligence Seeds ---
# =============================================================================
puts "Seeding North East India Road Accessibility Intelligence Network..."

roads_data = [
  {
    name: "East-West Strategic Arterial (Guwahati – Nagaon – Kaziranga – Jorhat)",
    road_number: "NH-27",
    district: "Kamrup / Nagaon",
    state: "Assam",
    status: "accessible",
    risk_score: 18.0,
    length_km: 305.0,
    reason: "Pavement condition optimal. Minor monsoon surface moisture, bridges fully structural.",
    last_updated_at: 15.minutes.ago,
    coordinates: [
      [26.1445, 91.7362],
      [26.1920, 92.1520],
      [26.3450, 92.6840],
      [26.5820, 93.1700],
      [26.7509, 94.2037]
    ]
  },
  {
    name: "Trans-Arunachal Mountain Highway (Itanagar – Ziro – Daporijo)",
    road_number: "NH-13",
    district: "Papum Pare / Lower Subansiri",
    state: "Arunachal Pradesh",
    status: "moderate_risk",
    risk_score: 58.0,
    length_km: 198.0,
    reason: "Heavy rainfall causing minor mudslides and gravel washout along unpaved curves.",
    last_updated_at: 25.minutes.ago,
    coordinates: [
      [27.0844, 93.6053],
      [27.3500, 93.7200],
      [27.5600, 93.8300],
      [27.9800, 94.2200]
    ]
  },
  {
    name: "Sela Pass High-Altitude Corridor (Tawang – Sela – Bomdila)",
    road_number: "NH-229",
    district: "Tawang / West Kameng",
    state: "Arunachal Pradesh",
    status: "blocked",
    risk_score: 92.0,
    length_km: 172.0,
    reason: "Severe rockfall & slope failure at Sela Pass detour. Heavy transit impassable.",
    last_updated_at: 8.minutes.ago,
    coordinates: [
      [27.5855, 91.8679],
      [27.5020, 92.1000],
      [27.3800, 92.2500],
      [27.2645, 92.4200]
    ]
  },
  {
    name: "Guwahati – Shillong Expressway Corridor",
    road_number: "NH-06",
    district: "Ri-Bhoi / East Khasi Hills",
    state: "Meghalaya",
    status: "moderate_risk",
    risk_score: 45.0,
    length_km: 99.0,
    reason: "Persistent heavy mist, low visibility & wet pavement in high plateau section.",
    last_updated_at: 40.minutes.ago,
    coordinates: [
      [26.1445, 91.7362],
      [25.9000, 91.8000],
      [25.7200, 91.8500],
      [25.5788, 91.8933]
    ]
  },
  {
    name: "Shillong – Cherrapunjee Highland Ridge Route",
    road_number: "SH-05",
    district: "East Khasi Hills",
    state: "Meghalaya",
    status: "high_risk",
    risk_score: 78.0,
    length_km: 54.0,
    reason: "Extreme rainfall saturation (190 mm/24h), road shoulder erosion near gorge bends.",
    last_updated_at: 12.minutes.ago,
    coordinates: [
      [25.5788, 91.8933],
      [25.4500, 91.8200],
      [25.3500, 91.7600],
      [25.2758, 91.7226]
    ]
  },
  {
    name: "Kohima – Kangpokpi – Imphal Valley Lifeline",
    road_number: "NH-02",
    district: "Kohima / Senapati / Imphal West",
    state: "Manipur",
    status: "moderate_risk",
    risk_score: 52.0,
    length_km: 138.0,
    reason: "Waterlogging in valley sectors, continuous monitoring of slope stabilization works.",
    last_updated_at: 30.minutes.ago,
    coordinates: [
      [25.6751, 94.1086],
      [25.3800, 94.0100],
      [25.1000, 93.9600],
      [24.8170, 93.9368]
    ]
  },
  {
    name: "Imphal – Pallel – Moreh Border Corridor",
    road_number: "NH-102",
    district: "Tengnoupal / Chandel",
    state: "Manipur",
    status: "accessible",
    risk_score: 28.0,
    length_km: 110.0,
    reason: "Highway fully clear and fortified. Normal commercial and relief vehicle speeds.",
    last_updated_at: 50.minutes.ago,
    coordinates: [
      [24.8170, 93.9368],
      [24.5200, 94.0200],
      [24.3100, 94.1800],
      [24.2400, 94.3000]
    ]
  },
  {
    name: "Dimapur – Kohima Mountain Highway",
    road_number: "NH-29",
    district: "Dimapur / Kohima",
    state: "Nagaland",
    status: "moderate_risk",
    risk_score: 55.0,
    length_km: 74.0,
    reason: "Subsidence near Dzüdza river bridge. One-way convoy flow operational.",
    last_updated_at: 18.minutes.ago,
    coordinates: [
      [25.9060, 93.7270],
      [25.8000, 93.8800],
      [25.7200, 94.0200],
      [25.6751, 94.1086]
    ]
  },
  {
    name: "Aizawl – Lunglei Ridge Highway",
    road_number: "NH-54",
    district: "Aizawl / Serchhip / Lunglei",
    state: "Mizoram",
    status: "high_risk",
    risk_score: 74.0,
    length_km: 165.0,
    reason: "Multiple debris slides cleared to single lane. Extreme slope incline hazards.",
    last_updated_at: 14.minutes.ago,
    coordinates: [
      [23.7271, 92.7176],
      [23.4000, 92.7800],
      [23.1000, 92.8100],
      [22.8800, 92.7300]
    ]
  },
  {
    name: "Churaibari – Agartala Central Lifeline",
    road_number: "NH-08",
    district: "North Tripura / West Tripura",
    state: "Tripura",
    status: "accessible",
    risk_score: 16.0,
    length_km: 185.0,
    reason: "Four-lane highway operating smoothly. Drainage systems fully functional.",
    last_updated_at: 1.hour.ago,
    coordinates: [
      [24.4500, 92.2400],
      [24.1800, 91.9500],
      [23.9500, 91.6200],
      [23.8315, 91.2868]
    ]
  },
  {
    name: "Sevoke – Teesta – Gangtok Mountain Lifeline",
    road_number: "NH-10",
    district: "Kalimpong / East Sikkim",
    state: "Sikkim",
    status: "blocked",
    risk_score: 94.0,
    length_km: 114.0,
    reason: "Teesta river flooding breached foundation wall at 29th Mile. Traffic suspended.",
    last_updated_at: 5.minutes.ago,
    coordinates: [
      [26.8800, 88.4700],
      [27.0500, 88.4800],
      [27.2000, 88.5200],
      [27.3314, 88.6138]
    ]
  },
  {
    name: "Silchar – Haflong Hill Railway-Road Corridor",
    road_number: "NH-27S",
    district: "Cachar / Dima Hasao",
    state: "Assam",
    status: "high_risk",
    risk_score: 82.0,
    length_km: 102.0,
    reason: "Barail range flash runoff. Heavy vehicles restricted due to culvert damage.",
    last_updated_at: 20.minutes.ago,
    coordinates: [
      [24.8333, 92.7789],
      [25.0200, 92.8600],
      [25.1800, 93.0200]
    ]
  }
]

roads_data.each do |r_attrs|
  coords = r_attrs.delete(:coordinates)
  road = Road.find_or_initialize_by(road_number: r_attrs[:road_number], state: r_attrs[:state])
  road.assign_attributes(r_attrs)
  road.geometry_coordinates = coords
  road.save!
  puts "  ✓ [#{road.status.upcase}] #{road.road_number} • #{road.name} (#{road.state}): Risk #{road.risk_score}/100"
end

puts "Configured #{Road.count} monitored road corridors in GIS intelligence database."

# =============================================================================
# --- Field Incident Reports Seeds (Geo-tagged Observations) ---
# =============================================================================
puts "Seeding Field Incident Reports..."
operator_user = User.find_by(role: :operator) || User.first

incidents_data = [
  {
    incident_type: "landslide",
    severity: "critical",
    status: "verified",
    location_name: "Sela Pass Detour Junction, Tawang",
    district: "Tawang",
    state: "Arunachal Pradesh",
    latitude: 27.5855,
    longitude: 91.8679,
    reported_at: 15.minutes.ago,
    description: "Major rockfall debris and mudslide blocking both inbound and outbound highway lanes at Sela Pass curve. Over 40 vehicles stalled. NDRF clearing detachment required.",
    user: operator_user
  },
  {
    incident_type: "flood",
    severity: "high",
    status: "verified",
    location_name: "Teesta Embankment 29th Mile",
    district: "Kalimpong",
    state: "Sikkim",
    latitude: 27.0500,
    longitude: 88.4800,
    reported_at: 45.minutes.ago,
    description: "River water overtopping asphalt by 1.2 meters. Retaining foundation breached. Complete vehicle ban enforced until hydro-level subsides.",
    user: operator_user
  },
  {
    incident_type: "road_damage",
    severity: "medium",
    status: "reported",
    location_name: "Dzüdza River Bridge Approach",
    district: "Kohima",
    state: "Nagaland",
    latitude: 25.6751,
    longitude: 94.1086,
    reported_at: 2.hours.ago,
    description: "Substantial pavement subsidence on west abutment approach. Heavy trucks halted, light utility vehicles passing cautiously in single file.",
    user: operator_user
  },
  {
    incident_type: "weather_disruption",
    severity: "medium",
    status: "verified",
    location_name: "Cherrapunjee High Plateau Ridge",
    district: "East Khasi Hills",
    state: "Meghalaya",
    latitude: 25.2758,
    longitude: 91.7226,
    reported_at: 3.hours.ago,
    description: "Extremely dense cloud cover and torrential rainfall limiting forward optical visibility to under 10 meters. Emergency convoy speeds capped at 20 km/h.",
    user: operator_user
  },
  {
    incident_type: "traffic_blockage",
    severity: "low",
    status: "resolved",
    location_name: "Guwahati Bypass Toll Plaza",
    district: "Kamrup Metropolitan",
    state: "Assam",
    latitude: 26.1445,
    longitude: 91.7362,
    reported_at: 5.hours.ago,
    description: "Breakdown of heavy timber carrier cleared by mobile crane. Logistics corridors returned to nominal flow velocity.",
    user: operator_user
  }
]

incidents_data.each do |inc_attrs|
  inc = Incident.find_or_initialize_by(location_name: inc_attrs[:location_name], incident_type: inc_attrs[:incident_type])
  inc.assign_attributes(inc_attrs)
  inc.save!
  puts "  ✓ [#{inc.severity.upcase}] #{inc.type_emoji} #{inc.type_label} @ #{inc.location_name}: Status #{inc.status.upcase}"
end

puts "Configured #{Incident.count} field incident reports."

# =============================================================================
# --- Run ENMA Hybrid Road Risk Intelligence Engine over All Corridors ---
# =============================================================================
puts "\nExecuting ENMA Hybrid Road Risk Intelligence Engine..."
Road.find_each do |road|
  res = road.recalculate_risk!(trigger_source: "initial_assessment")
  puts "  ⚡ [#{res[:risk_level].upcase}] #{road.road_number} • #{road.name} (#{road.state}): Score #{res[:risk_score]}/100 (W:#{res[:factors][:weather]} H:#{res[:factors][:historical]} I:#{res[:factors][:incidents]} C:#{res[:factors][:condition]} G:#{res[:factors][:geographic]})"
end

puts "Configured #{RoadRiskAssessment.count} road risk intelligence assessments."

# =============================================================================
# --- Fleet Vehicles & Active Supply Chain Shipments ---
# =============================================================================
puts "\nSeeding Fleet Vehicles and Active Logistics Deliveries..."
vehicles_seed = [
  { registration_number: "AS-01-EE-4589", vehicle_type: "Truck", status: "in_transit", capacity: 8000.0, current_latitude: 25.8800, current_longitude: 91.8200, current_speed: 44.0, current_heading: 140.0, driver_name: "Rahul Boro", driver_phone: "+91 98640 11223" },
  { registration_number: "ML-05-AM-9012", vehicle_type: "Ambulance", status: "in_transit", capacity: 1500.0, current_latitude: 25.6800, current_longitude: 91.8700, current_speed: 58.0, current_heading: 160.0, driver_name: "Tenzing Syiem", driver_phone: "+91 94361 44556" },
  { registration_number: "AS-03-TR-7821", vehicle_type: "Supply Vehicle", status: "available", capacity: 6000.0, current_latitude: 26.1445, current_longitude: 91.7362, current_speed: 0.0, current_heading: 0.0, driver_name: "Anupam Das", driver_phone: "+91 98540 88990" },
  { registration_number: "AR-01-ER-3411", vehicle_type: "Emergency Vehicle", status: "delayed", capacity: 4500.0, current_latitude: 27.2000, current_longitude: 93.6000, current_speed: 22.0, current_heading: 75.0, driver_name: "Kipa Taba", driver_phone: "+91 94022 77112" }
]

vehicles_seed.each do |v_attrs|
  v = Vehicle.find_or_initialize_by(registration_number: v_attrs[:registration_number])
  v.assign_attributes(v_attrs)
  v.save!
  puts "  🚚 Vehicle #{v.registration_number} (#{v.vehicle_type}): Status #{v.status.upcase}"
end

# Seed active shipments
guwahati = Location.find_by(name: "Guwahati") || Location.first
shillong = Location.find_by(name: "Shillong") || Location.second
itanagar = Location.find_by(name: "Itanagar") || Location.third

v1 = Vehicle.find_by(registration_number: "AS-01-EE-4589")
if v1 && guwahati && shillong
  sh1 = Shipment.find_or_initialize_by(tracking_number: "ENMA-TRK-2026-MED01")
  sh1.assign_attributes(
    vehicle: v1,
    cargo_type: "medicine",
    priority: "critical",
    origin: guwahati,
    origin_name: guwahati.name,
    origin_latitude: guwahati.latitude,
    origin_longitude: guwahati.longitude,
    destination: shillong,
    destination_name: shillong.name,
    destination_latitude: shillong.latitude,
    destination_longitude: shillong.longitude,
    status: "in_transit",
    planned_route_geometry_json: [
      [26.1445, 91.7362], [26.0500, 91.7600], [25.9600, 91.7900],
      [25.8800, 91.8200], [25.7900, 91.8500], [25.7000, 91.8700],
      [25.6300, 91.8850], [25.5788, 91.8933]
    ],
    progress_percentage: 62.0,
    distance_traveled_km: 62.0,
    total_distance_km: 100.0,
    provider_planned_eta: Time.current + 45.minutes,
    current_estimated_eta: Time.current + 50.minutes,
    enma_adjusted_eta: Time.current + 55.minutes,
    delay_minutes: 10,
    current_corridor_risk: 28.0,
    ml_disruption_probability: 0.18
  )
  sh1.save!

  # Seed location history
  VehicleLocation.find_or_create_by!(vehicle: v1, recorded_at: 10.minutes.ago) do |l|
    l.shipment = sh1
    l.latitude = 25.9600
    l.longitude = 91.7900
    l.speed = 46.0
    l.source = "simulation"
  end
  VehicleLocation.find_or_create_by!(vehicle: v1, recorded_at: 2.minutes.ago) do |l|
    l.shipment = sh1
    l.latitude = 25.8800
    l.longitude = 91.8200
    l.speed = 44.0
    l.source = "simulation"
  end
  puts "  📦 Shipment #{sh1.tracking_number} (Medicines): #{sh1.origin_name} -> #{sh1.destination_name} (62% completed)"
end

puts "Seeding complete for ENMA AI Logistics Telemetry & GPS Fleet Tracking."




