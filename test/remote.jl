@with_repo_access begin
    remote = GitRemote(test_repo, "git://github.com/libgit2/libgit2.git")
    connect(remote, :fetch) do r
        @test isconnected(r) == true
    end
    @test isconnected(remote) == false
end

@with_repo_access begin
    ns = remote_names(test_repo)
    @test sort(ns) == sort(["test_remote", "libgit2"])
end

@with_repo_access begin
    rs = remotes(test_repo)
    @test sort(map(r -> name(r), rs)) == sort(["test_remote", "libgit2"])
end

#test_remote_new_name
@with_repo_access begin
    remote = GitRemote(test_repo, "git://github.com/libgit2/libgit2.git")
    @test name(remote) == nothing
    @test "git://github.com/libgit2/libgit2.git" == url(remote)
end

# test_remote_new_invalid_url
@with_repo_access begin
    @test_throws GitRemote(test_repo, "libgit2")
end

# test_url_set
@with_repo_access begin
    new_url = "git://github.com/libgit2/TestGitRepository.git"
    remote = GitRemote(test_repo, "git://github.com/libgit2/libgit2.git")
    set_url!(remote, new_url)
    @test url(remote) == new_url
end

# test_set invalid url_
@with_repo_access begin
    new_url = "invalid"
    remote = GitRemote(test_repo, "git://github.com/libgit2/libgit2.git")
    @test_throws set_url!(remote, new_url)
end

# test_push_url
@with_repo_access begin 
    @test push_url(lookup_remote(test_repo, "test_remote")) == "git://github.com/libgit2/TestEmptyRepository.git"
    @test push_url(lookup_remote(test_repo, "libgit2")) == nothing
end

# test_push_url_set
@with_repo_access begin 
    new_url = "git://github.com/libgit2/TestGitRepository.git"
    remote = GitRemote(test_repo, "git://github.com/libgit2/libgit2.git")

    @test push_url(remote) == nothing
    set_push_url!(remote, new_url)
    @test push_url(remote) == new_url
end

# test_push_url_set_invalid
@with_repo_access begin 
    new_url = "upstream"
    remote = GitRemote(test_repo, "git://github.com/libgit2/libgit2.git")
    @test_throws set_push_url!(remote, new_url)
end

#@show :test_fetch_refspecs
@with_repo_access begin 
    remote = lookup_remote(test_repo, "test_remote")
    @test ["+refs/heads/*:refs/remotes/test_remote/*"] == fetch_refspecs(remote)
    @test isempty(push_refspecs(lookup_remote(test_repo, "libgit2")))
end

#@show :test_push_refspecs
@with_repo_access begin 
    remote = lookup_remote(test_repo, "test_remote")
    @test ["refs/heads/*:refs/heads/testing/*"] == push_refspecs(remote)
    @test isempty(push_refspecs(lookup_remote(test_repo, "libgit2")))
end

#@show :test_add_fetch
@with_repo_access begin 
    remote = GitRemote(test_repo, "git://github.com/libgit2/libgit2.git")
    add_fetch!(remote, "+refs/heads/*:refs/remotes/test/*")
    @test ["+refs/heads/*:refs/remotes/test/*"] == fetch_refspecs(remote)
end

#@show :test_add_push
@with_repo_access begin 
    remote = GitRemote(test_repo, "git://github.com/libgit2/libgit2.git")
    add_push!(remote, "refs/heads/*:refs/heads/test/*")
    @test ["refs/heads/*:refs/heads/test/*"] == push_refspecs(remote)
end

#@show :test_clear_refspecs
@with_repo_access begin 
    remote = lookup_remote(test_repo, "test_remote")
    clear_refspecs!(remote)

    @test isempty(push_refspecs(remote))
    @test isempty(fetch_refspecs(remote))
end

# test_remote_lookup
@with_repo_access begin 
    remote = lookup_remote(test_repo, "libgit2")
    @test url(remote) == "git://github.com/libgit2/libgit2.git"
    @test name(remote) == "libgit2"
end

#test_remote_lookup_missing
@with_repo_access begin 
    @test lookup_remote(test_repo, "missing_remote") == nothing
end

#test_remote_lookup_invalid
@with_repo_access begin 
    @test_throws lookup_remote(test_repo, "*\?")
end

#TODO: remote write

# test_remote_add
@with_tmp_repo_access begin
   remote_add!(test_repo, "upstream", "git://github.com/libgit2/libgit2.git")
    remote = lookup_remote(test_repo, "upstream")
    @test name(remote) == "upstream"
    @test url(remote)  == "git://github.com/libgit2/libgit2.git"
end

# test_remote_add_with_invalid_url
@with_tmp_repo_access begin
    @test_throws remote_add!(test_repo, "upstream", "libgit2")
end

# test_url_set
@with_tmp_repo_access begin
    new_url = "git://github.com/l?#!@#ibgit2/TestGitRepository.git"
    remote = lookup_remote(test_repo, "origin")
    set_url!(remote, new_url)
    save!(remote)
    @test url(lookup_remote(test_repo, "origin")) == new_url
end


# test_rename
@with_tmp_repo_access begin
    remote = lookup_remote(test_repo, "origin")
    rename!(remote, "new_remote_name")
    @test lookup_remote(test_repo, "new_remote_name") != nothing
end

#test_rename_invalid_name
@with_tmp_repo_access begin
    remote = lookup_remote(test_repo, "origin")
    @test_throws rename!(remote, "/?")
end

#test_rename_exists
@with_tmp_repo_access begin
    remote = lookup_remote(test_repo, "origin")
    @test_throws rename!(remote, "origin")
end

# test_rename_error_callback
@with_tmp_repo_access begin
    config(test_repo)["remote.origin.fetch"]  = "+refs/*:refs/*"
    remote = lookup_remote(test_repo, "origin")
    @test ["+refs/*:refs/*"] == rename!(remote, "test_remote")
end
