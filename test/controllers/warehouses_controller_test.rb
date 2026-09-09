require "test_helper"

class WarehousesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @warehouse = warehouses(:one) if respond_to?(:warehouses)
    @warehouse ||= Warehouse.first || Warehouse.create!(
      name: "Guwahati Strategic Depot",
      latitude: 26.1445,
      longitude: 91.7362,
      capacity: 10000,
      utilized_capacity: 4000,
      operational_status: "OPERATIONAL"
    )
    @user = users(:one) if respond_to?(:users)
    @user ||= User.first || User.create!(
      name: "Admin User",
      email_address: "admin_test@resqway.ai",
      username: "admintest",
      password: "password123",
      password_confirmation: "password123",
      role: :admin
    )
  end

  test "GET /warehouses responds with success" do
    sign_in @user if respond_to?(:sign_in)
    get warehouses_url
    assert_response :success
    assert_select "h1", text: /Warehouse Intelligence/
  end

  test "GET /warehouses/:id responds with success" do
    sign_in @user if respond_to?(:sign_in)
    get warehouse_url(@warehouse)
    assert_response :success
    assert_select "h1", text: /#{@warehouse.name}/
  end
end
