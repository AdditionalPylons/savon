require 'builder'
require 'savon/message'

class Savon
  class Envelope

    NSID = 'lol'

    def initialize(operation, header, body, options = {})
      @logger = Logging.logger[self]

      @operation = operation
      @header = header || {}
      @body = body || {}

      @nsid_counter = -1
      @namespaces = {}

      @wsa_options = options
    end

    def register_namespace(namespace)
      @namespaces[namespace] ||= create_nsid
    end

    def to_s
      build_envelope(build_header, build_body)
    end

    private

    def create_nsid
      @nsid_counter += 1
      "#{NSID}#{@nsid_counter}"
    end

    def build_header
      return "" if @header.empty?
      Message.new(self, @operation.input.header_parts).build(@header)
    end

    def build_body
      return "" if @body.empty?
      body = Message.new(self, @operation.input.body_parts).build(@body)

      if rpc_call?
        build_rpc_wrapper(body)
      else
        body
      end
    end

    def build_envelope(header, body)
      builder = Builder::XmlMarkup.new(indent: 2)
      builder.tag! :env, :Envelope, collect_namespaces do |xml|
        if(@wsa_options[:enable_wsa] == true)
          build_wsa_header(xml)
        else
          xml.tag!(:env, :Header) { |xml| xml << header }
        end
        xml.tag!(:env, :Body) { |xml| xml << body }
      end

      builder.target!
    end

    def build_wsa_header xml
      unless xml.nil?
        namespaces = case @wsa_options[:must_understand]
        when nil
          nil
        when true
          {'env:mustUnderstand' => "1"}
        when false
          {'env:mustUnderstand' => "0"}          
        end

        xml.tag!(:env, :header, build_wsa_namespace) { |xml| 
          xml.tag!(:wsa, :Action, namespaces) { |xml| xml << ( @wsa_options[:action] || @operation.soap_action ) }

          xml.tag!(:wsa, :To, namespaces) { |xml| xml << @wsa_options[:to] || @operation.endpoint }

          (xml.tag!(:wsa, :ReplyTo, namespaces) { |xml|
            xml.tag!(:wsa, :Address) { |xml| xml << @wsa_options[:reply_to]}
            (xml.tag!(:wsa, :ReferenceParameters) { |xml| xml << @wsa_options[:reply_to_reference_params]}) if @operation[:reply_to_reference_params]
          }) if @wsa_options[:reply_to]

          (xml.tag!(:wsa, :From, namespaces) { |xml| 
            xml.tag!(:wsa, :Address) { |xml| xml << @wsa_options[:from]}
          }) if @wsa_options[:from]

          (xml.tag!(:wsa, :FaultTo, namespaces) { |xml|
            xml.tag!(:wsa, :Address) { |xml| xml << @wsa_options[:fault_to]}
            (xml.tag!(:wsa, :ReferenceParameters) { |xml| xml << @wsa_options[:fault_to_reference_params]}) if @wsa_options[:fault_to_reference_params]
          }) if @wsa_options[:fault_to]

          relates_to_ns = @wsa_options[:relationship_type].nil? ? {} : {'RelationshipType' => @wsa_options[:relationship_type]} 
          (xml.tag!(:wsa, :RelatesTo, relates_to_ns.merge(namespaces)) { |xml| @wsa_options[:relates_to]}) if @wsa_options[:relates_to]

          (xml.tag!(:wsa, :MessageID, namespaces) { |xml| xml << @wsa_options[:message_id] }) if @wsa_options[:message_id]
          
        }
      end
    end

    def build_wsa_namespace
      if @wsa_options[:version] == 200408 or @wsa_options[:version] == '200408'
        return {'xmlns:wsa' => "http://www.w3.org/2004/08/addressing"}
      else
        return {'xmlns:wsa' => "http://www.w3.org/2005/08/addressing"}
      end
    end

    def build_rpc_wrapper(body)
      name = @operation.name
      namespace = @operation.binding_operation.input_body[:namespace]
      nsid = register_namespace(namespace) if namespace

      tag = [nsid, name].compact.join(':')

      '<%{tag}>%{body}</%{tag}>' % { tag: tag, body: body }
    end

    def rpc_call?
      @operation.binding_operation.style == 'rpc'
    end

    def collect_namespaces
      # registered namespaces
      namespaces = @namespaces.each_with_object({}) { |(namespace, nsid), memo|
        memo["xmlns:#{nsid}"] = namespace
      }

      # envelope namespace
      namespaces['xmlns:env'] = case @operation.soap_version
        when '1.1' then 'http://schemas.xmlsoap.org/soap/envelope/'
        when '1.2' then 'http://www.w3.org/2003/05/soap-envelope'
      end

      namespaces
    end

  end
end
