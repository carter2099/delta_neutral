module ApplicationHelper
  def format_usd(amount)
    return "—" unless amount
    prefix = amount >= 0 ? "" : "-"
    "#{prefix}$#{number_with_delimiter(amount.abs.round(2))}"
  end

  def format_pnl(amount)
    return "—" unless amount
    css_class = amount >= 0 ? "text-green" : "text-red"
    prefix = amount >= 0 ? "+" : ""
    content_tag(:span, "#{prefix}#{format_usd(amount)}", class: css_class)
  end

  def format_percent(value)
    return "—" unless value
    "#{(value * 100).round(2)}%"
  end

  def format_token_amount(amount, precision: 6)
    return "—" unless amount
    number_with_precision(amount, precision: precision)
  end

  def drift_status_class(drift_percent)
    case drift_percent
    when 0...0.03 then "low"
    when 0.03...0.05 then "medium"
    else "high"
    end
  end
end
