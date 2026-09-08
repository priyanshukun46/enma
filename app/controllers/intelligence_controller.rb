# frozen_string_literal: true

class IntelligenceController < ApplicationController
  def predictions
    @horizon = params[:horizon].presence ? params[:horizon].to_i : 12
    @service = Enma::PredictiveCascadingImpactService.new
    @analysis = @service.analyze(forecast_hours: @horizon)

    @roads = Road.order(:road_number)
    @active_alerts = LogisticsAlert.where(
      alert_type: %w[predictive_cascading_failure cascading_risk_warning]
    ).active.recent.limit(10)

    respond_to do |format|
      format.html
      format.json { render json: @analysis }
    end
  end

  def response_plan
    @horizon = params[:horizon].presence ? params[:horizon].to_i : 12
    @service = Enma::AutonomousResponseOptimizationService.new
    @optimization = @service.analyze(forecast_hours: @horizon)

    @active_alerts = LogisticsAlert.where(
      alert_type: %w[autonomous_response_required prepositioning_recommended critical_response_delay]
    ).active.recent.limit(10)

    @last_feedback = session[:last_commander_feedback]

    respond_to do |format|
      format.html { render :response }
      format.json { render json: @optimization }
    end
  end

  def feedback
    decision = params[:decision].to_s.downcase.presence || "approved"
    recommendation_id = params[:recommendation_id].presence || "REC-GENERIC"
    feedback_text = params[:commander_feedback].to_s
    modifications = Array(params[:modifications])

    feedback_record = {
      recommendation_id: recommendation_id,
      decision: decision,
      modifications: modifications,
      commander_feedback: feedback_text,
      timestamp: Time.current
    }

    session[:last_commander_feedback] = feedback_record

    if defined?(LogisticsAlert)
      begin
        LogisticsAlert.create!(
          alert_type: "commander_feedback_recorded",
          severity: decision == "approved" ? "info" : "warning",
          title: "Commander Decision: #{decision.upcase} for #{recommendation_id}",
          message: "Commander decision recorded with feedback: #{feedback_text.presence || 'None provided'}",
          status: "acknowledged",
          metadata_json: feedback_record
        )
      rescue StandardError => e
        Rails.logger.warn("[IntelligenceController] Feedback alert creation failed: #{e.message}")
      end
    end

    respond_to do |format|
      format.html do
        flash[:notice] = "Human Command Decision [#{decision.upcase}] successfully logged for #{recommendation_id}."
        redirect_to intelligence_response_path(horizon: params[:horizon])
      end
      format.json do
        render json: { status: "SUCCESS", feedback: feedback_record }
      end
    end
  end

  def command_center
    @horizon = params[:horizon].presence ? params[:horizon].to_i : 12
    @previous_snapshot = session[:last_command_snapshot]
    @command_decision = session[:last_command_decision]
    @service = Enma::UnifiedEmergencyCommandService.new(
      previous_snapshot: @previous_snapshot,
      command_decision: @command_decision,
      session_store: session
    )
    @command = @service.analyze(forecast_hours: @horizon)

    # Persist current snapshot to session for continuous plan drift monitoring
    session[:last_command_snapshot] = @command[:situation_snapshot]

    @active_alerts = LogisticsAlert.where(
      alert_type: %w[command_plan_drift_detected autonomous_response_required predictive_cascading_failure]
    ).active.recent.limit(10) if defined?(LogisticsAlert)

    respond_to do |format|
      format.html { render :command }
      format.json { render json: @command }
    end
  end

  def command_approve
    process_command_decision("APPROVED")
  end

  def command_modify
    process_command_decision("MODIFIED")
  end

  def command_reject
    process_command_decision("REJECTED")
  end

  private

  def process_command_decision(decision_type)
    recommendation_id = params[:recommendation_id].presence || "REC-OPT-#{Time.current.to_i}"
    notes = params[:notes].presence || params[:commander_feedback].to_s
    modifications = Array(params[:modifications])
    scenario_fp = params[:scenario_fingerprint].presence || "FP-GENERIC"
    recommendation_fp = params[:recommendation_fingerprint].presence || "REC-FP-GENERIC"

    decision_record = {
      decision: decision_type,
      recommendation_id: recommendation_id,
      timestamp: Time.current,
      notes: notes,
      commander_feedback: notes,
      modifications: modifications,
      scenario_fingerprint: scenario_fp,
      recommendation_fingerprint: recommendation_fp,
      human_control_required: true,
      autonomous_execution: false
    }

    session[:last_command_decision] = decision_type
    session[:last_commander_feedback] = decision_record

    if defined?(LogisticsAlert)
      begin
        LogisticsAlert.create!(
          alert_type: "commander_feedback_recorded",
          severity: decision_type == "APPROVED" ? "info" : "warning",
          title: "Commander Decision: #{decision_type} for #{recommendation_id}",
          message: "COMMAND DECISION RECORDED: #{notes.presence || 'Confirmed by human commander'}. AI recommendations remain decision-support only. No real-world autonomous execution has occurred.",
          status: "acknowledged",
          metadata_json: decision_record
        )
      rescue StandardError => e
        Rails.logger.warn("[IntelligenceController] Command decision alert failed: #{e.message}")
      end
    end

    respond_to do |format|
      format.html do
        flash[:notice] = "COMMAND DECISION RECORDED [#{decision_type}]. AI recommendations remain decision-support only. No real-world autonomous execution has occurred."
        redirect_to intelligence_command_path(horizon: params[:horizon])
      end
      format.json do
        render json: {
          status: "SUCCESS",
          decision: decision_type,
          message: "COMMAND DECISION RECORDED. AI recommendations remain decision-support only. No real-world autonomous execution has occurred.",
          human_control_required: true,
          autonomous_execution: false,
          record: decision_record
        }
      end
    end
  end
end
