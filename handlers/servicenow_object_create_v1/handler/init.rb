require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class ServicenowObjectCreateV1
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Store the info values in a Hash of info names to values.
    @info_values = {}
    REXML::XPath.each(@input_document,"/handler/infos/info") { |item|
      @info_values[item.attributes['name']] = item.text
    }

    # Retrieve all of the handler parameters and store them in a hash attribute
    # named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, 'handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text.to_s
    end

    @enable_debug_logging = @info_values['enable_debug_logging'].downcase == 'yes' ||
                            @info_values['enable_debug_logging'].downcase == 'true'
    puts "Parameters: #{@parameters.inspect}" if @enable_debug_logging
  end

  def execute()
    error_handling = @parameters['error_handling']

    resource = RestClient::Resource.new("#{@info_values['server']}/api/now/table",
      :user => @info_values['username'], :password => @info_values['password'],
      :headers => {:accept => "application/json", :content_type => "application/json"})

    puts "Attempting to create a(n) '#{@parameters['table']}' with the fields '#{@parameters['json_body']}'" if @enable_debug_logging
    
    begin
      resp = resource["#{@parameters['table']}"].post(@parameters['json_body'])
    
      puts "Item created. Parsing result and returning results:\n#{resp}" if @enable_debug_logging
      id = JSON.parse(resp)["result"]["sys_id"]

    rescue RestClient::Exception => error
      error_message = error.inspect
      raise "An unexpected error occurred: #{error.http_body}" if error_handling == "Rasie Error"
    rescue Exception => error
      error_message = error.inspect
      raise error if error_handling == "Rasie Error"
    end  

    <<-RESULTS
    <results>
      <result name="Handler Error Message">#{escape(error_message)}</result>
      <result name="Id">#{id}</result>
    </results>
    RESULTS
  end

  # This is a template method that is used to escape results values (returned in
  # execute) that would cause the XML to be invalid.  This method is not
  # necessary if values do not contain character that have special meaning in
  # XML (&, ", <, and >), however it is a good practice to use it for all return
  # variable results in case the value could include one of those characters in
  # the future.  This method can be copied and reused between handlers.
  def escape(string)
    # Globally replace characters based on the ESCAPE_CHARACTERS constant
    string.to_s.gsub(/[&"><]/) { |special| ESCAPE_CHARACTERS[special] } if string
  end
  # This is a ruby constant that is used by the escape method
  ESCAPE_CHARACTERS = {'&'=>'&amp;', '>'=>'&gt;', '<'=>'&lt;', '"' => '&quot;'}
end
