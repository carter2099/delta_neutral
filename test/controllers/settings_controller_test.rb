require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "should get edit" do
    get edit_settings_path
    assert_response :success
  end

  test "should get edit without existing setting" do
    settings(:one).destroy
    get edit_settings_path
    assert_response :success
  end

  test "should update setting" do
    patch settings_path, params: { setting: { hyperliquid_leverage: 5, hyperliquid_cross_margin: false } }
    assert_redirected_to edit_settings_path

    setting = users(:one).setting.reload
    assert_equal 5, setting.hyperliquid_leverage
    assert_equal false, setting.hyperliquid_cross_margin
  end

  test "should create setting if none exists" do
    settings(:one).destroy

    assert_difference "Setting.count", 1 do
      patch settings_path, params: { setting: { hyperliquid_leverage: 10, hyperliquid_cross_margin: true } }
    end
    assert_redirected_to edit_settings_path

    setting = users(:one).reload.setting
    assert_equal 10, setting.hyperliquid_leverage
    assert_equal true, setting.hyperliquid_cross_margin
  end

  test "should reject invalid leverage" do
    patch settings_path, params: { setting: { hyperliquid_leverage: 0 } }
    assert_response :unprocessable_entity
  end
end
