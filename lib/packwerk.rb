# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require "active_support"
require "constant_resolver"

require "packwerk/offense"

require "packwerk/application_validator"
require "packwerk/association_inspector"
require "packwerk/checking_deprecated_references"
require "packwerk/cli"
require "packwerk/configuration"
require "packwerk/const_node_inspector"
require "packwerk/constant_discovery"
require "packwerk/constant_name_inspector"
require "packwerk/dependency_checker"
require "packwerk/deprecated_references"
require "packwerk/files_for_processing"
require "packwerk/file_processor"
require "packwerk/formatters/progress_formatter"
require "packwerk/generators/application_validation"
require "packwerk/generators/configuration_file"
require "packwerk/generators/inflections_file"
require "packwerk/generators/root_package"
require "packwerk/graph"
require "packwerk/inflector"
require "packwerk/node_processor"
require "packwerk/node_visitor"
require "packwerk/output_styles"
require "packwerk/package"
require "packwerk/package_set"
require "packwerk/parsers"
require "packwerk/privacy_checker"
require "packwerk/reference_extractor"
require "packwerk/run_context"
require "packwerk/updating_deprecated_references"
require "packwerk/version"
require "packwerk/violation_type"
require "packwerk/ancestors"

module Packwerk
end
