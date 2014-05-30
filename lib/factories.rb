require "marso/version"
# require 'watir-webdriver'
# require 'selenium-webdriver'
#
# module Marso
#   module_function
#
#   def openNewBrowser(browser=nil)
#     browser = !browser.nil? && browser.class == Symbol ? browser : :firefox
#     profile = nil
#     case browser
#     when :firefox
#       profile = Selenium::WebDriver::Firefox::Profile.new
#     else
#       raise "Marso does not support '#{browser}' yet. The only supported browser is currently firefox"
#     end
#
#     profile['browser.cache.disk.enable'] = false
#
#     b = Watir::Browser.new browser, :profile => profile
#     return b
#   end
# end
