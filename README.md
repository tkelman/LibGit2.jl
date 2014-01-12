# LibGit2.jl

Work in Progress LibGit2 bindings for Julia
Adapted from the Ruby's Rugged libgit bindings

[![Build Status](https://travis-ci.org/jakebolewski/LibGit2.jl.png)](https://travis-ci.org/jakebolewski/LibGit2.jl)

## Testing
To run the tests you must first update the libgit2 submodule:

```
submodule init
submodule update

cd test/
julia runtests.jl all
```
