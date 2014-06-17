
class Symbol

  def > s
    return bigger(s)
  end

  def >= s
    return bigger(s, true)
  end

  def < s
    !(self>s)
  end

  def <= s
    if self == s
      return true
    else
      return self<s
    end
  end

  def to_load_mode
    case self
    when :none
      return :none
    when :with_stories
      return :stories
    when :with_stories_scenarios
      return :stories_with_scenarios
    when :with_scenarios
      return :scenario_contexts
    when :with_all
      return :all
    else
      return self
    end
  end

  private
    def bigger(s, indlude_equal=false)
      if self == :none
        case s
        when :none
          return indlude_equal
        when :passed
          return false
        when :cancelled
          return false
        when :failed_no_component
          return false
        when :failed
          return false
        when :error
          return false
        else
          return nil
        end
      end

      if self == :passed
        case s
        when :none
          return true
        when :passed
          return indlude_equal
        when :cancelled
          return false
        when :failed_no_component
          return false
        when :failed
          return false
        when :error
          return false
        else
          return nil
        end
      end

      if self == :cancelled
        case s
        when :none
          return true
        when :passed
          return true
        when :cancelled
          return indlude_equal
        when :failed_no_component
          return false
        when :failed
          return false
        when :error
          return false
        else
          return nil
        end
      end

      if self == :failed_no_component
        case s
        when :none
          return true
        when :passed
          return true
        when :cancelled
          return true
        when :failed_no_component
          return indlude_equal
        when :failed
          return false
        when :error
          return false
        else
          return nil
        end
      end

      if self == :failed
        case s
        when :none
          return true
        when :passed
          return true
        when :cancelled
          return true
        when :failed_no_component
          return true
        when :failed
          return indlude_equal
        when :error
          return false
        else
          return nil
        end
      end

      if self == :error
        case s
        when :none
          return true
        when :passed
          return true
        when :cancelled
          return true
        when :failed_no_component
          return true
        when :failed
          return true
        when :error
          return indlude_equal
        else
          return nil
        end
      end
    end
end

class Array
  def status
    _status = :none
    unless self.nil? || self.empty?
      _status = self.reduce { |x,y| Marso.item_with_stronger_status(x, y) }.status
    end

    return _status == :failed_no_component ? :failed : _status
  end
end

module Marso

  def self.item_with_stronger_status(x, y)
    return x.status>=y.status ? x : y
  end
end
