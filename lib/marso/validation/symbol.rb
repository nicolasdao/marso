
class NilClass
  
  def ensure_valid_sync_mode
    raise ArgumentError, "'sync_mode' cannot be nil" if self == null
  end
end

class Object

  def ensure_valid_sync_mode
    raise ArgumentError, "'sync_mode' must be a Symbol" unless self.is_a?(Symbol)
  end
end

class Symbol

  def ensure_valid_sync_mode
    raise ArgumentError, "':#{self}' is an invalid sync_mode value. Valid values are either :sync or :async" unless (self == :sync || self == :async)
  end
end
