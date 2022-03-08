require 'rake'
require 'tmpdir'
require 'rake/tasklib'
require 'open3'
require 'yaml'
require 'readline'
require 'digest/md5'
require 'fileutils'
require 'open-uri'
require 'base64'

# Load local modules
require_relative '.rake_modules/scaffold'
require_relative '.rake_modules/monkeypatch'
require_relative '.rake_modules/utils'
require_relative '.rake_modules/tester/tester'

HELMFILE_GLOB = 'helmfile.d/*services/**/helmfile.yaml'.freeze
CHARTS_GLOB = 'charts/**/Chart.yaml'.freeze
KUBERNETES_VERSIONS = '1.19,1.16'.freeze
ISTIOCTL_VERSION = 'istioctl-1.9.5'.freeze

# This returns a base64-encoded value.
LISTENERS_DEFINITIONS_URL = 'https://gerrit.wikimedia.org/r/plugins/gitiles/operations/puppet/+/refs/heads/production/hieradata/common/profile/services_proxy/envoy.yaml?format=TEXT'.freeze
LISTENERS_FIXTURE = '.fixtures/service_proxy.yaml'.freeze

## RAKE TASKS

desc 'Checks dependencies'
task :check_dep do
  check_binary('helm')
  check_binary('helmfile')

  res, output = _exec('helm version --client --short')
  helm_version = output.split('.').first

  raise("Only helm v3 is supported. Installed helm version is #{helm_version}") if helm_version != 'v3'
end

# This is to ensure that all repos are available and up to date
desc 'Add and update all needed helm repositories'
task repo_update: :check_dep do
  repo_urls = []
  FileList.new(CHARTS_GLOB).each do |path_to_chart|
    chart_yaml = yaml_load_file(path_to_chart)
    dependencies = []
    # Dependencies are to be defined in Chart.yaml
    dependencies = chart_yaml['dependencies'] if chart_yaml['dependencies']

    next unless dependencies

    dependencies.each do |dep|
      next unless dep.has_key?('repository')

      unless dep['repository'].match(/^http/)
        raise("Only http(s) URLs supported for non-local helm dependencies (#{path_to_chart_yaml})")
      end

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
task :lint do |_t, args|
  charts = args.nil? || args.extras.empty? ? nil : args.extras.join('/')
  Rake::Task[:check_charts].invoke('lint', charts)
  Rake::Task[:check_charts].reenable
end

desc 'Runs helm template on all charts and validate the output with kubeyaml'
task :validate_template do |_t, args|
  charts = args.nil? || args.extras.empty? ? nil : args.extras.join('/')
  Rake::Task[:check_charts].invoke('validate', charts)
  Rake::Task[:check_charts].reenable
end

desc 'Runs helmfile lint on all service deployments'
task validate_deployments: :repo_update do |_, args|
  deployments = args.nil? || args.extras.empty? ? nil : args.extras.join('/')
  Rake::Task[:check_deployments].invoke('lint', deployments)
  Rake::Task[:check_deployments].reenable
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
      next unless !resource.nil? \
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
  chart = 'test-scaffold'
  begin
    # run scaffolding first
    sc = Scaffold.new('example', chart, '9090')
    sc.run
    # Add a fixture for php apps
    File.open('charts/test-scaffold/.fixtures/php.yaml', 'w') do |fh|
      data = { main_app: { type: 'php' } }
      fh.write(data.to_yaml)
    end
    Rake::Task[:check_charts].invoke('lint/validate', chart)
    Rake::Task[:check_charts].reenable
  ensure
    FileUtils.rm_rf("charts/#{chart}")
  end
end

desc 'Show diff introduced by the patch'
task :helm_diffs do |_t, args|
  charts = args.nil? || args.extras.empty? ? nil : args.extras.join('/')
  Rake::Task[:check_charts].invoke('diff', charts)
  Rake::Task[:check_charts].reenable
end

desc 'Show diffs in deployments introduced by the patch'
task deployment_diffs: %i[check_dep repo_update] do |_, args|
  charts = args.nil? || args.extras.empty? ? nil : args.extras.join('/')
  Rake::Task[:check_deployments].invoke('diff', charts)
  Rake::Task[:check_deployments].reenable
end

## RAKE TASKS admin_ng

desc 'Runs helmfile lint on admin_ng for all environments'
task admin_lint: %i[check_dep repo_update] do
  Rake::Task[:check].invoke('admin', nil, nil)
  Rake::Task[:check].reenable
end

desc 'Runs helmfile template on admin_ng for all environments and validate the output with kubeyaml'
task admin_validate: %i[check_dep repo_update] do |_t, args|
  envs = args.nil? || args.extras.empty? ? nil : args.extras.join('/')
  Rake::Task[:check].invoke('admin', 'validate', envs)
  Rake::Task[:check].reenable
end

desc 'Shows admin diff introduced by this patch'
task admin_diff: %i[check_dep repo_update] do |_t, args|
  envs = args.nil? || args.extras.empty? ? nil : args.extras.join('/')
  Rake::Task[:check].invoke('admin', 'diff', envs)
  Rake::Task[:check].reenable
end

## RAKE TASKS custom_deploy

desc 'Validate istio configuration'
task :validate_istio_config do
  check_binary(ISTIOCTL_VERSION)
  FileList.new('custom_deploy.d/istio/*/config.yaml').each do |config|
    ok, out = _exec "#{ISTIOCTL_VERSION} validate -f #{config}"
    next if ok

    puts "Failed to verify istio config '#{config}':".red
    puts out
    raise('Failure')
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

desc 'Update the proxy_listeners fixture'
task :refresh_fixtures do
  puts 'Downloading the service proxy definitions'
  # Download the services proxy file from puppet.
  URI.open(LISTENERS_DEFINITIONS_URL) do |res|
    decoded = Base64.decode64(res.read)
    hiera = YAML.safe_load(decoded)
    # We don't really need an upstream to be accurate here.
    upstream_mock = { 'address' => 'mock.discovery.wmnet', 'port' => 443, 'encryption' => true }
    data = hiera['profile::services_proxy::envoy::listeners'].map { |x| x['upstream'] = upstream_mock; [x.delete('name'), x] }.to_h

    File.open(LISTENERS_FIXTURE, 'w') do |out|
      res = { 'services_proxy' => data }
      YAML.dump(res, out)
    end
    puts "New version saved at #{LISTENERS_FIXTURE}"
  end
end

task :check, [:kind, :tests, :assets] do |_, args|
  # This task is supposed to only be called by upstream ones
  # so it *has* args
  view = Tester.view args
  options = {}
  options[:assets] = args[:assets].split('/') unless args[:assets].nil?
  options[:tests] = args[:tests].split('/') unless args[:tests].nil?
  pattern = case args[:kind]
            when 'charts'
              CHARTS_GLOB
            when 'deployments'
              HELMFILE_GLOB
            when 'admin'
              'admin'
            end
  tr = Tester.runner pattern, options
  tr.run
  puts view.render(tr)
  abort('validation failed') unless tr.failed.empty?
end

desc 'Run checks for all the charts.'
task :check_charts, [:tests, :charts] do |_, args|
  args = {} if args.nil?
  Rake::Task[:check].invoke('charts', args.fetch(:tests, nil), args.fetch(:charts, nil))
  Rake::Task[:check].reenable
end

desc 'Run checks for all deployments.'
task :check_deployments, %i[tests deployments] do |_, args|
  args = {} if args.nil?
  Rake::Task[:check].invoke('deployments', args.fetch(:tests, nil), args.fetch(:deployments, nil))
  Rake::Task[:check].reenable
end

desc 'Run checks for the admin section'
task :check_admin do
  Rake::Task[:check].invoke('admin', nil, nil)
  Rake::Task[:check].reenable
end
task default: %i[repo_update test_scaffold check_charts check_deployments check_admin validate_envoy_config validate_istio_config]
