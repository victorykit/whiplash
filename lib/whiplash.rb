require 'whiplash/version'
require 'whiplash/stats'
require 'simple-random'
require 'redis'
require 'redis-namespace'
require 'json'

module Whiplash
  FAIRNESS_CONSTANT7 = FC7 = 2

  class << self
    # Accepts:
    #   1. A 'hostname:port' String
    #   2. A 'hostname:port:db' String (to select the Redis db)
    #   4. A Redis URL String 'redis://host:port'
    #   5. An instance of `Redis`, or `Redis::Client`
    def redis=(server)
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
    def redis
      return @redis if @redis
      self.redis = Redis.respond_to?(:connect) ? Redis.connect : "localhost:6379"
      self.redis
    end

    def log(message)
      message = "[whiplash] #{message}"
      if defined?(Rails)
        Rails.logger.info message
      else
        puts message
      end
    end
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

  def redis_nonce(mysession)
    # force creation of a session_id
    mysession[:tmp] = 1
    mysession.delete(:tmp)
    sessionid = mysession[:session_id] || request.session_options[:id]
    return "#{sessionid}_#{Random.rand}"
  end

  def spin_for_choice(test_name, choice, mysession=nil)
    data = {type: "spin", when: Time.now.to_f, nonce: redis_nonce(mysession), test: test_name, choice: choice}
    Whiplash.log data.to_json
    Whiplash.redis.incr("whiplash/#{test_name}/#{choice}/spins")
    mysession[test_name] = choice
    return choice
  end

  def measure!(test_name, goal, options=[true, false], mysession=nil)
    return spin!(test_name, goal, options, mysession, true)
  end

  def spin!(test_name, goal, options=[true, false], mysession=nil, measure=false)
    mysession ||= session
    #manual_whiplash_mode allows to set new options using /whiplash_sessions page
    if mysession.key?(test_name) && (options.include?(mysession[test_name]) || mysession.key?("manual_whiplash_mode"))
      return mysession[test_name]
    end

    return options.first if options.count == 1

    Whiplash.redis.sadd("whiplash/goals/#{goal}", test_name)
    if measure
      choice = options.sample
    else
      choice = best_guess(data_for_options(test_name, options))
    end
    return spin_for_choice(test_name, choice, mysession)
  end

  def win_on_option!(test_name, choice, mysession=nil)
    return if choice.nil?
    mysession ||= session
    data = {type: "win", when: Time.now.to_f, nonce: redis_nonce(mysession), test: test_name, choice: choice}
    Whiplash.log data.to_json
    Whiplash.redis.incr("whiplash/#{test_name}/#{choice}/wins")
  end

  def lose_on_option!(test_name, choice, mysession=nil)
    return if choice.nil?
    mysession ||= session
    data = {type: "lose", when: Time.now.to_f, nonce: redis_nonce(mysession), test: test_name, choice: choice}
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
    Whiplash::Stats.new.all_tests
  end
end
