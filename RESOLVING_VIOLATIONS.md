# Resolving Violations

Violations can be [recorded as a deprecation](#recording-violations) or (better!) [eliminated](#eliminating-violations).

## Recording Violations
💡 New dependency violations are never hard-blocked. There are many very valid reasons to run `bin/packwerk update-todo`, adding new violations to `package_todo.yml` files. Even if you feel your reason might not be "valid," if your judgement says adding the violation and shipping your change will produce positive impact, trust your gut.

### Emergency Fixes
❔ Is it a revert or is there a lot of urgency because you are fixing a production bug impacting customers?

➡️ Simply run `bin/packwerk update-todo`, and address the violation when the customer issue is resolved.

### Improving System Design
❔ Are you improving system boundaries by renaming or moving a file, class, constant,` or module?

➡️ Simply run `bin/packwerk update-todo`. We've improved how our system is organized, so the new violations are natural.

### Making Things Explicit
❔ Are you making something that was implicit (hidden to Packwerk) explicit, such as adding a Sorbet signature, using a class instead of a method call, or something similar?

➡️ Simply run `bin/packwerk update-todo`. Making something implicit explicit and capturing that as a new violation is a strict improvement.

### Temporary State
❔ Is the violation temporary because you will soon delete the code or is it part of a refactor to improve system boundaries and reduce violations overall?

➡️ Simply run `bin/packwerk update-todo`. Sometimes things get "worse" before they get better.

### Delivering Features
❔ Are you in a rush to get a feature out and product, your manager, or an internal sense of urgency has made you feel like you can't resolve system design issues?

➡️ Stay strong. Eliminate the violation. It is important to build a sustainable business that optimizes for the long-term. Look for advocates such as from mentors or within your team who can help you justify improving system design.

## Eliminating Violations
💡 Dependency violations are Packwerk's signal that what we've stated about the desired system design (what
packages exist and what lives in them, the dependencies in a package.yml, and the public interface in the package's public folder) doesn't match the reality of our system.
If what we've stated about our system design doesn't feel right, then the violations won't make sense either! Make sure to think through system design before addressing a violation.

### Moving Things Around
❔ Does the code you're writing (or changing) live in the right package? Does the code you're referencing live in the right package?

If not, find a better place for it to live.

Otherwise, follow the guide for eliminating [Dependency Violations](#dependency-violations).

#### Use Existing Public Interface
❔ Does the package you're using expose public API in its public folder that supports your use case?

➡️ Use that public API instead!

#### Change The Public Interface
❔ Can we work with the package's owner to create and use a public API? Or should the thing we're using already be public?

➡️  Work together on a new public API and use that instead! If the thing we're using should be public, move it to the public folder to make it public!

⛈️ If working with the package's owner to improve the API is not possible, run `bin/packwerk update-todo`. Add some context to your PR about why it's not possible.

### Dependency Violations
💡  Packwerk thinks something is a dependency violation if you're referencing a constant, class, module defined ANYWHERE but your package doesn't list it as an explicit dependency in its `package.yml`. We care about these because it allows us to be systematically intentional about what our code needs to run and helps us untangle and remove dependency cycles from our system.

Thoughtful dependency management is another cornerstone of well-modularized code.

#### Adding Explicit Dependencies
❔ Do we actually want to depend on the other package? Work with your team to help answer this question!

➡️  Add the other package to your package's `package.yml` `dependencies` key.

⁉️ Did you get a cyclic dependency when CI ran `bin/packwerk validate`?

➡️  Work with your team to think through what link in the cycle we don't want. Remove that link and rerun `bin/packwerk validate`.

#### Changing The System Design
❔ Can we spend some time to think through changes to the system design that don't require the dependency?

➡️  Work with the owners of the relevant packages, as well as your team, to think through a design that doesn't include the unwanted dependency.

⛈️ If this is not possible within the scope of your changes (think hard about this one!), run `bin/packwerk update-todo`. Add some context to your PR about why it's not possible, and any additional context you may have, such as a possible solution.
