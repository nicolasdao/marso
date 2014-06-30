require 'pathname'
require 'securerandom'
require 'fileutils'
require_relative 'story'
require_relative '../base_factory'

module Marso

	class StoryFactory
		include Marso::BaseFactory

		def create_story_file(description={}, root=nil)
			raise ArgumentError, "Story's name is required" unless description[:name]
			id = description[:id] || SecureRandom.hex(3)
			name = description[:name]
			in_order_to = description[:in_order_to] || ""
			as_a = description[:as_a] || ""
			i = description[:i] || ""

			template = get_template(Pathname("../story_template.rb").expand_path(__FILE__))
				.gsub(/#\{id\}/, id)
				.gsub(/#\{name\}/, name)
				.gsub(/#\{in_order_to\}/, in_order_to)
				.gsub(/#\{as_a\}/, as_a)
				.gsub(/#\{i\}/, i)

			fname = name.downcase.gsub(' ', '_')
			feature_file = "#{fname}.rb"
			root = root || File.join(Dir.pwd, fname)

			FileUtils.mkdir root unless File.directory? root
			FileUtils.mkdir File.join(root, "Scenarios")

			dest = File.join(root, feature_file)
			File.open(dest, "w") do |f|
				f.write(template)
			end

			return feature_file
		end
	end
end