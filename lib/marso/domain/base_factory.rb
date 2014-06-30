
module Marso
	module BaseFactory
		private
			def get_template(path)
				template = nil
				File.open(path, "rb") do |f|
					template = f.read
				end
				return template
			end
	end
end