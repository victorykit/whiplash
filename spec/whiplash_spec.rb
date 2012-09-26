require 'spec_helper'

describe Whiplash do
  include Whiplash

  before(:all) { Whiplash.redis = Whiplash::FakeRedis.new }
  let(:session) { {session_id: "x"} }

  it "should guess floats" do
    arm_guess(0, 0).class.should == Float
    arm_guess(1, 0).class.should == Float
    arm_guess(2, 1).class.should == Float
    arm_guess(1000, 5).class.should == Float
    arm_guess(10, -2).class.should == Float
  end

  it "should pick one of the options as the best" do
    [:a, :b].should include best_guess(a: [10, 5], b: [100, 99])
  end

  it "should incr wins only for entries in given session" do
    Whiplash.redis.stub(:smembers).with("whiplash/goals/spec whiplash").and_return(["spec website layout", "spec email title"])
    website_session = {:session_id => :some_web_session, "spec website layout" => "flashy"}
    email_session = {:session_id => :some_email, "spec email title" => "hello there"}

    Whiplash.redis.should_receive(:incr).with("whiplash/spec website layout/flashy/wins")
    Whiplash.redis.should_not_receive(:incr).with("whiplash/spec email title//wins")

    win!("spec whiplash", website_session)
  end

  it "should incr wins only when choice has value" do
    website_session = {:session_id => :some_web_session, "spec website layout" => "flashy"}
    Whiplash.redis.should_not_receive(:incr)
    win_on_option!("spec whiplash layout", nil, website_session)
  end

  it "should decr wins only when choice has value" do
    website_session = {:session_id => :some_web_session, "spec website layout" => "flashy"}
    Whiplash.redis.should_not_receive(:decr)
    lose_on_option!("spec whiplash layout", nil, website_session)
  end

  it "should not incr redis if only one option" do
    test_name = "arbitrary test name"
    
    Whiplash.redis.set("whiplash/#{test_name}/a/spins", 0)
    spin! test_name, :arbitrary_goal, ["a"]
    Whiplash.redis.get("whiplash/#{test_name}/a/spins").should == 0
  end
  
  it "should spin and win" do
    test_name = "arbitrary test name"
    Whiplash.redis.del("whiplash/#{test_name}/true/spins")
    choice = spin!(test_name, :arbitrary_goal, [true, false])
    [true, false].should include choice
    Whiplash.redis.get("whiplash/#{test_name}/#{choice}/spins").to_i.should == 1
    win!(:arbitrary_goal)
    Whiplash.redis.get("whiplash/#{test_name}/#{choice}/wins").to_i.should == 1
  end
  
  it "should pick the best" do
    test_name = "arbitrary test"
    Whiplash.redis.set("whiplash/#{test_name}/a/spins", 100000000)
    Whiplash.redis.set("whiplash/#{test_name}/a/wins", 100000000)
    Whiplash.redis.set("whiplash/#{test_name}/b/spins", 100000000)
    Whiplash.redis.set("whiplash/#{test_name}/b/wins", 0)
    
    results = Hash.new(0)
    1000.times do
      results[spin!(test_name, :arbitrary_goal, ["a", "b"])] += 1
    end
    
    results["a"].should be > (results["b"] + 100)
  end

  it "should compose all_tests data" do
    spin!("different colored dingoes", :pet_me, ["red", "brown"])
    spin!("different looking dingoes", :love_me, ["big eyes", "long lashes"])
    win!(:pet_me)

    test = all_tests.find { |t| t[:name] == "different colored dingoes"}
    ["red", "brown"].should include test[:options].first
    test[:goal].should == :pet_me
    test[:arms].first[:spins].should == 1
    test[:arms].first[:wins].should == 1
    test[:trials].should == 1

    test = all_tests.find { |t| t[:name] == "different looking dingoes"}
    ["big eyes", "long lashes"].should include test[:options].first
    test[:goal].should == :love_me
    test[:arms].first[:spins].should == 1
    test[:arms].first[:wins].should == 0
    test[:trials].should == 1
  end
end
