class HealthController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

  def show
    db_status = check_database
    cache_status = check_cache

    status = (db_status && cache_status) ? :ok : :service_unavailable

    render json: {
      status: (status == :ok ? "healthy" : "degraded"),
      app: "ENMA AI",
      version: "1.0.0",
      environment: Rails.env,
      timestamp: Time.current.iso8601,
      checks: {
        database: db_status ? "connected" : "error",
        cache: cache_status ? "operational" : "error"
      }
    }, status: status
  end

  private

  def check_database
    ActiveRecord::Base.connection.execute("SELECT 1")
    true
  rescue StandardError => e
    Rails.logger.error("[HealthController] Database check failed: #{e.message}")
    false
  end

  def check_cache
    test_key = "health_check_#{SecureRandom.hex(4)}"
    Rails.cache.write(test_key, "ok", expires_in: 10.seconds)
    val = Rails.cache.read(test_key)
    Rails.cache.delete(test_key)
    val == "ok"
  rescue StandardError => e
    Rails.logger.error("[HealthController] Cache check failed: #{e.message}")
    false
  end
end
