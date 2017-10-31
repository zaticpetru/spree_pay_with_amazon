##
# Amazon Payments - Login and Pay for Spree Commerce
#
# @category    Amazon
# @package     Amazon_Payments
# @copyright   Copyright (c) 2014 Amazon.com
# @license     http://opensource.org/licenses/Apache-2.0  Apache License, Version 2.0
#
##
source 'https://rubygems.org'

branch = ENV.fetch('SPREE_BRANCH', 'master')
gem 'spree' #, github: 'spree/spree', branch: branch

# Provides basic authentication functionality for testing parts of your engine
gem 'spree_auth_devise', github: 'spree/spree_auth_devise', branch: '3-0-stable'
group :development, :test do
  gem 'pry-rails'
end

group :test do
  gem 'codeclimate-test-reporter', require: nil
  gem 'webmock'
end

gem 'pg'
gem 'mysql2'

gemspec
