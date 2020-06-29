require 'rake'
require 'rake/tasklib'
require 'open3'
require 'yaml'

ERROR_CONTEXT_LINES = 4
PRIVATE_STUB = '.fixtures/private_stub.yaml'
HELM_REPO = 'stable'
HELMFILE_GLOB = "helmfile.d/services/*/*/helmfile.yaml"
KUBERNETES_VERSIONS = "1.17,1.16,1.15,1.14,1.13,1.12"  # Let's target only what we have or want to upgrade to

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

def raise_if_failed(data)
  data.each{ |_, success| raise('Failure') unless success }
end

def _exec(command, input=nil, nostderr=false)
  ret = []
  # Executes a command, returns an array [true/false, String], first element
  # denoting success or failure, second one being stdout/stderr
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


def check_template(chart, fixture = nil, kubeyaml = nil)
  if fixture != nil
    # When passing multiple values, concatenate them
    quoted = fixture.map{ |x| "-f '#{x}'" }.join " "
    command = "helm template #{quoted} '#{chart}'"
    error = "Error checking #{chart}, value files: #{fixture}"
#  elsif fixture != nil
#    command = "helm template -f '#{fixture}' '#{chart}'"
#    fixture_name = File.basename(fixture, '.yaml')
#    error = "Error checking #{chart} (fixture #{fixture_name})"
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
      puts error.red
      puts "Error is at line #{e.line}, column #{e.column} of the output of `#{command}`: #{e.problem}".red
      puts "Context:\n"
      lines = output.split("\n")
      min_line = [0, e.line - ERROR_CONTEXT_LINES].max
      pre_lines = e.line - min_line
      post_lines = [lines.length, e.line + ERROR_CONTEXT_LINES].min - e.line
      puts lines[min_line, pre_lines].join "\n"
      puts lines[e.line].red
      puts lines[e.line + 1, post_lines].join "\n"
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
      docs = output.split('---')
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


def parse_helmfile(filename)
  charts = {}
  helmfile_dir = File.dirname(filename)
  data = File.read(filename)
  helmfile_data = YAML.safe_load(data)
  helmfile_data['releases'].each do |release|
    chart = release['chart'].gsub(/^#{HELM_REPO}/, 'charts')
    charts[chart] ||= []
    release['values'].each do |val|
      # We can't test private files, so we use a stub in those cases.
      if val.include? "private/"
        private_stub = "#{chart}/#{PRIVATE_STUB}"
        if File.exists? private_stub
          charts[chart] << private_stub
        end
      else
        charts[chart] << File.join(helmfile_dir, val)
      end
    end
  end
  charts
end

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
  deployments.each do |helmfile|
    radix, deployment = File.split(File.dirname(helmfile))
    _, cluster = File.split(radix)
    # Skip the example, shall we
    next if deployment == '_example_'
    charts = parse_helmfile helmfile
    if charts.length == 1
      chart, values = charts.first
      results["#{deployment}/#{cluster}"] = check_template chart, values
    else
      charts.each do |chart, values|
        results["#{deployment}/#{cluster} => #{chart}"] = check_template chart, values
      end
    end
  end
  pprint "Helmfile deployments check summary:", results
end

task :default => [:lint, :validate_template, :validate_deployments]
