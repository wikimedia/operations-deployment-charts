require 'rake'
require 'tmpdir'
require 'rake/tasklib'
require 'open3'
require 'yaml'

ERROR_CONTEXT_LINES = 4
PRIVATE_STUB = '.fixtures/private_stub.yaml'
HELM_REPO = 'stable'
HELMFILE_GLOB = "helmfile.d/services/**/helmfile.yaml"
KUBERNETES_VERSIONS = "1.19,1.16,1.12"
HELMFILE_ENV = 'eqiad'

# Extend string to add color output
class String
  def red
    colour(31)
  end

  def green
    colour(32)
  end

  private
  def colour(colour_code)
    "\e[#{colour_code}m#{self}\e[0m"
  end
end

# Very basic threadpool implementation
class ThreadPool
  def initialize(nthreads:)
    @concurrency = nthreads
    @jobs = Queue.new
    @pool = Array.new(@concurrency) do
      Thread.new do
        catch(:exit) do
          loop do
            job = @jobs.pop
            job.call()
          end
        end
      end
    end
  end
  def run(&block)
    @jobs << block
  end

  def join
    # schedule an exit for each thread
    @concurrency.times do
      run { throw :exit }
    end
    @pool.map(&:join)
  end
end

# pretty-print output
def pprint(title, data)
  puts "=="
  puts title
  puts ""
  data.each do |chart, success|
    if success
      puts "#{chart.ljust(72)}OK".green
    else
      puts "#{chart.ljust(72)}FAIL".red
    end
  end
end

# Checks the output of _exec
def raise_if_failed(data)
  data.each{ |_, success| raise('Failure') unless success }
end

# Executes a command, returns an array [true/false, String], first element
# denoting success or failure, second one being stdout/stderr
def _exec(command, input=nil, nostderr=false)
  ret = []
  Open3.popen3(command) {|stdin, stdout, stderr, wait_thr|
    if input
      stdin.write(input)
      stdin.close()
    end
    out = stdout.gets(nil)
    err = stderr.gets(nil)
    exit_status = wait_thr.value.exitstatus
    if exit_status == 0
      ret = [true, out]
    else
      out = nostderr ? out : err
      ret = [false, out]
    end
  }
  ret
end

# Cross-platform way of finding an executable in the $PATH.
#
#   which('ruby') #=> /usr/bin/ruby
def which(cmd)
  exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
    exts.each do |ext|
      exe = File.join(path, "#{cmd}#{ext}")
      return exe if File.executable?(exe) && !File.directory?(exe)
    end
  end
  nil
end

# Reports a yaml parsing error with some useful context
def report_yaml_parse_error(cmd, msg, output, e)
  puts msg.red
  puts "Error is at line #{e.line}, column #{e.column} of the output of `#{cmd}`: #{e.problem}".red
  puts "Context:\n"
  lines = output.split("\n")
  min_line = [0, e.line - ERROR_CONTEXT_LINES].max
  pre_lines = e.line - min_line
  post_lines = [lines.length, e.line + ERROR_CONTEXT_LINES].min - e.line
  puts lines[min_line, pre_lines].join "\n"
  puts lines[e.line].red
  puts lines[e.line + 1, post_lines].join "\n"
end


# Checks an helm chart.
# Does so by running helm template (injecting value fixture files if present)
# If kubeyaml is available, also run kubeyaml.
def check_template(chart, fixture = nil, kubeyaml = nil)
  if fixture != nil
    # When passing multiple values, concatenate them
    quoted = fixture.map{ |x| "-f '#{x}'" }.join " "
    command = "helm template #{quoted} '#{chart}'"
    error = "Error checking #{chart}, value files: #{fixture}"
  else
    command = "helm template '#{chart}'"
    error = "Error checking #{chart}"
  end
  success, output = _exec command
  if success
    docs = []
    begin
      YAML.load_stream(output) do |resource|
        next unless resource
        docs << resource['kind']
        # not doing anything here, we're just verifying it loads for now.
      end
    rescue Psych::SyntaxError => e
      report_yaml_parse_error(command, error, output, e)
      success = false
    rescue StandardError => e
      success = false
      puts error.red
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
          source = doc.match(/^# Source: [a-zA-Z0-9\/\.-]*$/)
          doc = doc.strip.gsub(/^# Source: [a-zA-Z0-9\/\.-]*$/, '').strip
          next if doc.length == 0
          succ, out = _exec command, doc, true
          if not succ
            puts error.red
            puts "Error validating semantically YAML"
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
    puts error.red
    puts "Error running #{command}:"
    puts output
  end
  return success
end


# parses an helmfile and returns the status of running 'helmfile lint'
# for all environments.
# The return data are organized as follows:
#  {environment: true/false}
def validate_helmfile_full(filepath)
  # Do everything in a tempdir
  results = {}
  helm_home = ENV['HELM_HOME'] || File.expand_path("~/.helm")
  dir_to_copy, file = File.split filepath
  Dir.mktmpdir do |dir|
    # Copy HELM_HOME so that we don't incur in race conditions when running in
    # parallel, see T261313
    local_helm_home = File.join dir, ".helm"
    FileUtils.cp_r helm_home, local_helm_home
    # Copy the original dir files to the tmpdir
    FileUtils.cp_r "#{dir_to_copy}/.", dir
    filename = File.join dir, file
    fixtures = File.join(dir, '.fixtures.yaml')
    source = File.read(filename)

    # Patch helmfile so that .fixtures.yaml is used instead of
    # /etc/helmfile-defaults/general-#{env}.yaml
    if File.exists? fixtures
      source.sub!('/etc/helmfile-defaults/general-{{ .Environment.Name }}.yaml', fixtures)
      File.write filename, source
    end
    ok, data = _exec "HELM_HOME=#{local_helm_home} helmfile -e staging -f #{filename} build", nil, true
    # If we can't run helmfile build, we need to bail out early.
    return {'staging' => false} unless ok

    helmfile_raw_data = YAML.safe_load(data)
    envs = helmfile_raw_data['environments'].keys

    # now for each environment, build the list of
    # helm commands to run
    envs.each do |env|
      ok, out = _exec "HELM_HOME=#{local_helm_home} helmfile -e #{env} -f #{filename} lint"
      puts(out) unless ok
      results[env] = ok
      # TODO: feed the output of helmfile template to kubeyaml?
    end
  end
  results
end


## RAKE TASKS

all_charts = FileList.new('charts/**/Chart.yaml').map{ |x| File.dirname(x)}
desc 'Runs helm lint on all charts'
task :lint do
  results = {}
  all_charts.each do |chart|
    puts "Linting #{chart}"
    results[chart] =  system("helm lint '#{chart}'")
  end
  pprint "Helm lint summary:", results
  raise_if_failed results
end

desc 'Runs helm template on all charts'
task :validate_template do
  # Detect kubeyaml, if present also semantically validate YAML
  # Note that we only do this in this task, to avoid heavily increased execution
  # times
  kubeyaml = which('kubeyaml')
  results = {}
  all_charts.each do |chart|
    results[chart] = check_template chart, nil, kubeyaml
    fixtures = FileList.new("#{chart}/.fixtures/*.yaml")
    fixtures.each do |fixture|
      # Exclude the private stub if present.
      next if fixture.include? PRIVATE_STUB
      fixture_name = File.basename(fixture, '.yaml')
      results["#{chart} => #{fixture_name}"] = check_template chart, [fixture], kubeyaml
    end
  end
  pprint "Helm template summary:", results
  raise_if_failed results
end

desc 'Runs helm template using the helmfile values'
task :validate_deployments do
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
      next if ['_example_', 'eqiad', 'codfw', 'staging'].include? deployment
      deployment_results = validate_helmfile_full helmfile
      res = deployment_results
      mutex.synchronize do
        res.each do |cluster, outcome|
          results["#{deployment}/#{cluster}"] = outcome
        end
      end
    end
  end
  tp.join
  pprint "Helmfile deployments check summary:", results
  raise_if_failed results
end

desc 'Validate the envoy configuration'
task :validate_envoy_config do
  puts "Generating and verifying the envoy configuration..."
  # run helm template for a specific fixture that generates a service proxy and tls terminator
  command = "helm template --values .fixtures/service_discovery.yaml charts/termbox"
  res, out = _exec command
  unless res
    puts out.red
    raise('Failure generating the helm manifest')
  end
  # Extract the envoy configuration, write it to a file
  begin
    config = ""
    YAML.load_stream(out) do |resource|
      next unless resource["kind"] == "ConfigMap" \
        && resource["metadata"] \
        && resource["metadata"]["name"] \
        && resource["metadata"]["name"].end_with?("envoy-config-volume")
      config = resource["data"]["envoy.yaml"]
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
    FileUtils.mkdir '.tmp', mode: 0777
    at_exit { FileUtils.remove_entry '.tmp' }
  end

  f = File.open "#{dest}/envoy.yaml", 'w'
  f.write config
  f.close()
  # If we're copying the file into the container, it needs to be world-readable
  File.chmod 0755, "#{dest}/envoy.yaml" unless has_envoy

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
    raise("Failure")
  else
    puts out.green
  end
end

task :default => [:lint, :validate_template, :validate_deployments, :validate_envoy_config]
