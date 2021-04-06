# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class ServicenowAttachmentCreateV1
  # Prepare for execution by pre-loading Ars form definitions, building Hash
  # objects for necessary values, and validating the present state.  This method
  # sets the following instance variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @debug_logging_enabled - A Boolean value indicating whether logging should
  #   be enabled or disabled.
  # * @parameters - A Hash of parameter names to parameter values.
  # * @field_values - A Hash of HPD:WorkLog database field names to the values to
  #   be used for the record.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Parameters
  # * +input+ - The String of Xml that was built by evaluating the node.xml
  #   handler template.
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Store the info values in a Hash of info names to values.
    @info_values = {}
    REXML::XPath.each(@input_document, "/handler/infos/info") do |item|
      @info_values[item.attributes["name"]] = item.text.to_s.strip
    end

    # Determine if debug logging is enabled.
    @debug_logging_enabled = ["yes","true"].include?(@info_values['enable_debug_logging'].downcase)
    puts("Logging enabled.") if @debug_logging_enabled

    puts(format_hash("Handler Info Values:", @info_values)) if @debug_logging_enabled

    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.each(@input_document, "/handler/parameters/parameter") do |item|
      @parameters[item.attributes["name"]] = item.text.to_s.strip
    end
    puts(format_hash("Handler Parameters:", @parameters)) if @debug_logging_enabled

  end
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An Xml formatted String representing the return variable results.

  def execute
    @api_location = @info_values["api_location"]
    @api_location.chomp!("/")
    @api_username = @info_values["api_username"]
    @api_password = @info_values["api_password"]

    @servicenow_api_location = @info_values["servicenow_api_location"]
    @servicenow_api_location.chomp!("/")
    @servicenow_api_username = @info_values["servicenow_api_username"]
    @servicenow_api_password = @info_values["servicenow_api_password"]

    # Initialize return data
    error_message = nil
    error_key = nil
    response_code = nil

    begin
      attachment = create_attachment_from_json(@parameters['attachment_json']) if @parameters['attachment_input_type']=="JSON"
      attachment = create_attachment_from_field(@parameters['attachment_field'], @api_location) if @parameters['attachment_input_type']=="Field"

      @content_type = attachment['contentType']
      @accept = :json
      @servicenow_path="/api/now/attachment/file?table_name=#{@parameters['table_name']}&table_sys_id=#{@parameters['table_sys_id']}&file_name=#{attachment['name']}"

      servicenow_api_route = "#{@servicenow_api_location}#{@servicenow_path}"
      puts "API ROUTE: POST #{servicenow_api_route}" if @debug_logging_enabled

      response = RestClient::Request.execute \
        method: :POST, \
        url: servicenow_api_route, \
        user: @servicenow_api_username, \
        password: @servicenow_api_password, \
        payload: attachment['content'], \
        headers: {:content_type => @content_type, :accept => @accept}
      response_code = response.code
    rescue RestClient::Exception => e
      begin
        error = nil
        response_code = e.response.code

        # Attempt to parse the JSON error message.
        error = JSON.parse(e.response)
        error_message = error["error"]
        error_key = error["errorKey"] || ""
      rescue Exception
        puts "There was an error parsing the JSON error response" if @debug_logging_enabled
        error_message = e.inspect
      end

      # Raise the error if instructed to, otherwise will fall through to
      # return an error message.
      raise if @error_handling == "Raise Error"
    end

    # Return (and escape) the results that were defined in the node.xml
    <<-RESULTS
    <results>
      <result name="Response Body">#{escape(response.nil? ? {} : response.body)}</result>
      <result name="Response Code">#{escape(response_code)}</result>
      <result name="Handler Error Message">#{escape(error_message)}</result>
    </results>
    RESULTS
  end


  ##############################################################################
  # File Retrieve utility functions
  ##############################################################################
  def create_attachment_from_json(json)
    field_values = JSON.parse(json)
    puts("Using File URL: \n#{field_values[0]["url"]}") if @debug_logging_enabled
    puts("Using File Name: \n#{field_values[0]["name"]}") if @debug_logging_enabled
    attachment = RestClient::Resource.new(
      field_values[0]["url"],
      user: @info_values['api_username'],
      password: @info_values['api_password']
    ).get

    attachment_field = {}
    attachment_field['name'] = field_values[0]["name"]
    attachment_field['contentType'] = field_values[0]["contentType"]
    #attachment_field['base64_content'] = Base64.encode64(attachment.body)
    attachment_field['content'] = attachment.body
    attachment_field['size'] = attachment.body.size()

    return attachment_field
  end

  def create_attachment_from_field(field_name, server)
    # Call the Kinetic Request CE API
    begin
      # Submission API Route including Values
      # /{spaceSlug}/app/api/v1/submissions/{submissionId}}?include=...

      submission_api_route = server + '/app/api/v1' +
        '/submissions/' + URI.escape(@parameters['submission_id']) + '/?include=values'
      puts("Submission API Route: \n#{submission_api_route}") if @debug_logging_enabled

      # Retrieve the Submission Values
      submission_result = RestClient::Resource.new(
        submission_api_route,
        user: @info_values['api_username'],
        password: @info_values['api_password']
      ).get

      # If the submission exists
      unless submission_result.nil?

       submission = JSON.parse(submission_result)['submission']
        field_value = submission['values'][field_name]
        # If the attachment field value exists
        unless field_value.nil?
          files = []
          # Attachment field values are stored as arrays, one map for each file attachment
          field_value.each_index do |index|
            file_info = field_value[index]
            # The attachment file name is stored in the 'name' property
            # API route to get the generated attachment download link from Kinetic Request CE.
            attachment_download_api_route = server + '/app/api/v1' +
              '/submissions/' + URI.escape(@parameters['submission_id']) +
              '/files/' + URI.escape(field_name) +
              '/' + index.to_s +
              '/' + URI.escape(file_info['name']) +
              '/url'
            puts("Attachment Download API Route: \n#{attachment_download_api_route}") if @debug_logging_enabled


            # Retrieve the URL to download the attachment from Kinetic Request CE.
            # This URL will only be valid for a short amount of time before it expires
            # (usually about 5 seconds).
            attachment_download_result = RestClient::Resource.new(
              attachment_download_api_route,
              user: @info_values['api_username'],
              password: @info_values['api_password']
            ).get

            unless attachment_download_result.nil?
              url = JSON.parse(attachment_download_result)['url']
              file_info["url"] = url
            end
            file_info.delete("link")
            files << file_info
          end
        end
      end

    # If the credentials are invalid
    rescue RestClient::Unauthorized
      raise StandardError, "(Unauthorized): You are not authorized."
    rescue RestClient::ResourceNotFound => error
      raise StandardError, error.response
    end

    if files.nil?
        puts("No File in Field: \n#{field_name}") if @debug_logging_enabled
        return nil
    else
        puts("Using File URL: \n#{files[0]["url"]}") if @debug_logging_enabled
        puts("Using File Name: \n#{files[0]["name"]}") if @debug_logging_enabled
        attachment = RestClient::Resource.new(
          files[0]["url"],
          user: @info_values['api_username'],
          password: @info_values['api_password']
        ).get

        attachment_field = {}
        #attachment_field.name = files[0]["name"]
        #attachment_field.base64_content = Base64.encode64(attachment.body)
        #attachment_field.size = attachment.body.size()
        attachment_field['name'] = files[0]["name"]
        attachment_field['contentType'] = files[0]["contentType"]
        #attachment_field['base64_content'] = Base64.encode64(attachment.body)
        attachment_field['content'] = attachment.body
        attachment_field['size'] = attachment.body.size()

        return attachment_field

    end #if

  end #method

  ##############################################################################
  # General handler utility functions
  ##############################################################################
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

  # Builds a string that is formatted specifically for the Kinetic Task log file
  # by concatenating the provided header String with each of the provided hash
  # name/value pairs.  The String format looks like:
  #   HEADER
  #       KEY1: VAL1
  #       KEY2: VAL2
  # For example, given:
  #   field_values = {'Field 1' => "Value 1", 'Field 2' => "Value 2"}
  #   format_hash("Field Values:", field_values)
  # would produce:
  #   Field Values:
  #       Field 1: Value 1
  #       Field 2: Value 2
  def format_hash(header, hash)
    # Starting with the "header" parameter string, concatenate each of the
    # parameter name/value pairs with a prefix intended to better display the
    # results within the Kinetic Task log.
    hash.inject(header) do |result, (key, value)|
      result << "\n    #{key}: #{value}"
    end
  end

end
