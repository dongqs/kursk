require 'redis'
require 'json'
require 'digest'

script = File.read("core.lua")

sha1 = Digest::SHA1.hexdigest script
redis = Redis.new

n = 0
last_n = 0

time = Time.new
now = Time.new
period = now - time

result = redis.eval script, [], [now.to_f, period.to_f]

loop do
  n += 1
  time = now
  now = Time.new
  period = now - time

  result = redis.evalsha sha1, [], [now.to_f, period.to_f]

  sleep 0.01
  if now.to_f.round - time.to_f.round > 0
    puts "#{n - last_n} #{result}"
    last_n = n
  end
end
