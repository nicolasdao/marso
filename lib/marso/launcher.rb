require 'colorize'
require_relative 'feature'
require_relative 'story'
require_relative 'scenario'
require_relative 'helpers/componenthelper'
require_relative 'messages/errors'

module Marso

  def self.load_features(rootpath="")
    rootpath = Dir.pwd if (rootpath.nil? || rootpath.empty?)
    file_path_pattern = File.join(rootpath, 'features/*/*.rb')

    features = Marso.load_component(:feature, file_path_pattern)
  end

  # options (optional): Hash defined as follow
  #    :rootpath => Path of the folder containing the 'features' folder. If not
  #                 specified, then the default is to set it to the current
  #                 caller's location
  #    :select => Single feature's id or Array of feature's ids. The execution
  #               of features will be restricted to those ids only
  def self.run_features(options={})
    rootpath = Dir.pwd if (options[:rootpath].nil? || options[:rootpath].empty?)

    features = Marso.load_features(rootpath)

    if features.empty?
      puts Marso::Messages.no_features_found.red
      return false
    end

    selection =
      options[:select].nil? ?
      [] : options[:select].is_a?(Array) ? options[:select] : [options[:select]]

    if selection.any?
      offenders = selection.select { |x| !features.any? { |y| y.id == x } }
      if offenders.any?
        puts Marso::Messages.no_features_found.red(offenders)
        return false
      end
    end

    feat_to_runned = selection.any? ? features.select { |x| selection.include?(x.id) } : features

    feat_to_runned.each { |x| x.run :all}
    true
  end
end
