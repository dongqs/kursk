require 'sinatra'
require 'json'
require 'redis'

get '/' do
  if params[:name]
    erb :index
  else
    name = (0...4).to_a.map { ('a'..'z').to_a.sample }.join
    redirect "/?name=#{name}"
  end
end

get '/status' do
  {
    status: "success",
    message: "welcome to kursk",
  }.to_json
end

get '/move' do
  name = params[:name]

  key = "tank:#{name}"
  redis = Redis.new
  redis.sadd "tanks", name

  if redis.hgetall(key).empty?
    redis.hset key, "x", 400
    redis.hset key, "y", 300
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
  redis.hset key, "firing", params[:firing]

  redis.expire key, 60

  tank = redis.hgetall key

  tank_names = redis.smembers "tanks"
  missile_names = redis.smembers "missiles"
  {
    tanks: tank_names.map { |name|
      tank = redis.hgetall "tank:#{name}"
      {
        name: name,
        x: tank["x"].to_f,
        y: tank["y"].to_f,
      }
    },
    missiles: missile_names.map { |name|
      missile = redis.hgetall "missile:#{name}"
      {
        name: name,
        x: missile["x"].to_f,
        y: missile["y"].to_f,
      }
    }
  }.to_json
end
