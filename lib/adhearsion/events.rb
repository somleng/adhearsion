# encoding: utf-8

require 'has_guarded_handlers'
require 'singleton'
require 'celluloid'
require 'celluloid/pool'

module Adhearsion
  module Events

    class Handler
      include HasGuardedHandlers
      include Singleton

      def call_handler(handler, guards, event)
        super
        throw :pass
      end

      alias :register_callback :register_handler

      def method_missing(method_name, *args, &block)
        register_handler method_name, *args, &block
      end

      def respond_to_missing?(method_name, include_private = false)
        true
      end
    end

    class Worker
      include Celluloid

      def work(type, object)
        Handler.instance.trigger_handler type, object
      rescue => e
        raise if type == :exception
        async.work :exception, e
      end
    end

    class << self
      def method_missing(method_name, *args, &block)
        Handler.instance.send method_name, *args, &block
      end

      def respond_to_missing?(method_name, include_private = false)
        Handler.instance.respond_to? method_name, include_private
      end

      def trigger(type, object = nil)
        queue.async.work type, object
      end

      def trigger_immediately(type, object = nil)
        queue.work type, object
      end

      def draw(&block)
        Handler.instance.instance_exec(&block)
      end

      def queue
        unless @queue && @queue.alive?
          init
        end

        @queue
      end

      def init
        size = Adhearsion.config.core.event_threads
        logger.debug "Initializing event worker pool of size #{size}"
        @queue = Worker.pool(size: size)
      end

      def refresh!
        clear
        init
      end

      def clear
        @queue = nil
        Handler.instance.clear_handlers
      end
    end

  end
end
