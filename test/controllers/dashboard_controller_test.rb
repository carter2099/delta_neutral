require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "should get index" do
    get root_path
    assert_response :success
    assert_select "h1", /Dashboard/i
  end

  test "redirects to login when not authenticated" do
    sign_out
    get root_path
    assert_redirected_to new_session_path
  end
end
