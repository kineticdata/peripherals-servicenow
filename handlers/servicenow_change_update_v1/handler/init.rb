require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class ServicenowChangeUpdateV1
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

    enum_risk = {" "=>'',"Very High"=>'1',"High"=>'2',"Moderate"=>'3',"Low"=>'4',"None"=>'5'}.to_s

    sys_id = @parameters['sys_id']
    number = @parameters['number']
    requested_by = @parameters['requested_by']
    # Downcase the menu item
    category = @parameters['category'].downcase
    cmdb_ci = @parameters['configuration_item']
    #index at 0 for int value
    priority = @parameters['priority'][0,1]
    risk = enum_risk[@parameters['risk']]
    #index at 0 for int value
    impact = @parameters['impact'][0,1]
    short_description = @parameters['short_description']
    description = @parameters['description']
    approval = @parameters['approval'].downcase
    type = @parameters['type']
    assignment_group = @parameters['assignment_group']
    assigned_to = @parameters['assigned_to']

    request = "change_request"
    post_type = "application/json"
    post_json =
    {
      "number"=>number,
      "requested_by"=>requested_by,
      "category"=>category,
      "cmdb_ci"=>cmdb_ci,
      "priority"=>priority,
      "risk"=>risk,
      "impact"=>impact,
      "short_description"=>short_description,
      "description"=>description,
      "approval"=>approval,
      "type"=>type,
      "assignment_group"=>assignment_group,
      "assigned_to"=>assigned_to,
      "sysparm_action"=>"update",
    }.to_json
    puts "Change request object for update: #{post_json}" if @enable_debug_logging

    url = "https://#{server}.service-now.com/api/now/table/change_request/#{sys_id}"
    puts "URL built for REST call to ServiceNow: #{url}" if @enable_debug_logging

    begin
    request_json = RestClient.put("#{url}", post_json,
                                {:authorization => "Basic #{Base64.strict_encode64("#{username}:#{password}")}",
                                :content_type => 'application/json',
                                :accept => 'application/json'
                                })
    rescue RestClient::BadRequest => error
      puts "Error encountered while attempting to update change: \n#{error.http_body}"
    end
    parsed_results = JSON.parse(request_json)
    result = parsed_results["result"]
    puts "Result after API request: #{result}" if @enable_debug_logging

    <<-RESULTS
    <results/>
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
