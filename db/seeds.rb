# This file seeds the AccessAI database with realistic North East India logistics,
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

# --- Warehouses (Strategically located across North East India) ---
warehouses_data = [
  { name: "North East Regional Hub - Guwahati", latitude: 26.1800, longitude: 91.7500, capacity: 50000 },
  { name: "Arunachal Logistics Center - Itanagar", latitude: 27.1100, longitude: 93.6200, capacity: 20000 },
  { name: "Meghalaya Distribution Point - Shillong", latitude: 25.5800, longitude: 91.8800, capacity: 25000 },
  { name: "Manipur Relief Base - Imphal", latitude: 24.8200, longitude: 93.9600, capacity: 18000 },
  { name: "Tripura Central Warehouse - Agartala", latitude: 23.8400, longitude: 91.2900, capacity: 30000 }
]

warehouses_data.each do |data|
  Warehouse.find_or_create_by!(name: data[:name]) do |warehouse|
    warehouse.assign_attributes(data)
  end
end
puts "Configured #{Warehouse.count} warehouses."

# --- Emergency Records ---
emergencies_data = [
  { title: "Heavy Landslide Blocks NH-6", emergency_type: "Landslide", severity: "Critical", latitude: 25.1764, longitude: 93.0177, status: "Active" },
  { title: "Massive Flood in Dhemaji District", emergency_type: "Flood", severity: "High", latitude: 27.4800, longitude: 94.5800, status: "Active" },
  { title: "Heavy Rainfall Warning for East Khasi Hills", emergency_type: "Heavy Rainfall", severity: "Medium", latitude: 25.5000, longitude: 91.8000, status: "Monitoring" },
  { title: "Road Blockage to Tawang Due to Snowfall", emergency_type: "Road Blockage", severity: "High", latitude: 27.5000, longitude: 91.8000, status: "Active" },
  { title: "Minor Landslide Near Ukhrul", emergency_type: "Landslide", severity: "Low", latitude: 25.1000, longitude: 94.3000, status: "Resolved" }
]

emergencies_data.each do |data|
  emergency = Emergency.find_or_initialize_by(title: data[:title])
  emergency.assign_attributes(data)
  emergency.save!
end
puts "Configured #{Emergency.count} emergencies."

puts "Seeding complete for Phase 4."
