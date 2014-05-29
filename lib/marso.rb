require "marso/version"
require "colorize"

module Marso
	module_function

	def assert message, &block
		begin
			if (block.call)
				puts "Assert #{message}: PASSED".green
			else
				puts "Assert #{message}: FAILED".red
			end
		rescue Exception => e
			puts "Assert #{message} FAILED with exception #{e}"
		end
	end
end
