# ------------------------------------
# Tests adapted from Git2Go Library
# ------------------------------------
context("test lookup git objects") do
    test_path = joinpath(pwd(), "testrepo")
    repo = create_test_repo(test_path)
    try
        cid, tid = seed_test_repo(repo)

        c1 = lookup(GitCommit, repo, cid)
        c2 = lookup_commit(repo, cid)
        @test c1 == c2
        @test git_otype(c1) == 1 # api.OBJ_COMMIT
        @test git_otype(c2) == 1 # api.OBJ_COMMIT

        # test repo has one commit
        ctree = GitTree(c1)
        @test length(ctree) == 1

        t = lookup(GitTree, repo, tid)
        @test Oid(t) == tid
        @test isa(t, GitTree)
        entry = entry_byname(t, "README")
        @test entry != nothing

        @test filemode(entry) == 33188 #api.FILEMODE_BLOB
        obj = lookup(repo, Oid(t))
        @test isa(obj, GitTree)

        obj = revparse(repo, "HEAD")
        @test isa(obj, GitCommit)
        @test Oid(obj) == cid

        obj = revparse(repo, "HEAD^{tree}")
        @test isa(obj, GitTree)
        @test Oid(obj) == Oid(t)
    finally
        close(repo)
        LibGit2.free!(repo)
        Base.gc()
        rm(test_path, recursive=true)
    end
end

# -----------------------------------------
# Tests adapted from Ruby's Rugged Library
# -----------------------------------------
with_repo_access() do test_repo, path

   #@test LibGit2.path(test_repo) == path

   context("test lookup any object type") do
       blob = test_repo[Oid("fa49b077972391ad58037050f2a75f74e3671e92")]
       @test isa(blob, GitBlob)

       commit = test_repo[Oid("8496071c1b46c854b31185ea97743be6a8774479")]
       @test isa(commit, GitCommit)

       tag = test_repo[Oid("0c37a5391bbff43c37f0d0371823a5509eed5b1d")]
       @test isa(tag, GitTag)

       tree = test_repo[Oid("c4dc1555e4d4fa0e0c9c3fc46734c7c35b3ce90b")]
       @test isa(tree, GitTree)
   end

   context("test fail to lookup non existant objects") do
       @test_throws LibGitError{:Odb,:NotFound} test_repo[Oid("a496071c1b46c854b31185ea97743be6a8774479")]
   end

   context("test lookup object") do
        obj = test_repo[Oid("8496071c1b46c854b31185ea97743be6a8774479")]
        @test isa(obj, GitCommit)
        @test Oid("8496071c1b46c854b31185ea97743be6a8774479") == Oid(obj)
   end

   context("test objects are the same") do
        obj1 = test_repo[Oid("8496071c1b46c854b31185ea97743be6a8774479")]
        obj2 = test_repo[Oid("8496071c1b46c854b31185ea97743be6a8774479")]
        @test obj1 == obj2
   end

   context("test read raw data") do
        obj = test_repo[Oid("8496071c1b46c854b31185ea97743be6a8774479")]
        @test isa(raw(obj), OdbObject)
   end

   context("test lookup by rev") do
        obj = revparse(test_repo, "v1.0")
        @test Oid(obj) == Oid("0c37a5391bbff43c37f0d0371823a5509eed5b1d")
        obj = revparse(test_repo, "v1.0^1")
        @test Oid(obj) == Oid("8496071c1b46c854b31185ea97743be6a8774479")
   end

   context("test lookup id by rev") do
       o = revparse_oid(test_repo, "v1.0")
       @test o == Oid("0c37a5391bbff43c37f0d0371823a5509eed5b1d")
       o = revparse_oid(test_repo, "v1.0^1")
       @test o == Oid("8496071c1b46c854b31185ea97743be6a8774479")
   end
end
