require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class ServicenowIncidentSearchV1
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
    username = @info_values['username']
    password = @info_values['password']

    if @info_values['instance_url'].match(/http:\/\//)
      puts "WARNING: The site '#{@info_values['site']}' does not appear to be configured \
for ssl. This handler uses basic authentication which means your username and password \
are being sent over an insecure connection if ssl is not configured."
    end

    soap_envelope = <<-SOAP_ENV
<?xml version="1.0"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:inc="http://www.service-now.com/incident">
   <soapenv:Header/>
   <soapenv:Body>
       <inc:getRecords>
           #{@parameters['query_xml']}
       </inc:getRecords>
   </soapenv:Body>
</soapenv:Envelope>
SOAP_ENV

    resource = RestClient::Resource.new(@info_values["instance_url"], :user => username, :password => password)
    resp = resource['incident_list.do?SOAP'].post soap_envelope, :content_type => "application/soap+xml"

    doc = REXML::Document.new(resp.body)

    ids_elem = REXML::Element.new("ids")
    REXML::XPath.each(doc, 'SOAP-ENV:Envelope/SOAP-ENV:Body/getRecordsResponse/getRecordsResult/sys_id') do |element|
      id_elem = REXML::Element.new("id")
      id_elem.add_text(element.text)
      ids_elem.add_element(id_elem)
    end    

    # Initialize the REXML formatter.  Also set the compact attribute to true, this
    # will result in no new lines for text within XML elements when printed.
    @formatter = REXML::Formatters::Pretty.new
    @formatter.compact = true
    # format the xml output string
    string = @formatter.write(ids_elem, "")

    
    <<-RESULTS
    <results>
      <result name='XML'>#{escape(string)}</result>
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
