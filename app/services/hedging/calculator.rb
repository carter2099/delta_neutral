module Hedging
  class Calculator
    # Calculate target hedge positions for a position
    def calculate_targets(position)
      config = position.hedge_configuration
      return {} unless config

      targets = {}

      # Calculate target for token0
      if config.should_hedge?(position.token0_symbol)
        hl_symbol = config.mapping_for(position.token0_symbol)
        target_size = -(position.token0_amount || 0) * config.hedge_ratio
        targets[hl_symbol] = {
          asset: hl_symbol,
          target_size: target_size.to_f,
          source_token: position.token0_symbol,
          source_amount: position.token0_amount&.to_f || 0
        }
      end

      # Calculate target for token1
      if config.should_hedge?(position.token1_symbol)
        hl_symbol = config.mapping_for(position.token1_symbol)

        # If same HL symbol as token0, combine the targets
        if targets[hl_symbol]
          targets[hl_symbol][:target_size] += -(position.token1_amount || 0) * config.hedge_ratio
          targets[hl_symbol][:source_token] = "#{targets[hl_symbol][:source_token]}, #{position.token1_symbol}"
          targets[hl_symbol][:source_amount] += position.token1_amount&.to_f || 0
        else
          target_size = -(position.token1_amount || 0) * config.hedge_ratio
          targets[hl_symbol] = {
            asset: hl_symbol,
            target_size: target_size.to_f,
            source_token: position.token1_symbol,
            source_amount: position.token1_amount&.to_f || 0
          }
        end
      end

      targets
    end

    # Compare current hedge positions with targets and return required adjustments
    def calculate_adjustments(position)
      targets = calculate_targets(position)
      current_hedges = position.hedge_positions.index_by(&:asset)
      adjustments = []

      targets.each do |asset, target|
        current = current_hedges[asset]
        current_size = current&.size&.to_f || 0

        adjustments << {
          asset: asset,
          current_size: current_size,
          target_size: target[:target_size],
          delta: target[:target_size] - current_size,
          source_token: target[:source_token],
          source_amount: target[:source_amount]
        }
      end

      # Check for positions that should be closed (no longer in targets)
      current_hedges.each do |asset, hedge|
        next if targets.key?(asset)

        adjustments << {
          asset: asset,
          current_size: hedge.size.to_f,
          target_size: 0,
          delta: -hedge.size.to_f,
          action: :close
        }
      end

      adjustments
    end

    # Calculate total notional value of target hedges at current prices
    def calculate_notional_value(position, prices)
      targets = calculate_targets(position)
      total = 0

      targets.each do |asset, target|
        price = prices[asset] || 0
        total += target[:target_size].abs * price
      end

      total
    end
  end
end
