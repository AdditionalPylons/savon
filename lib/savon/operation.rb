require 'savon/response'
require 'savon/envelope'
require 'savon/example_message'

class Savon
  class Operation

    ENCODING = 'UTF-8'

    CONTENT_TYPE = {
      '1.1' => 'text/xml;charset=%s',
      '1.2' => 'application/soap+xml;charset=%s'
    }

    def initialize(operation, wsdl, http)
      @operation = operation
      @wsdl = wsdl
      @http = http

      @endpoint = operation.endpoint
      @soap_version = operation.soap_version
      @soap_action = operation.soap_action
      @encoding = ENCODING
      @wsa = example_wsa

      this.convert_to_snakecase = true
    end

    # Public: Accessor for the SOAP endpoint.
    attr_accessor :endpoint

    # Public: Accessor for the SOAP version.
    attr_accessor :soap_version

    # Public: Accessor for the SOAPAction HTTP header.
    attr_accessor :soap_action

    # Public: Accessor for the encoding. Defaults to 'UTF-8'.
    attr_accessor :encoding

    # Public: Returns a Hash of HTTP headers to send.
    def http_headers
      return @http_headers if @http_headers
      headers = {}

      headers['SOAPAction']   = %{"#{soap_action}"} if soap_action
      headers['Content-Type'] = CONTENT_TYPE[soap_version] % encoding

      @http_headers = headers
    end

    # Public: Sets the Hash of HTTP headers.
    attr_writer :http_headers

    # Public: Sets the request header Hash.
    attr_accessor :header

    # Public: Create an example request header Hash.
    def example_header
      ExampleMessage.build(@operation.input.header_parts)
    end

    # Public: Sets the request body Hash.
    attr_accessor :body

    # Public: Create an example request body Hash.
    def example_body
      ExampleMessage.build(@operation.input.body_parts)
    end

    # Public: Returns the input body parts used to build the request body.
    def body_parts
      @operation.input.body_parts.inject([]) { |memo, part| memo + part.to_a }
    end

    # Public: Build the request XML for this operation.
    def build
      if(wsa and wsa[:enable_wsa] == true)
        Envelope.new(@operation, header, body, wsa).to_s
      else
        Envelope.new(@operation, header, body).to_s
      end
    end

    # Public: Call the operation.
    def call
      raw_response = @http.post(endpoint, http_headers, build)
      Response.new(raw_response, convert_to_snakecase)
    end

    # Public: Returns the input style for this operation.
    def input_style
      @input_style ||= @operation.input_style
    end

    # Public: Returns the output style for this operation.
    def output_style
      @output_style ||= @operation.output_style
    end

    # Public: Returns an example WS-A configureation hash.
    def example_wsa
      {
        enable_wsa: false,
        must_understand: nil,
        version: 200508,
        action: nil,
        to: nil,
        reply_to: nil,
        reply_to_params: nil,
        message_id: nil,
        from: nil,
        fault_to: nil,
        fault_to_params: nil,
        relates_to: nil,
        relationship_type: nil
      }
    end

    # Public: Accessor for setting WS-A headers.
    attr_accessor :wsa

    # Public: Determines if response should be converted to snakecase.
    attr_accessor :convert_to_snakecase

  end
end
