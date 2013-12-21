@with_repo_access begin
    # blob
    @test_throws lookup_tag(test_repo, Oid("fa49b077972391ad58037050f2a75f74e3671e92"))
    # commit
    @test_throws lookup_tag(test_repo, Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    # tag
    @test_throws lookup_tag(test_repo, Oid("c4dc1555e4d4fa0e0c9c3fc46734c7c35b3ce90b"))
end

