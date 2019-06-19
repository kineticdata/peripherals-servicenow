require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class ServicenowUserRetrieveV1
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
    # Get info
    username = @info_values['username']
    password = @info_values['password']
    server = @info_values['server']
    
    # Get parameters
    query = @parameters['query']
    query_type  = @parameters['query_type'].downcase

    # Request for this handler
    request = "sys_user"
    # Build the query String
    query_string = "https://#{username}:#{password}@#{server}.service-now.com/#{request}.do?JSON&sysparm_query=#{query_type}=#{query}"
    encoded_uri = URI.encode(query_string)
    # Run GET request and grab the response
    response_string = RestClient.get(encoded_uri)
    # SNOW requests come back in the format {records: [{...}]}, 
    #   we want it to be [{..}] to check size for single result
    response_string = response_string[/\[\{.*\}\]/]
    
    # After regex is run, the string will go from {records : [{...}]} to nil if no results are returned
    if response_string == nil
      throw "No results returned for #{query_type} : #{query}."
    end
    
    # Create JSON hash of all results
    check_json = JSON.parse(response_string)
    
    # Make sure there are no more than 1 results returned
    if check_json.size > 1
      throw "Multiple results returned for #{query_type} : #{query}."
    end  
    
    # Cut the square brackets off the JSON
    response_string = response_string[1..-2]
    # and parse
    record_json = JSON.parse(response_string)
    
    # Grab fields of existing user
    keys = record_json.keys
    xml_string = ""
    keys.each do | key |
      value = record_json[key]
      xml_string << "<result name=\"#{key}\">#{value}</result>"
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
