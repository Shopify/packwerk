# Resolving violations
## Understanding how to respond to new violations

When you have a new dependency or privacy violation, what do you do?

Firstly, remember that there are many valid reasons to run `bin/packwerk update-deprecations` and add new violations to `deprecated_references.yml` files. Even if you feel your reason might not be "valid," if your judgement says adding the violation and shipping the change will produce positive impact, trust your gut!

This is a little "flow-chart" to help us understand how to respond to violations:
1. Is it a revert or is there a lot of urgency because you are fixing a production bug impacting customers?
    - Simply run `bin/packwerk update-deprecations`, and address the violation when the customer issue is resolved.
2. Are you improving system boundaries by renaming or moving a file, class, constant, or module?
    - Simply run `bin/packwerk update-deprecations` . We've improved how our system is organized, so the new violations are natural.
3. Are you making something that was implicit (hidden to Packwerk) explicit, such as adding a Sorbet signature, using a class instead of a method call, or something similar?
    - Simply run `bin/packwerk update-deprecations` . Making something implicit explicit and capturing that as a new violation is a strict improvement.
4. Is the violation temporary because you will soon delete the code or is it part of a refactor to improve system boundaries and reduce violations?
    - Simply run `bin/packwerk update-deprecations` . Sometimes things get "worse" before they get better.
5. Are you in a rush to get a feature out and product, your manager, or an internal sense of urgency has made you feel like you can't resolve system design issues?
    - Stay strong – it is important to build a sustainable business that optimizes for the long-term. Look for advocates such as from mentors or within your team who can help you justify improving system design.

Next, remember that dependency and privacy violations are Packwerk's signal that what we've stated about the desired system design (what packages exist and what lives in them, the dependencies in a package.yml, and the public interface in the package's public folder) doesn't match the reality of our system.

If what we've stated about our system design doesn't feel right, then the violations won't make sense either! Make sure to think through system design before addressing a violation. So therefore we ask the questions:

6. Does the code you're writing live in the wrong package?
    - Move the code to where it belongs.
7. Does the code you're referencing live in the right package?
    - Move the code to where it belongs.

Packwerk thinks something is a privacy violation if you’re referencing a constant, class, or module defined in the private implementation (i.e. not the public folder) of another package. We care about these because we want to make sure we only use parts of a package that have been exposed as public API.

An explicit and implementation-hiding public API is a cornerstone of well-modularized code.

8. Is it a privacy violation?
    - Does the package you're using expose public API in its public folder that supports your use case? 
        - Yes! Use that public API instead!
        - No. Can we work with the package's owner to create and use a public API? Or should the thing we're using already be public?
            - Yes! Work together on a new public API and use that instead! If the thing we're using should be public, move it to the public folder to make it public!
            - No. `bin/packwerk update-deprecations`, and add some context as a comment in your PR about why it's not possible

Packwerk thinks something is a dependency violation if you’re referencing a constant, class, module defined ANYWHERE but your package doesn’t list it as an explicit dependency in its package.yml. We care about these because it allows us to be systematically intentional about what our code needs to run and helps us untangle and remove dependency cycles from our system. 

Thoughtful dependency management is another cornerstone of well-modularized code.

9. Is it a dependency violation?
    - Do we actually want to depend on the other package? Work with your team to help answer this question!
        - Yes! Add the other package to your package's package.yml dependencies key.
            - Did you get a cyclic dependency when CI ran `bin/packwerk validate`? Work with your team to think through what link in the cycle we don't want. Remove that link and rerun `bin/packwerk update-deprecations`. 
        - No. Can we spend some time to think through changes to system design that don't require that dependency?
            - Yes! Work with your team to think through a design that doesn't depend on the other package.
            - No. `bin/packwerk update-deprecations`, and add some context as a comment in your PR about why it's not possible
