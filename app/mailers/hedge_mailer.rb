class HedgeMailer < ApplicationMailer
  def rebalance_alert(position, analysis_result)
    @position = position
    @analysis = analysis_result
    @user = position.user

    mail(
      to: @user.notification_email,
      subject: "[Delta Neutral] Rebalance needed: #{position.token0_symbol}/#{position.token1_symbol}"
    )
  end

  def rebalance_completed(rebalance_event)
    @event = rebalance_event
    @position = rebalance_event.position
    @user = @position.user

    subject = if @event.paper_trade?
      "[Delta Neutral] Paper trade completed: #{@position.token0_symbol}/#{@position.token1_symbol}"
    else
      "[Delta Neutral] Rebalance completed: #{@position.token0_symbol}/#{@position.token1_symbol}"
    end

    mail(
      to: @user.notification_email,
      subject: subject
    )
  end

  def rebalance_failed(rebalance_event)
    @event = rebalance_event
    @position = rebalance_event.position
    @user = @position.user

    mail(
      to: @user.notification_email,
      subject: "[Delta Neutral] Rebalance FAILED: #{@position.token0_symbol}/#{@position.token1_symbol}"
    )
  end
end
