# typed: true
# frozen_string_literal: true

module Packwerk
  module Inflections
    module Default
      class << self
        def apply_to(inflections_object)
          # copied from active_support/inflections
          # https://github.com/rails/rails/blob/d2ae2c3103e93783971d5356d0b3fd1b4070d6cf/activesupport/lib/active_support/inflections.rb#L12
          inflections_object.plural(/$/, "s")
          inflections_object.plural(/s$/i, "s")
          inflections_object.plural(/^(ax|test)is$/i, '\1es')
          inflections_object.plural(/(octop|vir)us$/i, '\1i')
          inflections_object.plural(/(octop|vir)i$/i, '\1i')
          inflections_object.plural(/(alias|status)$/i, '\1es')
          inflections_object.plural(/(bu)s$/i, '\1ses')
          inflections_object.plural(/(buffal|tomat)o$/i, '\1oes')
          inflections_object.plural(/([ti])um$/i, '\1a')
          inflections_object.plural(/([ti])a$/i, '\1a')
          inflections_object.plural(/sis$/i, "ses")
          inflections_object.plural(/(?:([^f])fe|([lr])f)$/i, '\1\2ves')
          inflections_object.plural(/(hive)$/i, '\1s')
          inflections_object.plural(/([^aeiouy]|qu)y$/i, '\1ies')
          inflections_object.plural(/(x|ch|ss|sh)$/i, '\1es')
          inflections_object.plural(/(matr|vert|ind)(?:ix|ex)$/i, '\1ices')
          inflections_object.plural(/^(m|l)ouse$/i, '\1ice')
          inflections_object.plural(/^(m|l)ice$/i, '\1ice')
          inflections_object.plural(/^(ox)$/i, '\1en')
          inflections_object.plural(/^(oxen)$/i, '\1')
          inflections_object.plural(/(quiz)$/i, '\1zes')

          inflections_object.singular(/s$/i, "")
          inflections_object.singular(/(ss)$/i, '\1')
          inflections_object.singular(/(n)ews$/i, '\1ews')
          inflections_object.singular(/([ti])a$/i, '\1um')
          inflections_object.singular(/((a)naly|(b)a|(d)iagno|(p)arenthe|(p)rogno|(s)ynop|(t)he)(sis|ses)$/i, '\1sis')
          inflections_object.singular(/(^analy)(sis|ses)$/i, '\1sis')
          inflections_object.singular(/([^f])ves$/i, '\1fe')
          inflections_object.singular(/(hive)s$/i, '\1')
          inflections_object.singular(/(tive)s$/i, '\1')
          inflections_object.singular(/([lr])ves$/i, '\1f')
          inflections_object.singular(/([^aeiouy]|qu)ies$/i, '\1y')
          inflections_object.singular(/(s)eries$/i, '\1eries')
          inflections_object.singular(/(m)ovies$/i, '\1ovie')
          inflections_object.singular(/(x|ch|ss|sh)es$/i, '\1')
          inflections_object.singular(/^(m|l)ice$/i, '\1ouse')
          inflections_object.singular(/(bus)(es)?$/i, '\1')
          inflections_object.singular(/(o)es$/i, '\1')
          inflections_object.singular(/(shoe)s$/i, '\1')
          inflections_object.singular(/(cris|test)(is|es)$/i, '\1is')
          inflections_object.singular(/^(a)x[ie]s$/i, '\1xis')
          inflections_object.singular(/(octop|vir)(us|i)$/i, '\1us')
          inflections_object.singular(/(alias|status)(es)?$/i, '\1')
          inflections_object.singular(/^(ox)en/i, '\1')
          inflections_object.singular(/(vert|ind)ices$/i, '\1ex')
          inflections_object.singular(/(matr)ices$/i, '\1ix')
          inflections_object.singular(/(quiz)zes$/i, '\1')
          inflections_object.singular(/(database)s$/i, '\1')

          inflections_object.irregular("person", "people")
          inflections_object.irregular("man", "men")
          inflections_object.irregular("child", "children")
          inflections_object.irregular("sex", "sexes")
          inflections_object.irregular("move", "moves")
          inflections_object.irregular("zombie", "zombies")

          inflections_object.uncountable(["equipment", "information", "rice", "money", "species", "series", "fish",
                                          "sheep", "jeans", "police"])
        end
      end
    end
  end
end
