require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))
require 'uri'

class ServicenowObjectQueryRetrieveV1
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
    error_handling  = @parameters["error_handling"]

    display_value = @parameters['display_value']
    exclude_ref_link = @parameters['exclude_ref_link']
    suppress_pag_header = @parameters['suppress_pag_header']
    fields = @parameters['fields']
    limit = @parameters['limit']
    query_category = @parameters['query_category']

    begin
    resource = RestClient::Resource.new("#{@info_values['server']}/api/now/table",
      :user => @info_values['username'], :password => @info_values['password'],
      :headers => {:accept => "application/json", :content_type => "application/json"})

    puts "Attempting to retrieve objects using query '#{@parameters['query']}' from table '#{@parameters['table']}'" if @enable_debug_logging
    
      url = "#{@parameters['table']}?sysparm_query=#{URI.escape(@parameters['query'])}"

      url += "&sysparm_display_value=#{display_value}" if !display_value.empty?
      url += "&sysparm_exclude_reference_link=#{exclude_ref_link}" if !exclude_ref_link.empty?
      url += "&sysparm_suppress_pagination_header=#{suppress_pag_header}" if !suppress_pag_header.empty?
      url += "&sysparm_fields=#{URI.escape(fields)}" if !fields.empty?
      url += "&sysparm_limit=#{limit}" if !limit.empty?
      url += "&sysparm_query_category=#{query_category}" if !query_category.empty?

      puts "URL: #{url}" if @enable_debug_logging

      resp = resource[url].get
    rescue RestClient::ResourceNotFound => error
      error_message = error.inspect
      raise "404 Not Found: Make sure the 'server' and 'table' are valid inputs: #{error.http_body}."
    rescue RestClient::Exception => error
      error_message = error.inspect
      raise error if error_handling == "Rasie Error"
    end

    puts "Object retrieved; Parsing JSON results and returning object" if @enable_debug_logging
    json = JSON.parse(resp)
      

    <<-RESULTS
    <results>
      <result name="Handler Error Message">#{escape(error_message)}</result>
      <result name="object_json">#{escape(json["result"].to_json)}</result>
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
