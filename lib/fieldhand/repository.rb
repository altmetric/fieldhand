require 'fieldhand/arguments'
require 'fieldhand/header'
require 'fieldhand/logger'
require 'fieldhand/metadata_format'
require 'fieldhand/paginator'
require 'fieldhand/record'
require 'fieldhand/set'
require 'fieldhand/identify_parser'
require 'uri'

module Fieldhand
  # A repository is a network accessible server that can process the 6 OAI-PMH requests.
  #
  # See https://www.openarchives.org/OAI/openarchivesprotocol.html
  class Repository
    attr_reader :uri, :logger

    def initialize(uri, logger = Logger.null)
      @uri = uri.is_a?(::URI) ? uri : URI(uri)
      @logger = logger
    end

    def identify
      paginator.
        sax_items('Identify', IdentifyParser).
        first
    end

    def metadata_formats(identifier = nil)
      return enum_for(:metadata_formats, identifier) unless block_given?

      arguments = {}
      arguments['identifier'] = identifier if identifier

      paginator.
        items('ListMetadataFormats', 'ListMetadataFormats/metadataFormat', arguments).
        each do |format, response_date|
          yield MetadataFormat.new(format, response_date)
        end
    end

    def sets
      return enum_for(:sets) unless block_given?

      paginator.
        items('ListSets', 'ListSets/set').
        each do |set, response_date|
          yield Set.new(set, response_date)
        end
    end

    def records(arguments = {})
      return enum_for(:records, arguments) unless block_given?

      query = Arguments.new(arguments).to_query

      paginator.
        items('ListRecords', 'ListRecords/record', query).
        each do |record, response_date|
          yield Record.new(record, response_date)
        end
    end

    def identifiers(arguments = {})
      return enum_for(:identifiers, arguments) unless block_given?

      query = Arguments.new(arguments).to_query

      paginator.
        items('ListIdentifiers', 'ListIdentifiers/header', query).
        each do |header, response_date|
          yield Header.new(header, response_date)
        end
    end

    def get(identifier, arguments = {})
      query = {
        'identifier' => identifier,
        'metadataPrefix' => arguments.fetch(:metadata_prefix, 'oai_dc')
      }

      paginator.
        items('GetRecord', 'GetRecord/record', query).
        map { |record, response_date| Record.new(record, response_date) }.
        first
    end

    private

    def paginator
      @paginator ||= Paginator.new(uri, logger)
    end
  end
end
