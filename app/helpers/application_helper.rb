module ApplicationHelper
  def format_usd(value, precision: 2)
    n = number_with_delimiter(number_with_precision(value.to_f.abs, precision: precision))
    value.to_f < 0 ? "-$#{n}" : "$#{n}"
  end
end
