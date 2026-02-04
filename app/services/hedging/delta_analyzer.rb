module Hedging
  class DeltaAnalyzer
    Result = Struct.new(:needs_rebalance, :drift_percent, :adjustments, :reason, keyword_init: true)

    def initialize(calculator: Calculator.new)
      @calculator = calculator
    end

    def analyze(position)
      config = position.hedge_configuration
      return no_rebalance_result("No hedge configuration") unless config

      adjustments = @calculator.calculate_adjustments(position)
      return no_rebalance_result("No adjustments calculated") if adjustments.empty?

      max_drift = calculate_max_drift(adjustments)
      threshold = config.rebalance_threshold

      if max_drift >= threshold
        Result.new(
          needs_rebalance: true,
          drift_percent: max_drift,
          adjustments: adjustments,
          reason: "Drift #{format_percent(max_drift)} exceeds threshold #{format_percent(threshold)}"
        )
      else
        Result.new(
          needs_rebalance: false,
          drift_percent: max_drift,
          adjustments: adjustments,
          reason: "Drift #{format_percent(max_drift)} within threshold #{format_percent(threshold)}"
        )
      end
    end

    # Check if any position exceeds threshold
    def any_exceeds_threshold?(positions)
      positions.any? do |position|
        result = analyze(position)
        result.needs_rebalance
      end
    end

    # Get all positions that need rebalancing
    def positions_needing_rebalance(positions)
      positions.select do |position|
        analyze(position).needs_rebalance
      end
    end

    private

    def calculate_max_drift(adjustments)
      adjustments.map do |adj|
        current = adj[:current_size].abs
        target = adj[:target_size].abs

        # Avoid division by zero
        next 0 if target.zero? && current.zero?

        if target.zero?
          # Position should be closed entirely
          1.0
        elsif current.zero?
          # New position needed
          1.0
        else
          # Calculate relative drift
          (adj[:delta].abs / target).abs
        end
      end.max || 0
    end

    def no_rebalance_result(reason)
      Result.new(
        needs_rebalance: false,
        drift_percent: 0,
        adjustments: [],
        reason: reason
      )
    end

    def format_percent(value)
      "#{(value * 100).round(2)}%"
    end
  end
end
