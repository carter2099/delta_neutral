# Create a default admin user if none exists
# You can customize these values or set them via environment variables

if User.count.zero?
  email = ENV.fetch("ADMIN_EMAIL", "admin@example.com")
  password = ENV.fetch("ADMIN_PASSWORD", "changeme123")

  user = User.create!(
    email_address: email,
    password: password,
    paper_trading_mode: true,
    testnet_mode: true,
    auto_rebalance_enabled: false
  )

  puts "Created admin user: #{email}"
  puts "Default password: #{password}"
  puts "Remember to change the password after first login!"
else
  puts "User already exists, skipping seed."
end
