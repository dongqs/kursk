local now = tonumber(ARGV[1])
local period = tonumber(ARGV[2])

local default_x = 0
local default_y = 0
local default_vx = 0
local default_vy = 0
local min_x = 0
local max_x = 800
local min_y = 0
local max_y = 600
local fire_pause = 0.3
local tank_a = 200
local missile_v = 300
local hit_ll = 400

local tank_names = redis.call('keys', 'tank:*')
local tanks = {}
for i, name in pairs(tank_names) do

  local x = tonumber(redis.call('hget', name, 'x'))
  local y = tonumber(redis.call('hget', name, 'y'))
  local vx = tonumber(redis.call('hget', name, 'vx'))
  local vy = tonumber(redis.call('hget', name, 'vy'))
  local ax = tonumber(redis.call('hget', name, 'ax'))
  local ay = tonumber(redis.call('hget', name, 'ay'))
  local dx = tonumber(redis.call('hget', name, 'dx'))
  local dy = tonumber(redis.call('hget', name, 'dy'))
  local fired_at = tonumber(redis.call('hget', name, 'fired_at'))
  local firing = redis.call('hget', name, 'firing')

  if firing then

    local tank = {}

    firing = tonumber(firing)

    ax = ax * tank_a
    ay = ay * tank_a

    vx = vx + ax * period
    vy = vy + ay * period

    vx = vx * math.pow(0.8, period)
    vy = vy * math.pow(0.8, period)

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

    tank['fire'] = tonumber(redis.call("get", "fire:" .. name)) or 0
    tank['kill'] = tonumber(redis.call("get", "kill:" .. name)) or 0
    tank['die'] = tonumber(redis.call("get", "die:" .. name)) or 0
    tank['x'] = x
    tank['y'] = y
    tanks[name] = tank

    if firing > 0 then
      if (now - fired_at) > fire_pause then
        local missile = "missile:" .. name .. ":" .. now

        redis.call("incr", "fire:" .. name)

        redis.call("hset", name, "fired_at", now)
        redis.call("hset", name, "firing", 0)

        redis.call("hset", missile, "x", x + dx * 30)
        redis.call("hset", missile, "y", y + dy * 30)
        redis.call("hset", missile, "dx", dx)
        redis.call("hset", missile, "dy", dy)
        redis.call("hset", missile, "by", name)
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

    for tank_name, tank in pairs(tanks) do

      local lx = x - tank["x"]
      local ly = y - tank["y"]

      if lx * lx + ly * ly < hit_ll then

        local killer_name = redis.call("hget", name, "by")
        redis.call("incr", "kill:" .. killer_name)
        redis.call("incr", "die:" .. tank_name)
        redis.call("hset", tank_name, "x", default_x)
        redis.call("hset", tank_name, "y", default_y)
        redis.call("hset", tank_name, "vx", default_vx)
        redis.call("hset", tank_name, "vy", default_vy)
        break
      end
    end
  end
end

local result = {}
result['tanks'] = tanks
result['missiles'] = missiles

redis.call("setex", "result", 60, cjson.encode(result))

return(table.getn(tank_names) .. ' ' .. table.getn(missile_names))
