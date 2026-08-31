class EmergencyResponseService
  attr_reader :service

  def initialize(emergency)
    @service = EmergencyIntelligenceService.new(emergency)
  end

  def analyze
    @service.analyze
  end

  def calculate_haversine_distance(lat1, lon1, lat2, lon2)
    @service.calculate_haversine_distance(lat1, lon1, lat2, lon2)
  end
end
