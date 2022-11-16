# frozen_string_literal: true

using Sanity::Refinements::Strings
using Sanity::Refinements::Arrays

module Sanity
  module Http
    module Mutation
      class << self
        def included(base)
          base.extend(ClassMethods)
          base.extend(Forwardable)
          base.delegate(%i[project_id api_version dataset token api_subdomain] => :"Sanity.config")
          base.delegate(mutatable_api_endpoint: :resource_klass)
        end
      end

      module ClassMethods
        def call(**args)
          new(**args).call
        end
      end

      # See https://www.sanity.io/docs/http-mutations#visibility-937bc4250c79
      ALLOWED_VISIBILITY = %i[sync async deferred]

      # See https://www.sanity.io/docs/http-mutations#aa493b1c2524
      REQUEST_KEY = "mutations"

      # See https://www.sanity.io/docs/http-mutations#952b77deb110
      DEFAULT_QUERY_PARAMS = {
        return_ids: false,
        return_documents: false,
        visibility: :sync
      }.freeze

      attr_reader :options, :params, :resource_klass, :query_set, :result_wrapper

      def initialize(**args)
        @resource_klass = args.delete(:resource_klass)
        @params = args.delete(:params)
        @query_set = Set.new
        @result_wrapper = args.delete(:result_wrapper) || Sanity::Http::Results

        raise ArgumentError, "resource_klass must be defined" unless resource_klass
        raise ArgumentError, "params argument is missing" unless params

        opts = (args.delete(:options) || {})
        DEFAULT_QUERY_PARAMS.keys.each do |qup|
          query_set << [qup, opts.fetch(qup, DEFAULT_QUERY_PARAMS[qup])]
        end
        raise ArgumentError, "visibility argument must be one of #{ALLOWED_VISIBILITY}" unless valid_invisibility?
      end

      def body_key
        self.class.name.demodulize.underscore.camelize_lower
      end

      def call
        req = Net::HTTP::Post.new(uri.path, headers)
        req.body = {"#{REQUEST_KEY}": body}.to_json
        result = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
          http.request(req)
        end
        block_given? ? yield(result_wrapper.call(result)) : result_wrapper.call(result)
      end

      private

      def base_url
        "https://#{project_id}.#{api_subdomain}.sanity.io/#{api_version}/#{mutatable_api_endpoint}/#{dataset}"
      end

      def body
        return Array.wrap({"#{body_key}": params}) if params.is_a?(Hash)

        Array.wrap(params.map { |pam| {"#{body_key}": pam} })
      end

      def camelize_query_set
        result = {}
        hash = query_set.to_h
        hash.each_key do |key|
          result[key.to_s.camelize_lower] = hash[key]
        end
        result
      end

      def headers
        {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{token}"
        }
      end

      def query_params
        camelize_query_set.map do |key, val|
          "#{key}=#{val}"
        end.join("&")
      end

      def uri
        URI(base_url).tap do |obj|
          obj.query = query_params
        end
      end

      def valid_invisibility?
        ALLOWED_VISIBILITY.include? query_set.to_h[:visibility]
      end
    end
  end
end
