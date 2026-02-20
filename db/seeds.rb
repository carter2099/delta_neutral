# Lookup tables
networks = {
  "ethereum" => 1,
  "arbitrum" => 42161,
  "base" => 8453,
  "optimism" => 10,
  "polygon" => 137
}

networks.each do |name, chain_id|
  Network.find_or_create_by!(name: name) { |n| n.chain_id = chain_id }
end

%w[uniswap hyperliquid].each do |name|
  Dex.find_or_create_by!(name: name)
end

# Dev admin user
if Rails.env.development? || Rails.env.test?
  User.find_or_create_by!(email_address: "admin@example.com") do |u|
    u.first_name = "Admin"
    u.last_name = "User"
    u.password = "password123"
    u.password_confirmation = "password123"
  end
end

puts "Seeded #{Network.count} networks, #{Dex.count} dexes, #{User.count} users"
