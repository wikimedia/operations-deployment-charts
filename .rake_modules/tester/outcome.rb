# frozen_string_literal: true

module Tester
  # Container for a test result
  class TestOutcome
    attr_reader :out, :err, :exit_status, :command
    def initialize(stdout, stderr, exitstatus, cmd)
      # Ensure stdout and stderr are nil if they consist of whitespaces only
      @out = stdout.strip.empty? ? nil : stdout unless stdout.nil?
      @err = stderr.strip.empty? ? nil : stderr unless stderr.nil?
      @exit_status = exitstatus
      @command = cmd
    end

    def ok?
      @exit_status.zero?
    end

    def grep_v(pattern)
      @out = @out.split("\n").reject { |l| l =~ pattern }.join("\n") unless @out.nil?
      @err = @err.split("\n").reject { |l| l[pattern] }.join("\n") unless @err.nil?
    end

    def ignore_errors
      @exit_status = 0
    end

    def ==(other)
      return false unless other.is_a?(Tester::TestOutcome)

      (@out == other.out && @err == other.err && @exit_status == other.exit_status && @command == other.command)
    end
  end

  # Specialized outcome for kubeyaml tests.
  class KubeyamlTestOutcome < TestOutcome
    attr_reader :outcomes
    def initialize(command)
      @out = ''
      @err = ''
      @exit_status = 0
      @outcomes = {}
      @command = command
    end

    def add(src, outcome)
      @outcomes[src] ||= []
      @outcomes[src] << outcome
    end

    def ok?
      @outcomes.values.map { |outcomes| outcomes.reject(&:ok?) }.flatten.empty?
    end

    def err
      err = {}
      @outcomes.each do |source, outcomes|
        counter = 0
        outcomes.each do |outcome|
          next if outcome.out.nil?

          err["#{source}[#{counter}]"] = outcome.out
          counter += 1
        end
      end
      err
    end
  end

  class KubeconformTestOutcome < TestOutcome
    attr_reader :outcomes
    def initialize()
      @out = ''
      @err = ''
      @exit_status = 0
      @outcomes = {}
    end

    def add(kubernetes_version, outcome)
      @outcomes[kubernetes_version] = outcome
    end

    def ok?
      @outcomes.values.reject { |outcome| outcome.ok? }.flatten.empty?
    end

    def err
      err = {}
      @outcomes.each do |version, outcome|
        next if outcome.out.nil?
        err["k8s v#{version}"] = outcome.out
      end
      err
    end
  end
end
