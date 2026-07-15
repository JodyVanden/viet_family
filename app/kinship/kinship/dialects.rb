module Kinship
  # Regional vocabulary. Only the words that actually differ by region are keyed
  # here; terms shared across dialects live in Terms. Default is Southern.
  module Dialects
    SOUTHERN = {
      father: "Ba",
      mother: "Má"
    }.freeze

    NORTHERN = {
      father: "Bố",
      mother: "Mẹ"
    }.freeze

    ALL = { southern: SOUTHERN, northern: NORTHERN }.freeze

    module_function

    def fetch(dialect)
      ALL.fetch(dialect) { raise ArgumentError, "unknown dialect: #{dialect.inspect}" }
    end
  end
end
