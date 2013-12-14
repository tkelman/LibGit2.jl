# create a repo with a README file
cleanup_dir(p) = begin
    if isdir(p)
        run(`rm -f -R $p`)
    end
end

test_path = joinpath(pwd(), "testrepo")
try
    repo = create_test_repo(test_path)
    cid, tid = seed_test_repo(repo)

    c1 = repo_lookup(GitCommit, repo, cid)
    c2 = repo_lookup_commit(repo, cid)
    @test c1 == c2
    @test git_otype(c1) == api.OBJ_COMMIT
    @test git_otype(c2) == api.OBJ_COMMIT
    
    # test repo has one commit
    ctree = GitTree(c1)
    @test count(ctree) == 1

    t = repo_lookup(GitTree, repo, tid)
    @test oid(t) == tid
    @test isa(t, GitTree)
    entry = entry_byname(t, "README")
    @test entry != nothing
    
    @test filemode(entry) == api.FILEMODE_BLOB
    obj = repo_lookup(repo, oid(t))
    @test isa(obj, GitTree)

    obj = repo_revparse_single(repo, "HEAD")
    @test isa(obj, GitCommit)
    @test oid(obj) == cid
    
    obj = repo_revparse_single(repo, "HEAD^{tree}")
    @test isa(obj, GitTree)
    @test oid(obj) == oid(t)
catch err
    cleanup_dir(test_path)
    rethrow(err)
end 
cleanup_dir(test_path)
