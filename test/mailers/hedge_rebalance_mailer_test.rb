require "test_helper"

class HedgeRebalanceMailerTest < ActionMailer::TestCase
  test "rebalance_notification" do
    rebalance = short_rebalances(:one)

    email = HedgeRebalanceMailer.rebalance_notification(rebalance)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "one@example.com" ], email.to
    assert_match "Hedge Rebalanced: WETH", email.subject
    assert_match "WETH", email.body.encoded
    assert_match "0.70000000", email.body.encoded
    assert_match "0.75000000", email.body.encoded
  end
end
