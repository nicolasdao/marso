
module Marso
  module Messages

    def self.no_features_found
      "E0000: No features were found under path '#{rootpath}'.\n" +
      "Browse to a different folder, or use the :rootpath option to define an adequate path"
    end

    def self.features_not_found(offenders)
      "E0001: The following selected feature ids couldn't be found: #{offenders.join(', ')}"
    end

  end
end
