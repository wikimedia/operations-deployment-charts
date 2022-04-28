# frozen_string_literal: true

require 'open3'
require 'tempfile'
require 'yaml'
require_relative './outcome'
require_relative '../utils'
require_relative '../monkeypatch'

module Tester
  class AssetError < StandardError
  end

  # Container for a test asset
  class BaseTestAsset
    ERROR_CONTEXT_LINES = 4
    INIT_RESULT = { lint: nil, validate: {}, diff: {} }.freeze
    attr_reader :name, :path, :result, :fixtures

    def initialize(path, to_run = nil)
      @path = File.dirname(path)
      @name = File.basename(@path)
      # Duplicating a frozen ruby object unfreezes it.
      # Also, ruby only does shallow copies, so we need to  actually dup the content.
      # of the constant.
      @result = self.class::INIT_RESULT.map { |x, v| [x, v.dup] }.to_h
      # Container for cached templates, given we might need them
      # multiple times (for validation and diffing, for instance)
      @cached = nil
      # Marker that can be used to mark an asset as failed
      # to avoid further processing.
      @bad = false
      # Check if this asset should run, now that we know the name.
      @should_run = to_run.nil? || to_run.include?(name)
      # After this point, we have expensive operations.
      # Avoid running them unless we need to.
      @fixtures = if should_run?
                    # Test cases we'll use when executing commands on the asset.
                    collect_fixtures
                  end
    end

    def label
      @path
    end

    # Check if an asset should run or not.
    def should_run?
      @should_run
    end

    # check if an asset should execute the tests or if it
    # was not selected or is marked as bad
    def should_test?
      (@should_run && !@bad)
    end

    # Set the asset to have failed.
    def bad(msg, cmd)
      @result[:lint] = TestOutcome.new('', msg, 1, cmd)
      @bad = true
    end

    # Return a hash of validation error outcomes
    def validate_errors
      @result[:validate].reject { |_, v| v.ok? }
    end

    # Has the asset failed?
    def ok?
      return true if @result == self.class::INIT_RESULT
      return false unless @result[:lint].nil? || @result[:lint].ok?
      return false unless validate_errors.empty?

      true
    end

    # Return the diffs we found
    def diffs
      @result[:diff].reject { |_, v| v.ok? }
    end

    # Are there any diffs?
    def diffs?
      diffs.any?
    end

    # The public interfaces.
    # Run linting on the asset. Will need to be implemented in the subclasses
    def lint; end

    # Validate the manifest, by first verifying it's valid yaml,
    # then running it through kubeyaml.
    def validate(options)
      # Avoid running if the asset is marked as bad
      return unless should_test?

      r = @result[:validate]
      cached_templates.each do |label, outcome|
        r[label] = outcome
        # Given we run both helm and helmfile with --debug,
        # we move on to the next stages of validation even
        # if the rendered template is invalid,
        # as our validate_yaml has a better diagnostic output
        # than what helm gives us. So here we proceed even if outcome.ok? is false.
        # yaml validation.
        # So if we had any output at all to stdout, proceed to yaml validation
        next if !outcome.ok? && outcome.out.nil?

        r[label] = validate_yaml outcome
        next unless r[label].ok?

        r[label] = validate_kubeyaml(outcome, options[:kube_versions]) if options[:kubeyaml]
      end
    end

    # Find any difference in assets between the current code tree
    # and what is committed at origin/master.
    # The algorithm works as follows:
    #  get all templates for both source trees, and all fixtures
    #  for all the test cases we have:
    #  - if both templates render correctly, obtain a diff output and return it as a
    #    TestOutcome with exitstatus you'd expect from diff(1)
    #  - if the origin template didn't render or wasn't present, show the new manifest as addition
    #  - if the new template didn't render, return that error as an outcome itself
    #  - Return a simple TestOutcome with error "$label has been removed" if the template is not
    #    present in the change but was present before
    def diff(orig_dir)
      # Avoid running if the asset is marked bad
      return unless should_test?

      diffs = @result[:diff]
      # Get the templates for the head of origin/master
      head = templates(orig_dir)
      cached_templates.each do |label, outcome|
        if outcome.ok?
          manifest = outcome.out
          if head.include?(label)
            head_outcome = head[label]
            head_manifest = head_outcome.ok? ? head_outcome.out : 'Template did not render correcly.'
          else
            # New asset!
            head_manifest = ''
          end
          diffs[label] = _diff(head_manifest, manifest)
        else
          diffs[label] = outcome
        end
      end
      new_labels = cached_templates.keys
      head.keys.reject { |k| new_labels.include? k }.each do |k|
        diffs[k] = TestOutcome.new('', "#{label} has been removed", 2, "diff-for #{label}")
      end
    end

    def cached_templates
      @cached = templates if @cached.nil?
      @cached
    end

    # Execute a command.
    def _exec(command, input = nil, chdir = nil)
      outcome = nil
      options = chdir.nil? ? {} : { chdir: chdir }
      Open3.popen3(command, options) do |stdin, stdout, stderr, wait_thr|
        if input
          stdin.write(input)
          stdin.close
        end
        outcome = TestOutcome.new stdout.gets(nil), stderr.gets(nil), wait_thr.value.exitstatus, command
      end
      outcome
    end

    def _diff(original, changed)
      begin
        orig = Tempfile.new('orig')
        orig.write(original)
        orig.close
        change = Tempfile.new('changed')
        change.write(changed)
        change.close
        outcome = _exec("diff --show-function-line=kind -au8 --color=always '#{orig.path}' '#{change.path}'")
      ensure
        orig&.unlink
        change&.unlink
      end
      outcome
    end

    # Checks if a string is a valid yaml document.
    # returns a TestOutcome instance.
    def validate_yaml(output)
      cmd = "yaml-validate $(#{output.command})"
      begin
        YAML.load_stream(output.out) do |resource|
          # not doing anything here, we're just verifying the yaml documents get loaded.
        end
        TestOutcome.new('', '', 0, cmd)
      rescue Psych::SyntaxError => e
        TestOutcome.new('', yaml_parse_error(output, e), 1, cmd)
      rescue StandardError => e
        TestOutcome.new('', 'Error parsing the helm template output'.red + "\n#{e}", 2, cmd)
      end
    end

    # Validates the provided manifest collection running every element through kubeyaml
    def validate_kubeyaml(outcome, versions)
      # Kubeyaml does only validate the first object in a yaml stream.
      # See https://github.com/chuckha/kubeyaml/issues/7
      # So we split the manifest in single yaml documents.
      docs = outcome.out.split(/^---/)
      results = KubeyamlTestOutcome.new("kubeyaml -versions #{versions} -- #{label}")
      source = 'root'

      # There may be multiple objects (doc) in one source file (document).
      # In that case, no new Source line is emitted for following objects
      # and we need to reuse the last one.
      docsrc = docs.map do |doc|
        if (source_match = doc.match(%r{^# Source: ([a-zA-Z0-9/.-]*)$}))
          source = source_match.captures[0]
        end
        # Remove the # Source: line. It can be helpful if the template ends up
        # fully empty as kubeyaml won't then emit a useless warning
        doc = doc.strip.gsub(%r{^# Source: [a-zA-Z0-9/.-]*$}, '').strip
        [source, doc]
      end

      tp = ThreadPool.new(nthreads: [10, Etc.nprocessors].max)
      mutex = Mutex.new
      docsrc.each do |src, doc|
        next if doc.empty?

        tp.run do
          # Run kubeyaml
          outcome = _exec("kubeyaml -versions #{versions}", doc)
          mutex.synchronize do
            results.add(src, outcome)
          end
        end
      end
      tp.join
      results
    end

    private

    # Produces templates for all manifests. Needs to be implemented in the subclasses.
    def templates(_chdir = nil)
      {}
    end

    # Collect the test cases people created. Needs to be implemented in the subclasses.
    def collect_fixtures
      {}
    end

    # Render a nice error message (with context) for a yaml parsing error
    def yaml_parse_error(output, exc)
      lines = output.out.split("\n")
      min_line = [0, exc.line - BaseTestAsset::ERROR_CONTEXT_LINES].max
      pre_lines = exc.line - min_line
      post_lines = [lines.length, exc.line + ERROR_CONTEXT_LINES].min - exc.line
      [
        "Error is at line #{exc.line}, column #{exc.column} of the output of `#{output.command}`: #{exc.problem}".red,
        'Context:',
        lines[min_line, pre_lines],
        lines[exc.line].red,
        lines[exc.line + 1, post_lines]
      ].flatten.join("\n")
    end
  end

  # Assets for helm charts
  class ChartAsset < BaseTestAsset
    PRIVATE_STUB = '.fixtures/private_stub.yaml'

    def lint
      outcome = _exec("helm lint #{@path}")
      # surpress warnings about symlinks, see https://github.com/helm/helm/issues/7019
      outcome.grep_v(/found symbolic link/)
      @result[:lint] = outcome
    end

    private

    # Returns a hash of fixture_name => fixture_path
    def collect_fixtures(chdir = nil)
      real_path = chdir.nil? ? @path : File.join(chdir, @path)
      return [] unless File.exist? real_path

      fixtures = FileList.new("#{real_path}/.fixtures/*.yaml").reject { |f| f.include?(ChartAsset::PRIVATE_STUB) }
      all = fixtures.map do |f|
        fl = File.basename(f, '.yaml')
        name = "#{@path} => #{fl}"
        [name, f]
      end.to_h
      # Add the actual chart to the list of tests to run.
      all[@path] = nil
      all
    end

    # Produces a k8s manifest by running helm template, for all fixtures
    def templates(chdir = nil)
      # Container for all templates
      outcomes = {}
      # we need to collect fixtures again if we're in an alternative source
      fix = chdir.nil? ?  fixtures : collect_fixtures(chdir)
      fix.each do |label, fixture|
        quoted = fixture.nil? ? '' : "-f '#{fixture}'"
        # --debug will output yaml even if it's invalid
        command = "helm template --debug #{quoted} '#{@path}'"
        outcomes[label] = _exec command, nil, chdir
        outcomes[label].grep_v(/found symbolic link in path/)
        # If we got a yaml parse error, we will let the validation
        # take that into account, and output better diagnostics.
        outcomes[label].ignore_errors if outcomes[label].err =~ /YAML parse error/
      end
      outcomes
    end
  end

  # Assets for managing helmfile resources.
  class HelmfileAsset < BaseTestAsset
    ENV_EXPLORE = %w[staging eqiad ml-serve-eqiad].freeze
    LISTENERS_FIXTURE = '.fixtures/service_proxy.yaml'
    INIT_RESULT = { lint: {}, validate: {}, diff: {} }.freeze
    def initialize(path, to_run)
      @helmfile = File.basename path
      @origin = Dir.pwd
      super(path, to_run)
    end

    # Set the asset to have failed.
    def bad(msg, cmd)
      # If we already have a lint result, we don't want to replace it.
      # This can happen during diffing, if the previous version of the
      # helmfile asset was broken for some reason.
      @result[:lint] = { 'all': TestOutcome.new('', msg, 1, cmd) } if @result[:lint] == self.class::INIT_RESULT[:lint]
      @bad = true
    end

    def label
      @path.gsub('helmfile.d/', '')
    end

    def lint
      return unless should_test?

      @fixtures.each do |label, env|
        result[:lint][label] = _helmfile(command: 'lint', environment: env)
      end
    end

    def ok?
      return true if @result == self.class::INIT_RESULT

      unless @result[:lint].nil?
        lints = @result[:lint].values.map(&:ok?)
        return false if lints.include?(false)
      end
      return false unless validate_errors.empty?

      true
    end

    private

    def collect_fixtures(chdir = nil)
      res = nil
      real_path = chdir.nil? ? path : File.join(chdir, path)
      return [] unless File.exist? real_path

      # Our helmfiles are templated. So we need to first produce a valid one using "helmfile build"
      self.class::ENV_EXPLORE.each do |env|
        res = _exec("helmfile -e #{env} build", nil, real_path)
        return YAML.safe_load(res.out)['environments'].keys.map { |e| ["#{label}/#{e}", e] }.to_h if res.ok?
      end
      # If we get here, it means we failed to compile the helmfile
      # to extract the environments.
      bad(res.err, "helmfile build #{path}")
    end

    # Run an helmfile command.
    # We need to create a dedicated execution env for every source
    def _helmfile(command:, environment:, source: @origin, patch: true)
      out = nil
      run_in_tmpdir(source) do |tmpdir|
        patch_helmfile(tmpdir) if patch
        helm_home = File.join(tmpdir, '.helm')
        # Execute helmfile
        # --skip-deps skips updating repositories and helm chart dependencies over and over again.
        # This requires the dependencies to be available in the git checkout, but this is how we currently
        # handle it anyways.
        out = _exec(
          "HELM_HOME='#{helm_home}' helmfile -e '#{environment}' -f '#{@helmfile}' '#{command}' --skip-deps",
          nil,
          tmpdir
        )
      end
      out
    end

    def templates(alt_source = nil)
      src = alt_source.nil? ? @origin : alt_source
      outcomes = {}
      # we need to collect fixtures again if we're in an alternative source
      fix = fixtures
      unless alt_source.nil?
        fix = collect_fixtures(alt_source)
        # If the previous commit was broken, we need to just return empty outcomes.
        # See T307043.
        return outcomes unless should_test?
      end

      fix.each do |label, environment|
        outcomes[label] = _helmfile(command: 'template', environment: environment, source: src)
        # If we got a yaml parse error, we will let the validation
        # take that into account, and output better diagnostics.
        outcomes[label].ignore_errors if outcomes[label].err =~ /YAML parse error/
      end
      outcomes
    end

    # Prepare an environment where we can safely run helmfile on the asset in parallel with others.
    def run_in_tmpdir(source, &block)
      helm_home = ENV['HELM_HOME'] || File.expand_path('~/.helm')
      # abort("unable to find helm home: #{helm_home}. Do you need to run helm init?") unless File.directory?(helm_home)
      dir_to_copy = File.join source, @path
      Dir.mktmpdir do |dir|
        local_helm_home = File.join dir, '.helm'
        if File.directory?(helm_home)
          FileUtils.cp_r helm_home, local_helm_home
        else
          FileUtils.mkdir_p local_helm_home
        end
        # Copy the original dir files to the tmpdir
        FileUtils.cp_Lr "#{dir_to_copy}/.", dir
        # Also copy over all charts (and common templates) here because concurrent "helm dep build"
        # would fail otherwise.
        # Copy all charts (and common templates) here because concurrent
        # "helm dep build" will fail otherwise.
        ['common_templates', 'charts', self.class::LISTENERS_FIXTURE].each do |what|
          FileUtils.cp_r File.join(source, what), dir
        end
        block.call dir
      end
    end

    # Patch helmfiles so that .fixtures.yaml is used instead of
    # * /etc/helmfile-defaults/general-#{env}.yaml for services helmfiles
    # * /etc/helmfile-defaults/private/admin/#{env}.yaml for admin_ng helmfiles
    # * For services, also add the service-proxy fixture
    # Also replace references to charts in wmf-stable repo with the local path,
    # and add --debug to the helm args
    def patch_helmfile(dir)
      charts_dir = File.join dir, 'charts'
      helmfile_glob = File.join(dir, '**/helmfile*.yaml')
      fixtures_file = File.join(dir, '.fixtures.yaml')
      FileList.new(helmfile_glob).each do |helmfile_path|
        content = File.read(helmfile_path)
        # Replace references to charts in the repository with local ones
        # to also catch changes to charts that are not released yet.
        content.gsub!(%r{^(\s*chart:\s+["']{0,1})wmf-stable/}, "\\1#{charts_dir.chomp('/').concat('/')}")
        # Prepend --debug to the list of args, so we get the yaml output even in case of error.
        content.gsub!(/^(\s*- )--kubeconfig$/m, "\\1--debug\n\\0")
        # Add fixtures.
        # For services, we patch helmfile unconditionally
        content.gsub!('/etc/helmfile-defaults/general-{{ .Environment.Name }}.yaml', fixtures_file)
        if File.exist? fixtures_file
          # Patch admin_ng as well, if the fixtures file exists
          content.gsub!('/etc/helmfile-defaults/private/admin/{{ .Environment.Name }}.yaml', fixtures_file)
        else
          # if the fixtures file doesn't exist, just use the listeners default fixture instead.
          # Please note that this won't affect admin fixtures.
          FileUtils.cp LISTENERS_FIXTURE, fixtures_file
        end
        File.write helmfile_path, content
      end
    end
  end

  # Class for testing admin assets.
  class AdminAsset < HelmfileAsset
    # Given we have only one admin asset with multiple "fixtures",
    # We allow to actually select the fixtures
    def filter_fixtures(to_run)
      @fixtures.filter! { |_, v| to_run.include?(v) } unless to_run.nil?
    end
  end
end
