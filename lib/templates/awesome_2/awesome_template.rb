class AwesomeTemplate < MetricFu::Template

  def write
    # Getting rid of the crap before and after the project name from integrity
    dir = MetricFu.configuration.is_cruise_control_rb? ? File.join(Dir.pwd, '..') : Dir.pwd
    @name =  File.basename(File.expand_path(dir)).gsub(/^\w+-|-\w+$/, "")

    # Create the instance variables first so we can have them available for
    # each report page (they are used for the navigation links)
    report.each_pair do |section, contents|
      if template_exists?(section)
        create_instance_var(section, contents)
      end
    end

    # Generate the actual report pages
    report.each_pair do |section, contents|
      if template_exists?(section)
        @html = erbify(section)
        @current_section = section
        html = erbify('layout')
        fn = output_filename(section)
        MetricFu.report.save_output(html, MetricFu.output_directory, fn)
      end
    end

    # Instance variables we need should already be created from above
    if template_exists?('index')
      @html = erbify('index')
      @current_section = :index
      html = erbify('layout')
      fn = output_filename('index')
      MetricFu.report.save_output(html, MetricFu.output_directory, fn)
    end
  end

  def this_directory
    File.dirname(__FILE__)
  end
end

