using Base.Test
using LibGit2

include("util.jl")

testnames = ["oid", "repository", "signature", "index", "object",
             "reference", "odb"]

tests = ARGS==["all"] ? testnames : ARGS

function runtests(name)
    println(" \033[1m*\033[0m \033[31m$(name)\033[0m")
    Core.include("$name.jl")
end

function propagate_errors(a, b)
    if isa(a,Exception)
        rethrow(a)
    end
    if isa(b,Exception)
        rethrow(b)
    end
    nothing
end

reduce(propagate_errors, nothing, map(runtests, tests))

println(" \033[32;1mSUCCESS\033[0m")
