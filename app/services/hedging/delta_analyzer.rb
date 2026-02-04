module Hedging
  # Analyzes the drift between current and target hedge positions to determine
  # whether a rebalance is needed.
  #
  # Drift is calculated as +|delta| / |target|+ for each asset, and the maximum
  # drift across all assets is compared against the position's configured
  # +rebalance_threshold+.
  #
  # @example
  #   analyzer = Hedging::DeltaAnalyzer.new
  #   result = analyzer.analyze(position)
  #   result.needs_rebalance #=> true
  #   result.drift_percent   #=> 0.15
  #   result.reason          #=> "Drift 15.0% exceeds threshold 5.0%"
  class DeltaAnalyzer
    # @return [Struct] analysis result with +:needs_rebalance+ (Boolean),
    #   +:drift_percent+ (Float), +:adjustments+ (Array), +:reason+ (String)
    Result = Struct.new(:needs_rebalance, :drift_percent, :adjustments, :reason, keyword_init: true)

    # @param calculator [Hedging::Calculator] calculator instance for computing adjustments
    def initialize(calculator: Calculator.new)
      @calculator = calculator
    end

    # Analyze a position's hedge drift and determine if rebalancing is needed.
    #
    # @param position [Position] the position to analyze
    # @return [Result] analysis result indicating whether rebalancing is needed
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

    # Check if any position in a collection exceeds its rebalance threshold.
    #
    # @param positions [Array<Position>] positions to check
    # @return [Boolean] true if at least one position needs rebalancing
    def any_exceeds_threshold?(positions)
      positions.any? do |position|
        result = analyze(position)
        result.needs_rebalance
      end
    end

    # Filter positions to only those needing rebalancing.
    #
    # @param positions [Array<Position>] positions to check
    # @return [Array<Position>] positions where drift exceeds threshold
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
