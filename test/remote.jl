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

