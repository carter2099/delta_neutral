require "test_helper"

class AuthFlowTest < ActionDispatch::IntegrationTest
  test "unauthenticated user is redirected to login" do
    get root_path
    assert_redirected_to new_session_path
  end

  test "user can sign in and access dashboard" do
    get new_session_path
    assert_response :success

    post session_path, params: { email_address: users(:one).email_address, password: "password" }
    assert_redirected_to root_path

    follow_redirect!
    assert_response :success
    assert_select "h1", /Dashboard/i
  end

  test "user can sign out" do
    sign_in_as(users(:one))

    delete session_path
    assert_redirected_to new_session_path

    get root_path
    assert_redirected_to new_session_path
  end
end
