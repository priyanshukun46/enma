require "test_helper"

class IncidentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Field Officer Tawang",
      email_address: "officer_test@resqway.ai",
      password: "password123",
      role: :operator
    )

    @incident = Incident.create!(
      incident_type: "landslide",
      severity: "critical",
      status: "reported",
      description: "Severe rockfall blocking primary arterial road for emergency convoy.",
      latitude: 27.5855,
      longitude: 91.8679,
      location_name: "Sela Pass Detour",
      district: "Tawang",
      state: "Arunachal Pradesh",
      reported_at: Time.current,
      user: @user
    )
  end

  test "should get index" do
    get incidents_url
    assert_response :success
    assert_select "h1", /Field Incident Reports/
  end

  test "should get show" do
    get incident_url(@incident)
    assert_response :success
    assert_select "h1", /#{@incident.location_name}/
  end

  test "should redirect new when not authenticated" do
    get new_incident_url
    assert_redirected_to login_url
  end

  test "should get new when authenticated" do
    post login_url, params: { login: @user.email_address, password: "password123" }
    assert_response :redirect

    get new_incident_url
    assert_response :success
    assert_select "h1", /Report.*Incident/
    assert_select "form[action='#{incidents_path}']"
  end

  test "should create incident when authenticated" do
    post login_url, params: { login: @user.email_address, password: "password123" }

    assert_difference("Incident.count", 1) do
      post incidents_url, params: {
        incident: {
          incident_type: "flood",
          severity: "high",
          description: "Submerged bridge crossing preventing emergency vehicle passage.",
          latitude: 26.88,
          longitude: 88.47,
          location_name: "Teesta Bridge approach",
          state: "Sikkim"
        }
      }
    end

    created_incident = Incident.order(created_at: :desc).first
    assert_redirected_to incident_url(created_incident)
    assert_equal @user.id, created_incident.user_id
  end

  test "should return JSON list of incidents" do
    get incidents_url, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_operator json.size, :>=, 1
    assert_equal "landslide", json.first["incident_type"]
  end
end
