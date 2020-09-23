# Contributing

## Issue reporting
* Check to make sure the same issue has not already been reported or fixed
* Open an issue with a descriptive title and summary
* Be clear and concise and provide as many details as possible (e.g. Ruby version, Packwerk version, etc.)
* Include relevant code, where necessary

## Pull requests
* Read and understand our [Code of Conduct](https://github.com/Shopify/packwerk/blob/main/CODE_OF_CONDUCT.md)
* Make sure tests are added for any changes to the code
* [Squash related commits together](http://gitready.com/advanced/2009/02/10/squashing-commits-with-rebase.html)
* If the change includes any new keys to `packwerk.yml`, make sure that the [application validator](https://github.com/Shopify/packwerk/blob/1c711748b4a28b65220e2cefba764ffd8eb1a101/lib/packwerk/application_validator.rb#L116) is aligned with that change
* Open a pull request once the change is ready to be reviewed
* Be descriptive about the problem and reason about the proposed solution
* Include release notes describing the potential impact of the change in the pull request
* Make sure there has been at least one approval from Shopify before merging
