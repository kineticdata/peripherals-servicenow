require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class ServicenowGroupRetrieveV1
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
  end
  
  def execute()
    # Initializing the info needed for the handler given the inputted values
    username = @info_values['username']
    password = @info_values['password']
    server = @info_values['server']

    query_string = @parameters['retrieve_by'] + "=" + @parameters['value']
    
    # Building up the URL for the REST call and then making the get request to
    # retrieve the desired information
    request_uri = "https://#{username}:#{password}@#{server}.service-now.com/sys_user_group.do?JSON&sysparm_query=#{query_string}"
    uri = URI.encode(request_uri)
    resp = RestClient.get uri

    # Create JSON hash of all results
    json = JSON.parse(resp)
    
    # Throw an error if no results are retrieved
    if json["records"].size == 0
      raise StandardError, "No results returned for #{query_string}"
    end
    # Make sure there are no more than 1 results returned
    if json["records"].size > 1
      raise StandardError, "Multiple results returned for #{query_string}"
    end

    xml_string = ""
    json["records"][0].each_pair do |key, value|
      xml_string << "<result name=\"#{key}\">#{value}</result>\n"
    end
    
    <<-RESULTS
    <results>
    #{xml_string}
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
