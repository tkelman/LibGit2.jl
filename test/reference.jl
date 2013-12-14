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
    
    _ = create_ref(repo, "refs/tags/tree", tid, true)
    tag = lookup_ref(repo, "refs/tags/tree")
    @test git_reftype(tag) == api.REF_OID 
    @test isa(tag, GitReference{Oid})
    
    ref = lookup_ref(repo, "HEAD")
    @test git_reftype(ref) == api.REF_SYMBOLIC
    @test isa(ref, GitReference{Sym})

    @test target(ref) == nothing
    ref = resolve(ref)
    @test isa(ref, GitReference{Oid})
    @test isa(target(ref), Oid)
    @test symbolic_target(ref) == ""
    @test hex(cid) == hex(target(ref))

    _ = rename(tag, "refs/tags/renamed", false)
    tag = lookup_ref(repo, "refs/tags/renamed")
    @test isa(tag, GitReference{Oid})

catch err
    rethrow(err)
finally 
    cleanup_dir(test_path)
end

