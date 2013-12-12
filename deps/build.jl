using BinDeps

ENV["JULIA_ROOT"] = abspath(JULIA_HOME, "../../")

cd(joinpath(Pkg.dir(), "LibGit2", "deps", "src") )
run(`make`)
if (!ispath("../usr"))
  run(`mkdir ../usr`)
end
if (!ispath("../usr/lib"))
  run(`mkdir ../usr/lib`)
end
run(`mv libwrapgit.$(BinDeps.shlib_ext) ../usr/lib`)

