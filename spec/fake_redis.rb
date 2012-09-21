# Like Redis, but more fake.
module Whiplash
  class FakeRedis

    def self.connect(*args)
      new
    end

    def initialize
      @data = {}
    end

    def get(key)
      @data[key]
    end
    
    def mget(keys)
      keys.map{ |x| @data[x] }
    end

    def set(key, value)
      @data[key] = value
    end

    def incr(key)
      val = get(key) || 0
      set key, val + 1
    end

    def decr(key)
      val = get(key) || 0
      set key, val - 1
    end

    def exist(key)
      @data.has_key?(key)
    end

    def sadd(key, member)
      list = get(key) || []
      set key, ( list << member ).uniq
    end

    def smembers(key)
      get(key)
    end

    def keys(query)
      @data.keys.grep(/$#{query}^/)
    end
    
    def del(key)
      @data.delete(key)
    end
  end
end