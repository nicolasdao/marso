require 'colorize'

module Marso
  module StepPublish

    # include_id will prepend the scenario id to the step's description.
    # This can be useful in the case where each step is being output to the
    # console in realtime. In that situation multiple steps from multiple
    # scenarios may be intertwined if they are executed concurently. Without
    # the scenario id, it may be difficult to identify which step belongs to
    # which scenario
    def colorized_text(include_id=false)
      scenario_id = "#{self.scenario_id}".colorize(self.color_theme)
      body = nil
      case @status
      when :none
        body = "#{self.description}".light_yellow
      when :passed
          body = "#{self.description}: PASSED".green
      when :failed
        body = "#{self.description}: FAILED".red
      when :cancelled
        body = "#{self.description}: CANCELLED".light_black
      when :error
        body = "#{self.description}".red
      end

      return include_id ? "#{scenario_id}: #{body}" : body
    end
  end
end
