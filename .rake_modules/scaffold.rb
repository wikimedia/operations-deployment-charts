# frozen_string_literal: true

require 'yaml'
require 'rake'
# This class manages scaffolding a new service chart.
class Scaffold
  attr_accessor :image_name, :service_name, :port
  def initialize(image, service, port)
    raise('Missing PORT for scaffolding') if port.nil?
    raise('Missing NAME for scaffolding') if service.nil?
    raise('Missing IMAGE name for scaffolding') if image.nil?

    @image_name = image
    @service_name = service
    @port = port
    @values = read_tpl 'values.yaml'
    @chart = read_tpl 'Chart.yaml'
  end

  def copytree
    # Copies all files to the final charts directory
    FileUtils.copy_entry scaffold_for(''), service_for('')
    save_to @values, service_for('values.yaml')
    save_to @chart, service_for('Chart.yaml')
  end

  def link_common_templates
    version = YAML.safe_load(@values)['helm_scaffold_version']
    templates = FileList.new("common_templates/#{version}/*.tpl").map(&:strip)
    Dir.chdir(service_for('')) do
      File.symlink("../../common_templates/#{version}/default-network-policy-conf.yaml",
                   'default-network-policy-conf.yaml')
    end
    Dir.chdir(service_for('templates')) do
      templates.each { |tpl| File.symlink("../../../#{tpl}", File.basename(tpl)) }
    end
  end

  def run
    puts "Copying files to #{service_for ''}"
    copytree
    puts 'Linking common templates'
    link_common_templates
    puts "You can edit your chart (if needed!) at #{Dir.pwd}#{service_for ''}"
  end

  private

  def read_tpl(filename)
    # Read the scaffold file, apply variable substitution.
    apply_variables File.read(scaffold_for(filename))
  end

  def scaffold_for(filename)
    "_scaffold/#{filename}"
  end

  def service_for(filename)
    "charts/#{@service_name}/#{filename}"
  end

  def save_to(data, path)
    File.open(path, 'w') do |fh|
      fh.write(data)
    end
  end

  def common_tpl_for(version, filename)
    "common_templates/#{version}/#{filename}"
  end

  def apply_variables(tpl)
    tpl.gsub!('$IMAGE_NAME', @image_name)
    tpl.gsub!('$SERVICE_NAME', @service_name)
    tpl.gsub!('$PORT', @port)
    tpl
  end
end
