module Hedging
  # Calculates target hedge positions and required adjustments for a Uniswap V3
  # LP position based on its current token holdings and hedge configuration.
  #
  # Target hedge sizes are negative (short) and scaled by the configured
  # +hedge_ratio+. Tokens mapped to +nil+ in the configuration (e.g., stablecoins)
  # are not hedged. When both LP tokens map to the same HL symbol, their targets
  # are combined.
  #
  # @example
  #   calculator = Hedging::Calculator.new
  #   targets = calculator.calculate_targets(position)
  #   #=> { "ETH" => { asset: "ETH", target_size: -10.5, ... } }
  #
  #   adjustments = calculator.calculate_adjustments(position)
  #   #=> [{ asset: "ETH", current_size: -8.0, target_size: -10.5, delta: -2.5, ... }]
  class Calculator
    # Calculate target hedge positions for each hedgeable token in the position.
    #
    # @param position [Position] a position with an associated {HedgeConfiguration}
    # @return [Hash{String => Hash}] targets keyed by HL asset symbol, each with
    #   +:asset+, +:target_size+, +:source_token+, +:source_amount+
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

    # Compare current hedge positions against targets and return required adjustments.
    #
    # Includes adjustments for positions that should be closed (no longer in targets).
    #
    # @param position [Position] a position with hedge_positions and hedge_configuration
    # @return [Array<Hash>] adjustments with keys +:asset+, +:current_size+,
    #   +:target_size+, +:delta+, +:source_token+, +:source_amount+
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

    # Calculate the total USD notional value of target hedges at given prices.
    #
    # @param position [Position] a position with an associated {HedgeConfiguration}
    # @param prices [Hash{String => Numeric}] current prices keyed by HL asset symbol
    # @return [Numeric] total notional value in USD
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
