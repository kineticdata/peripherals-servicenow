require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class ServicenowUserUpdateV1
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

    # Simple translates
    enum_bool={"yes"=>"1","no"=>"0"}
    enum_notification={"Enable"=>"1","Disable"=>"0"}

    # Get parameters
    sys_id = @parameters['sys_id']
    user_name = @parameters['user_name']
    first_name = @parameters['first_name']
    last_name = @parameters['last_name']
    title = @parameters['title']
    department_id = @parameters['department_id']
    user_password = @parameters['password']
    user_password_needs_reset = enum_bool[@parameters['password_needs_reset']]
    locked_out = enum_bool[@parameters['enum_bool']]
    active = enum_bool[@parameters['active']]
    date_format = @parameters['date_format']
    email = @parameters['email']
    pre_time_zone = @parameters['time_zone']
    phone = @parameters['phone']
    mobile_phone = @parameters['mobile_phone']

    # Timezone as is unless system
    if pre_time_zone == "System"
      time_zone = nil
    else
      time_zone = pre_time_zone
    end

    request = "sys_user_list"
    type = "application/json"
    # Create json string
    post_json =
    {
      'user_name'=>user_name,
      'first_name'=>first_name,
      'last_name'=>last_name,
      'title'=>title,
      'department_id'=>department_id,
      'password'=>user_password,
      'password_needs_reset'=>user_password_needs_reset,
      'locked_out'=>locked_out,
      'active'=>active,
      'date_format'=>date_format,
      'email'=>email,
      'time_zone'=>time_zone,
      'phone'=>phone,
      'mobile_phone'=>mobile_phone,
      'sysparm_action'=>'update'
    }.to_json
    puts "User object to be posted: #{post_json}" if @enable_debug_logging
    # Build request
    urlOfUpdate = "https://#{server}.service-now.com/api/now/table/sys_user/#{sys_id}"
    puts "URL built for ServiceNow REST API : #{urlOfUpdate}" if @enable_debug_logging

    # Execute request
    begin
    response_json = RestClient.put("#{urlOfUpdate}", post_json,
                                {:authorization => "Basic #{Base64.strict_encode64("#{username}:#{password}")}",
                                :content_type => 'application/json',
                                :accept => 'application/json'
                                })
    rescue RestClient::BadRequest => error
      puts "Error encountered while attempting to updating sys_user:\n#{error.http_body}"
    end

    puts "sys_user has been updated to: #{response_json.to_json}" if @enable_debug_logging
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
