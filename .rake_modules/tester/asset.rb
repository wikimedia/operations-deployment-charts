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
    KUBECONFORM_SCHEMA_LOCATIONS = [
      '/var/cache/kubeconform/{{ .NormalizedKubernetesVersion }}-standalone{{ .StrictSuffix }}/{{ .ResourceKind }}{{ .KindSuffix }}.json',
      '/var/cache/kubeconform/{{ .NormalizedKubernetesVersion }}/{{ .ResourceKind }}{{ .KindSuffix }}.json',
      './jsonschema/istio/{{ .ResourceKind }}_{{ .ResourceAPIVersion }}.json',
      './jsonschema/charts/{{ .ResourceKind }}_{{ .ResourceAPIVersion }}.json'
    ].map { |path| "-schema-location '#{path}'" }.join(' ').freeze
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

    # Returns a mapping of asset fixture to supported Kubernetes version, if
    # any.
    def kube_version
      @kube_version
    end

    # The public interfaces.
    # Run linting on the asset. Will need to be implemented in the subclasses
    def lint; end

    # Validate the manifest, by first verifying it's valid yaml,
    # then running it through kubeconform
    def validate(options)
      # Avoid running if the asset is marked as bad
      return unless should_test?

      r = @result[:validate]
      cached_templates.each do |label, outcome|
        r[label] = outcome
        # Given we run both helm and helmfile with --debug,
        # we move on to the next stages of validation even
        # if the rendered template is invalid, as our
        # validate_yaml has a better diagnostic output
        # than what helm gives us.
        #
        # So here we proceed to YAML validation even if
        # outcome.ok? is false as long as there was any
        # output to stdout (e.g. there is something to
        # validate).
        next if outcome.out.nil?

        r[label] = validate_yaml outcome
        next unless r[label].ok?

        if options[:kubeconform]
          r[label] = validate_kubeconform(label, outcome, options[:kube_versions])
        end
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
        manifest = outcome.ok? ? outcome.out : 'Template did not render correctly (HEAD of local branch).'
        if head.include?(label)
          head_outcome = head[label]
          head_manifest = head_outcome.ok? ? head_outcome.out : 'Template did not render correctly (HEAD of origin/master).'
        else
          # New asset!
          head_manifest = nil
        end
        diffs[label] = _diff(head_manifest, manifest)
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

    # Validates the provided manifest collection running every element through kubeconform
    def validate_kubeconform(label, outcome, versions)
      results = KubeconformTestOutcome.new

      tp = ThreadPool.new(nthreads: [versions.length, Etc.nprocessors].min)
      mutex = Mutex.new
      satisfied_versions = select_satisfied_versions(label, versions)
      satisfied_versions.each do |version|
        tp.run do
          # Run kubeconform
          testoutcome = _exec(
            "kubeconform -kubernetes-version #{version} #{KUBECONFORM_SCHEMA_LOCATIONS} -strict -summary", outcome.out
          )
          mutex.synchronize do
            results.add(version, testoutcome)
          end
        end
      end
      tp.join
      results
    end

    # Selects Kubernetes versions which satisfy the version constraint for a
    # specific fixture as returned by self.kube_version. If the fixture is not
    # present, all versions are returned. Version comparison relies on the
    # logic provided by github.com/Masterminds/semver
    def select_satisfied_versions(label, versions)
      if ! (self.kube_version and self.kube_version.has_key?(label))
        return versions
      end
      versions.select do |version|
        _, s = Open3.capture2e('semver-cli', 'satisfies', version, self.kube_version[label])
        s.exitstatus == 0
      end
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
    LISTENERS_FIXTURE = '.fixtures/service_proxy.yaml'

    def initialize(path, to_run = nil)
      super
      if should_run?
        chart_yaml = yaml_load_file(path)
        @library = chart_yaml['type'] == 'library'
        @kube_version = collect_kube_version(chart_yaml)
      end
    end

    def library?
      @library
    end

    def lint
      outcome = _exec("helm lint #{@path}")
      # surpress warnings about symlinks, see https://github.com/helm/helm/issues/7019
      outcome.grep_v(/found symbolic link/)
      @result[:lint] = outcome
    end

    private

    # Returns a mapping of fixture to supported kubeVersion of the chart. At
    # present the version is the same for all fixtures.
    def collect_kube_version(chart_yaml)
      return nil unless chart_yaml.key?('kubeVersion')

      @kube_version = fixtures.reduce({}) do |memo, (fixture, _)|
        memo[fixture] = chart_yaml['kubeVersion']
        memo
      end
    end

    # Returns a hash of fixture_name => fixture_path
    def collect_fixtures(chdir = nil)
      real_path = chdir.nil? ? @path : File.join(chdir, @path)
      return [] unless File.exist? real_path

      # There might be empty fixture files (crds.yaml for example) that
      # do have a meaning in a different context but won't actually change
      # rendered output of the chart. Skip those.
      fixtures = FileList.new("#{real_path}/.fixtures/*.yaml").reject { |f|
        f.include?(ChartAsset::PRIVATE_STUB) || File.size(f).zero?
      }
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
        # Always prepend the LISTENERS_FIXTURE file so charts don't have to define "services_proxy"
        # but can override that structure at will.
        command = "helm template --debug -f '#{LISTENERS_FIXTURE}' #{quoted} '#{@path}'"
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
    ENV_EXPLORE = %w[staging eqiad ml-serve-eqiad ml-staging-codfw dse-k8s-eqiad].freeze
    LISTENERS_FIXTURE = '.fixtures/service_proxy.yaml'
    INIT_RESULT = { lint: {}, validate: {}, diff: {} }.freeze

    def initialize(path, to_run)
      @helmfile = File.basename path
      @origin = Dir.pwd
      # This is a per-env list of charts that have versions pinned.
      super(path, to_run)
      @pinned_chart_versions = pinned_charts
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

    def collect_charts(chdir = nil)
      res = nil
      real_path = chdir.nil? ? path : File.join(chdir, path)
      return [] unless File.exist? real_path

      # Our helmfiles are templated. So we need to first produce a valid one using "helmfile build"
      self.class::ENV_EXPLORE.each do |env|
        res = _exec("helmfile -e #{env} build", nil, real_path)
        next unless res.ok?

        releases = YAML.safe_load(res.out)['releases']
        return releases.map { |release| release['chart'].gsub('wmf-stable/', '') }.uniq
      end
      []
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
        patch_helmfile(tmpdir, environment) if patch
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
        # Copy all charts (and common files) here because concurrent
        # "helm dep build" will fail otherwise.
        ['charts', self.class::LISTENERS_FIXTURE].each do |what|
          FileUtils.cp_r File.join(source, what), dir
        end
        block.call dir
      end
    end

    def pinned_charts
      results = {}
      # If we failed to build a base helmfile state, we bail out on this too.
      return results if @bad
      return results if @fixtures.nil?

      @fixtures.each_value do |env|
        res = _exec("helmfile -e #{env} build", nil, @path)
        next unless res.ok?

        manifest = YAML.safe_load(res.out)
        # We want to gather: chart name => version for all releases that have a pinned version.
        results[env] = manifest['releases'].select { |r| r['version'] }.map { |r| [r['chart'], r['version']] }.to_h
      end
      results
    end

    # Patch helmfiles so that .fixtures.yaml is used instead of
    # * /etc/helmfile-defaults/general-#{env}.yaml for services helmfiles
    # * /etc/helmfile-defaults/private/admin/#{env}.yaml for admin_ng helmfiles
    # * For services, also add the service-proxy fixture
    # Also replace references to charts in wmf-stable repo with the local path,
    # and add --debug to the helm args
    #
    def patch_helmfile(dir, env)
      # First run helmfile build to find any chart that has a pinned version
      charts_dir = File.join dir, 'charts'
      helmfile_glob = File.join(dir, '**/helmfile*.yaml')
      fixtures_file = File.join(dir, '.fixtures.yaml')
      FileList.new(helmfile_glob).each do |helmfile_path|
        # Replace references to charts in the repository with local ones
        # to also catch changes to charts that are not released yet.
        content = patch_charts(helmfile_path, env, charts_dir)

        # Prepend --debug to the list of args, so we get the yaml output even in case of error.
        content.gsub!(/^(\s*- )--kubeconfig$/m, "\\1--debug\n\\0")

        # Add fixtures.
        # For services, we patch helmfile unconditionally, then if the file doesn't exist, we copy
        # the default listeners file over. For admin, we only patch helmfile if the fixtures file exists.
        content.gsub!('/etc/helmfile-defaults/general-{{ .Environment.Name }}.yaml', fixtures_file)
        if File.exist? fixtures_file
          # Patch admin_ng as well, if the fixtures file exists
          content.gsub!('/etc/helmfile-defaults/private/admin/{{ .Environment.Name }}.yaml', fixtures_file)
        else
          # Please note that this won't affect admin fixtures.
          FileUtils.cp LISTENERS_FIXTURE, fixtures_file
        end
        File.write helmfile_path, content
      end
    end

    # Patch the chart names to point to the local filesystem rather than our
    # repository. This is done so that changes in the chart in the current change
    # are accounted for when building validation/diffs.
    # As a complication, some charts now have a pinned version; sadly helmfile ignores the pinned
    # version if we patch the chart to be sourced locally.
    # So, scan the whole helmfile for chart: entries and find if they have a related version entry.
    # Given versions are typically templated, we want to ensure that a version is indeed pinned in this
    # environment.
    # There are limits to this approach, because we can't just template out the whole helmfile.
    # This function returns the content already patched for charts.
    def patch_charts(filepath, env, charts_dir)
      content = File.readlines(filepath)
      chart = nil
      version = false
      last_chart_match = 0
      lines_to_patch = []
      content.each_index do |i|
        line = content[i]
        chart_match = line.match(%r{^\s*chart:\s+["']{0,1}(wmf-stable/.*)["']{0,1}$})
        if chart_match
          # If we already had a chart, we are in a new chart stanza. We want to patch out last
          lines_to_patch << last_chart_match if should_patch?(env, chart, version)
          last_chart_match = i
          chart = chart_match[1]
          version = false
          next
        end
        # Please note: this will only work if version: always comes after chart: or the opposite.
        # anything more complex would've been an overkill.
        if line.match(/^\s*version:\s+["']{0,1}(.*)["']{0,1}$/)
          version = true
          next
        end
      end
      # Add the remaining chart match if any
      lines_to_patch << last_chart_match if should_patch?(env, chart, version)
      # Now patch all the lines to patch
      lines_to_patch.each do |to_patch|
        content[to_patch].gsub!(
          %r{^(\s*chart:\s+["']{0,1})wmf-stable/}, "\\1#{charts_dir.chomp('/').concat('/')}"
        )
      end
      content.join
    end

    def should_patch?(env, chart, version)
      if chart.nil?
        false
      elsif !version
        true
      else
        @pinned_chart_versions[env][chart].nil?
      end
    end
  end

  # Class for testing admin assets.
  class AdminAsset < HelmfileAsset

    def initialize(path, to_run = nil)
      super
      if should_run?
        @kube_version = collect_kube_version(path)
      end
    end

    # Given we have only one admin asset with multiple "fixtures",
    # We allow to actually select the fixtures
    def filter_fixtures(to_run)
      @fixtures.filter! { |_, v| to_run.include?(v) } unless to_run.nil?
    end

    private

    # Returns a mapping of fixture(environment) to the configured
    # kubernetesVersion of the environment.
    def collect_kube_version(path)
      fixtures.reduce({}) do |memo, (fixture, env)|
        env_vals_path = "#{File.dirname(path)}/values/#{env}/values.yaml"
        if File.exist?(env_vals_path)
          env_vals = yaml_load_file(env_vals_path)
          if env_vals and env_vals.has_key?('kubernetesVersion')
            memo[fixture] = env_vals['kubernetesVersion']
          else
            raise "Required key 'kubernetesVersion' not found in: '#{env_vals_path}'"
          end
        else
          raise "Required values file, '#{env_vals_path}', for env, '#{env}', not found"
        end
        memo
      end
    end

  end
end
