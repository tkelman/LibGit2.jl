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

# test_fetch_refspecs
@with_repo_access begin 
    remote = lookup_remote(test_repo, "test_remote")
    @test ["+refs/heads/*:refs/remotes/test_remote/*"] == fetch_refspecs(remote)
    @test isempty(push_refspecs(lookup_remote(test_repo, "libgit2")))
end

# test_push_refspecs
@with_repo_access begin 
    remote = lookup_remote(test_repo, "test_remote")
    @test ["refs/heads/*:refs/heads/testing/*"] == push_refspecs(remote)
    @test isempty(push_refspecs(lookup_remote(test_repo, "libgit2")))
end

# test_add_fetch
@with_repo_access begin 
    remote = GitRemote(test_repo, "git://github.com/libgit2/libgit2.git")
    add_fetch!(remote, "+refs/heads/*:refs/remotes/test/*")
    @test ["+refs/heads/*:refs/remotes/test/*"] == fetch_refspecs(remote)
end

# test_add_push
@with_repo_access begin 
    remote = GitRemote(test_repo, "git://github.com/libgit2/libgit2.git")
    add_push!(remote, "refs/heads/*:refs/heads/test/*")
    @test ["refs/heads/*:refs/heads/test/*"] == push_refspecs(remote)
end

# test_clear_refspecs
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

# test_remote_lookup_missing
@with_repo_access begin 
    @test lookup_remote(test_repo, "missing_remote") == nothing
end

# test_remote_lookup_invalid
@with_repo_access begin 
    @test_throws lookup_remote(test_repo, "*\?")
end

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

# test_push_single_ref
@sandboxed_test "testrepo.git" begin
    remote_repo = test_repo
    config(remote_repo)["core.bare"] = "true"
    repo = clone(sbt, "testrepo.git", "testrepo")
    create_ref(repo, "refs/heads/unit_test", 
               Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    remote = lookup_remote(repo, "origin")

    result = push!(test_repo, remote,
                   ["refs/heads/master", 
                    "refs/heads/master:refs/heads/foobar",
                    "refs/heads/unit_test"])
    @test isempty(result)

    @test (target(lookup_ref(remote_repo, "refs/heads/foobar")) 
            == Oid("a65fedf39aefe402d3bb6e24df4d4f5fe4547750"))

    @test (target(lookup_ref(remote_repo, "refs/heads/unit_test"))
            == Oid("8496071c1b46c854b31185ea97743be6a8774479")) 
end

# test_push_non_bare_raise error
@sandboxed_test "testrepo.git" begin
    remote_repo = test_repo
    config(remote_repo)["core.bare"] = "false"
    repo = clone(sbt, "testrepo.git", "testrepo")
    create_ref(repo, "refs/heads/unit_test", 
               Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    remote = lookup_remote(repo, "origin")
    @test_throws push!(repo, remote, ["refs/heads/master"])
end

#test_push_non_forward_raise_error
@sandboxed_test "testrepo.git" begin
    remote_repo = test_repo
    config(remote_repo)["core.bare"] = "true"
    repo = clone(sbt, "testrepo.git", "testrepo")
    create_ref(repo, "refs/heads/unit_test", 
               Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    remote = lookup_remote(repo, "origin")
    @test_throws push!(repo, remote, ["refs/heads/unit_test:refs/heads/master"])

    @test (target(lookup_ref(remote_repo, "refs/heads/master"))
              == Oid("a65fedf39aefe402d3bb6e24df4d4f5fe4547750"))
end

#test_push_non_forward_forced_raise_no_error
@sandboxed_test "testrepo.git" begin
    remote_repo = test_repo
    config(remote_repo)["core.bare"] = "true"
    repo = clone(sbt, "testrepo.git", "testrepo")
    create_ref(repo, "refs/heads/unit_test", 
               Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    remote = lookup_remote(repo, "origin")

    result = push!(repo, remote, ["+refs/heads/unit_test:refs/heads/master"])
    
    @test isempty(result)
    @test (target(lookup_ref(remote_repo, "refs/heads/master"))
            == Oid("8496071c1b46c854b31185ea97743be6a8774479")) 
end

# test_remote_disconnect
@remote_transport_test begin
    connect(test_remote, :fetch)
    @test isconnected(test_remote) == true

    disconnect(test_remote)
    @test isconnected(test_remote) == false
end

#test_remote_ls
@remote_transport_test begin
    connect(test_remote, :fetch) do r
        rheads = ls(r)
        @test length(rheads) == 7
        rhead = first(rheads)
        @test rhead.islocal == false
        @test rhead.oid != nothing
        @test rhead.loid == nothing
    end
end

# test git remote fetch
@remote_transport_test begin
    connect(test_remote, :fetch) do r
        download(r) |> update_tips!
    end
    @test rev_parse(test_repo, "origin/master") |> oid == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
    @test lookup(test_repo, "36060c5") != nothing
end
