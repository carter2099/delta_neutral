require "test_helper"

class RebalanceEventTest < ActiveSupport::TestCase
  setup do
    @event = rebalance_events(:completed_rebalance)
  end

  test "valid rebalance event" do
    assert @event.valid?
  end

  test "validates status inclusion" do
    @event.status = "invalid"
    refute @event.valid?

    %w[pending executing completed failed].each do |status|
      @event.status = status
      assert @event.valid?, "Expected #{status} to be valid"
    end
  end

  test "validates trigger_type inclusion" do
    @event.trigger_type = "invalid"
    refute @event.valid?

    %w[manual scheduled threshold].each do |trigger|
      @event.trigger_type = trigger
      assert @event.valid?, "Expected #{trigger} to be valid"
    end
  end

  test "duration calculates correctly" do
    assert @event.duration.positive?
  end

  test "duration returns nil if not completed" do
    @event.completed_at = nil
    assert_nil @event.duration
  end

  test "mark_executing! updates status and started_at" do
    event = rebalance_events(:failed_rebalance)
    event.update!(status: "pending", started_at: nil)

    event.mark_executing!

    assert_equal "executing", event.status
    assert_not_nil event.started_at
  end

  test "mark_completed! updates status and records" do
    event = rebalance_events(:failed_rebalance)
    event.update!(status: "executing")

    event.mark_completed!(
      executed_actions: [{ asset: "ETH", success: true }],
      post_state: { token0_amount: 10.0 }
    )

    assert_equal "completed", event.status
    assert_not_nil event.completed_at
    assert_equal [{ "asset" => "ETH", "success" => true }], event.executed_actions
    assert_equal({ "token0_amount" => 10.0 }, event.post_state)
  end

  test "mark_failed! updates status and error" do
    event = rebalance_events(:completed_rebalance)
    event.update!(status: "executing")

    event.mark_failed!("Test error")

    assert_equal "failed", event.status
    assert_equal "Test error", event.error_message
  end

  test "scopes work correctly" do
    assert_includes RebalanceEvent.completed, @event
    refute_includes RebalanceEvent.failed, @event
  end

  test "recent scope orders by created_at desc" do
    events = RebalanceEvent.recent.to_a
    assert events.each_cons(2).all? { |a, b| a.created_at >= b.created_at }
  end

  test "actions_summary for paper trade" do
    assert_includes @event.actions_summary, "Paper trade"
  end

  test "actions_summary for executed" do
    @event.paper_trade = false
    assert_includes @event.actions_summary, "Executed"
  end
end
