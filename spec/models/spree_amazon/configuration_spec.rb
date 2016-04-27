require 'spec_helper'

describe SpreeAmazon::Configuration do
  describe '#use_static_preferences!' do
    it "raises an error" do
      configuration = SpreeAmazon::Configuration.new

      expect {
        configuration.use_static_preferences!
      }.to raise_error("SpreeAmazon::Configuration cannot use static preferences")
    end
  end
end
