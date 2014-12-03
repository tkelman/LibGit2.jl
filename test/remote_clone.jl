using Base.Test
using LibGit2

context(f::Function, s::AbstractString) = (println(s); f())

has_ssh() = begin
    keys = ["URL", "USER", "KEY", "PUBKEY", "PASSPHRASE"]
    for key in keys
        if !(haskey(ENV, "GITTEST_REMOTE_SSH_$key"))
            return false
        end
    end
    return true
end

has_git() = haskey(ENV, "GITTEST_REMOTE_GIT_URL")

ssh_key_credential() = CredSSHKey(ENV["GITTEST_REMOTE_SSH_USER"],
                                  ENV["GITTEST_REMOTE_SSH_PUBKEY"],
                                  ENV["GITTEST_REMOTE_SSH_KEY"],
                                  ENV["GITTEST_REMOTE_SSH_PASSPHRASE"])

if !has_git()
    warn("Skipping remote clone => test clone over git")
else
    dir = mktempdir()
    try
        repo = repo_clone(ENV["GITTEST_REMOTE_GIT_URL"], dir)
        @test isa(repo, GitRepo)
    finally
        rm(dir, recursive=true)
    end
end

if !has_ssh()
    warn("Skipping remote clone => test clone over ssh with credentials")
else
    dir = mktempdir()
    try
        repo = repo_clone(ENV["GITTEST_REMOTE_SSH_URL"], dir,
                          {:credentials => ssh_key_credential()})
        @test isa(repo, GitRepo)
    finally
        rm(dir, recursive=true)
    end
end

if !has_ssh()
    warn("Skipping remote clone => test clone over ssh with credentials callback")
else
    dir = mktempdir()
    try
        repo = repo_clone(ENV["GITTEST_REMOTE_SSH_URL"], dir,
                          {:credentials => (url, username, allowed_types) -> ssh_key_credential()})
        @test isa(repo, GitRepo)
    finally
        rm(dir, recursive=true)
    end
end

context("test clone callback args without username") do
    dir = mktempdir()
    gurl, gusername, gallowed_types = nothing, nothing, nothing
    #TODO: better error
    @test_throws ErrorException repo_clone("github.com:libgit2/TestGitRepository", dir, {
          :credentials => (args...) -> begin
            gurl, gusername, gallowed_types = args
            return nothing
          end
    })
    @test gurl == "github.com:libgit2/TestGitRepository"
    @test gusername == nothing
    for t in [:plaintext, :sshkey]
        @test in(t, gallowed_types)
    end
end

context("test clone callback args with username") do
    dir = mktempdir()
    gurl, gusername, gallowed_types = nothing, nothing, nothing
    #TODO: better error
    @test_throws ErrorException repo_clone("git@github.com:libgit2/TestGitRepository", dir, {
          :credentials => (args...) -> begin
            gurl, gusername, gallowed_types = args
            return nothing
          end
    })
    @test gurl == "git@github.com:libgit2/TestGitRepository"
    @test gusername == "git"
    for t in [:plaintext, :sshkey]
        @test in(t, gallowed_types)
    end
end

println(" \033[32;1mSUCCESS\033[0m")
