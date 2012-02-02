module Notes
  module VERSION #:nodoc:
    MAJOR = 0
    MINOR = 16
    TINY = 2
    BUILD = "pre" # nil, "pre", "beta1", "beta2", "rc", "rc2"

    STRING = [MAJOR, MINOR, TINY, BUILD].compact.join('.')
  end
end
