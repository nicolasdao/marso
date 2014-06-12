module Marso
  # The is module assume that the entity that will mix it uses a, integer
  # variable called '@indent_steps' that is used to indent the text
  module TextHelper
    private
      def puts_indented(text)
        puts get_indented_text(text)
      end

      def print_indented(text)
        puts get_indented_text(text)
      end

      def get_indented_text(text)
        indent = Array.new(@indent_steps, "\t").join
        indent.concat(text.gsub("\n", "\n#{indent}"))
      end
  end
end
