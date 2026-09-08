require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  test "GET /health returns 200 with healthy status and json checks" do
    get health_check_url
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal "healthy", json["status"]
    assert_equal "ENMA AI", json["app"]
    assert_equal "1.0.0", json["version"]
    assert_equal "connected", json["checks"]["database"]
    assert_equal "operational", json["checks"]["cache"]
  end
end
