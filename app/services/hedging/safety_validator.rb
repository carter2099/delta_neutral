module Hedging
  # Pre-trade safety validation for hedge adjustments.
  #
  # Enforces guardrails to prevent erroneous or dangerous trades:
  # - Maximum single trade size ({MAX_TRADE_SIZE_USD})
  # - Maximum total batch value ({MAX_TRADE_SIZE_USD} * 2)
  # - Excessive drift detection ({MAX_REASONABLE_DRIFT})
  # - Minimum hedge value filter ({MIN_HEDGE_VALUE_USD})
  #
  # @example
  #   validator = Hedging::SafetyValidator.new
  #   validator.validate_adjustments!(adjustments, prices: { "ETH" => 2000.0 })
  #   #=> true (or raises ValidationError)
  class SafetyValidator
    # Raised when a trade fails safety validation.
    # @!attribute [r] code
    #   @return [Symbol] machine-readable error code
    class ValidationError < StandardError
      attr_reader :code

      # @param message [String] human-readable error description
      # @param code [Symbol] error code (:trade_too_large, :excessive_drift,
      #   :missing_asset, :total_too_large)
      def initialize(message, code: :unknown)
        @code = code
        super(message)
      end
    end

    # @return [Integer] maximum single trade size in USD
    MAX_TRADE_SIZE_USD = 100_000

    # @return [Float] maximum drift ratio before flagging as suspicious (5.0 = 500%)
    MAX_REASONABLE_DRIFT = 5.0

    # @return [Integer] minimum hedge value in USD; smaller positions are skipped
    MIN_HEDGE_VALUE_USD = 10

    # @param hl_client [Hyperliquid::ClientWrapper, nil] optional HL client for price lookups
    def initialize(hl_client: nil)
      @hl_client = hl_client
    end

    # Validate a batch of adjustments, raising on the first failure.
    #
    # @param adjustments [Array<Hash>] adjustments with +:asset+, +:delta+,
    #   +:current_size+, +:target_size+
    # @param prices [Hash{String => Numeric}] current asset prices in USD
    # @return [true] if all validations pass
    # @raise [ValidationError] if any check fails
    def validate_adjustments!(adjustments, prices: {})
      adjustments.each do |adj|
        validate_single_adjustment!(adj, prices: prices)
      end

      validate_total_value!(adjustments, prices: prices)

      true
    end

    # Validate a single adjustment for trade size, drift, and asset presence.
    #
    # @param adjustment [Hash] adjustment with +:asset+, +:delta+, +:current_size+, +:target_size+
    # @param prices [Hash{String => Numeric}] current asset prices in USD
    # @return [true] if validation passes
    # @raise [ValidationError] if any check fails
    def validate_single_adjustment!(adjustment, prices: {})
      asset = adjustment[:asset]
      delta = adjustment[:delta]
      price = prices[asset] || 0

      # Validate asset is known
      validate_asset!(asset)

      # Validate trade size
      if price > 0
        trade_value = delta.abs * price
        validate_trade_size!(trade_value, asset)
      end

      # Validate drift isn't suspiciously large
      validate_drift!(adjustment)

      true
    end

    # Validate that an asset symbol is present.
    #
    # @param asset [String, nil] the asset symbol
    # @return [true] if present
    # @raise [ValidationError] with code +:missing_asset+ if blank
    def validate_asset!(asset)
      return true if asset.present?

      raise ValidationError.new(
        "Asset symbol is required",
        code: :missing_asset
      )
    end

    # Validate that a single trade's USD value is within limits.
    #
    # @param value_usd [Numeric] the trade's notional value in USD
    # @param asset [String] the asset symbol (for error messages)
    # @return [true] if within limits
    # @raise [ValidationError] with code +:trade_too_large+ if over {MAX_TRADE_SIZE_USD}
    def validate_trade_size!(value_usd, asset)
      return true if value_usd <= MAX_TRADE_SIZE_USD

      raise ValidationError.new(
        "Trade size $#{value_usd.round(2)} for #{asset} exceeds maximum $#{MAX_TRADE_SIZE_USD}",
        code: :trade_too_large
      )
    end

    # Validate that drift is not suspiciously large (likely a data error).
    #
    # @param adjustment [Hash] with +:delta+, +:current_size+, +:target_size+, +:asset+
    # @return [true] if drift is reasonable
    # @raise [ValidationError] with code +:excessive_drift+ if over {MAX_REASONABLE_DRIFT}
    def validate_drift!(adjustment)
      current = adjustment[:current_size]&.abs || 0
      target = adjustment[:target_size]&.abs || 0

      return true if current.zero? || target.zero?

      drift = (adjustment[:delta].abs / [current, target].max)

      return true if drift <= MAX_REASONABLE_DRIFT

      raise ValidationError.new(
        "Drift of #{(drift * 100).round(1)}% for #{adjustment[:asset]} is suspiciously large",
        code: :excessive_drift
      )
    end

    # Validate that the total batch value doesn't exceed safety limits.
    #
    # @param adjustments [Array<Hash>] adjustments with +:asset+ and +:delta+
    # @param prices [Hash{String => Numeric}] current asset prices in USD
    # @return [true] if within limits
    # @raise [ValidationError] with code +:total_too_large+ if over limit
    def validate_total_value!(adjustments, prices: {})
      total = adjustments.sum do |adj|
        price = prices[adj[:asset]] || 0
        adj[:delta].abs * price
      end

      return true if total <= MAX_TRADE_SIZE_USD * 2

      raise ValidationError.new(
        "Total trade value $#{total.round(2)} exceeds safety limits",
        code: :total_too_large
      )
    end

    # Check if a hedge value is too small to bother executing.
    #
    # @param value_usd [Numeric] the hedge's notional value in USD
    # @return [Boolean] true if below {MIN_HEDGE_VALUE_USD}
    def should_skip_hedge?(value_usd)
      value_usd < MIN_HEDGE_VALUE_USD
    end

    # Generate warning messages for adjustments that are notable but not invalid.
    #
    # @param adjustments [Array<Hash>] adjustments with +:asset+, +:delta+,
    #   +:current_size+, +:target_size+
    # @param prices [Hash{String => Numeric}] current asset prices in USD
    # @return [Array<String>] human-readable warning messages
    def warnings_for(adjustments, prices: {})
      warnings = []

      adjustments.each do |adj|
        price = prices[adj[:asset]] || 0
        value = adj[:delta].abs * price

        if value > MAX_TRADE_SIZE_USD * 0.5
          warnings << "Large trade: #{adj[:asset]} ~$#{value.round(0)}"
        end

        if adj[:current_size]&.zero? && adj[:target_size]&.abs&.positive?
          warnings << "New position: #{adj[:asset]}"
        end
      end

      warnings
    end
  end
end
