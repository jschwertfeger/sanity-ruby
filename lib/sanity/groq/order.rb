# frozen_string_literal: true

module Sanity
  module Groq
    class Order
      class << self
        def call(**args)
          new(**args).call
        end
      end

      RESERVED = %i[order]

      attr_reader :order, :val

      def initialize(**args)
        opts = args.slice(*RESERVED)
        @order = opts[:order]

        @val = +""
      end

      def call
        return unless order

        raise ArgumentError, "order must be hash" unless order.is_a?(Hash)

        order.to_a.each_with_index do |(key, sort), idx|
          str =" | order(#{key} #{sort})"
          val << idx.positive? ? str : str.strip
        end

        val
      end
    end
  end
end
