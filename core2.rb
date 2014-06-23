require 'redis'
require 'json'

script = <<EOF
local now = tonumber(ARGV[1])
local period = tonumber(ARGV[2])

local min_x = 0
local max_x = 800
local min_y = 0
local max_y = 600
local fire_pause = 1.0
local tank_a = 100
local missile_v = 100

local tank_names = redis.call('keys', 'tank:*')
local tanks = {}
for i, name in pairs(tank_names) do
  local firing = redis.call('hget', name, 'firing')

  if firing then

    firing = tonumber(firing)

    local tank = {}
    local x = tonumber(redis.call('hget', name, 'x'))
    local y = tonumber(redis.call('hget', name, 'y'))
    local vx = tonumber(redis.call('hget', name, 'vx'))
    local vy = tonumber(redis.call('hget', name, 'vy'))
    local ax = tonumber(redis.call('hget', name, 'ax'))
    local ay = tonumber(redis.call('hget', name, 'ay'))
    local dx = tonumber(redis.call('hget', name, 'dx'))
    local dy = tonumber(redis.call('hget', name, 'dy'))
    local fired_at = tonumber(redis.call('hget', name, 'fired_at'))

    ax = ax * tank_a
    ay = ay * tank_a

    vx = vx + ax * period
    vy = vy + ay * period

    vx = vx * math.pow(0.5, period)
    vy = vy * math.pow(0.5, period)

    x = x + vx * period
    y = y + vy * period

    if x < min_x then
      vx = -vx
      x = min_x
    end

    if x > max_x then
      vx = -vx
      x = max_x
    end

    if y < min_y then
      vy = -vy
      y = min_y
    end

    if y > max_y then
      vy = -vy
      y = max_y
    end

    redis.call("hset", name, "vx", vx)
    redis.call("hset", name, "vy", vy)
    redis.call("hset", name, "x", x)
    redis.call("hset", name, "y", y)

    tank['name'] = name
    tank['x'] = x
    tank['y'] = y
    tanks[name] = tank

    if firing > 0 then
      if (now - fired_at) > fire_pause then
        local missile = "missile:" .. name .. ":" .. now

        redis.call("hset", name, "fired_at", now)
        redis.call("hset", name, "firing", 0)

        redis.call("hset", missile, "x", x)
        redis.call("hset", missile, "y", y)
        redis.call("hset", missile, "dx", dx)
        redis.call("hset", missile, "dy", dy)
      end
    end
  end
end

local missile_names = redis.call('keys', 'missile:*')
local missiles = {}
for i, name in pairs(missile_names) do
  local missile = {}
  local x = redis.call('hget', name, 'x')
  local y = redis.call('hget', name, 'y')
  local dx = redis.call('hget', name, 'dx')
  local dy = redis.call('hget', name, 'dy')

  x = x + dx * missile_v * period
  y = y + dy * missile_v * period

  if x < min_x or x > max_x or y < min_y or y > max_y then
    redis.call("del", name)
  else
    redis.call("hset", name, "x", x)
    redis.call("hset", name, "y", y)
    missile["x"] = x
    missile["y"] = y
    missiles[name] = missile
  end
end

local result = {}
result['tanks'] = tanks
result['missiles'] = missiles

redis.call("setex", "result", 60, cjson.encode(result))
EOF

redis = Redis.new

n = 0
last_n = 0

time = Time.new
now = Time.new

loop do
  n += 1
  time = now
  now = Time.new
  period = now - time

  result = redis.eval script, [], [now.to_f, period.to_f]

  sleep 0.01
  if now.to_f.round - time.to_f.round > 0
    puts "#{n - last_n}"
    last_n = n
  end
end
