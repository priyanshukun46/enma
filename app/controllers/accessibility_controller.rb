class AccessibilityController < ApplicationController
  before_action :set_location, only: [:show]

  def index
    @locations = Location.order(accessibility_score: :asc)
    @total_locations = @locations.count
    @highly_accessible_count = @locations.count { |l| l.accessibility_score.to_f >= 80.0 }
    @moderate_access_count = @locations.count { |l| l.accessibility_score.to_f >= 60.0 && l.accessibility_score.to_f < 80.0 }
    @difficult_access_count = @locations.count { |l| l.accessibility_score.to_f >= 40.0 && l.accessibility_score.to_f < 60.0 }
    @critical_zones_count = @locations.count { |l| l.accessibility_score.to_f < 40.0 }
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
