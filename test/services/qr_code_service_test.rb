require "test_helper"

class QrCodeServiceTest < ActiveSupport::TestCase
  setup do
    @original_app_url = ENV["APP_URL"]
  end

  teardown do
    ENV["APP_URL"] = @original_app_url
  end

  test "public_url uses ENV['APP_URL'] when present" do
    ENV["APP_URL"] = "https://enma.ai"
    assert_equal "https://enma.ai", QrCodeService.public_url

    ENV["APP_URL"] = "https://enma.ai/"
    assert_equal "https://enma.ai", QrCodeService.public_url
  end

  test "public_url falls back to request base_url when ENV['APP_URL'] is absent" do
    ENV["APP_URL"] = nil
    mock_request = Struct.new(:base_url).new("https://demo.enma.ai")
    assert_equal "https://demo.enma.ai", QrCodeService.public_url(mock_request)
  end

  test "public_url falls back to localhost:3000 when no request and no env var" do
    ENV["APP_URL"] = nil
    assert_equal "http://localhost:3000", QrCodeService.public_url(nil)
  end

  test "generate_svg returns valid SVG XML string" do
    svg = QrCodeService.generate_svg("https://enma.ai")
    assert svg.present?
    assert svg.include?("<svg")
    assert svg.include?("</svg>")
  end

  test "generate_svg handles custom module size and colors" do
    svg = QrCodeService.generate_svg("https://enma.ai", module_size: 7, color: "#1e293b", fill: "#ffffff")
    assert svg.present?
    assert svg.include?("#1e293b")
  end

  test "generate_svg gracefully recovers from invalid arguments" do
    svg = QrCodeService.generate_svg(nil)
    assert svg.present?
    assert svg.include?("<svg")
  end
end
