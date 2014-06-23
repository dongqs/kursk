require 'rest-client'

n = (ARGV[0] || 5).to_i
s = (ARGV[1] || 1).to_f

puts "ai number: #{n}"


ais = {}
(0...n).to_a.each {
  name = "ai-" + (0...2).to_a.map { ('a'..'z').to_a.sample }.join
  offset = rand * Math::PI
  ais[name] = offset
}

time = Time.new
now = Time.new

loop do
  time = now
  now = Time.new
  puts now - time

  t = now.to_f

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
    rescue => exc
      puts exc.to_s
      raise
    end
  end

  sleep s
end
