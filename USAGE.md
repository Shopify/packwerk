# Packwerk usage

## Table of Contents

* [What problem does Packwerk solve?](#what-problem-does-packwerk-solve)
* [What is a package?](#what-is-a-package)
  * [Package principles](#package-principles)
* [Getting started](#getting-started)
  * [Setting up Spring](#setting-up-spring)
* [Configuring Packwerk](#configuring-packwerk)
  * [Using a custom ERB parser](#using-a-custom-erb-parser)
* [Validating the package system](#validating-the-package-system)
* [Defining packages](#defining-packages)
  * [Package metadata](#package-metadata)
* [Types of boundary checks](#types-of-boundary-checks)
  * [Enforcing privacy boundary](#enforcing-privacy-boundary)
    * [Using public folders](#using-public-folders)
  * [Enforcing dependency boundary](#enforcing-dependency-boundary)
* [Checking for violations](#checking-for-violations)
* [Resolving new violations](#resolving-new-violations)
  * [Understanding how to respond to new violations](#understanding-how-to-respond-to-new-violations)
* [Recording existing violations](#recording-existing-violations)
  * [Understanding the list of deprecated references](#understanding-the-list-of-deprecated-references)

## What problem does Packwerk solve?

Large applications need clear boundaries to avoid turning into a [ball of mud](https://en.wikipedia.org/wiki/Big_ball_of_mud). However, Ruby does not provide a good solution to enforcing boundaries between code.

Packwerk is a gem that can be used to enforce boundaries between groups of code we call packages.

## What is a package?

A package is a folder containing autoloaded code. To decide whether code belongs together in a package, these are some design best practices:

- We should package things together that have high functional [cohesion](https://en.wikipedia.org/wiki/Cohesion_(computer_science)).
- Packages should be relatively loosely coupled to each other.

![cohesion](docs/cohesion.png)

### Package principles

Package principles help to guide the organization of classes in a large system. These principles can also be applied to packages in large and complex codebases.

The [package principles](https://en.wikipedia.org/wiki/Package_principles) page on Wikipedia does a good job explaining what well designed packages look like.

## Getting started

After including Packwerk in the Gemfile, you will first want to generate a binstub:
You can do this by running `bundle binstub packwerk`, which will generate a [binstub](https://bundler.io/man/bundle-binstubs.1.html#DESCRIPTION) at `bin/packwerk`.

Then, you can generate the necessary files to get Packwerk running by executing:

    bin/packwerk init

Here is a list of files generated:

| File                        | Location     | Description |
|-----------------------------|--------------|------------|
| Packwerk configuration      | packwerk.yml | See [Setting up the configuration file](#Setting-up-the-configuration-file) |
| Root package                | package.yml  | A package for the root folder |

After that, you may begin creating packages for your application. See [Defining packages](#Defining-packages)

### Setting up Spring

[Spring](https://github.com/rails/spring) is a preloader for Rails. Because `packwerk` loads `Rails`, it can be sped up dramatically by enabling spring.  Packwerk supports the usage of Spring.
Firstly, spring needs to know about the packwerk spring command when spring is loading. To do that, add `require 'packwerk/spring_command'` to `config/spring.rb` in your application.
Secondly, to enable Spring, first run `bin/spring binstub packwerk` which will "springify" the generated binstub.


## Configuring Packwerk

Packwerk reads from the `packwerk.yml` configuration file in the root directory. Packwerk will run with the default configuration if any of these settings are not specified.

| Key                  | Default value                             | Description  |
|----------------------|-------------------------------------------|--------------|
| include              | **/*.{rb,rake,erb}                        | list of patterns for folder paths to include |
| exclude              | {bin,node_modules,script,tmp,vendor}/**/* | list of patterns for folder paths to exclude |
| package_paths        | **/                                       | a single pattern or a list of patterns to find package configuration files, see: [Defining packages](#Defining-packages) |
| custom_associations  | N/A                                       | list of custom associations, if any |
| parallel             | true                                      | when true, fork code parsing out to subprocesses |
| cache                | false                                     | when true, caches the results of parsing files |
| cache_directory      | tmp/cache/packwerk                        | the directory that will hold the packwerk cache |

### Using a custom ERB parser

You can specify a custom ERB parser if needed. For example, if you're using `<%graphql>` tags from https://github.com/github/graphql-client in your ERBs, you can use a custom parser subclass to comment them out so that Packwerk can parse the rest of the file:

```ruby
class CustomParser < Packwerk::Parsers::Erb
  def parse_buffer(buffer, file_path:)
    preprocessed_source = buffer.source

    # Comment out <%graphql ... %> tags. They won't contain any object
    # references anyways.
    preprocessed_source = preprocessed_source.gsub(/<%graphql/, "<%#")

    preprocessed_buffer = Parser::Source::Buffer.new(file_path)
    preprocessed_buffer.source = preprocessed_source
    super(preprocessed_buffer, file_path: file_path)
  end
end

Packwerk::Parsers::Factory.instance.erb_parser_class = CustomParser
```

## Using the cache
Packwerk ships with an cache to help speed up file parsing. You can turn this on by setting `cache: true` in `packwerk.yml`.

This will write to `tmp/cache/packwerk`.

## Validating the package system

There are some criteria that an application must meet in order to have a valid package system. These criteria include having a valid autoload path cache, package definition files, and application folder structure. The dependency graph within the package system also has to be acyclic.

We recommend setting up the package system validation for your Rails application in a CI step (or through a test suite for Ruby projects) separate from `bin/packwerk check`.

Use the following command to validate the application:

    bin/packwerk validate

![](static/packwerk_validate.gif)

## Defining packages

You can create a `package.yml` in any folder to make it a package. The package name is the path to the folder from the project root.

_Note: It is helpful to define a namespace that corresponds to the package name and contains at least all the public constants of the package. This makes it more obvious which package a constant is defined in._

### Package metadata

Package metadata can be included in the `package.yml`. Metadata won't be validated, and can thus be anything. We recommend including information on ownership and stewardship of the package.

Example:
```yaml
    # components/sales/package.yml
    metadata:
      stewards:
      - "@Shopify/sales"
      slack_channels:
      - "#sales"
```

## Types of boundary checks

Packwerk can perform two types of boundary checks: privacy and dependency.

#### Enforcing privacy boundary

A package's privacy boundary is violated when there is a reference to the package's private constants from a source outside the package.

There are two ways you can enforce privacy for your package:

1. Enforce privacy for all external sources

```yaml
# components/merchandising/package.yml
enforce_privacy: true  # will make everything private that is not in
                        # the components/merchandising/app/public folder
```

Setting `enforce_privacy` to true will make all references to private constants in your package a violation.

2. Enforce privacy for specific constants

```yaml
# components/merchandising/package.yml
enforce_privacy:
  - "::Merchandising::Product"
  - "::SomeNamespace"  # enforces privacy for the namespace and
                       # everything nested in it
```

It will be a privacy violation when a file outside of the `components/merchandising` package tries to reference `Merchandising::Product`.

##### Using public folders
You may enforce privacy either way mentioned above and still expose a public API for your package by placing constants in the public folder, which by default is `app/public`. The constants in the public folder will be made available for use by the rest of the application.

##### Defining your own public folder

You may prefer to override the default public folder, you can do so on a per-package basis by defining a `public_path`.

Example:

```yaml
public_path: my/custom/path/
```

#### Enforcing dependency boundary
A package's dependency boundary is violated whenever it references a constant in some package that has not been declared as a dependency.

Specify `enforce_dependencies: true` to start enforcing the dependencies of a package. The intentional dependencies of the package are specified as a list under a `dependencies:` key.

Example:

```yaml
# components/shop_identity/package.yml
enforce_dependencies: true
dependencies:
  - components/platform
```

It will be a dependency violation when `components/shop_identity` tries to reference a constant that is not within `components/platform` or itself.

## Checking for violations

After enforcing the boundary checks for a package, you may execute:

    bin/packwerk check

Packwerk will check the entire codebase for any new or stale violations.

You can also specify folders for a shorter run time. When checking against folders all subfolders will be analyzed, irrespective of nested package boundaries.

    bin/packwerk check components/your_package

You can also specify packages for a shorter run time. When checking against packages any packages nested underneath the specified packages will not be checked. This can be helpful to test packages like the root package, which can have many nested packages.

    bin/packwerk check --packages=components/your_package,components/your_other_package

![](static/packwerk_check.gif)

In order to keep the package system valid at each version of the application, we recommend running `bin/packwerk check` in your CI pipeline.

See: [TROUBLESHOOT.md - Sample violations](TROUBLESHOOT.md#Sample-violations)

## Resolving new violations
### Understanding how to respond to new violations

When you have a new dependency or privacy violation, what do you do?

See: [RESOLVING_VIOLATIONS.md](RESOLVING_VIOLATIONS.md)

## Recording existing violations

For existing codebases, packages are likely to have existing boundary violations.

If so, you will want to stop the bleeding and prevent more violations from occuring. The existing violations in the codebase can be recorded in a [deprecated references list](#Understanding_the_list_of_deprecated_references) by executing:

    bin/packwerk update-deprecations

Similar to `bin/packwerk check`, you may also run `bin/packwerk update-deprecations` on folders or packages:

    bin/packwerk update-deprecations components/your_package

![](static/packwerk_update.gif)

_Note: Changing dependencies or enabling dependencies will not require a full update of the codebase, only the package that changed. On the other hand, changing or enabling privacy will require a full update of the codebase._

`bin/packwerk update-deprecations` should only be run to record existing violations and to remove deprecated references that have been worked off. Running `bin/packwerk update-deprecations` to resolve a violation should be the very last resort.

See: [TROUBLESHOOT.md - Troubleshooting violations](TROUBLESHOOT.md#Troubleshooting_violations)


### Understanding the list of deprecated references

The deprecated references list is called `deprecated_references.yml` and can be found in the package folder. The list outlines the constant violations of the package, where the violation is located, and the file defining the violation.

The deprecated references list should not be added to, but worked off over time.

```yaml
components/merchant:
  "::Checkouts::Core::CheckoutId":
    violations:
    - dependency
    files:
    - components/merchant/app/public/merchant/generate_order.rb
```

Above is an example of a constant violation entry in `deprecated_references.yml`.

* `components/merchant` - package where the constant violation is found
* `::Checkouts::Core::CheckoutId` - violated constant in question
* `dependency` - type of violation, either dependency or privacy
* `components/merchant/app/public/merchant/generate_order.rb` - path to the file containing the violated constant

Violations exist within the package that makes a violating reference. This means privacy violations of your package can be found listed in `deprecated_references.yml` files in the packages with the reference to a private constant.
