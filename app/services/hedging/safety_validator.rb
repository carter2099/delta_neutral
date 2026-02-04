module Hedging
  class SafetyValidator
    class ValidationError < StandardError
      attr_reader :code

      def initialize(message, code: :unknown)
        @code = code
        super(message)
      end
    end

    # Maximum single trade size in USD
    MAX_TRADE_SIZE_USD = 100_000

    # Maximum drift before we consider it suspicious (e.g., 500% drift is likely an error)
    MAX_REASONABLE_DRIFT = 5.0

    # Minimum position size to bother hedging (in USD)
    MIN_HEDGE_VALUE_USD = 10

    def initialize(hl_client: nil)
      @hl_client = hl_client
    end

    def validate_adjustments!(adjustments, prices: {})
      adjustments.each do |adj|
        validate_single_adjustment!(adj, prices: prices)
      end

      validate_total_value!(adjustments, prices: prices)

      true
    end

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

    def validate_asset!(asset)
      return true if asset.present?

      raise ValidationError.new(
        "Asset symbol is required",
        code: :missing_asset
      )
    end

    def validate_trade_size!(value_usd, asset)
      return true if value_usd <= MAX_TRADE_SIZE_USD

      raise ValidationError.new(
        "Trade size $#{value_usd.round(2)} for #{asset} exceeds maximum $#{MAX_TRADE_SIZE_USD}",
        code: :trade_too_large
      )
    end

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

    def should_skip_hedge?(value_usd)
      value_usd < MIN_HEDGE_VALUE_USD
    end

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
