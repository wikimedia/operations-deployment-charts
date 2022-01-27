# frozen_string_literal: true

ERROR_CONTEXT_LINES = 4

# Cross-platform way of finding an executable in the $PATH.
#
#   which('ruby') #=> /usr/bin/ruby
def which(cmd)
  exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
    exts.each do |ext|
      exe = File.expand_path("#{cmd}#{ext}", path)
      return exe if File.executable?(exe) && !File.directory?(exe)
    end
  end
  nil
end

# Check a binary is available
def check_binary(binary)
  if which(binary).nil?
    tasks = Rake.application.top_level_tasks.join(' ')
    puts "You need #{binary} to run this task. Please install it or run \"rake run_locally['#{tasks}']\" to run in a docker container".red
    raise
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
            job.call
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
  puts '=='
  puts title
  puts ''
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
  data.each { |_, success| raise('Failure') unless success }
end

# Executes a command, returns an array [true/false, String], first element
# denoting success or failure, second one being stdout/stderr
def _exec(command, input = nil, nostderr = false)
  ret = []
  Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
    if input
      stdin.write(input)
      stdin.close
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
  end
  ret
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

# Returns a colored diff between two strings
def diff(original, changed)
  begin
    orig = Tempfile.new('orig')
    orig.write(original)
    orig.close
    change = Tempfile.new('changed')
    change.write(changed)
    change.close
    output = `diff --show-function-line=kind -au8 --color=always '#{orig.path}' '#{change.path}'`
  ensure
    orig&.unlink
    change&.unlink
  end
  output
end

def yaml_load_file(yaml_path)
  dir, file = File.split yaml_path
  begin
    error = "Parsing #{yaml_path}"
    yaml = YAML.load_file(yaml_path)
  rescue Psych::SyntaxError => e
    report_yaml_parse_error(yaml_type, error, yaml, e)
    raise("Failure parsing #{file}")
  rescue StandardError => e
    puts error.red
    puts e
    raise("Generic failure interpreting #{file}")
  end
  yaml
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
