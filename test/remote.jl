@with_repo_access begin
    remote = GitRemote(test_repo, "git://github.com/libgit2/libgit2.git")
    connect(remote, :fetch) do r
        @test isconnected(r) == true
    end
    @test isconnected(remote) == false
end


