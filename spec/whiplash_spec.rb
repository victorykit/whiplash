require 'spec_helper'

describe Whiplash do
  include Whiplash

  before(:all) { Whiplash.redis = Whiplash::FakeRedis.new }

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

  pending "should not incr redis if only one option"
  
  it "should spin and win" do
    session = {session_id: "x"}
    test_name = "arbitrary test name"
    Whiplash.redis.del("whiplash/#{test_name}/true/spins")
    choice = spin!(test_name, :arbitrary_goal, [true, false], session)
    [true, false].should include choice
    Whiplash.redis.get("whiplash/#{test_name}/#{choice}/spins").to_i.should == 1
    win!(:arbitrary_goal, session)
    Whiplash.redis.get("whiplash/#{test_name}/#{choice}/wins").to_i.should == 1
  end
end
