class AnalyticsInsightService
  attr_reader :locations, :warehouses, :emergencies, :readiness_data

  def initialize(locations: nil, warehouses: nil, emergencies: nil, readiness_data: nil)
    @locations = locations || Location.all
    @warehouses = warehouses || Warehouse.all
    @emergencies = emergencies || Emergency.all
    @readiness_data = readiness_data || LogisticsReadinessService.new(locations: @locations, warehouses: @warehouses, emergencies: @emergencies).calculate
  end

  def generate_insights
    insights = []

    # 1. Critical Vulnerability Insight
    critical_locs = locations.select { |l| l.accessibility_score.to_f < 40.0 }
    if critical_locs.any?
      top_critical = critical_locs.min_by { |l| l.accessibility_score.to_f }
      insights << {
        type: "critical",
        badge: "CRITICAL VULNERABILITY",
        badge_class: "bg-red-100 text-red-800 border-red-300",
        icon: "fa-exclamation-triangle",
        icon_color: "text-red-600",
        title: "#{critical_locs.size} Communities Face Severe Access Constraints",
        detail: "#{top_critical.name} (#{top_critical.state}) and #{critical_locs.size - 1} other highland zones exhibit accessibility scores below 40/100 due to acute landslide susceptibility and long medical transit distances.",
        action: "View Critical Watchlist",
        action_anchor: "#critical-watchlist"
      }
    else
      insights << {
        type: "critical",
        badge: "VULNERABILITY WATCH",
        badge_class: "bg-yellow-100 text-yellow-800 border-yellow-300",
        icon: "fa-shield-alt",
        icon_color: "text-yellow-600",
        title: "All Communities Maintain Moderate Baseline Accessibility",
        detail: "No settlement is currently below the 40-point critical cutoff; continuous monitoring of seasonal road degradation active.",
        action: "View All Locations",
        action_anchor: "#critical-watchlist"
      }
    end

    # 2. Positive Trend / Strategic Logistics Asset
    total_capacity = warehouses.sum(:capacity)
    top_warehouse = warehouses.max_by { |w| w.capacity.to_i }
    insights << {
      type: "positive",
      badge: "LOGISTICS STRENGTH",
      badge_class: "bg-emerald-100 text-emerald-800 border-emerald-300",
      icon: "fa-warehouse",
      icon_color: "text-emerald-600",
      title: "Strategic Relief Buffer: #{total_capacity.to_fs(:delimited)} Units Available",
      detail: "#{top_warehouse&.name || 'Regional Hub'} anchors regional supply operations with high capacity and direct access to multi-lane national transit arteries.",
      action: "View Warehouses on Map",
      action_anchor: "#regional-map"
    }

    # 3. Emergency Alert
    active_emergencies = emergencies.select { |e| %w[Active open Responding].include?(e.status) }
    critical_emergencies = active_emergencies.select { |e| e.severity.to_s.downcase == "critical" }
    if critical_emergencies.any?
      top_em = critical_emergencies.first
      insights << {
        type: "alert",
        badge: "DISASTER ALERT",
        badge_class: "bg-red-100 text-red-800 border-red-300 animate-pulse",
        icon: "fa-radiation",
        icon_color: "text-red-600",
        title: "#{critical_emergencies.size} Critical Disaster Incidents Active",
        detail: "#{top_em.title} requires priority emergency response vehicle dispatch and automated supply detour corridor clearance.",
        action: "Open Response Center",
        action_anchor: "#disaster-intelligence"
      }
    elsif active_emergencies.any?
      insights << {
        type: "alert",
        badge: "INCIDENT WATCH",
        badge_class: "bg-amber-100 text-amber-800 border-amber-300",
        icon: "fa-bell",
        icon_color: "text-amber-600",
        title: "#{active_emergencies.size} Active Incidents Under Telemetry Tracking",
        detail: "Active weather warnings and road maintenance operations are being monitored across district command networks.",
        action: "Open Response Center",
        action_anchor: "#disaster-intelligence"
      }
    else
      insights << {
        type: "alert",
        badge: "CLEAR OPERATIONS",
        badge_class: "bg-green-100 text-green-800 border-green-300",
        icon: "fa-check-circle",
        icon_color: "text-green-600",
        title: "Zero Active Disaster Disruptions",
        detail: "All primary logistics corridors report nominal operational clearance and standard transit throughput.",
        action: "Explore Map",
        action_anchor: "#regional-map"
      }
    end

    # 4. Tactical Resource Pre-Positioning Directive
    insights << {
      type: "recommendation",
      badge: "AI DIRECTIVE",
      badge_class: "bg-indigo-100 text-indigo-800 border-indigo-300",
      icon: "fa-lightbulb",
      icon_color: "text-indigo-600",
      title: "Tactical Supply Pre-Positioning Directive",
      detail: readiness_data[:recommendation] || "Pre-position emergency rations and portable water filtration units in high-altitude zones ahead of seasonal monsoon forecasts.",
      action: "Review Readiness",
      action_anchor: "#logistics-readiness"
    }

    insights
  end
end
