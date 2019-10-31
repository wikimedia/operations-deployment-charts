require 'rake'
require 'rake/tasklib'
require 'open3'
require 'yaml'

ERROR_CONTEXT_LINES = 4

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
      puts "#{chart.ljust(40)}OK".green
    else
      puts "#{chart.ljust(40)}FAIL".red
    end
  end
end

def raise_if_failed(data)
  data.each{ |_, success| raise('Failure') unless success }
end

def _exec(command)
  ret = []
  # Executes a command, returns an array [true/false, String], first element
  # denoting success or failure, second one being stdout/stderr
  Open3.popen3(command) {|stdin, stdout, stderr, wait_thr|
    exit_status = wait_thr.value.exitstatus
    if exit_status == 0
      out = stdout.gets(nil)
      ret = [true, out]
    else
      out = stderr.gets(nil)
      ret = [false, out]
    end
  }
  ret
end


def check_template(chart, fixture = nil)
  if fixture != nil
    command = "helm template -f '#{fixture}' '#{chart}'"
    fixture_name = File.basename(fixture, '.yaml')
    error = "Error checking #{chart} (fixture #{fixture_name})"
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
  else
    # Error happens before yaml validation
    puts error.red
    puts output
  end
  return success
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
  results = {}
  all_charts.each do |chart|
    results[chart] = check_template chart
    fixtures = FileList.new("#{chart}/.fixtures/*.yaml")
    fixtures.each do |fixture|
      fixture_name = File.basename(fixture, '.yaml')
      results["#{chart} => #{fixture_name}"] = check_template chart, fixture
    end
  end
  pprint "Helm template summary:", results
  raise_if_failed results
end

task :default => [:lint, :validate_template]
