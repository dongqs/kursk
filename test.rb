require 'redis'
require 'json'

redis = Redis.new
script = <<EOF
local name = "s"
name = name .. 12.345 * 10
return name
EOF
puts redis.eval script
