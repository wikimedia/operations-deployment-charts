# frozen_string_literal: true

require_relative './utils'

# This class manages scaffolding a new service chart.
# It only works if a presets file is presented.
class Scaffold
  attr_accessor :answers

  def initialize(model, chart, presets_file)
    @model = model
    @chart = chart
    @presets = presets_file
    @sextant = which('sextant')
  end

  def command
    "#{@sextant} create-chart -s _scaffold/#{@model} -p #{@presets} charts/#{@chart}"
  end

  def run
    ok, out = _exec(command)
    puts("failed to run #{command}: #{out}") unless ok
  end
end
