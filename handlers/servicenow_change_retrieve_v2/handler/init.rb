require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class ServicenowChangeRetrieveV2
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
    username = @info_values['username']
    password = @info_values['password']
    server = @info_values['server']

    sys_id = @parameters['sys_id']

    begin
    url = "https://#{server}.service-now.com/api/now/table/change_request/#{sys_id}"
    puts "URL built up to make request to ServiceNow REST API: #{url}" if @enable_debug_logging

    response = RestClient.get("#{url}", {:authorization => "Basic #{Base64.strict_encode64("#{username}:#{password}")}",
                                :content_type => 'application/json',
                                :accept => 'application/json'
                                })
    rescue RestClient::BadRequest => error
      puts "Error encountered while attempting to retrieve change: \n#{error.http_body}"
    end
    puts "Response to API call: #{response}" if @enable_debug_logging

    parsed_response =  JSON.parse(response)

    # After regex is run, the string will go from {records : [{...}]} to nil if no results are returned
    if parsed_response['result'].size < 1
      throw "No results returned for #{sys_id}."
    end

    result = parsed_response["result"]

    # Grab fields of existing user
    keys = result.keys
    xml_string = ""
    keys.each do | key |
      value = result[key]
      xml_string << "<result name=\"#{key}\">#{value}</result>"
    end
    puts "results generated from response: #{xml_string}" if @enable_debug_logging

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
