require 'spec_helper'

describe SpreeAmazon::Configuration do
  describe '#use_static_preferences!' do
    # We cannot use_static_preferences since we allow users
    # to configure the settings through the admin UI, calling
    # use_static_preferences will reset all settings to their
    # default values and store them in memory
    it "raises an error" do
      configuration = SpreeAmazon::Configuration.new

      expect {
        configuration.use_static_preferences!
      }.to raise_error("SpreeAmazon::Configuration cannot use static preferences")
    end
  end
end
