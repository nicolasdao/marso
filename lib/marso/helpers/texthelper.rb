require 'colorize'

module Marso
  # The is module assume that the entity that will mix it uses a, integer
  # variable called '@indent_steps' that is used to indent the text
  module TextHelper

    def indented_colorized_text
      indent_text(colorized_text, self.tree_position)
    end

    def colorized_text
      "Overide me".red
    end

    private

      def indent_text(text, indentation)
        indent = Array.new(indentation, "\t").join
        indent.concat(text.gsub("\n", "\n#{indent}"))
      end
  end
end
