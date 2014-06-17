require 'eventmachine'

module Marso
  class Enumerate

    STOP_MSG = "End of seed"
    attr_reader :process, :src

    def self.from(collection)
      _process = lambda {
        collection.each { |x|
          Fiber.yield x
        }

        raise StopIteration, STOP_MSG
      }

      Enumerate.new(_process)
    end

    def initialize(process, source={})
      @src = source
      @process = process

      @fiber_delegate = Fiber.new do
        process.call
      end
    end

    def resume
      if @src.is_a?(Marso::Enumerate)
        @fiber_delegate.resume(@src.resume)
      else # case where @src is nil
        @fiber_delegate.resume
      end
    end

    def source(other_source)
      Enumerate.new(@process, other_source)
    end

    def clone
      class_name = self.class.to_s
      if @src.is_a?(Marso::Enumerate)
        return Object.const_get(class_name).new(@process, @src.clone)
      else
        return Object.const_get(class_name).new(@process)
      end
    end

    def |(other_source)
      other_source.source(clone_original_source_to_protect_it)
    end

    def where(&block)
      FiberFilter.new(block, clone_original_source_to_protect_it)
    end

    def select(&block)
      FiberProjection.new(block, clone_original_source_to_protect_it)
    end

    def select_many(&block)
      FiberProjectionMany.new(block, clone_original_source_to_protect_it)
    end

    def execute(max_iteration=1000000)
      begin
        if max_iteration.zero?
          loop do
            self.resume
          end
        else
          max_iteration.times { self.resume }
        end
      rescue StopIteration => ex
        raise ex unless ex.message == STOP_MSG
      rescue Exception => ex
        raise ex
      end
    end

    def to_a
      a = []
      begin
        loop do
          a << self.resume
        end
      rescue StopIteration => ex
        raise ex unless ex.message == STOP_MSG
      rescue Exception => ex
        raise ex
      end

      return a
    end

    private
      def clone_original_source_to_protect_it
        # prevent the core source to be altered so that we can reuse it
        # to build other queries. Otherwise, after one usage, there'll be
        # a dead fiber exception thrown
        return self.clone
      end
  end

  class FiberProjection < Enumerate

    def initialize(process, source={})
      @src = source
      @process = process

      @fiber_delegate = Fiber.new do
        output = nil
        while input = Fiber.yield(output)
          output = process.call(input)
        end
      end

      @fiber_delegate.resume
    end

    def source(other_source)
      FiberProjection.new(@process, other_source)
    end
  end

  class FiberProjectionMany < Enumerate

    def initialize(process, source={})
      @src = source
      @process = process
      @is_inside_inner_enumerate = false

      @fiber_delegate = Fiber.new do
        output = []
        while input = Fiber.yield(output)
          output = process.call(input)

          @is_inside_inner_enumerate = true

          output.each { |o|
            Fiber.yield(o)
          }

          @is_inside_inner_enumerate = false
        end
      end

      @fiber_delegate.resume
    end

    def resume
      if @src.is_a?(Marso::Enumerate) && !@is_inside_inner_enumerate
        output = @fiber_delegate.resume(@src.resume)
        output = @fiber_delegate.resume(@src.resume)  if output.is_a?(Array) && output.empty?
        return output
      else
        output = @fiber_delegate.resume
        output = @fiber_delegate.resume(@src.resume) unless @is_inside_inner_enumerate
        output = @fiber_delegate.resume(@src.resume)  if output.is_a?(Array) && output.empty?
        return output
      end
    end

    def source(other_source)
      FiberProjectionMany.new(@process, other_source)
    end

  end

  class FiberFilter < Enumerate

    def initialize(process, source={})
      @src = source
      @process = process

      @fiber_delegate = Fiber.new do
        output = nil
        while input = Fiber.yield(output)
          if process.call(input)
            output = input
          else
            output = :invalid_input
          end
        end
      end

      @fiber_delegate.resume
    end

    def resume
      v = nil
      if @src.is_a?(Marso::Enumerate)
        v = @fiber_delegate.resume(@src.resume)
        v = self.resume if v == :invalid_input
      else
        v = @fiber_delegate.resume
      end
      return v
    end

    def source(other_source)
      FiberFilter.new(@process, other_source)
    end
  end
end
