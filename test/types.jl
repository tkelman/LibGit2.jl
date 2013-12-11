using Base.Test
using LibGit2

config = LibGit2.GitConfig()
err = ccall((:git_config_new, :libgit2), 
            Cint, (Ptr{GitConfig},),
            &config)
@test err == 0

path = "/home/jake/Test/test"
repo = LibGit2.GitRepository()
err  = ccall((:git_repository_open, :libgit2),
             Cint,
             (Ptr{GitRepository}, Ptr{Cchar}),
             &repo, bytestring(path))
@test err == 0

#@test isbare(repo) == true
@test isempty(repo) == true
