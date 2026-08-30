require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  test "should get search page without query" do
    get search_url
    assert_response :success
    assert_select "h2", "Global Search"
  end

  test "should search for locations by name" do
    get search_url, params: { q: "Guwahati" }
    assert_response :success
    assert_select "div", text: /Guwahati/
  end
end
