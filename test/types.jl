using Base.Test
using LibGit2

config = GitConfig()
err = ccall((:git_config_new, :libgit2), 
            Cint, (Ptr{GitConfig},),
            &config)
@test err == 0
