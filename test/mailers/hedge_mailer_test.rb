require "test_helper"

class HedgeMailerTest < ActionMailer::TestCase
  setup do
    @position = positions(:eth_usdc)
    @event = rebalance_events(:completed_rebalance)
    @analysis = Hedging::DeltaAnalyzer::Result.new(
      needs_rebalance: true,
      drift_percent: 0.15,
      adjustments: [{ asset: "ETH", current_size: -8.0, target_size: -10.0, delta: -2.0 }],
      reason: "Drift 15% exceeds threshold 5%"
    )
  end

  test "rebalance_alert" do
    email = HedgeMailer.rebalance_alert(@position, @analysis)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal ["one@example.com"], email.to
    assert_includes email.subject, "Rebalance needed"
    assert_includes email.subject, "WETH/USDC"

    # Check body parts (multipart email has both html and text)
    body_text = email.body.parts.map(&:body).map(&:to_s).join(" ")
    assert_includes body_text, "15"
  end

  test "rebalance_completed" do
    email = HedgeMailer.rebalance_completed(@event)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal ["one@example.com"], email.to
    assert_includes email.subject, "completed"

    body_text = email.body.parts.map(&:body).map(&:to_s).join(" ")
    assert_includes body_text, "WETH/USDC"
  end

  test "rebalance_completed_paper_trade" do
    @event.paper_trade = true

    email = HedgeMailer.rebalance_completed(@event)

    assert_includes email.subject, "Paper trade"
  end

  test "rebalance_failed" do
    failed_event = rebalance_events(:failed_rebalance)

    email = HedgeMailer.rebalance_failed(failed_event)

    assert_emails 1 do
      email.deliver_now
    end

    assert_includes email.subject, "FAILED"

    body_text = email.body.parts.map(&:body).map(&:to_s).join(" ")
    assert_includes body_text, "Connection timeout"
  end
end
