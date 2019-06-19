require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class ServicenowUserRetrieveV2
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
    # Get info
    username = @info_values['username']
    password = @info_values['password']
    server = @info_values['server']

    # Get parameters
    sys_id = @parameters['sys_id']

    # Build the query String
    url = "https://#{server}.service-now.com/api/now/table/sys_user/#{sys_id}"
    puts "url built for query: #{url}" if @enable_debug_logging
    #Make the API call using RestClient
    begin
    resp = RestClient.get("#{url}", {:authorization => "Basic #{Base64.strict_encode64("#{username}:#{password}")}",
                            :content_type => 'application/json',
                            :accept => 'application/json'
                            })
    rescue RestClient::BadRequest => error
      puts "Error encountered while attempting to retrieve user: \n#{error.http_body}"
    end
    response_json = JSON.parse(resp)
    puts "parse JSON of return results: #{response_json}" if @enable_debug_logging

    results = response_json["result"]

    results_hash = Hash[*results]

    # Grab fields of existing user
    keys = results_hash.keys
    xml_string = ""
    keys.each do | key |
      value = results_hash[key]
      xml_string << "<result name=\"#{key}\">#{value}</result>"
    end
    puts "hash created from JSON return: #{xml_string} " if @enable_debug_logging
    require "pry";binding.pry
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
