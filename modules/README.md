# Helm template modules
## Introduction
Every template name has three components:

* namespace
* module
* template name

For each namespace, you have a `module.json` file containing
information about the modules within, and the dependencies between them.

## How to write modules
 In general, you should structure your templates here as you would
 structure functions in a programming language - be careful about your public api, 
 use semver, prefer backwards compatibility as much as possible.

### Required values
If your module assumes some value should be present in `values.yaml` for the chart,
you should also add it to the namespace's `values.yaml` file, which should help
people understand the meaning of the various knobs your modules offer.

### Versioning
All modules should be versioned following **strict semantic versioning**, meaning
that a patch release cannot make backwards-incompatible changes or
modify the module dependencies in any ways.
So in short: unless you are adding new functions
only, you should definitely bump a minor version,
unless you're just refactoring stuff.

Whenever you want to create a new version of a module, add a new file with the name `<module>_<semver>.tpl` to the repository, and register it in `module.json` if it's a new major or minor version.

By convention, if a template is NOT meant for consumption by the
end user, but rather a building block that is mostly an implementation detail, 
its template name should start with an underscore:

 base.networkpolicy._somethingprivate

 and CI will (one day!) produce an error if it's used outside of the module itself.

## The module.json file

 This file should appear at the root of every namespace, and describe 
 all modules contained in the namespace and their 
 dependencies.

 Every module will be described by an object with the following keys:
 * **name** (string): the module name
 * **version** (string): the semver string in the format `major.minor`.
 * **depends**: A list of modules, in the format `namespace.module:major.minor` to describe dependencies

 You may notice that it's not allowed to define dependency changes between minor versions: this is because 
 strict semantic versioning is assumed (and this makes the dependency resolution algorhythm much simpler).