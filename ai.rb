require 'rest-client'

n = 5

ais = {}
(0...n).to_a.each {
  name = "ai-" + (0...2).to_a.map { ('a'..'z').to_a.sample }.join
  offset = rand * Math::PI
  ais[name] = offset
}

loop do
  sleep 1
  t = Time.new.to_f

  ais.each do |name, offset|
    begin
      RestClient.get "http://localhost:4567/move", params: {
          name: name,
          ax: Math.cos(t + offset + rand),
          ay: Math.sin(t + offset + rand),
          dx: Math.sin(t + offset + rand),
          dy: Math.cos(t + offset + rand),
          firing: 1,
      }
    rescue
      puts "connection lost"
    end
  end
end
