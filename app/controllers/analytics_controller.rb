class AnalyticsController < ApplicationController
  def index
    load_analytics_data
  end

  def report
    load_analytics_data
    render :report, layout: "application"
  end

  private

  def load_analytics_data
    @time_range = params[:time_range].presence || "all"

    @locations = Location.all
    @warehouses = Warehouse.all

    @emergencies = case @time_range
                   when "7d"  then Emergency.where("created_at >= ?", 7.days.ago)
                   when "30d" then Emergency.where("created_at >= ?", 30.days.ago)
                   else Emergency.all
                   end

    # 1. Executive Logistics Readiness Service
    @readiness_service = LogisticsReadinessService.new(
      locations: @locations,
      warehouses: @warehouses,
      emergencies: @emergencies
    )
    @readiness = @readiness_service.calculate

    # 2. Dynamic Rule-Based AI Insights Service
    @insight_service = AnalyticsInsightService.new(
      locations: @locations,
      warehouses: @warehouses,
      emergencies: @emergencies,
      readiness_data: @readiness
    )
    @insights = @insight_service.generate_insights

    # 3. Executive Metrics
    @readiness_score = @readiness[:score]
    @readiness_category = @readiness[:category]
    @high_risk_zones_count = @locations.count { |l| l.accessibility_score.to_f < 60.0 }
    @active_emergencies_count = @emergencies.count { |e| %w[Active open Responding].include?(e.status) }
    @total_communities_count = @locations.size

    # 4. Risk Distribution
    total_locs = [@locations.size, 1].max.to_f
    critical_risk = @locations.count { |l| l.accessibility_score.to_f < 40.0 }
    high_risk = @locations.count { |l| l.accessibility_score.to_f >= 40.0 && l.accessibility_score.to_f < 60.0 }
    moderate_risk = @locations.count { |l| l.accessibility_score.to_f >= 60.0 && l.accessibility_score.to_f < 80.0 }
    low_risk = @locations.count { |l| l.accessibility_score.to_f >= 80.0 }

    @risk_distribution = {
      critical: { count: critical_risk, percentage: (critical_risk / total_locs * 100).round(1) },
      high: { count: high_risk, percentage: (high_risk / total_locs * 100).round(1) },
      moderate: { count: moderate_risk, percentage: (moderate_risk / total_locs * 100).round(1) },
      low: { count: low_risk, percentage: (low_risk / total_locs * 100).round(1) }
    }

    # 5. Accessibility Analytics
    highly_acc = @locations.count { |l| l.accessibility_score.to_f >= 80.0 }
    mod_acc = @locations.count { |l| l.accessibility_score.to_f >= 60.0 && l.accessibility_score.to_f < 80.0 }
    diff_acc = @locations.count { |l| l.accessibility_score.to_f >= 40.0 && l.accessibility_score.to_f < 60.0 }
    crit_acc = @locations.count { |l| l.accessibility_score.to_f < 40.0 }

    @accessibility_distribution = {
      highly_accessible: { count: highly_acc, percentage: (highly_acc / total_locs * 100).round(1) },
      moderately_accessible: { count: mod_acc, percentage: (mod_acc / total_locs * 100).round(1) },
      difficult_access: { count: diff_acc, percentage: (diff_acc / total_locs * 100).round(1) },
      critical_accessibility: { count: crit_acc, percentage: (crit_acc / total_locs * 100).round(1) }
    }

    @avg_accessibility = (@locations.sum { |l| l.accessibility_score.to_f } / total_locs).round(1)
    @lowest_acc_location = @locations.min_by { |l| l.accessibility_score.to_f }
    @highest_acc_location = @locations.max_by { |l| l.accessibility_score.to_f }

    # 6. Disaster Intelligence
    @total_emergencies_count = @emergencies.size
    @resolved_emergencies_count = @emergencies.count { |e| e.status == "Resolved" }
    @critical_severity_count = @emergencies.count { |e| e.severity.to_s.downcase == "critical" }
    @emergency_types_breakdown = @emergencies.group_by(&:emergency_type).transform_values(&:size)

    # 7. Critical Intelligence Watchlist (Top 5 Vulnerable Nodes)
    @watchlist_locations = @locations.sort_by { |l| l.accessibility_score.to_f }.first(5).map do |loc|
      risk_score = (100.0 - loc.accessibility_score.to_f).round(1)
      status_text = if risk_score >= 75.0
                      "CRITICAL RISK"
                    elsif risk_score >= 50.0
                      "HIGH RISK"
                    elsif risk_score >= 25.0
                      "MODERATE"
                    else
                      "LOW RISK"
                    end

      status_badge = if risk_score >= 75.0
                       "bg-red-100 text-red-800 border-red-300"
                     elsif risk_score >= 50.0
                       "bg-orange-100 text-orange-800 border-orange-300"
                     elsif risk_score >= 25.0
                       "bg-yellow-100 text-yellow-800 border-yellow-300"
                     else
                       "bg-green-100 text-green-800 border-green-300"
                     end

      {
        location: loc,
        id: loc.id,
        name: loc.name,
        state: loc.state,
        district: loc.district,
        risk_score: risk_score,
        accessibility_score: loc.accessibility_score.to_f,
        primary_threat: loc.primary_risk_factor || (loc.landslide_risk.to_s.downcase == "critical" ? "Landslide & Mudflow" : "Road Blockage"),
        status_text: status_text,
        status_badge: status_badge
      }
    end

    # 8. Regional State Comparison
    grouped_by_state = @locations.group_by(&:state)
    @state_comparison = grouped_by_state.map do |state, locs|
      avg_acc = (locs.sum { |l| l.accessibility_score.to_f } / locs.size.to_f).round(1)
      avg_rsk = (100.0 - avg_acc).round(1)
      active_em = @emergencies.count do |e|
        %w[Active open Responding].include?(e.status) && (
          e.location&.state == state ||
          locs.any? { |l| (l.latitude - e.latitude).abs < 0.5 && (l.longitude - e.longitude).abs < 0.5 }
        )
      end

      {
        state: state,
        location_count: locs.size,
        avg_accessibility: avg_acc,
        avg_risk: avg_rsk,
        active_emergencies: active_em
      }
    end.sort_by { |s| -s[:avg_risk] }

    # 9. Map Data Serialization
    @map_locations = @locations.map do |loc|
      {
        id: loc.id,
        name: loc.name,
        state: loc.state,
        district: loc.district,
        latitude: loc.latitude,
        longitude: loc.longitude,
        accessibility_score: loc.accessibility_score.to_f,
        risk_score: (100.0 - loc.accessibility_score.to_f).round(1),
        accessibility_category: loc.accessibility_category,
        primary_risk_factor: loc.primary_risk_factor
      }
    end

    @map_warehouses = @warehouses.map do |wh|
      {
        id: wh.id,
        name: wh.name,
        latitude: wh.latitude,
        longitude: wh.longitude,
        capacity: wh.capacity
      }
    end

    @map_emergencies = @emergencies.map do |em|
      {
        id: em.id,
        title: em.title,
        emergency_type: em.emergency_type,
        severity: em.severity,
        latitude: em.latitude,
        longitude: em.longitude,
        status: em.status,
        affected_radius: em.affected_radius || 50.0
      }
    end
  end
end
