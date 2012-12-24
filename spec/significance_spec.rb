describe Significance do
  specify do
    Significance.([[200, 570-200], [205, 572-205]]).should == 0.2092993793815333
  end
end
