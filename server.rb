require 'sinatra'
require 'json'
require 'redis'

get '/' do
  erb :index
end

get '/fight' do
  if params[:name]
    erb :fight
  else
    name = (0...4).to_a.map { ('a'..'z').to_a.sample }.join
    redirect "/fight?name=#{name}"
  end
end

get '/status' do
  {
    status: "success",
    message: "welcome to kursk",
  }.to_json
end

get '/move' do
  time = Time.new
  name = params[:name]

  key = "tank:#{name}"
  redis = Redis.new
  redis.sadd "tanks", name

  if redis.hgetall(key).empty?
    redis.hset key, "x", 400
    redis.hset key, "y", 300
    redis.hset key, "vx", 0
    redis.hset key, "vy", 0
    redis.hset key, "fired_at", time.to_f
  end

  ax = params[:ax].to_f
  ay = params[:ay].to_f
  al = Math.sqrt(ax * ax + ay * ay)
  al = 1 if al < 1

  dx = params[:dx].to_f
  dy = params[:dy].to_f
  dl = Math.sqrt(dx * dx + dy * dy)
  dl = 1 if dl == 0

  redis.hset key, "ax", ax / al
  redis.hset key, "ay", ay / al
  redis.hset key, "dx", dx / dl
  redis.hset key, "dy", dy / dl
  redis.hset key, "firing", params[:firing].to_i # as the symbol of finishing of initialze, do not hset after this line

  redis.expire key, 5

  result = redis.get "result"

  result
end
