# create a repo with a README file
cleanup_dir(p) = begin
    if isdir(p)
        run(`rm -f -R $p`)
    end
end

# ------------------------------------
# Tests adapted from Git2Go Library
# ------------------------------------
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
    rethrow(err)
finally 
    cleanup_dir(test_path)
end

# -----------------------------------------
# Tests adapted from Ruby's Rugged Library
# -----------------------------------------
@with_repo_access begin
   @test repo_path(test_repo) == test_repo_path
   
   begin # lookup any object type 
       blob = lookup(test_repo, Oid("fa49b077972391ad58037050f2a75f74e3671e92"))
       @test isa(blob, GitBlob)

       commit = lookup(test_repo, Oid("8496071c1b46c854b31185ea97743be6a8774479"))
       @test isa(commit, GitCommit)
        
       #TODO
       #tag = lookup(test_repo, Oid("0c37a5391bbff43c37f0d0371823a5509eed5b1d"))
       #@test isa(tag, GitTag)

       tree = lookup(test_repo, Oid("c4dc1555e4d4fa0e0c9c3fc46734c7c35b3ce90b"))
       @test isa(tree, GitTree)
   end

   begin # test_fail_to_lookup_inexistant_object 
       @test_throws lookup(test_repo, Oid("a496071c1b46c854b31185ea97743be6a8774479"))
   end

   begin # test_lookup_object
        obj = lookup(test_repo, Oid("8496071c1b46c854b31185ea97743be6a8774479"))
        @test isa(obj, GitCommit)
        @test Oid("8496071c1b46c854b31185ea97743be6a8774479") == oid(obj)
   end

   begin # test_objects_are_the_same
        obj1 = lookup(test_repo, Oid("8496071c1b46c854b31185ea97743be6a8774479"))
        obj2 = lookup(test_repo, Oid("8496071c1b46c854b31185ea97743be6a8774479"))
        @test obj1 == obj2
   end
  
   #TODO:
   begin # test_read_raw_data
        #obj = lookup(test_repo, Oid("8496071c1b46c854b31185ea97743be6a8774479"))
        #@assert raw(obj)
   end
   
   #TODO:
   begin # test_lookup_by_rev
        #obj = @repo.rev_parse("v1.0")
        #assert "0c37a5391bbff43c37f0d0371823a5509eed5b1d", obj.oid
        #obj = @repo.rev_parse("v1.0^1")
        #assert "8496071c1b46c854b31185ea97743be6a8774479", obj.oid
   end 
   
   #TODO:
   begin # test_lookup_oid_by_rev
       #oid = @repo.rev_parse_oid("v1.0")
       #assert "0c37a5391bbff43c37f0d0371823a5509eed5b1d", oid
       #@repo.rev_parse_oid("v1.0^1")
       #assert "8496071c1b46c854b31185ea97743be6a8774479", oid
   end
end
