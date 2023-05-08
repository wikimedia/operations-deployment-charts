# frozen_string_literal: true

require_relative './runner'
require_relative './view'

# Module tester contains all the facilities for
# testing the deployment-charts repository.
# the main module here only contains factory methods.
module Tester
  # Creates a runner instance.
  # Will find assets based on the provided glob pattern.
  def self.runner(pattern, options)
    if pattern == 'admin'
      AdminTestRunner.new pattern, options
    elsif pattern == 'scaffold'
      ScaffoldTestRunner.new pattern, options
    elsif pattern.include?('helmfile.d')
      DeploymentTestRunner.new pattern, options
    elsif pattern.include?('charts')
      TestRunner.new pattern, options
    else
      abort("unrecognized pattern '#{pattern}'")
    end
  end

  # Creates a View. Takes as input the kind of test being run.
  def self.view(args)
    case args[:kind]
    when 'charts', 'deployments', 'admin', 'scaffold'
      CLIView.new args
    else
      abort("We don't have a view of kind '#{args[:kind]}'")
    end
  end
end
