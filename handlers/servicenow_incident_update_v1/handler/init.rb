require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class ServicenowIncidentUpdateV1
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

    # Downcase the menu item
    sys_id = @parameters['sys_id']
    category = @parameters['category'].downcase
    short_description = @parameters['short_description']
    # Gets the first char of impact and urgency i.e. the int value
    impact = @parameters['impact'][0,1]
    urgency = @parameters['urgency'][0,1]
    contact_type = @parameters['contact_type']
    caller_id = @parameters['caller_id']
    location = @parameters['location']
    cmdb_ci = @parameters['cmdb_ci']
    assignment_group = @parameters['assignment_group']
    assigned_to = @parameters['assigned_to']

    #Create incident object for update and convert it to JSON.
    pre_json =
    {
      "category"=>category,
      "short_description"=>short_description,
      "impact"=>impact,
      "urgency"=>urgency,
      "contact_type"=>contact_type,
      "caller_id"=>caller_id,
      "location"=>location,
      "cmdb_ci"=>cmdb_ci,
      "assignment_group"=>assignment_group,
      "assigned_to"=>assigned_to,
      "sysparm_action"=>"update",
    }
    put_json = {}
    keys = pre_json.keys

    keys.each do | key |
      if !pre_json[key].empty?
        put_json[key] = pre_json[key]
      end
    end
    put_json = put_json.to_json
    puts "JSON object built up to be posted to ServiceNow API #{put_json}" if @enable_debug_logging

    url = "https://#{server}.service-now.com/api/now/table/incident/#{sys_id}"
    puts "URL of puts call for incident update: #{url}" if @enable_debug_logging
    begin
    resp_update = RestClient.put("#{url}", put_json,
                                {:authorization => "Basic #{Base64.strict_encode64("#{username}:#{password}")}",
                                :content_type => 'application/json',
                                :accept => 'application/json'
                                })
    rescue RestClient::BadRequest => error
      puts "Error encountered while attempting to updating incident:\n#{error.http_body}"
    end

    puts "Incident has been updated to: #{resp_update.to_json}" if @enable_debug_logging
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
