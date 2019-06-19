require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class ServicenowIncidentCreateV2
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
    url = "https://#{server}.service-now.com/api/now/table/incident"
    json_response = {}

    # Downcase the menu item
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

    request_body_map =
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
      "sysparm_action"=>"insert",
    }.to_json

    begin
     response = RestClient.post("#{url}", "#{request_body_map}",
                                {:authorization => "Basic #{Base64.strict_encode64("#{username}:#{password}")}",
                                :content_type => 'application/json',
                                :accept => 'application/json'
                                })
     json_response = JSON.parse(response.body)
     rescue => e
       puts "ERROR: #{e}"
    end

    <<-RESULTS
    <results>
          <result name="Incident Number">#{json_response["result"]["number"]}</result>
          <result name="System Id">#{json_response["result"]["sys_id"]}</result>
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
