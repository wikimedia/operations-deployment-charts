require 'rake'
require 'tmpdir'
require 'rake/tasklib'
require 'open3'
require 'yaml'
require 'readline'

require 'fileutils'

# Load local modules
$LOAD_PATH.unshift File.expand_path('.')
require '.rake_modules/scaffold'
require '.rake_modules/monkeypatch'
require '.rake_modules/utils'

PRIVATE_STUB = '.fixtures/private_stub.yaml'.freeze
HELM_REPO = 'stable'.freeze
HELMFILE_GLOB = 'helmfile.d/services/**/helmfile.yaml'.freeze
KUBERNETES_VERSIONS = '1.19,1.16'.freeze
HELMFILE_ENV = 'eqiad'.freeze

# execute helm template
def exec_helm_template(chart, fixture = nil)
  helm = helm_version(chart)
  if !fixture.nil?
    # When passing multiple values, concatenate them
    quoted = fixture.map { |x| "-f '#{x}'" }.join ' '
    command = "#{helm} template #{quoted} '#{chart}'"
    error = "Error checking #{chart}, value files: #{fixture}"
  else
    command = "#{helm} template '#{chart}'"
    error = "Error checking #{chart}"
  end
  ret = _exec command
  ret.append(command)
  ret
end

# Run an helmfile command on each environment declared in source.
# Returns an hash environment => block.call success, output
def exec_helmfile_command(command, source, &block)
  results = {}
  helm_home = ENV['HELM_HOME'] || File.expand_path('~/.helm')
  dir_to_copy, file = File.split source
  return {} unless File.directory? dir_to_copy

  Dir.mktmpdir do |dir|
    # Copy HELM_HOME so that we don't incur in race conditions when running in
    # parallel, see T261313
    local_helm_home = File.join dir, '.helm'
    abort("unable to find helm home: #{helm_home}. Do you need to run helm init?") unless File.directory?(helm_home)
    FileUtils.cp_r helm_home, local_helm_home
    # Copy the original dir files to the tmpdir
    FileUtils.cp_r "#{dir_to_copy}/.", dir
    filename = File.join dir, file
    fixtures = File.join(dir, '.fixtures.yaml')
    source = File.read(filename)

    # Patch helmfile so that .fixtures.yaml is used instead of
    # /etc/helmfile-defaults/general-#{env}.yaml
    # The file is a go text-template so we can't load the yaml and modify it.
    if File.exist? fixtures
      source.sub!('/etc/helmfile-defaults/general-{{ .Environment.Name }}.yaml', fixtures)
      File.write filename, source
    end

    data = nil
    ['staging', 'eqiad'].each do |e|
      ok, data = _exec "HELM_HOME=#{local_helm_home} helmfile -e #{e} -f #{filename} build", nil, true
      break if ok
    end
    # If we can't run helmfile build, we need to bail out early.
    return { 'default' => false } if data.nil?

    helmfile_raw_data = YAML.safe_load(data)
    envs = helmfile_raw_data['environments'].keys

    # now for each environment, build the list of
    # helm commands to run
    envs.each do |env|
      result = _exec "HELM_HOME=#{local_helm_home} helmfile -e #{env} -f #{filename} #{command}"
      results[env] = block.call result
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
      report_yaml_parse_error("helm template #{chart} -f #{fixture.join(' -f ')}", 'Error parsing the helm template output', output, e)
      success = false
    rescue StandardError => e
      success = false
      puts "Error parsing the helm template output".red
      puts e
    end
    if kubeyaml
      threads = []
      command = "#{kubeyaml} -versions #{KUBERNETES_VERSIONS}"
      # split per YAML doc. See GH issue #7 as to why
      docs = output.split(/^---/)
      docs.each do |doc|
        t = Thread.new do
          # Remove the # Source: line. It can be helpful if the template ends up
          # fully empty as kubeyaml won't then emit a useless warning
          source = doc.match(%r{^# Source: [a-zA-Z0-9/\.-]*$})
          doc = doc.strip.gsub(%r{^# Source: [a-zA-Z0-9/\.-]*$}, '').strip
          next if doc.length == 0

          succ, out = _exec command, doc, true
          unless succ
            puts 'Error validating semantically YAML'
            puts "Kubeyaml says:\n#{out}\n for:\n#{source}"
            success = succ
          end
        end
        threads.push(t)
      end
      threads.each { |t| t.join }
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
  results = exec_helmfile_command('lint', filepath) do |result|
    ok, out = result
    puts(out) unless ok
    ok
  end
  results
end

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

      manifests = exec_helmfile_command('template', helmfile) do |result|
        if result[0]
          result[1]
        else
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

## RAKE TASKS

desc 'Checks dependencies'
task :check_dep do
  check_binary('helm')
  check_binary('helm3')
end

# This is just to ensure the repo is up to date as one may
# experience weird behaviour if not.
desc 'Runs helm(2/3) repo update'
task repo_update: :check_dep do
  system('helm repo update')
  system('helm3 repo update')
end

all_charts = FileList.new('charts/**/Chart.yaml').map { |x| File.dirname(x) }
desc 'Runs helm lint on all charts'
task :lint, [:charts] => :check_dep do |_t, args|
  charts = get_charts(args, all_charts)
  results = {}
  charts.each do |chart|
    puts "Linting #{chart}"
    helm = helm_version(chart)
    results[chart] = system("#{helm} lint '#{chart}'")
  end
  pprint 'Helm lint summary:', results
  raise_if_failed results
end

desc 'Runs helm template on all charts'
task :validate_template, [:charts] => :check_dep do |_t, args|
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

desc 'Runs helm template using the helmfile values'
task validate_deployments: :check_dep do
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
  command = 'helm template --values .fixtures/service_discovery.yaml charts/termbox'
  res, out = _exec command
  unless res
    puts out.red
    raise('Failure generating the helm manifest')
  end
  # Extract the envoy configuration, write it to a file
  begin
    config = ''
    YAML.load_stream(out) do |resource|
      next unless resource['kind'] == 'ConfigMap' \
        && resource['metadata'] \
        && resource['metadata']['name'] \
        && resource['metadata']['name'].end_with?('envoy-config-volume')

      config = resource['data']['envoy.yaml']
    end
  rescue StandardError => e
    puts e.red
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
task :helm_diffs, [:charts] => :check_dep do |_t, args|
  charts = get_charts(args, all_charts)
  change = {}
  change = run_with_fixtures(charts) do |chart, fixtures, _|
    exec_helm_template(chart, fixtures)
  end
  original = {}
  Git.open('.').back_to('origin/master') do
    all_original_charts = FileList.new('charts/**/Chart.yaml').map { |x| File.dirname(x) }
    original_charts = get_charts(args, all_original_charts)
    original = run_with_fixtures(original_charts) do |chart, fixtures, _|
      exec_helm_template(chart, fixtures)
    end
  end
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
        puts "#{label.ljust(72)}DIFFS FOUND"
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
  change.each do |label, manifest|
    # If the deployment is new, we want to output it all as a diff.
    original_manifest = if original.include? label
                          original[label]
                        else
                          ''
    end
    diffs = diff(original_manifest, manifest)
    if diffs != ''
      puts "#{label.ljust(72)}DIFFS FOUND"
      puts diffs
    end
  end
end

def check_docker
  unless which('docker')
    puts 'You need to install docker'.red
    raise
  end
  `docker version`
  if $?.exitstatus != 0
    puts "You need to be able to run docker commands as uid #{Process.uid}"
    raise
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

task default: %i[repo_update test_scaffold lint validate_template validate_deployments validate_envoy_config helm_diffs deployment_diffs]
