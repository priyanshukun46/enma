require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get landing page with new design" do
    get landing_url
    assert_response :success
    assert_select "h1", /Northeast Lifeline/
    assert_select "a[href=?]", sign_up_path
  end

  test "root url serves landing page for unauthenticated users" do
    get root_url
    assert_response :success
    assert_select "h1", /Northeast Lifeline/
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
    assert_select "h2", /About (ResQWay|ENMA AI)/
  end
end
