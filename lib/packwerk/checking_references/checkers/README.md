# Packwerk::Checkers

- Checker implements `invalid_reference?(reference)`, which takes a `Packwerk::Reference` and returns Boolean.

### Packwerk::Reference

- It contains the information about source package and destination package.


## Example: DependencyChecker

- Dependency means any outgoing dependency from the source package.
- If source package is enforcing dependency, it will check if declared dependency includes the destination package.


## Example: PrivacyChecker

- Privacy means any incoming dependency towards the destination package.
- If destination package is enforcing privacy, it till check if source package references non-public constants.
