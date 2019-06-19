require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class ServicenowGroupCreateV1
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

    post_json = {
      "name"=> @parameters['name'],
      "email"=>@parameters['group_email'],
      "parent"=>@parameters['parent'],
      "manager"=>@parameters['manager'],
      "description"=>@parameters['description'],
      "sysparm_action"=>"insert"
    }.to_json

    url = "https://#{server}.service-now.com/api/now/table/sys_user_group"
    puts "URL buiit up for REST call: #{url}" if @enable_debug_logging

    begin
    resp = RestClient.post("#{url}", post_json, {:authorization => "Basic #{Base64.strict_encode64("#{username}:#{password}")}",
                            :content_type => 'application/json',
                            :accept => 'application/json'
                            })
    rescue RestClient::Forbidden => error
      puts "A group with the same credentials may already exsists that require unique values in your ServiceNow instance.  \n#{error.http_body}"
    rescue RestClient::BadRequest => error
      puts "Error encountered while attempting to updating incident:\n#{error.http_body}"
    end

    json_resp = JSON.parse(resp)
    puts "Response object returned from ServiceNow API: #{json_resp}" if @enable_debug_logging
    sys_id = json_resp["result"]["sys_id"]
    puts "New group sys_id returned from ServiceNow API: #{json_resp}" if @enable_debug_logging

    <<-RESULTS
    <results>
      <result name="sys_id">#{sys_id}</result>
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
