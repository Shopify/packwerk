require "packwerk/inflections/custom"

ActiveSupport::Inflector.inflections do |inflect|
  Packwerk::Inflections::Custom.new(
    Rails.root.join("custom_inflections.yml")
  ).apply_to(inflect)
end
