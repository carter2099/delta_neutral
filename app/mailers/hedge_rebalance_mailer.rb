# Delivers hedge rebalance notification emails to position owners.
class HedgeRebalanceMailer < ApplicationMailer
  helper ApplicationHelper
  # Sends a notification email when a short position has been rebalanced.
  #
  # The subject includes the asset symbol and the old vs. new short sizes so
  # the user can identify the event at a glance in their inbox. When the new
  # short size is zero, the rebalance was triggered by an empty pool (the
  # position exited range on that side) and no replacement short was opened.
  #
  # @param short_rebalance [ShortRebalance] the rebalance event to report
  # @return [Mail::Message]
  def rebalance_notification(short_rebalance)
    @rebalance = short_rebalance
    @hedge = short_rebalance.hedge
    @position = @hedge.position

    mail(
      to: @position.user.email_address,
      subject: "Hedge Rebalanced: #{@rebalance.asset} (#{@rebalance.old_short_size} -> #{@rebalance.new_short_size})"
    )
  end
end
