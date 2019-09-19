require 'rake'
require 'rake/tasklib'

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
    results[chart] = system("helm template '#{chart}' > /dev/null")
  end
  pprint "Helm template summary:", results
  raise_if_failed results
end

task :default => [:lint, :validate_template]
