module QrCodeHelper
  def render_qr_svg(url = nil, module_size: 5, color: "currentColor", fill: "transparent")
    raw QrCodeService.generate_svg(
      url,
      request: (respond_to?(:request) ? request : nil),
      module_size: module_size,
      color: color,
      fill: fill
    )
  end

  def current_app_public_url
    QrCodeService.public_url(respond_to?(:request) ? request : nil)
  end
end
