# Upgrading from 2.0 to 2.0.1

2.0.0 now loads Rails so you don't have to keep track of `inflections.yml` and `load_paths` within `packwerk.yml`. Since we now load Rails, 2.0.0 was having some memory issues since the file parsing step forks, creating many processes each with a copy of the Rails app.

2.0.1 fixes this by having the main process create a new process that loads Rails, dumps the output, and the main process then parses that. This should bring the memory profile for `packwerk` back to normal levels.

If you're upgrading from 2.0.0, we recommend removing the spring portion of your binstub `bin/packwerk`:
```ruby
begin
  load File.expand_path('../spring', __FILE__)
rescue LoadError => e
  raise unless e.message.include?('spring')
end
```

This should be removed. You can also remove `require 'packwerk/spring_command.rb` from `spring.rb`. As long as your main rails application has spring installed as normal, it should continue to be fast without the memory bloat issue.

We also recommend making sure your application has a `bin/rake` binstub. If it doesn't have it, we fall back to loading Rails within the same process (so we do not break behavior for users), but this does retain the memory issue.

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
