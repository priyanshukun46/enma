require "rqrcode"

class QrCodeService
  DEFAULT_FALLBACK_URL = "http://localhost:3000"

  class << self
    def public_url(request = nil)
      url = ENV["APP_URL"].presence || request&.base_url.presence || DEFAULT_FALLBACK_URL
      url.to_s.strip.chomp("/")
    end

    def generate_svg(target_url = nil, request: nil, module_size: 5, fill: "ffffff", color: "18120e")
      url = target_url.presence || public_url(request)
      qrcode = RQRCode::QRCode.new(url, level: :m)

      # RQRCode's as_svg prepends '#' if missing, so strip any leading '#' to avoid '##ffffff'
      clean_color = color.to_s.strip.sub(/\A#+/, "")
      clean_fill  = fill.to_s.strip.sub(/\A#+/, "")

      # Handle special SVG transparent fill
      is_transparent = clean_fill.casecmp("transparent").zero?
      clean_fill = "ffffff" if is_transparent

      svg_output = qrcode.as_svg(
        color: clean_color,
        fill: clean_fill,
        shape_rendering: "crispEdges",
        module_size: module_size,
        standalone: true,
        use_path: true
      )

      # Ensure responsive sizing
      svg_output = svg_output.sub(/<svg([^>]*)>/, '<svg\1 class="w-full h-full" viewBox="0 0 ' + (qrcode.modules.length * module_size).to_s + ' ' + (qrcode.modules.length * module_size).to_s + '">')

      # If transparent was requested, remove the background rect
      if is_transparent
        svg_output = svg_output.sub(/<rect[^>]*\/>/, "")
      end

      # Strip <?xml ...?> declaration for clean HTML inline injection
      svg_output.sub(/\A<\?xml[^>]*\?>/, "").strip
    rescue StandardError => e
      Rails.logger.error("[QrCodeService] Failed to generate QR Code for #{url}: #{e.message}")
      # Fallback inline placeholder SVG
      %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" class="w-full h-full text-slate-400"><rect width="100" height="100" fill="#ffffff" stroke="#e25438" stroke-width="2"/><text x="50" y="55" font-size="10" text-anchor="middle" fill="#18120e">QR Error</text></svg>)
    end
  end
end
