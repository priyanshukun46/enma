require "test_helper"

class EmergencyTest < ActiveSupport::TestCase
  test "valid emergency saves successfully" do
    em = Emergency.new(
      title: "Flash Flood Alert",
      emergency_type: "Flood",
      severity: "High",
      latitude: 26.14,
      longitude: 91.73,
      status: "Active",
      affected_radius: 40.0
    )
    assert em.valid?
    assert em.save
  end

  test "validates required fields" do
    em = Emergency.new
    assert_not em.valid?
    assert_includes em.errors[:title], "can't be blank"
    assert_includes em.errors[:emergency_type], "can't be blank"
    assert_includes em.errors[:severity], "can't be blank"
    assert_includes em.errors[:latitude], "can't be blank"
    assert_includes em.errors[:longitude], "can't be blank"
    assert_includes em.errors[:status], "can't be blank"
  end

  test "status and severity helpers" do
    em = Emergency.new(severity: "Critical", status: "Active")
    assert em.active?
    assert_not em.resolved?
    assert_includes em.severity_badge_class, "text-red-800"

    em.status = "Resolved"
    assert em.resolved?
    assert_includes em.status_badge_class, "text-green-800"
  end
end
