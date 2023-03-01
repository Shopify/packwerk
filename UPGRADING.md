# Upgrading from 2.x to 3.0

In Packwerk 3.0, we've made two notable changes:

## Renaming deprecated_references to package_todo

The `update-deprecations` subcommand has been renamed to `update-todo`. Old `deprecated_references.yml` files will be automatically deleted and replaced with `package_todo.yml` files when you run `update-todo`. This behaviour has been in Packwerk [since 2.3.0](https://github.com/Shopify/packwerk/releases/tag/v2.3.0), and automatic deletion will be removed in the next release.

### Removal of privacy checking

Privacy checking via `enforce_privacy` has been removed. Developers are encouraged to focus on leveraging Packwerk for dependency checking. For those who still need privacy checks, please use [Gusto's extension gem](https://github.com/rubyatscale/packwerk-extensions).

# Upgrading from 1.x to 2.0

With Packwerk 2.0, we made a few changes to simplify the setup. Updating will require removing some previously necessary files and configuration.

## Gem group

Because packwerk is no longer involved in specifying the application's inflections, it doesn't have to live in the `production` group in your `Gemfile` anymore. We recommend moving it to the `development` group.

## Removing application config caches

### Load paths
We no longer require the `load_paths` key in `packwerk.yml`. You can simply delete the load_paths key as it will not be read anymore. Instead, Packwerk will ask Rails for load paths. If you're using spring, make sure to properly set up spring (see [USAGE.md](USAGE.md#setting-up-spring)) to keep packwerk fast.

### Inflections
We no longer require a custom `inflections.yml` file. Instead, you'll want to revert BACK to using the `inflections.rb` initializer as you would have done prior to adopting packwerk. To do this, you'll want to convert back to using the plain [ActiveSupport Inflections API](https://api.rubyonrails.org/classes/ActiveSupport/Inflector/Inflections.html).


Given the following example `inflections.yml`, here is an example `inflections.rb` that would follow. Tip: if you're using git, you can run `git log config/inflections.yml`, find the first commit that introduced `inflections.yml`, find the COMMIT_SHA, and then run `git show COMMIT_SHA` to see what your inflections file looked like before (note that you may have changed `inflections.yml` since then, though).

`config/inflections.yml`
```yml
# List your inflections in this file instead of `inflections.rb`
# See steps to set up custom inflections:
# https://github.com/Shopify/packwerk/blob/main/USAGE.md#Inflections

acronym:
 - 'HTML'
 - 'API'

singular:
 - ['oxen', 'oxen']

irregular:
 - ['person', 'people']

uncountable:
 - 'fish'
 - 'sheep'
```

`config/initializers/inflections.rb`
```ruby
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym('HTML')
  inflect.acronym('API')

  inflect.singular('oxen', 'oxen')

  inflect.irregular('person', 'people')

  inflect.uncountable('fish')
  inflect.uncountable('sheep')
 end
```
