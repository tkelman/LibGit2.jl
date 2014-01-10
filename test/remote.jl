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

