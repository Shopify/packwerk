# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Breaking Changes

* `Packwerk::VERSION` now follows the `Gem::Version` syntax, which allows for more reliable version comparison. You need to use `Packwerk.gem_version` instead of `Packwerk::VERSION` to get the version string

## [1.3.2] - September 1st, 2021

### Bug fixes

* Fix bug in the `update-deprecations` command when the deprecation file has conflicts.
* Ignore duplicated load paths

## [1.3.1] - July 14th, 2021

### Bug fixes

* Fix usage of `Object#present?` that was not present in the library

## [1.3.0] - July 7th, 2021

### New features

* Booting changes. Should only boot the Rails application when needed. Check #128 for more info.
* Combined check and detect-stale-violations. Check #131 for more info.

### Bug fixes

* Constants under the public path in the root package were not correctly identified as public.

### Breaking changes

* Possibly breaking if spring was used with your project from the booting changes.
* packwerk check can fail if the violations are stale or the "No offenses detected" string was checked in the output.

## [1.2.0] - June 10th, 2021

### New Features

* Execute Packwerk commands in parallel.
* Add support to CLI for specifying a custom offenses formatter.
* Lazy load constant only when needed to avoid doing unnecessary work when loading the gem.

### Bug Fixes

None.

### Breaking changes

None.

## [1.1.3] Apri 1st, 2021

### New Features

none.

### Bug Fixes

* https://github.com/Shopify/packwerk/issues/106 Require fileutils to fix uninitialized constant error (https://github.com/Shopify/packwerk/pull/107, @jaydorsey)
* Support Ruby 3.0 and Rails 7 (https://github.com/Shopify/packwerk/pull/110)

### Breaking changes

none.

## [1.1.2] - January 12th, 2021

### New Features

* Give more helpful error message if privatized constant can not be resolved #89 (@exterm)

### Bug Fixes

* Convert autoload paths to strings to resolve a Sorbet type violation #91 (@steve-low)
* Improve types on interface implementations for stronger Sorbet type checking #92 (@samuelgiles)
* Extract an interface out of PackWerk::OutputStyles and enforce stronger type checking #93 (@samuelgiles)

### Breaking changes

none.

## [1.1.1] - December 9th, 2020

### New Features

none.

### Bug Fixes

* `self::SOME_CONSTANT` doesn't break the parser anymore https://github.com/Shopify/packwerk/pull/54 (thanks @shageman)
* fixes Sorbet TypeError during `packwerk init` on fresh install  https://github.com/Shopify/packwerk/pull/77 (thanks @mikelkew)
* fix Ruby warnings https://github.com/Shopify/packwerk/pull/82 (thanks @santib)
* refactor `packwerk detect-stale-violations` and `packwerk update-deprecations` https://github.com/Shopify/packwerk/pull/78 (thanks again @santib)
* fix a bug in `packwerk check` due to empty `packwerk.yml` file https://github.com/Shopify/packwerk/pull/87 (thanks @alexblackie and @jaruserickson)

### Breaking changes

none.

## [1.1.0] - November 24th, 2020

### Changes

* Detect stale violations for Packwerk command https://github.com/Shopify/packwerk/pull/61
* Support array of paths in PackageSet https://github.com/Shopify/packwerk/pull/71
* Support providing a custom ERB parser class https://github.com/Shopify/packwerk/pull/67

## [1.0.2] - November 16th, 2020

### Bug fixes

* Fix inflections bug that resulted in missed constant associations violations https://github.com/Shopify/packwerk/pull/53
  * This bug fix may result in additional valid violations being found / recorded in applications with custom inflections.
* Add missing `.realpath` that was causing validation error https://github.com/Shopify/packwerk/pull/65

-------

This release also includes other refactors to improve the codebase.

## [1.0.1] - October 30th, 2020

### This release is broken. Please use `v1.0.0`

### Changes

* `packwerk update` deprecated in favour of `packwerk update-deprecations`
  * This will update messaging in `deprecated_references.yml` files

### Bug Fixes

* Vendored gems will no longer be included when `packwerk` is run

## [1.0.0] - September 23rd, 2020

Packwerk has been developed in conjunction with the Shopify codebase by several developers. This initial release extracts the existing code from the private repository into a public gem to be open sourced.
