require 'rake'
require 'tmpdir'
require 'rake/tasklib'
require 'open3'
require 'yaml'
require 'readline'
require 'digest/md5'
require 'fileutils'

# Load local modules
$LOAD_PATH.unshift File.expand_path('.')
require '.rake_modules/scaffold'
require '.rake_modules/monkeypatch'
require '.rake_modules/utils'

PRIVATE_STUB = '.fixtures/private_stub.yaml'.freeze
HELM_REPO = 'stable'.freeze
HELMFILE_GLOB = 'helmfile.d/*services/**/helmfile.yaml'.freeze
CHARTS_GLOB = 'charts/**/Chart.yaml'.freeze
KUBERNETES_VERSIONS = '1.19,1.16'.freeze
HELMFILE_ENV = 'eqiad'.freeze
ISTIOCTL_VERSION = 'istioctl-1.9.5'.freeze

# admin_validate will store the generated manifest files here to be used by admin_diff
admin_ng_manifests = {}

# all_charts stores a list of all chart directories
all_charts = FileList.new(CHARTS_GLOB).map { |x| File.dirname(x) }

# execute helm template
def exec_helm_template(chart, fixture = nil)
  if !fixture.nil?
    # When passing multiple values, concatenate them
    quoted = fixture.map { |x| "-f '#{x}'" }.join ' '
    command = "helm template #{quoted} '#{chart}'"
    error = "Error checking #{chart}, value files: #{fixture}"
  else
    command = "helm template '#{chart}'"
    error = "Error checking #{chart}"
  end
  ret = _exec command
  ret.append(command)
  ret
end

# Run an helmfile command on each environment declared in source (unless environments are passed as argument)
# Returns an hash environment => block.call success, output
def exec_helmfile_command(command, source, environments = nil, &block)
  results = {}
  helm_home = ENV['HELM_HOME'] || File.expand_path('~/.helm')
  dir_to_copy, helmfile_name = File.split source
  environments = environments.is_a?(String) ? [environments] : environments
  return {} unless File.directory? dir_to_copy

  Dir.mktmpdir do |dir|
    # Copy HELM_HOME so that we don't incur in race conditions when running in
    # parallel, see T261313
    local_helm_home = File.join dir, '.helm'
    abort("unable to find helm home: #{helm_home}. Do you need to run helm init?") unless File.directory?(helm_home)
    FileUtils.cp_r helm_home, local_helm_home
    # Copy the original dir files to the tmpdir
    FileUtils.cp_r "#{dir_to_copy}/.", dir

    # Copy all charts (and common templates) here because concurrent
    # "helm dep build" will fail otherwise.
    FileUtils.cp_r File.join(File.dirname(__FILE__), "common_templates"), dir
    FileUtils.cp_r File.join(File.dirname(__FILE__), "charts"), dir
    tmp_charts_dir = File.join(dir, 'charts')
    main_helmfile_path = File.join dir, helmfile_name
    fixtures = File.join(dir, '.fixtures.yaml')

    # Patch helmfiles so that .fixtures.yaml is used instead of
    # * /etc/helmfile-defaults/general-#{env}.yaml for services helmfiles
    # * /etc/helmfile-defaults/private/admin/#{env}.yaml for admin_ng helmfiles
    # Also replace references to charts in wmf-stable repo with the local path.
    #
    # The files are go text-templates so we can't load the yaml and modify it.
    helmfile_glob = File.join(dir, '**/helmfile*.yaml')
    FileList.new(helmfile_glob).each do |helmfile_path|
      helmfile = File.read(helmfile_path)
      # Replace references to charts in the repository with local ones
      # to also catch changes to charts that are not released yet.
      helmfile.gsub!(/^(\s*chart:\s+["']{0,1})wmf-stable\//, "\\1#{tmp_charts_dir.chomp('/').concat('/')}")
      if File.exist? fixtures
        # For service helmfiles
        helmfile.gsub!('/etc/helmfile-defaults/general-{{ .Environment.Name }}.yaml', fixtures)
        # For admin_ng helmfiles
        helmfile.gsub!('/etc/helmfile-defaults/private/admin/{{ .Environment.Name }}.yaml', fixtures)
      end
      File.write helmfile_path, helmfile
    end

    if environments
      envs = environments
    else
      # Run helmfile build to verify the helmfile is sane.
      # If it is, the output of build will be used to parse all defined environments from.
      data = nil
      all_data = {}
      ok = false
      ['staging', 'eqiad', 'ml-serve-eqiad'].each do |e|
        ok, data = _exec "HELM_HOME=#{local_helm_home} helmfile -e #{e} -f #{main_helmfile_path} build", nil, false
        all_data[e] = data
        break if ok
      end
      # If we can't run helmfile build, we need to bail out early.
      unless ok
        puts("Failed to run helmfile build in #{dir_to_copy}:".red)
        all_data.each do |env, errdata|
          puts("#{env} => #{errdata}")
        end
        return { 'default' => false }
      end

      helmfile_raw_data = YAML.safe_load(data)
      envs = helmfile_raw_data['environments'].keys
    end

    # now for each environment, run helmfile
    # --skip-deps skips updating repositories and helm chart dependencies over and over again.
    # This requires the dependencies to be available in the git checkout, but this is how we currently
    # handle it anyways.
    envs.each do |env|
      result = _exec "HELM_HOME=#{local_helm_home} helmfile -e #{env} -f #{main_helmfile_path} #{command} --skip-deps"
      results[env] = block.call env, result
    end
  end
  results
end

# Checks an helm chart.
# Does so by running helm template (injecting value fixture files if present)
# If kubeyaml is available, also run kubeyaml.
def check_template(chart, fixture = nil, kubeyaml = nil)
  success, output, command = exec_helm_template(chart, fixture)
  if success
    docs = []
    begin
      YAML.load_stream(output) do |resource|
        next unless resource

        docs << resource['kind']
        # not doing anything here, we're just verifying it loads for now.
      end
    rescue Psych::SyntaxError => e
      if fixture.nil?
        args = ""
      else
        args = "-f #{fixture.join(' -f ')}"
      end
      report_yaml_parse_error("helm template #{chart} #{args}", 'Error parsing the helm template output', output, e)
      success = false
    rescue StandardError => e
      success = false
      puts "Error parsing the helm template output".red
      puts e
    end
    if kubeyaml && success
      validate_with_kubeyaml(output) do |source, result|
        ok, out = result
        unless ok
          puts 'Semantical error during YAML validation'
          puts "Kubeyaml says:\n#{out}\n for: #{source}"
          success = ok
        end
      end
    end
  else
    # Error happens before yaml validation
    puts "Error running \"#{command}\":".red
    puts output
  end
  success
end

# parses an helmfile and returns the status of running 'helmfile lint'
# for all environments.
# The return data are organized as follows:
#  {environment: true/false}
def validate_helmfile_full(filepath)
  results = exec_helmfile_command('lint', filepath) do |_, result|
    ok, out = result
    puts(out) unless ok
    ok
  end
  results
end

def get_extra_args(args, fallback = nil)
  if args.nil? || args.extras.count == 0
    extras = fallback
  else
    extras = args.extras
  end
end

# (jayme): I might be missing something, but I don't think this is working.
# I did expect `rake lint[calico,secrets]` to work for example but it does not.
def get_charts(args, fallback)
  if args.nil? || args.count == 0
    charts = fallback
  else
    charts = args[:charts]
    charts = charts.split(',').map { |d| "charts/#{d}" } if charts.is_a?(String)
  end
  charts
end

# Runs the code in block by passing to it
# chart, fixture, additional_args
# and returns the results in a hash
def run_with_fixtures(charts, additional_args = nil, &block)
  results = {}
  charts.each do |chart|
    results[chart] = block.call chart, nil, additional_args
    fixtures = FileList.new("#{chart}/.fixtures/*.yaml")
    fixtures.each do |fixture|
      # Exclude the private stub if present.
      next if fixture.include? PRIVATE_STUB

      fixture_name = File.basename(fixture, '.yaml')
      results["#{chart} => #{fixture_name}"] = block.call chart, [fixture], additional_args
    end
  end
  results
end

# Get the resulting manifests for all helmfiles in the deployments list
# The results are returned in the format: {"deployment/environment": manifest}
def get_all_manifests(deployments)
  tp = ThreadPool.new(nthreads: 3)
  mutex = Mutex.new
  results = {}
  deployments.each do |helmfile|
    tp.run do
      _radix, deployment = File.split(File.dirname(helmfile))
      # Skip the example, and env-wide helmfiles
      next if ['_example_'].include? deployment

      manifests = exec_helmfile_command('template', helmfile) do |_, result|
        if result[0]
          result[1]
        else
          puts("Failed to helmfile template #{helmfile}".red)
          puts(result[1])
          ''
        end
      end

      mutex.synchronize do
        manifests.each do |cluster, manifest|
          results["#{deployment}/#{cluster}"] = manifest
        end
      end
    end
  end
  tp.join
  results
end

# Validate all YAML documents in document (expecting a single string, as generates by helm(file) template)
# via kubeyaml
def validate_with_kubeyaml(document, &block)
  # Prior to extracting this function, kubeyaml was running with nthreads = number of docs
  tp = ThreadPool.new(nthreads: 10)
  mutex = Mutex.new
  results = {}
  command = "kubeyaml -versions #{KUBERNETES_VERSIONS}"
  # Kubeyaml does only validate the first object in a yaml stream.
  # See https://github.com/chuckha/kubeyaml/issues/7
  docs = document.split(/^---/)
  source = ""
  docs.each do |doc|
    tp.run do
      # There may be multiple objects (doc) in one source file (document).
      # In that case, no new Source line is emitted for following objects
      # and we need to reuse the last one.
      if source_match = doc.match(%r{^# Source: ([a-zA-Z0-9\/\.-]*)$})
        new_source = source_match.captures[0]
        if new_source != source
          mutex.synchronize do
            source = source_match.captures[0]
          end
        end
      end
      # Remove the # Source: line. It can be helpful if the template ends up
      # fully empty as kubeyaml won't then emit a useless warning
      doc = doc.strip.gsub(%r{^# Source: [a-zA-Z0-9\/\.-]*$}, '').strip
      next if doc.length == 0

      result = _exec command, doc, true
      mutex.synchronize do
        results[source] = block.call source, result
      end
    end
  end
  tp.join
  results
end


## RAKE TASKS

desc 'Checks dependencies'
task :check_dep do
  check_binary('helm')
  check_binary('helmfile')

  res, output = _exec("helm version --short")
  helm_version = output.split(".").first

  if helm_version != "v3"
    raise('helm2 not supported, use helm3 binary')
  end

end

# This is to ensure that all repos are available and up to date
desc 'Add and update all needed helm repositories'
task repo_update: :check_dep do
  repo_urls = []
  all_charts.each do |path_to_chart|
    path_to_chart_yaml = File.join path_to_chart, 'Chart.yaml'
    chart_yaml = yaml_load_file(path_to_chart_yaml)
    dependencies = []
    # remove v1 support after T295750
    if chart_yaml['apiVersion'] == 'v1'
      # Read requirements.yaml
      path_to_requirements_yaml = File.join path_to_chart, 'requirements.yaml'
      next unless File.exists? path_to_requirements_yaml
      requirements_yaml = yaml_load_file(path_to_requirements_yaml)
      if requirements_yaml['dependencies']
        dependencies = requirements_yaml['dependencies']
      end
    elsif chart_yaml['apiVersion'] == 'v2'
      # Dependencies are to be defined in Chart.yaml
      if chart_yaml['dependencies']
        dependencies = chart_yaml['depencencies']
      end
    else
      puts error.red
      puts e
      raise('Failed to determine helm version to use')
    end

    next unless dependencies
    dependencies.each do |dep|
      raise("Only http(s) URLs supported for helm dependencies (#{path_to_chart_yaml})") unless dep['repository'].match(/^http/)
      repo_urls << dep['repository'].chomp('/')
    end
  end

  repo_urls.uniq.each do |repo_url|
    repo_hash = Digest::MD5.hexdigest(repo_url)
    puts("Adding helm repo #{repo_url} as #{repo_hash}")
    system("helm repo add --force-update #{repo_hash} #{repo_url}")
  end
  system('helm repo update')
end

desc 'Runs helm lint on all charts'
task :lint, [:charts] => :repo_update do |_t, args|
  charts = get_charts(args, all_charts)
  results = {}
  charts.each do |chart|
    puts "Linting #{chart} with helm"
    res, output = _exec("helm lint '#{chart}'")
    results[chart] = res
    # surpress warnings about symlinks, see https://github.com/helm/helm/issues/7019
    puts output.split("\n").select{|l| !l[/found symbolic link/] }
  end
  pprint 'Helm lint summary:', results
  raise_if_failed results
end

desc 'Runs helm template on all charts and validate the output with kubeyaml'
task :validate_template, [:charts] => :repo_update do |_t, args|
  charts = get_charts(args, all_charts)

  # Detect kubeyaml, if present also semantically validate YAML
  # Note that we only do this in this task, to avoid heavily increased execution
  # times
  kubeyaml_path = which('kubeyaml')
  results = run_with_fixtures(charts, kubeyaml_path) do |chart, fixtures, kubeyaml|
    check_template chart, fixtures, kubeyaml
  end
  pprint 'Helm template summary:', results
  raise_if_failed results
end

desc 'Runs helmfile lint on all service deployments'
task validate_deployments: :repo_update do
  results = {}
  deployments = FileList.new(HELMFILE_GLOB)
  # Do not overwhelm the charts repo,
  # run at most 3 threads at once
  tp = ThreadPool.new(nthreads: 3)
  mutex = Mutex.new
  deployments.each do |helmfile|
    tp.run do
      radix, deployment = File.split(File.dirname(helmfile))
      # Skip the example, and env-wide helmfiles
      next if ['_example_'].include? deployment

      deployment_results = validate_helmfile_full helmfile

      mutex.synchronize do
        deployment_results.each do |cluster, outcome|
          results["#{deployment}/#{cluster}"] = outcome
        end
      end
    end
  end
  tp.join
  pprint 'Helmfile deployments check summary:', results
  raise_if_failed results
end

desc 'Validate the envoy configuration'
task validate_envoy_config: :check_dep do
  puts 'Generating and verifying the envoy configuration...'
  # run helm template for a specific fixture that generates a service proxy and tls terminator
  command = 'helm template --values .fixtures/envoy_proxy.yaml charts/tegola-vector-tiles'
  res, out = _exec command
  unless res
    puts out.red
    raise('Failure generating the helm manifest')
  end
  # Extract the envoy configuration, write it to a file
  begin
    error = 'Extracting envoy config from "helm template" output'
    config = ''
    YAML.load_stream(out) do |resource|
      next unless resource != nil \
        && resource['kind'] == 'ConfigMap' \
        && resource['metadata'] \
        && resource['metadata']['name'] \
        && resource['metadata']['name'].end_with?('envoy-config-volume')
      config = resource['data']['envoy.yaml']
    end
  rescue StandardError => e
    puts error.red
    puts e
    raise('Failure reading the helm yaml template')
  end
  begin
    error = 'Parsing envoy.yaml'
    YAML.safe_load(config)
  rescue Psych::SyntaxError => e
    report_yaml_parse_error(command, error, config, e)
    raise('Failure parsing envoy YAML configuration')
  rescue StandardError => e
    puts error.red
    puts e
    raise('Generic failure interpreting envoy YAML configuration')
  end

  has_envoy = system('which envoy > /dev/null 2>&1')
  if has_envoy
    dest = '/etc/envoy'
  else
    dest = '.tmp'
    # Now create a temp directory where we write the yaml file, then run docker to verify it works.
    FileUtils.mkdir '.tmp', mode: 0o777
    at_exit { FileUtils.remove_entry '.tmp' }
  end

  f = File.open "#{dest}/envoy.yaml", 'w'
  f.write config
  f.close
  # If we're copying the file into the container, it needs to be world-readable
  File.chmod 0o755, "#{dest}/envoy.yaml" unless has_envoy

  FileUtils.cp_r('.fixtures/ssl/', "#{dest}/")

  if has_envoy
    cmd = 'envoy --mode validate -c /etc/envoy/envoy.yaml'
  else
    path = File.realpath '.tmp'
    cmd = "docker run --rm -v #{path}:/etc/envoy docker-registry.wikimedia.org/envoy:latest envoy --mode validate -c /etc/envoy/envoy.yaml"
  end
  res, out = _exec cmd
  if !res
    puts out.red
    raise('Failure')
  else
    puts out.green
  end
end

# Scaffolding
desc 'Create a new chart'
task :scaffold, [:image, :service, :port] do |_task, args|
  def get_data(arg, msg)
    if arg.nil?
      puts msg
      Readline.readline('> ', true)
    else
      arg
    end
  end
  port = get_data(args[:port], 'Please input the PORT on which the service will run')
  service = get_data(args[:service], 'Please input the NAME of the service')
  image = get_data(args[:image], 'Please input the IMAGE full label for the service')

  sc = Scaffold.new(image, service, port)
  sc.run
end

desc 'Validate a sample chart generated from scaffolding'
task test_scaffold: :check_dep do
  charts = ['charts/test-scaffold']
  begin
    # run scaffolding first
    sc = Scaffold.new('example', 'test-scaffold', '9090')
    sc.run
    # Add a fixture for php apps
    File.open('charts/test-scaffold/.fixtures/php.yaml', 'w') do |fh|
      data = { main_app: { type: 'php' } }
      fh.write(data.to_yaml)
    end
    Rake::Task[:lint].invoke(charts)
    Rake::Task[:lint].reenable
    Rake::Task[:validate_template].invoke(charts)
    Rake::Task[:validate_template].reenable
  ensure
    FileUtils.rm_rf(charts[0])
  end
end

desc 'Show diff introduced by the patch'
task :helm_diffs, [:charts] => :repo_update do |_t, args|
  charts = get_charts(args, all_charts)
  change = {}
  change = run_with_fixtures(charts) do |chart, fixtures, _|
    exec_helm_template(chart, fixtures)
  end
  original = {}
  Git.open('.').back_to('origin/master') do
    all_original_charts = FileList.new(CHARTS_GLOB).map { |x| File.dirname(x) }
    original_charts = get_charts(args, all_original_charts)
    original = run_with_fixtures(original_charts) do |chart, fixtures, _|
      exec_helm_template(chart, fixtures)
    end
  end
  puts("Helm diffs summary:\n\n")
  change.each do |label, result|
    success, manifest = result
    if success
      # New chart
      if !original.include?(label)
        diffs = manifest
      else
        orig_manifest = original[label][1]
        diffs = diff(orig_manifest, manifest)
      end
      if diffs != ''
        puts "#{label.ljust(72)}DIFFS FOUND#{' (new chart)' if !original.include?(label)}"
        puts diffs
      end
    else
      puts "#{label.ljust(72)}#{manifest.red}"
    end
  end
end

desc 'Show diffs in deployments introduced by the patch'
task deployment_diffs: %i[check_dep repo_update] do
  results = {}
  deployments = FileList.new(HELMFILE_GLOB)
  # Do not overwhelm the charts repo,
  # run at most 3 threads at once

  change = get_all_manifests(deployments)
  original = {}
  # Now get the originals
  Git.open('.').back_to('origin/master') do
    original_deployments = FileList.new(HELMFILE_GLOB)
    original = get_all_manifests(original_deployments)
  end
  puts("Deployment diffs summary:\n\n")
  change.each do |label, manifest|
    # If the deployment is new, we want to output it all as a diff.
    original_manifest = if original.include? label
                          original[label]
                        else
                          ''
    end
    diffs = diff(original_manifest, manifest)
    if diffs != ''
      puts "#{label.ljust(72)}DIFFS FOUND#{' (new deployment)' if original_manifest == ''}"
      puts diffs
    end
  end
end

## RAKE TASKS admin_ng

desc 'Runs helmfile lint on admin_ng for all environments'
task admin_lint: %i[check_dep repo_update] do
  results = validate_helmfile_full 'helmfile.d/admin_ng/helmfile.yaml'
  pprint 'admin_ng helmfile deployments lint summary:', results
  raise_if_failed results
end

desc 'Runs helmfile template on admin_ng for all environments and validate the output with kubeyaml'
task admin_validate: %i[check_dep repo_update] do |_t, args|
  check_binary('kubeyaml')
  helmfile_path = 'helmfile.d/admin_ng/helmfile.yaml'
  helmfile_envs = YAML.safe_load(File.read(helmfile_path))['environments'].keys
  envs = get_extra_args(args, helmfile_envs)
  results = {}

  puts "Generating and verifying admin_ng templates #{envs}..."
  tp = ThreadPool.new(nthreads: 3)
  mutex = Mutex.new
  envs.each do |env|
    tp.run do
      result = exec_helmfile_command('template', helmfile_path, env) do |e, r|
        ok, out = r
        print "admin_ng helmfile template (#{e}): "
        if ok
          puts "OK".green
        else
          puts "FAIL".red
          puts out
          raise('Failure')
        end
        out
      end

      mutex.synchronize do
        results[env] = result[env]
      end
    end
  end
  tp.join

  # validate_with_kubeyaml runs in multiple threads as well, so don't place it in the above block
  results.each do |env, document|
    print "admin_ng kubeyaml (#{env}): "
    validate_with_kubeyaml(document) do |source, result|
      ok, out = result
      unless ok
        puts "FAIL".red
        puts "Error validating semantically YAML for #{env}"
        puts "Kubeyaml says:\n#{out}\n for: #{source}"
        raise('Failure')
      end
    end
    puts "OK".green
  end

  # Store the manifests in a global variable for use by admin_diff
  admin_ng_manifests = results
end

desc 'Shows admin diff introduced by this patch'
task admin_diff: %i[check_dep repo_update admin_validate] do |_t, args|
  helmfile_path = 'helmfile.d/admin_ng/helmfile.yaml'
  helmfile_envs = YAML.safe_load(File.read(helmfile_path))['environments'].keys
  envs = get_extra_args(args, helmfile_envs)
  change = admin_ng_manifests # populated by admin_validate

  # Now get the originals
  original = {}
  Git.open('.').back_to('origin/master') do
    tp = ThreadPool.new(nthreads: 3)
    mutex = Mutex.new
    tp.run do
      envs.each do |env|
        result = exec_helmfile_command('template', helmfile_path, env) do |_, r|
          r[1]
        end
        mutex.synchronize do
          original[env] = result[env]
        end
      end
    end
    tp.join
  end
  change.each do |env, manifest|
    # If the deployment is new, we want to output it all as a diff.
    original_manifest = if original.include? env
                          original[env]
                        else
                          ''
    end
    diffs = diff(original_manifest, manifest)
    if diffs != ''
      puts "#{env.ljust(72)}DIFFS FOUND"
      puts diffs
      puts "\n"
    end
  end
end


## RAKE TASKS custom_deploy

desc 'Validate istio configuration'
task :validate_istio_config do
  check_binary(ISTIOCTL_VERSION)
  FileList.new('custom_deploy.d/istio/*/config.yaml').each do |config|
    ok, out = _exec "#{ISTIOCTL_VERSION} validate -f #{config}"
    unless ok
      puts "Failed to verify istio config '#{config}':".red
      puts out
      raise('Failure')
    end
  end
end

desc 'Run other tasks locally within the CI docker images'
task :run_locally, [:cmdargs] do |_t, args|
  check_docker
  cmdargs = if args.nil? || args.count.zero?
              ''
            else
              args[:cmdargs]
            end
  Dir.mktmpdir do |dir|
    puts "Copying and committing code to #{dir}"
    FileUtils.cp_r('.', dir)
    Dir.chdir dir do
      g = Git.open('.')
      # Change origin to anonymous https
      g.refresh_remote('origin', force = true)
      # Commit any outstanding file
      if g.diff('HEAD', '.').size != 0
        g.add(all: true)
        g.commit('running_diffs')
      end
      puts 'Now running in docker'
      cmd = [
        'docker',
        'run',
        '--pull always',
        '--rm',
        "--user #{Process.uid}",
        "-v #{dir}:/src:rw",
        '-v /etc/passwd:/etc/passwd:ro',
        '-v /etc/group:/etc/group:ro',
        'docker-registry.wikimedia.org/releng/helm-linter:latest',
        cmdargs
      ].join(' ')
      puts cmd
      puts `#{cmd}`
    end
  end
end

task default: %i[repo_update test_scaffold lint validate_template validate_deployments validate_envoy_config validate_istio_config helm_diffs deployment_diffs admin_lint admin_diff]
