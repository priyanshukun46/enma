# Warm up Smart Routes default calculation in the background after Rails boots
Rails.application.config.after_initialize do
  # Avoid running in test environment, console, asset precompile, migrations, or rake tasks
  next if Rails.env.test? || defined?(Rails::Console) || File.basename($PROGRAM_NAME) == "rake" || ARGV.any? { |a| a.include?("db:") || a.include?("assets:") || a.include?("test") }

  Thread.new do
    sleep 1 # Allow Puma to start accepting connections first
    ActiveRecord::Base.connection_pool.with_connection do
      g = Location.find_by(name: "Guwahati")
      s = Location.find_by(name: "Shillong")
      if g && s
        begin
          Enma::RouteRecommendationService.new(
            origin: g,
            destination: s,
            priority_mode: "balanced",
            vehicle_type: "Truck",
            cargo_type: "General Supplies"
          ).recommend
          Rails.logger.info("[SmartRoutes] Triple-buffer background pre-warming complete for Guwahati -> Shillong.")
        rescue StandardError => e
          Rails.logger.warn("[SmartRoutes] Pre-warming deferred: #{e.message}")
        end
      end
    end
  end
end

