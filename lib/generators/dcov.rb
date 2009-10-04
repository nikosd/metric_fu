require 'enumerator'

module MetricFu 

  class Dcov < Generator

    def self.verify_dependencies!
      `dcov --help`
      raise 'sudo gem install dcov # if you want the dcov tasks' unless $?.success?
    end

    #search through resource path and rub dcov on all .rb files, abstract method override
    def emit
        #Clean up file system before we start
        FileUtils.rm_rf(MetricFu::Dcov.metric_directory, :verbose => false)
        Dir.mkdir(MetricFu::Dcov.metric_directory)

        #what files are we going to test
        test_files = MetricFu.dcov[:dirs_to_dcov].map{ |dir| Dir[File.join(dir, "**/*.rb")] }.join(' ')

        #set Dcov Options (See dcov rdocs)
        dcov_opts = MetricFu.dcov[:dcov_opts].nil? ? "-p #{MetricFu.dcov[:ouput_directory]}" : MetricFu.dcov[:dcov_opts].join(' ')

        #setup place to store output
        metrics_output = "> #{MetricFu::Dcov.metric_directory}/dcov.txt 2>/dev/null"

        #actually do the test
        `dcov #{dcov_opts} #{test_files} #{metrics_output}`
    end

    # Parses the output file into a hash for use by template, abstract method override
    def analyze
      #get the logged output
      output1 = File.open(MetricFu::Dcov.metric_directory + '/dcov.txt').read

      #turn it into something easier to work with
      output1 = output1.split("\n")

      #parse output
      output_hash = {}        #somewhere to keep our parsed data
      sub_section_sym = ""    #aid for parsing sub sections
      item_name = ""          #aid for parsing sub sections
      output1.map! do |line|  #parse each line for essential data (totals, coverage percentage)
        next if line == ""                #skip blank lines
        next if !line[/Not covered:/].nil? #skip these lines
        next if line[/Generating report/]  #skip these lines
        next if line[/Writing report/]     #skip these lines

        #typically the first line, total files checked
        if line[/\AFiles:/]  
          output_hash[:file_count] = line[/\d+/]
          next
        end

        #These are the totals for each section
        if line[/\ATotal \w+/]
          output_hash[underscore(line[/\ATotal \w+/]).to_sym] = line[/\d+/]
          next
        end

        #Actual coverages and list of uncovered items, marks start of item list
        if line[/\A\w+ coverage/]
          sub_section_sym  = underscore(line[/\A\w+ coverage/]).to_sym
          #output_hash[sub_section_sym] = line[/\d+%/]
          output_hash= output_hash.merge(sub_section_sym=>{})
          output_hash[sub_section_sym] = output_hash[sub_section_sym].merge({:coverage => line[/\d+%/]})
          next
        end

        #if it hasn't been caught by now, it's an item... 
        if item_name == ""
          #get Item name
          item_name = line.strip
        else
          #get item data and store pair
          if output_hash[sub_section_sym][:not_covered].nil?
            output_hash[sub_section_sym] = output_hash[sub_section_sym].merge(:not_covered=>{})
          end
          output_hash[sub_section_sym][:not_covered] = output_hash[sub_section_sym][:not_covered].merge({item_name=>line.strip})
          item_name = ""
        end
      end

      @dcov = output_hash
    end
    
    #abstract method override
    def to_h
      { :dcov => @dcov }
    end

    def underscore(camel_cased_word)
      camel_cased_word.to_s.gsub(/::/, '/').
      gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
      gsub(/([a-z\d])([A-Z])/,'\1_\2').
      tr("-", "_").
      tr(" ", "_").
      downcase
    end
  end
end