require 'whiplash'
require 'sinatra/base'
require 'haml'

module Whiplash
  class Helper
    include ::Whiplash

    def stats
      all_tests.map do |test_name, test_info|
        arms = test_info[:options].map do |opt_name|
          {
            name: opt_name,
            spins: spins_for(test_name, opt_name),
            wins: wins_for(test_name, opt_name)
          }
        end.sort { |x,y| x[:name] <=> y[:name] }

        trials = arms.inject(0) { |acc, arm| acc + arm[:spins] }
        
        {
          name: test_name,
          trials: trials,
          arms: arms,
          goal: test_info[:goal]
        }
      end.sort do |x, y|
        compare_stats x, y
      end
    end

    # not bulletproof, but works with form like "petition 110 etc" (doesn't sort anything right of the number, though)
    def compare_stats(x, y)
      xname = x[:name]
      yname = y[:name]
      petition_id_pattern = /^petition (\d+)/
      xmatch = xname.match petition_id_pattern
      ymatch = yname.match petition_id_pattern
      if xmatch && ymatch
        xmatch[1].to_i <=> ymatch[1].to_i
      else
        xname <=> yname
      end
    end
  end

  class Server < Sinatra::Base
    dir = File.dirname(File.expand_path(__FILE__))

    set :views,  "#{dir}/server/views"
    set :public_folder, "#{dir}/server/public"
    set :haml, format: :html5

    helpers do
      def float_to_percentage(f)
        "%0.2f" % ( f * 100.0 )
      end
    end

    get '/' do
      @whiplash = Whiplash::Helper.new
      @stats = @whiplash.stats
      @redis_used = @whiplash.used_storage

      haml :index
    end
  end
end