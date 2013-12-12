const libwrapgit = find_library(["libwrapgit",],[Pkg.dir("LibGit2", "deps", "usr", "lib"),])
@assert(libwrapgit != "", "Failed to find required library libwrapgit. Try re-running the package script using Pkg.build(\"LibGit2\")")
