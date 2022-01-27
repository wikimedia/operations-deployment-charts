# frozen_string_literal: true

require 'erb'

module Tester
  # Class to create a presentation layer.
  class CLIView
    # "kind" here is protected by the factory method
    def initialize(args)
      @args = args
      tpl_dir = File.join File.dirname(__FILE__), 'templates'
      template = File.read(File.join(tpl_dir, "#{args[:kind]}.erb"))
      @tpl = ERB.new(template, nil, '-')
    end

    def has_lv?
      return true unless @args.include?(:tests)

      @args[:tests].include?('lint') || @args[:tests].include?('validate')
    end

    def has_diff?
      return true if @args[:tests].nil?

      @args[:tests].include?('diff')
    end

    def asset_name(asset)
      if asset.ok?
        asset.name.green
      else
        asset.name.red
      end
    end

    def report(outcome)
      if outcome
        '[OK]'.green
      else
        '[FAIL]'.red
      end
    end

    # Render the view
    # @param tr [TestRunner] the runner to operate on.
    def render(trun)
      ok = trun.succeded
      failed = trun.failed
      with_diffs = trun.assets.select { |_k, v| v.diffs? }
      @tpl.result(binding)
    end
  end
end
