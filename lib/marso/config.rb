module Marso
  class Config
    @@configuration={
      # If true, the result of each step is output to the console in realtime
      # rather than waiting for the entire scenario to finish and then display
      # all the steps all at once. Setting that config to true may make reading
      # the output harder when multiple scenarios are executed in paralell.
      # Steps of different scenarios may indeed be intertwined in the console
      :realtime_step_stdout => false,

      # If true, all steps of the same scenario defined after a broken step(i.e.
      # step in status :failed, :error, or :cancelled) will not be executed, and
      # will all be set so their status is :cancelled
      :cancel_steps_upon_issues => true
    }

    def self.set(config_name, config_value)
      @@configuration[config_name] = config_value if @@configuration.key?(config_name)
    end

    def self.get(config_name)
      @@configuration[config_name]
    end
  end
end
