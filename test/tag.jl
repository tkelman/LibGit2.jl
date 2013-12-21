@with_repo_access begin
    # blob
    @test_throws lookup_tag(test_repo, Oid("fa49b077972391ad58037050f2a75f74e3671e92"))
    # commit
    @test_throws lookup_tag(test_repo, Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    # tag
    @test_throws lookup_tag(test_repo, Oid("c4dc1555e4d4fa0e0c9c3fc46734c7c35b3ce90b"))

    begin # test reading a tag
        id = Oid("0c37a5391bbff43c37f0d0371823a5509eed5b1d")
        obj = lookup(test_repo, id)
        @test id == oid(obj)
        @test isa(obj, GitTag)
        @test message(obj) == "test tag message\n"
        @test name(obj) == "v1.0"
        @test target_id(obj) == Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644")
        @test target_id(obj) == oid(target(obj))
        @test isa(target(obj), GitCommit)
        c = tagger(obj)
        @test name(c) == "Scott Chacon"
        @test time(c) == 1288114383
        @test email(c) == "schacon@gmail.com"
    end

    begin # test reading the oid of a tag
        id = Oid("0c37a5391bbff43c37f0d0371823a5509eed5b1d")
        obj = lookup(test_repo, id)
        @test (target(obj) |> oid) == Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644")
    end
end
