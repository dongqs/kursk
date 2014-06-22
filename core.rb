require 'redis'

redis = Redis.new
time = Time.new

MIN_X = 0
MAX_X = 800
MIN_Y = 0
MAX_Y = 600
FIRE_PAUSE = 1.0
TANK_A = 100
MISSILE_V = 100

n = 0
last_n = 0


loop do
  now = Time.new
  period = now - time

  tank_names = redis.smembers "tanks"
  tank_names.each do |name|
    key = "tank:#{name}"
    tank = redis.hgetall key

    if tank.empty?
      redis.srem "tanks", name
      next
    end

    ax = tank["ax"].to_f * TANK_A
    ay = tank["ay"].to_f * TANK_A

    vx = tank["vx"].to_f + period * ax
    vy = tank["vy"].to_f + period * ay

    vx = vx * (0.5 ** period)
    vy = vy * (0.5 ** period)


    x = tank["x"].to_f + period * vx
    y = tank["y"].to_f + period * vy

#    x += (MAX_X - MIN_X) if x < MIN_X
#    x -= (MAX_X - MIN_X) if x > MAX_X
#
#    y += (MAX_Y - MIN_Y) if y < MIN_Y
#    y -= (MAX_Y - MIN_Y) if y > MAX_Y

    if x < MIN_X
      vx = -vx
      x = MIN_X
    end

    if x > MAX_X
      vx = -vx
      x = MAX_X
    end

    if y < MIN_Y
      vy = -vy
      y = MIN_Y
    end
    if y > MAX_Y
      vy = -vy
      y = MAX_Y
    end

    if tank["firing"].to_i > 0
      if now.to_f - tank["fired_at"].to_f > FIRE_PAUSE

        dx = tank["dx"].to_f
        dy = tank["dy"].to_f
        dl = Math.sqrt(dx * dx + dy * dy)

        dx = dx / dl
        dy = dy / dl

        redis.hset key, "fired_at", now.to_f

        missile = (0...6).to_a.map { ('a'..'z').to_a.sample }.join
        redis.sadd "missiles", missile
        mkey = "missile:#{missile}"

        redis.hset key, "firing", 0
        redis.hset mkey, "x", x
        redis.hset mkey, "y", y
        redis.hset mkey, "dx", dx
        redis.hset mkey, "dy", dy
      end
    end

    redis.hset key, "vx", vx
    redis.hset key, "vy", vy

    redis.hset key, "x", x
    redis.hset key, "y", y

#    puts "#{now} #{name}: #{ax.round(3)},#{ay.round(3)} #{vx.round(3)},#{vy.round(3)} #{x.round(3)},#{y.round(3)}"
  end

  missile_names = redis.smembers "missiles"
  missile_names.each do |name|
    key = "missile:#{name}"
    missile = redis.hgetall key

    x = missile["x"].to_f
    y = missile["y"].to_f
    dx = missile["dx"].to_f
    dy = missile["dy"].to_f

    x += dx * MISSILE_V * period
    y += dy * MISSILE_V * period

    if x < MIN_X or x > MAX_X or y < MIN_Y or y > MAX_Y
      redis.srem "missiles", name
      redis.del key
    else
      redis.hset key, "x", x
      redis.hset key, "y", y
    end
  end

  if now.to_f.round - time.to_f.round > 0
    puts "#{n - last_n} #{tank_names.length} #{missile_names.length}"
    last_n = n
  end

  time = now
  n += 1
  sleep 0.01
end
