with_repo_access() do test_repo, path
    # blob
    @test_throws LibGitError{:Invalid,:NotFound} lookup_tag(test_repo, Oid("fa49b077972391ad58037050f2a75f74e3671e92"))
    # commit
    @test_throws LibGitError{:Invalid,:NotFound} lookup_tag(test_repo, Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    # tree
    @test_throws LibGitError{:Invalid,:NotFound} lookup_tag(test_repo, Oid("c4dc1555e4d4fa0e0c9c3fc46734c7c35b3ce90b"))

    context("test reading a tag") do
        id = Oid("0c37a5391bbff43c37f0d0371823a5509eed5b1d")
        obj = lookup(test_repo, id)
        @test id == Oid(obj)
        @test isa(obj, GitTag)
        @test message(obj) == "test tag message\n"
        @test name(obj) == "v1.0"
        @test target_id(obj) == Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644")
        @test target_id(obj) == Oid(target(obj))
        @test isa(target(obj), GitCommit)
        c = tagger(obj)
        @test name(c) == "Scott Chacon"
        @test time(c) == 1288114383
        @test email(c) == "schacon@gmail.com"
    end

    context("test reading the oid of a tag") do
        id = Oid("0c37a5391bbff43c37f0d0371823a5509eed5b1d")
        obj = lookup(test_repo, id)
        @test Oid(target(obj)) == Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644")
    end
end

with_tmp_repo_access("test writing a tag") do test_repo, path
   sig = Signature("Julia", "julia@julia.com")
   tid = tag!(test_repo,
              name="tag",
              message="test tag message\n",
              target=Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"),
              tagger=sig)
   t = lookup(test_repo, tid)
   @test isa(t, GitTag)
   @test target_id(t) == Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644")
   @test target_id(t) == Oid(target(t))
   @test message(t) == "test tag message\n"
   @test name(tagger(t)) == "Julia"
   @test email(tagger(t)) == "julia@julia.com"
end

with_tmp_repo_access("test writing a tag without a signature") do test_repo, path
    testname = "Julia"
    testemail = "julia@julia.com"
    GitConfig(test_repo)["user.name"] = testname
    GitConfig(test_repo)["user.email"] = testemail
    id = tag!(test_repo,
              name="tag",
              message="test tag message\n",
              target=Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))
    @test isa(id, Oid)
    t = lookup(test_repo, id)
    @test name(tagger(t)) == testname
    @test email(tagger(t)) == testemail
end

with_tmp_repo_access("test invalid message type") do test_repo, path
    sig = Signature("Julia", "julia@julia.com")
    @test_throws TypeError tag!(
                              test_repo,
                              name="tag",
                              message=:error,
                              target=Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"),
                              tagger=sig)
end

with_tmp_repo_access("test writing light tags") do test_repo, path
    tag!(test_repo, name="tag", target=Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))
    t = lookup_ref(test_repo, "refs/tags/tag")
    @test target(t) == Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644")
end
