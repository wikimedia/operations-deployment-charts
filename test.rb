# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('.')
require '.rake_modules/testrunner.rb'
require '.rake_modules/utils'
tr = TestRunner.new 'charts/**/Chart.yaml'
tr.run
# puts mw.result[:validate].keys
