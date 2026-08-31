require "rqrcode"

class QrCodeService
  DEFAULT_FALLBACK_URL = "http://localhost:3000"

  class << self
    def public_url(request = nil)
      url = ENV["APP_URL"].presence || request&.base_url.presence || DEFAULT_FALLBACK_URL
      url.to_s.strip.chomp("/")
    end

    def generate_svg(target_url = nil, request: nil, module_size: 5, fill: "transparent", color: "currentColor")
      url = target_url.presence || public_url(request)
      qrcode = RQRCode::QRCode.new(url, level: :m)

      svg_output = qrcode.as_svg(
        color: color,
        fill: fill,
        shape_rendering: "crispEdges",
        module_size: module_size,
        standalone: true,
        use_path: true
      )
      # Strip <?xml ...?> declaration for clean HTML inline injection
      svg_output.sub(/\A<\?xml[^>]*\?>/, "").strip
    rescue StandardError => e
      Rails.logger.error("[QrCodeService] Failed to generate QR Code for #{url}: #{e.message}")
      # Fallback inline placeholder SVG
      %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" class="w-full h-full text-slate-400"><rect width="100" height="100" fill="none" stroke="currentColor" stroke-width="2"/><text x="50" y="55" font-size="10" text-anchor="middle" fill="currentColor">QR Error</text></svg>)
    end
  end
end
