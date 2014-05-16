using Base.Test
using LibGit2

function has_ssh()
    keys = ["URL", "USER", "KEY", "PUBKEY", "PASSPHRASE"]
    for key in keys
        if !(haskey(ENV, "GITTEST_REMOTE_SSH_$key"))
            return false
        end
    end
    return true
end

function has_git()
    return haskey(ENV, "GITTEST_REMOTE_GIT_URL")
end

function ssh_key_credential()
    return CredSSHKey(ENV["GITTEST_REMOTE_SSH_USER"],
                      ENV["GITTEST_REMOTE_SSH_PUBKEY"],
                      ENV["GITTEST_REMOTE_SSH_KEY"],
                      ENV["GITTEST_REMOTE_SSH_PASSPHRASE"])
end

if !has_git()
    warn("Skipping remote clone => test clone over git")
else
    dir = mktempdir()
    try 
        repo = repo_clone(ENV["GITTEST_REMOTE_GIT_URL"], dir)
        @test isa(repo, Repository)
    finally 
        run(`rm -r -f $dir`)
    end
end

if !has_ssh()
    warn("Skipping remote clone => test clone over ssh with credentials")
else
    dir = mktempdir()
    try
        repo = repo_clone(ENV["GITTEST_REMOTE_SSH_URL"], dir,
                          {:credentials => ssh_key_credential()})
        @test isa(repo, Repository)
    finally
        run(`rm -r -f $dir`)
    end
end

if !has_ssh()
    warn("Skipping remote clone => test clone over ssh with credentials callback")
else
    dir = mktempdir()
    try
        repo = repo_clone(ENV["GITTEST_REMOTE_SSH_URL"], dir,
                          {:credentials => (url, username, allowed_types) -> ssh_key_credential()})
        @test isa(repo, Repository)
    finally
        run(`rm -r -f $dir`)
    end
end

# test_clone_callback_args_without_username
begin
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

# test_clone_callback_args_with_username
begin
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
