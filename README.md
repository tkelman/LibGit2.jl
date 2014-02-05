# LibGit2.jl

Work in Progress LibGit2 bindings for Julia

Adapted from the Ruby's Rugged libgit bindings

[![Build Status](https://travis-ci.org/jakebolewski/LibGit2.jl.png)](https://travis-ci.org/jakebolewski/LibGit2.jl)

## Testing
LibGit2.jl is tested against the latest development branch of
libgit2.  To build libgit2 from source you need CMake.  See the
specific build instruction on libgit2's [README](https://github.com/libgit2/libgit2#building-libgit2---using-cmake).

To run the tests you must first update the libgit2 submodule:

```
submodule init
submodule update

cd test/
julia runtests.jl all
```
