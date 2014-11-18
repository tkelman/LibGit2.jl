with_repo_access("test isconnected") do test_repo, path
    skip, dlfile = false, tempname()
    try
       download("https://github.com", dlfile)
    catch
        skip = true
    finally
        if isfile(dlfile)
            rm(dlfile)
        end
    end
    if !skip
        remote = GitRemote(test_repo, "git://github.com/libgit2/libgit2.git")
        connect(remote, :fetch) do r
            @test connected(r)
        end
        @test disconnected(remote)
    end
end

with_repo_access("test remote names") do test_repo, path
    ns = remote_names(test_repo)
    @test sort(ns) == sort(["test_remote", "libgit2"])
end

with_repo_access("test remotes") do test_repo, path
    rs = remotes(test_repo)
    @test sort(map(r -> name(r), rs)) == sort(["test_remote", "libgit2"])
end

with_repo_access("test remote new name") do test_repo, path
    remote = GitRemote(test_repo, "git://github.com/libgit2/libgit2.git")
    @test name(remote) == nothing
    @test "git://github.com/libgit2/libgit2.git" == url(remote)
end

with_repo_access("test remote new invalid url") do test_repo, path
    #TODO: throw custom LibGitError ?
    @test_throws ArgumentError GitRemote(test_repo, "libgit2")
end

with_repo_access("test remote url set") do test_repo, path
    new_url = "git://github.com/libgit2/TestGitRepository.git"
    remote = GitRemote(test_repo, "git://github.com/libgit2/libgit2.git")
    set_url!(remote, new_url)
    @test url(remote) == new_url
end

with_repo_access("test set remote invalid url") do test_repo, path
    new_url = "invalid"
    remote = GitRemote(test_repo, "git://github.com/libgit2/libgit2.git")
    @test_throws ArgumentError set_url!(remote, new_url)
end

with_repo_access("test remote push url") do test_repo, path
    @test push_url(lookup_remote(test_repo, "test_remote")) == "git://github.com/libgit2/TestEmptyRepository.git"
    @test push_url(lookup_remote(test_repo, "libgit2")) == nothing
end

with_repo_access("test remote push url set") do test_repo, path
    new_url = "git://github.com/libgit2/TestGitRepository.git"
    remote = GitRemote(test_repo, "git://github.com/libgit2/libgit2.git")

    @test push_url(remote) == nothing
    set_push_url!(remote, new_url)
    @test push_url(remote) == new_url
end

with_repo_access("test remote push url set invalid") do test_repo, path
    new_url = "upstream"
    remote = GitRemote(test_repo, "git://github.com/libgit2/libgit2.git")
    @test_throws ArgumentError set_push_url!(remote, new_url)
end

with_repo_access("test remote fetch refspecs") do test_repo, path
    remote = lookup_remote(test_repo, "test_remote")
    @test ["+refs/heads/*:refs/remotes/test_remote/*"] == fetch_refspecs(remote)
    @test isempty(push_refspecs(lookup_remote(test_repo, "libgit2")))
end

with_repo_access("test remote push refspecs") do test_repo, path
    remote = lookup_remote(test_repo, "test_remote")
    @test ["refs/heads/*:refs/heads/testing/*"] == push_refspecs(remote)
    @test isempty(push_refspecs(lookup_remote(test_repo, "libgit2")))
end

with_repo_access("test remote add fetch") do test_repo, path
    remote = GitRemote(test_repo, "git://github.com/libgit2/libgit2.git")
    add_fetch!(remote, "+refs/heads/*:refs/remotes/test/*")
    @test ["+refs/heads/*:refs/remotes/test/*"] == fetch_refspecs(remote)
end

with_repo_access("test remote add push") do test_repo, path
    remote = GitRemote(test_repo, "git://github.com/libgit2/libgit2.git")
    add_push!(remote, "refs/heads/*:refs/heads/test/*")
    @test ["refs/heads/*:refs/heads/test/*"] == push_refspecs(remote)
end

with_repo_access("test remote clear refspecs") do test_repo, path
    remote = lookup_remote(test_repo, "test_remote")
    clear_refspecs!(remote)

    @test isempty(push_refspecs(remote))
    @test isempty(fetch_refspecs(remote))
end

with_repo_access("test remote lookup") do test_repo, path
    remote = lookup_remote(test_repo, "libgit2")
    @test url(remote)  == "git://github.com/libgit2/libgit2.git"
    @test name(remote) == "libgit2"
end

with_repo_access("test remote lookup missing") do test_repo, path
    @test lookup_remote(test_repo, "missing_remote") == nothing
end

with_repo_access("test remote lookup invalid") do test_repo, path
    @test_throws LibGitError{:Config,:InvalidSpec} lookup_remote(test_repo, "*\?")
end

#TODO: make this work on windows
@unix_only begin
    with_tmp_repo_access("test remote add") do test_repo, path
        remote_add!(test_repo, "upstream", "git://github.com/libgit2/libgit2.git")
        remote = lookup_remote(test_repo, "upstream")
        @test name(remote) == "upstream"
        @test url(remote)  == "git://github.com/libgit2/libgit2.git"
    end
end

with_tmp_repo_access("test remote add with invalid url") do test_repo, path
    @test_throws ArgumentError remote_add!(test_repo, "upstream", "libgit2")
end

with_tmp_repo_access("test remote url set") do test_repo, path
    new_url = "git://github.com/l?#!@#ibgit2/TestGitRepository.git"
    remote = lookup_remote(test_repo, "origin")
    set_url!(remote, new_url)
    save!(remote)
    @test url(lookup_remote(test_repo, "origin")) == new_url
end

with_tmp_repo_access("test remote rename") do test_repo, path
    remote = lookup_remote(test_repo, "origin")
    rename!(remote, "new_remote_name")
    @test lookup_remote(test_repo, "new_remote_name") != nothing
end

with_tmp_repo_access("test rename invalid name") do test_repo, path
    remote = lookup_remote(test_repo, "origin")
    @test_throws LibGitError{:Config,:InvalidSpec} rename!(remote, "/?")
end

with_tmp_repo_access("test remote rename exists") do test_repo, path
    remote = lookup_remote(test_repo, "origin")
    @test_throws LibGitError{:Config,:Exists} rename!(remote, "origin")
end

with_tmp_repo_access("test remote rename error callback") do test_repo, path
    GitConfig(test_repo)["remote.origin.fetch"]  = "+refs/*:refs/*"
    remote = lookup_remote(test_repo, "origin")
    @test ["+refs/*:refs/*"] == rename!(remote, "test_remote")
end

sandboxed_clone_test("testrepo.git", "test remote push single ref") do test_repo, test_clone, path
    create_ref(test_repo, "refs/heads/unit_test", Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    remote = lookup_remote(test_repo, "origin")
    result = push!(test_clone, remote,
                   ["refs/heads/master",
                    "refs/heads/master:refs/heads/foobar",
                    "refs/heads/unit_test"])
    @test isempty(result)
    @test target(lookup_ref(test_clone, "refs/heads/foobar")) == Oid("a65fedf39aefe402d3bb6e24df4d4f5fe4547750")
    @test target(lookup_ref(test_clone, "refs/heads/unit_test")) == Oid("8496071c1b46c854b31185ea97743be6a8774479")
end

sandboxed_clone_test("testrepo.git", "test push non bare raise error") do test_repo, test_clone, path
    GitConfig(test_clone)["core.bare"] = false
    create_ref(test_repo, "refs/heads/unit_test",
               Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    remote = lookup_remote(test_repo, "origin")
    #TODO: better errors
    @test_throws ErrorException push!(test_clone, remote, ["refs/heads/master"])
end

sandboxed_clone_test("testrepo.git", "test remote push non ff raise error") do test_repo, test_clone, path
    create_ref(test_repo, "refs/heads/unit_test",
               Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    remote = lookup_remote(test_repo, "origin")
    #TODO: better errors
    @test_throws ErrorException push!(test_clone, remote,
                                      ["refs/heads/unit_test:refs/heads/master"])
    @test target(lookup_ref(test_clone, "refs/heads/master")) == Oid("a65fedf39aefe402d3bb6e24df4d4f5fe4547750")
end

sandboxed_clone_test("testrepo.git", "test remote push non ff raise no error") do test_repo, test_clone, path
    create_ref(test_repo, "refs/heads/unit_test",
               Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    remote = lookup_remote(test_repo, "origin")
    result = push!(test_clone, remote, ["+refs/heads/unit_test:refs/heads/master"])
    @test isempty(result)
    @test target(lookup_ref(test_clone, "refs/heads/master")) == Oid("8496071c1b46c854b31185ea97743be6a8774479")
end

remote_transport_test("test remote disconnect") do test_repo, test_remote
    connect(test_remote, :fetch)
    @test connected(test_remote)
    disconnect(test_remote)
    @test disconnected(test_remote)
end

remote_transport_test("test remote ls") do test_repo, test_remote
    connect(test_remote, :fetch) do r
        rheads = LibGit2.ls(r)
        @test length(rheads) == 7
        rhead = rheads[1]
        @test rhead.islocal  == false
        @test rhead.id  != nothing
        @test rhead.lid  == nothing
    end
end

remote_transport_test("test remote git fetch") do test_repo, test_remote
    connect(test_remote, :fetch) do r
        download(r) |> update_tips!
    end
    @test Oid(revparse(test_repo, "origin/master")) == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
    @test test_repo["36060c5"] != nothing
end
