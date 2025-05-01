module MyLocalExtension
end

class MyOffensesFormatter
  include Packwerk::OffensesFormatter

  def show_offenses(offenses)
    ["hi i am a custom offense formatter", *offenses].join("\n")
  end

  def show_stale_violations(_offense_collection, _fileset)
    "stale violations report"
  end

  def identifier
    'my_offenses_formatter'
  end

  def show_strict_mode_violations(offenses)
    "strict mode violations report"
  end
end
