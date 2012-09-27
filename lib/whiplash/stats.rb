module Whiplash
  class Stats
    def all_tests
      test_names = list_tests_and_goals
      return [] if test_names.empty?

      spin_data = reindex_option_counts_by_test "spins"
      win_data = reindex_option_counts_by_test "wins"

      test_names.map do |test_name, goal_name|
        test_spins = spin_data[test_name]
        test_wins = win_data[test_name]

        arms = test_spins.map do |spin|
          win_pair = test_wins.assoc(spin[0])
          {
            name: spin[0],
            spins: spin[1].to_i,
            wins: win_pair ? win_pair[1].to_i : 0
          }
        end.sort_by { |arm| arm[:name] }

        trials = arms.inject(0) {|memo, arm| memo + arm[:spins]}

        { name: test_name, goal: goal_name, trials: trials, arms: arms }
      end
    end

    def list_tests_and_goals
      goal_keys = Whiplash.redis.keys('whiplash/goals/*')
      test_names = goal_keys.inject([]) do |list, goal_key|
        test = Whiplash.redis.smembers(goal_key)
        goal_name = goal_key.match(/whiplash\/goals\/(.*)/)[1].to_sym
        list + test.map { |test_name| [ test_name, goal_name ] }
      end
    end

    def reindex_option_counts_by_test sow
      keys_pattern = "whiplash/*/#{sow}"
      key_to_values_pattern = "whiplash\/(.*?)\/(.*?)\/#{sow}"
      reindex_by_first_key_part keys_pattern, key_to_values_pattern
    end

    def reindex_by_first_key_part keys_pattern, keys_to_values_pattern
      keys = Whiplash.redis.keys(keys_pattern)
      values = Whiplash.redis.mget(keys)
      key_parts = keys.map { |k| k.match(keys_to_values_pattern).captures }
      rows = key_parts.zip(values).map(&:flatten)
      rows.inject(Hash.new{|h, k| h[k] = []}) { |h, row| h[row[0]] << row.slice(1..-1); h }
    end
  end
end