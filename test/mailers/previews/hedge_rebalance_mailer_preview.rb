class HedgeRebalanceMailerPreview < ActionMailer::Preview
  def rebalance_notification
    rebalance = ShortRebalance.first || ShortRebalance.new(
      hedge: Hedge.first,
      asset: "WETH",
      old_short_size: 0.7,
      new_short_size: 0.75,
      realized_pnl: 25.0,
      rebalanced_at: Time.current
    )

    HedgeRebalanceMailer.rebalance_notification(rebalance)
  end
end
