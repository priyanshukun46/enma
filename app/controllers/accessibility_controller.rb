class AccessibilityController < ApplicationController
  before_action :set_location, only: [:show]

  def index
    @total_locations = Location.count
    @highly_accessible_count = Location.where("accessibility_score >= ?", 80.0).count
    @moderate_access_count = Location.where("accessibility_score >= ? AND accessibility_score < ?", 60.0, 80.0).count
    @difficult_access_count = Location.where("accessibility_score >= ? AND accessibility_score < ?", 40.0, 60.0).count
    @critical_zones_count = Location.where("accessibility_score < ?", 40.0).count

    @pagy, @locations = pagy(Location.order(accessibility_score: :asc))
  end

  def show
    @analysis = @location.accessibility_analysis
    @recommendations = @location.recommendations
  end

  def recalculate
    recalculated_count = 0

    Location.find_each do |location|
      location.recalculate_accessibility_score!
      recalculated_count += 1
    end

    flash[:notice] = "Accessibility Intelligence Scores successfully recalculated for #{recalculated_count} locations."
    redirect_to accessibility_path
  end

  private

  def set_location
    @location = Location.find(params[:id])
  end
end
