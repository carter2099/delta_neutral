# Manages per-user Hyperliquid trading settings (leverage and margin mode).
class SettingsController < ApplicationController
  # GET /settings/edit
  def edit
    @setting = Current.user.setting || Current.user.build_setting
  end

  # PATCH /settings
  def update
    @setting = Current.user.setting || Current.user.build_setting

    if @setting.update(setting_params)
      redirect_to edit_settings_path, notice: "Settings saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def setting_params
    params.require(:setting).permit(:hyperliquid_leverage, :hyperliquid_cross_margin)
  end
end
