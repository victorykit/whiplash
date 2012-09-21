require 'whiplash/version'
require 'simple-random'
require 'redis'
require 'redis-namespace'
require 'json'

module Whiplash
  FAIRNESS_CONSTANT7 = FC7 = 2

  # Accepts:
  #   1. A 'hostname:port' String
  #   2. A 'hostname:port:db' String (to select the Redis db)
  #   4. A Redis URL String 'redis://host:port'
  #   5. An instance of `Redis`, or `Redis::Client`
  def self.redis=(server)
    case server
    when String
      if server =~ /redis\:\/\//
        redis = Redis.connect(:url => server, :thread_safe => true)
      else
        server, namespace = server.split('/', 2)
        host, port, db = server.split(':')
        redis = Redis.new(host: host, port: port, thread_safe: true, db: db)
      end

      @redis = redis
    else
      @redis = server
    end
  end

  # Returns the current Redis connection. If none has been created, will
  # create a new one.
  def self.redis
    return @redis if @redis
    self.redis = Redis.respond_to?(:connect) ? Redis.connect : "localhost:6379"
    self.redis
  end

  def arm_guess(observations, victories)
    a = [victories, 0].max
    b = [observations-victories, 0].max
    s = SimpleRandom.new; s.set_seed; s.beta(a+FC7, b+FC7)
  end
  
  def best_guess(options)
    guesses = {}
    options.each { |o, v| guesses[o] = arm_guess(v[0], v[1]) }
    gmax = guesses.values.max
    best = options.keys.select { |o| guesses[o] ==  gmax }
    return best.sample
  end
  
  def data_for_options(test_name, options)
    keys = options.map {|o| ["whiplash/#{test_name}/#{o}/spins", "whiplash/#{test_name}/#{o}/wins"] }.flatten
    values = Whiplash.redis.mget(keys).map(&:to_i).each_slice(2)
    Hash[options.zip(values)]
  end
  
  def spin_for_choice(test_name, choice, mysession=nil)
    data = {type: "spin", when: Time.now.to_f, test: test_name, choice: choice}
    Whiplash.log data.to_json
    Whiplash.redis.incr("whiplash/#{test_name}/#{choice}/spins")
    mysession[test_name] = choice
    return choice
  end

  def measure!(test_name, options=[true, false], mysession=nil)
    mysession ||= session
    if mysession.key?(test_name) && options.include?(mysession[test_name])
      return mysession[test_name]
    end
    
    choice = options.sample
    return spin_for_choice(test_name, choice, mysession)
  end

  def spin!(test_name, goal, options=[true, false], mysession=nil)
    mysession ||= session
    #manual_whiplash_mode allows to set new options using /whiplash_sessions page
    if mysession.key?(test_name) && (options.include?(mysession[test_name]) || mysession.key?("manual_whiplash_mode"))
      return mysession[test_name]
    end
    
    return options.first if options.count == 1

    Whiplash.redis.sadd("whiplash/goals/#{goal}", test_name)
    choice = best_guess(data_for_options(test_name, options))
    return spin_for_choice(test_name, choice, mysession)
  end

  def win_on_option!(test_name, choice, mysession=nil)
    return if choice.nil?
    mysession ||= session
    data = {type: "win", when: Time.now.to_f, test: test_name, choice: choice}
    Whiplash.log data.to_json
    Whiplash.redis.incr("whiplash/#{test_name}/#{choice}/wins")
  end

  def lose_on_option!(test_name, choice, mysession=nil)
    return if choice.nil?
    mysession ||= session
    data = {type: "lose", when: Time.now.to_f, test: test_name, choice: choice}
    Whiplash.log data.to_json
    Whiplash.redis.decr("whiplash/#{test_name}/#{choice}/wins")
  end

  def win!(goal, mysession=nil)
    mysession ||= session
    Whiplash.redis.smembers("whiplash/goals/#{goal}").each do |t|
      win_on_option!(t, mysession[t], mysession)
    end
  end

  def all_tests
    tests = {}
    Whiplash.redis.keys('whiplash/goals/*').each do |g|
      Whiplash.redis.smembers(g).each do |t|
        tests[t] = {goal: g[15..-1], options: []}
      end
    end

    tests.keys.each do |t|
      prefix = "whiplash/#{t}/"
      suffix = "/spins"
      Whiplash.redis.keys(prefix + "*" + suffix).each do |o|
        tests[t][:options] << o[prefix.length..-suffix.length-1]
      end
    end
    tests
  end

  def spins_for test_name, opt_name
    Whiplash.redis.get("whiplash/#{test_name}/#{opt_name}/spins").to_i
  end

  def wins_for test_name, opt_name
    Whiplash.redis.get("whiplash/#{test_name}/#{opt_name}/wins").to_i
  end

  def used_storage
    max_redis_space = 104857600 # (100 MB)
    Whiplash.redis.info["used_memory"].to_f / max_redis_space
  end

  def self.log(message)
    message = "[whiplash] #{message}"
    if defined?(Rails)
      Rails.logger.info message
    else
      puts message
    end
  end
end
