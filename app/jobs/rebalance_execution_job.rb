class RebalanceExecutionJob < ApplicationJob
  queue_as :critical

  def perform(position_id, trigger_type = "manual")
    position = Position.find(position_id)
    user = position.user

    # Check circuit breaker
    circuit_breaker = Hedging::CircuitBreaker.new(cache_key: "hedging:circuit:#{user.id}")
    if circuit_breaker.open?
      Rails.logger.warn "[RebalanceExecutionJob] Circuit breaker open for user #{user.id}"
      return
    end

    # Calculate adjustments
    calculator = Hedging::Calculator.new
    adjustments = calculator.calculate_adjustments(position)

    # Create rebalance event
    event = position.rebalance_events.create!(
      trigger_type: trigger_type,
      paper_trade: user.paper_trading?,
      pre_state: build_pre_state(position),
      intended_actions: adjustments
    )

    begin
      event.mark_executing!

      # Validate adjustments
      client = Hyperliquid::ClientWrapper.new(testnet: user.testnet?)
      prices = fetch_prices(client, adjustments)

      validator = Hedging::SafetyValidator.new
      validator.validate_adjustments!(adjustments, prices: prices)

      # Execute or simulate
      executor = Hyperliquid::OrderExecutor.new(
        client: client,
        paper_trading: user.paper_trading?
      )

      circuit_breaker.call do
        result = executor.execute_adjustments(adjustments)

        if result[:success]
          # Record realized PnL for any positions being adjusted/closed
          record_realized_pnl(position, event, adjustments, prices)

          # Re-sync hedge positions after execution
          HedgeSyncJob.perform_now(position_id) unless user.paper_trading?

          event.mark_completed!(
            executed_actions: result[:results],
            post_state: build_post_state(position.reload)
          )

          # Send success notification
          HedgeMailer.rebalance_completed(event).deliver_later if user.notification_email.present?

          Rails.logger.info "[RebalanceExecutionJob] Rebalance completed for position #{position_id}"
        else
          raise "Execution failed: #{result[:results].select { |r| !r[:success] }.map { |r| r[:error] }.join(', ')}"
        end
      end
    rescue Hedging::CircuitBreaker::CircuitOpen => e
      event.mark_failed!(e.message)
      Rails.logger.error "[RebalanceExecutionJob] Circuit breaker prevented execution: #{e.message}"
    rescue Hedging::SafetyValidator::ValidationError => e
      event.mark_failed!("Validation failed: #{e.message}")
      Rails.logger.error "[RebalanceExecutionJob] Validation failed: #{e.message}"
    rescue => e
      event.mark_failed!(e.message)
      Rails.logger.error "[RebalanceExecutionJob] Rebalance failed for position #{position_id}: #{e.message}"

      # Notify on failure
      HedgeMailer.rebalance_failed(event).deliver_later if user.notification_email.present?

      raise
    end
  end

  private

  def build_pre_state(position)
    {
      token0_amount: position.token0_amount&.to_f,
      token1_amount: position.token1_amount&.to_f,
      hedge_positions: position.hedge_positions.map do |hp|
        { asset: hp.asset, size: hp.size&.to_f, entry_price: hp.entry_price&.to_f }
      end
    }
  end

  def build_post_state(position)
    {
      token0_amount: position.token0_amount&.to_f,
      token1_amount: position.token1_amount&.to_f,
      hedge_positions: position.hedge_positions.map do |hp|
        { asset: hp.asset, size: hp.size&.to_f, entry_price: hp.entry_price&.to_f }
      end
    }
  end

  def fetch_prices(client, adjustments)
    prices = {}
    adjustments.each do |adj|
      prices[adj[:asset]] ||= client.market_price(adj[:asset])
    rescue
      prices[adj[:asset]] = 0
    end
    prices
  end

  def record_realized_pnl(position, event, adjustments, prices)
    adjustments.each do |adj|
      hedge = position.hedge_positions.find_by(asset: adj[:asset])
      next unless hedge && hedge.entry_price && adj[:current_size] != 0

      # Only record PnL if we're reducing or closing a position
      current_size = adj[:current_size]
      target_size = adj[:target_size]
      next if current_size.abs <= target_size.abs && current_size.sign == target_size.sign

      size_closed = current_size - target_size
      exit_price = prices[adj[:asset]] || hedge.current_price

      next unless exit_price && hedge.entry_price

      # Calculate realized PnL
      # For shorts: profit = (entry - exit) * size_closed
      if size_closed.negative?  # Closing short
        pnl = (hedge.entry_price - exit_price) * size_closed.abs
      else  # Closing long (shouldn't happen in this app but for completeness)
        pnl = (exit_price - hedge.entry_price) * size_closed.abs
      end

      position.realized_pnls.create!(
        rebalance_event: event,
        asset: adj[:asset],
        size_closed: size_closed,
        entry_price: hedge.entry_price,
        exit_price: exit_price,
        realized_pnl: pnl
      )
    end
  end
end
