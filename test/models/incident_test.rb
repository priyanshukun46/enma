require "test_helper"

class IncidentTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      name: "Field Officer Tawang",
      email_address: "officer_tawang@enma.ai",
      password: "password123",
      role: :operator
    )

    @incident = Incident.new(
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

  test "valid incident saves successfully" do
    assert @incident.valid?
    assert @incident.save
  end

  test "validates required fields" do
    inc = Incident.new(incident_type: nil, severity: nil, status: nil)
    assert_not inc.valid?
    assert_includes inc.errors[:incident_type], "can't be blank"
    assert_includes inc.errors[:severity], "can't be blank"
    assert_includes inc.errors[:description], "can't be blank"
    assert_includes inc.errors[:latitude], "can't be blank"
    assert_includes inc.errors[:longitude], "can't be blank"
    assert_includes inc.errors[:reported_at], "can't be blank"
  end

  test "validates incident_type inclusion" do
    @incident.incident_type = "invalid_type"
    assert_not @incident.valid?
    assert_includes @incident.errors[:incident_type], "is not included in the list"
  end

  test "validates severity inclusion" do
    @incident.severity = "ultra_critical"
    assert_not @incident.valid?
    assert_includes @incident.errors[:severity], "is not included in the list"
  end

  test "validates status inclusion" do
    @incident.status = "unknown_status"
    assert_not @incident.valid?
    assert_includes @incident.errors[:status], "is not included in the list"
  end

  test "validates description length" do
    @incident.description = "short"
    assert_not @incident.valid?
    assert_includes @incident.errors[:description], "is too short (minimum is 10 characters)"
  end

  test "type helpers return correct metadata" do
    assert_equal "Landslide", @incident.type_label
    assert_equal "🪨", @incident.type_emoji
    assert_equal "fa-mountain", @incident.type_icon
  end

  test "as_map_json contains required GIS payload" do
    @incident.save!
    json = @incident.as_map_json
    assert_equal "landslide", json[:incident_type]
    assert_equal "critical", json[:severity]
    assert_equal 27.5855, json[:latitude]
    assert_equal 91.8679, json[:longitude]
    assert_equal "Field Officer Tawang", json[:reporter_name]
  end

  test "scopes filter correctly" do
    @incident.save!
    Incident.create!(
      incident_type: "flood",
      severity: "low",
      status: "resolved",
      description: "Minor water runoff subsided on valley route.",
      latitude: 26.1,
      longitude: 91.7,
      reported_at: Time.current
    )

    assert_includes Incident.by_type("landslide"), @incident
    assert_includes Incident.critical, @incident
    assert_equal 1, Incident.by_status("resolved").count
  end
end
