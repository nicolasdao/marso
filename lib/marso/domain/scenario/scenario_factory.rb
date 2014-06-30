require 'pathname'
require 'securerandom'
require 'fileutils'
require_relative 'scenario'
require_relative '../base_factory'

module Marso

	class ScenarioFactory
		include Marso::BaseFactory

		def create_scenario_file(description={}, root=nil)
			raise ArgumentError, "Scenario's name is required" unless description[:name]
			id = description[:id] || SecureRandom.hex(3)
			name = description[:name]
			given = description[:given] || ""
			_when = description[:when] || ""
			_then = description[:then] || ""

			template = get_template(Pathname("../scenario_template.rb").expand_path(__FILE__))
				.gsub(/#\{id\}/, id)
				.gsub(/#\{name\}/, name)
				.gsub(/#\{given\}/, given)
				.gsub(/#\{_when\}/, _when)
				.gsub(/#\{_then\}/, _then)

			fname = name.downcase.gsub(' ', '_')
			feature_file = "#{fname}.rb"
			root = root || Dir.pwd

			dest = File.join(root, feature_file)
			File.open(dest, "w") do |f|
				f.write(template)
			end

			return feature_file
		end
	end
end