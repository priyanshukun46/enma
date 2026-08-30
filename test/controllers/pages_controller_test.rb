require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get landing page" do
    get landing_url
    assert_response :success
    assert_select "h1", /Where Roads Don't/
    assert_select "a[href=?]", demo_path
  end

  test "should get demo page" do
    get demo_url
    assert_response :success
    assert_select "h2", /Guided Demo Scenario/
  end

  test "should get architecture page" do
    get architecture_url
    assert_response :success
    assert_select "h2", /System Architecture/
  end

  test "should get overview page" do
    get overview_url
    assert_response :success
    assert_select "h2", /2-Minute Judge Overview/
  end

  test "should get about page" do
    get about_url
    assert_response :success
    assert_select "h2", /About ENMA AI/
  end
end
