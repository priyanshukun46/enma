# frozen_string_literal: true

require "test_helper"

class IntelligenceControllerTest < ActionDispatch::IntegrationTest
  setup do
    LogisticsAlert.delete_all
    Road.delete_all
    Warehouse.delete_all
    Location.delete_all

    @guwahati = Location.create!(
      name: "Guwahati",
      state: "Assam",
      district: "Kamrup",
      location_type: "City",
      population: 1_000_000,
      latitude: 26.1445,
      longitude: 91.7362,
      road_quality: "excellent",
      rainfall_level: "low",
      landslide_risk: "low",
      transport_availability: "high"
    )

    @shillong = Location.create!(
      name: "Shillong",
      state: "Meghalaya",
      district: "East Khasi Hills",
      location_type: "Capital City",
      population: 150_000,
      latitude: 25.5788,
      longitude: 91.8933,
      road_quality: "good",
      rainfall_level: "moderate",
      landslide_risk: "low",
      transport_availability: "high"
    )

    @road = Road.create!(
      name: "Guwahati – Shillong Highway",
      road_number: "NH-06",
      state: "Meghalaya",
      status: "accessible",
      risk_score: 35.0,
      ml_disruption_probability: 0.30,
      length_km: 100.0,
      geometry_coordinates: [
        [26.1445, 91.7362],
        [25.5788, 91.8933]
      ]
    )

    @warehouse = Warehouse.create!(
      name: "Guwahati Central Depot",
      location: @guwahati,
      operational_status: "OPERATIONAL",
      capacity: 2000,
      utilized_capacity: 800,
      latitude: 26.1445,
      longitude: 91.7362
    )
  end

  test "GET /intelligence/predictions renders HTML dashboard successfully" do
    get intelligence_predictions_url
    assert_response :success
    assert_includes response.body, "Predictive Cascading Impact Intelligence"
    assert_includes response.body, "Threat Prioritization Matrix"
    assert_includes response.body, "5-Stage Cascading Propagation Chain"
    assert_includes response.body, "Counterfactual Decision Engine"
  end

  test "GET /intelligence/predictions with custom horizon param succeeds" do
    get intelligence_predictions_url(horizon: 24)
    assert_response :success
    assert_includes response.body, "24h Horizon"
  end

  test "GET /intelligence/predictions.json returns structured API payload" do
    get intelligence_predictions_url(format: :json)
    assert_response :success
    assert_equal "application/json", response.media_type

    json = JSON.parse(response.body)
    assert json.key?("overall_cascade_risk")
    assert json.key?("risk_level")
    assert json.key?("threatened_roads")
    assert json.key?("scenarios")
    assert json.key?("recommendations")
    assert json.key?("watchlist")
    assert json.key?("cascade_stages")
    assert json.key?("failure_dependency_graph")
    assert json.key?("projected_impact")
  end

  test "empty network renders safely without error" do
    Road.delete_all
    Location.delete_all

    get intelligence_predictions_url
    assert_response :success
    assert_includes response.body, "Predictive Cascading Impact Intelligence"
  end

  test "GET /intelligence/response renders HTML decision dashboard successfully" do
    get intelligence_response_url
    assert_response :success
    assert_includes response.body, "Autonomous Response Optimization Engine"
    assert_includes response.body, "AWAITING HUMAN COMMAND APPROVAL"
    assert_includes response.body, "AI RECOMMENDATION"
    assert_includes response.body, "Strategy Comparison"
    assert_includes response.body, "Operational Dispatch Timeline"
  end

  test "GET /intelligence/response with custom horizon param succeeds" do
    get intelligence_response_url(horizon: 24)
    assert_response :success
    assert_includes response.body, "Horizon:"
    assert_includes response.body, "24h"
  end

  test "GET /intelligence/response.json returns structured API payload" do
    get intelligence_response_url(format: :json)
    assert_response :success
    assert_equal "application/json", response.media_type

    json = JSON.parse(response.body)
    assert_equal "COMPLETE", json["status"]
    assert_equal "AWAITING_HUMAN_COMMAND_APPROVAL", json["human_approval_status"]
    assert json.key?("overall_response_urgency")
    assert json.key?("priority_zones")
    assert json.key?("warehouse_capabilities")
    assert json.key?("optimal_strategy")
    assert json.key?("alternative_strategies")
    assert json.key?("contingency_plans")
    assert json.key?("counterfactual_analysis")
    assert json.key?("decision_explanation")
    assert json.key?("operational_timeline")
  end

  test "POST /intelligence/feedback records commander decision successfully" do
    post intelligence_feedback_url, params: {
      recommendation_id: "REC-12345",
      decision: "approved",
      commander_feedback: "Authorized immediate dispatch of medical convoy",
      modifications: ["Add 2 escort vehicles"]
    }
    assert_redirected_to intelligence_response_url
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Human Command Decision [APPROVED]"
  end

  test "POST /intelligence/feedback.json returns structured acknowledgement" do
    post intelligence_feedback_url(format: :json), params: {
      recommendation_id: "REC-9999",
      decision: "modified",
      commander_feedback: "Reroute through secondary bypass depot",
      modifications: ["Activate Kohima secondary"]
    }
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "SUCCESS", json["status"]
    assert_equal "modified", json.dig("feedback", "decision")
    assert_equal "REC-9999", json.dig("feedback", "recommendation_id")
  end

  # =========================================================================
  # UNIFIED EMERGENCY COMMAND & CLOSED-LOOP TESTS
  # =========================================================================
  test "GET /intelligence/command renders HTML command center dashboard successfully" do
    get intelligence_command_url
    assert_response :success
    assert_includes response.body, "Unified Emergency Command"
    assert_includes response.body, "AWAITING HUMAN COMMAND APPROVAL"
    assert_includes response.body, "AI RECOMMENDATION — NOT AUTONOMOUS EXECUTION"
    assert_includes response.body, "Commander Attention Required"
    assert_includes response.body, "Plan Drift Monitor"
    assert_includes response.body, "Plan Assumptions"
    assert_includes response.body, "Explainable Decision Trace"
    assert_includes response.body, "Scenario Stress-Test Comparison"
  end

  test "GET /intelligence/command with custom horizon param succeeds" do
    get intelligence_command_url(horizon: 24)
    assert_response :success
    assert_includes response.body, "Horizon:"
    assert_includes response.body, "horizon=24"
    assert_includes response.body, "24h"
  end

  test "GET /intelligence/command.json returns structured command intelligence API payload" do
    get intelligence_command_url(format: :json)
    assert_response :success
    assert_equal "application/json", response.media_type

    json = JSON.parse(response.body)
    assert_equal "ACTIVE", json["status"]
    assert json.key?("command_state")
    assert_equal true, json.dig("command_state", "human_control_required")
    assert_equal false, json.dig("command_state", "autonomous_execution")
    assert json.key?("situation_snapshot")
    assert json.key?("operational_picture")
    assert json.key?("commander_attention")
    assert json.key?("data_reliability")
    assert json.key?("uncertainty_analysis")
    assert json.key?("commitment_level")
    assert json.key?("plan_assumptions")
    assert json.key?("assumption_health_score")
    assert json.key?("verification_recommendations")
    assert json.key?("no_action_baseline")
    assert json.key?("decision_trace")
    assert json.key?("scenario_comparison")
    assert json.key?("plan_drift")
    assert json.key?("plan_validity")
    assert json.key?("reoptimization")
    assert json.key?("closed_loop_status")
    assert json.key?("recommended_next_action")
    assert json.key?("explainability")
  end

  test "POST /intelligence/command/approve records commander approval and redirects" do
    post intelligence_command_approve_url, params: {
      recommendation_id: "REC-CMD-101",
      notes: "Commander authorized split dispatch plan",
      scenario_fingerprint: "FP-TEST-APPROVE"
    }
    assert_redirected_to intelligence_command_url
    follow_redirect!
    assert_response :success
    assert_includes response.body, "COMMAND DECISION RECORDED [APPROVED]"

    alert = LogisticsAlert.find_by(alert_type: "commander_feedback_recorded")
    assert_not_nil alert
    assert_includes alert.title, "APPROVED"
    assert_equal "APPROVED", alert.metadata_json["decision"]
  end

  test "POST /intelligence/command/modify records commander modification and redirects" do
    post intelligence_command_modify_url, params: {
      recommendation_id: "REC-CMD-102",
      notes: "Modify route: Hold secondary convoy at Kohima until road verified",
      modifications: ["Hold convoy at Kohima", "Dispatch UAV to verify NH-02"]
    }
    assert_redirected_to intelligence_command_url
    follow_redirect!
    assert_response :success
    assert_includes response.body, "COMMAND DECISION RECORDED [MODIFIED]"

    alert = LogisticsAlert.find_by(alert_type: "commander_feedback_recorded")
    assert_not_nil alert
    assert_includes alert.title, "MODIFIED"
  end

  test "POST /intelligence/command/reject records commander rejection and redirects" do
    post intelligence_command_reject_url, params: {
      recommendation_id: "REC-CMD-103",
      notes: "Reject plan due to impending localized flash flood"
    }
    assert_redirected_to intelligence_command_url
    follow_redirect!
    assert_response :success
    assert_includes response.body, "COMMAND DECISION RECORDED [REJECTED]"

    alert = LogisticsAlert.find_by(alert_type: "commander_feedback_recorded")
    assert_not_nil alert
    assert_includes alert.title, "REJECTED"
  end

  test "POST /intelligence/command/approve.json returns structured acknowledgement" do
    post intelligence_command_approve_url(format: :json), params: {
      recommendation_id: "REC-CMD-JSON-01",
      notes: "API approval authorization"
    }
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "SUCCESS", json["status"]
    assert_equal "APPROVED", json["decision"]
    assert_equal true, json["human_control_required"]
    assert_equal false, json["autonomous_execution"]
    assert_equal "REC-CMD-JSON-01", json.dig("record", "recommendation_id")
  end
end

