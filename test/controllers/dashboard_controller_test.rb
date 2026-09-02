require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Dashboard Test User",
      email_address: "dash_test@enma.ai",
      password: "password123",
      role: :operator
    )
  end

  test "unauthenticated user is redirected from dashboard to login" do
    get dashboard_url
    assert_redirected_to login_url
  end

  test "authenticated user gets dashboard with intelligence overview" do
    post login_url, params: { login: @user.email_address, password: "password123" }
    get dashboard_url
    assert_response :success
    assert_select "h2", /Overview/
    assert_select "h3", /Predictive Risk Heatmap/
  end

  test "root url shows landing page for unauthenticated user" do
    get root_url
    assert_response :success
  end

  test "root url redirects to dashboard for authenticated user" do
    post login_url, params: { login: @user.email_address, password: "password123" }
    get root_url
    assert_redirected_to dashboard_url
  end

  test "should handle POST to root without routing error" do
    post root_url
    assert_response :success
  end

  test "authenticated user gets dashboard with roads and ML prediction card rendered" do
    Road.create!(
      name: "NH-13 Trans-Arunachal Highway",
      road_number: "NH-13",
      state: "Arunachal Pradesh",
      district: "Tawang",
      status: "accessible",
      risk_score: 85.0,
      risk_level: "high"
    )
    post login_url, params: { login: @user.email_address, password: "password123" }
    get dashboard_url
    assert_response :success
    assert_select "span", text: /NH-13/
    assert_select "span", text: /ML Disruption/
  end
end
