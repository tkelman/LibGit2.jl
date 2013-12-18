# create a repo with a README file
cleanup_dir(p) = begin
    if isdir(p)
        run(`rm -f -R $p`)
    end
end

# ------------------------------------
# Tests adapted from Git2Go Library
# ------------------------------------

# TEST REF MODIFICATION
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


# TEST REF ITERATION
test_path = joinpath(pwd(), "testrepo")
try
    repo = create_test_repo(test_path)
    cid, tid = seed_test_repo(repo)

    sig = Signature("test", "test@test.com")
    idx = repo_index(repo)
    add_bypath!(idx, "README")
    tid = write_tree!(idx)

    message = "This is a commit\n"
    tree = lookup_tree(repo, tid)
  
    cid = commit(repo, "HEAD", sig, sig, message, tree)

    _ = create_ref(repo, "refs/heads/one",   cid, true)
    _ = create_ref(repo, "refs/heads/two",   cid, true)
    _ = create_ref(repo, "refs/heads/three", cid, true)

    expected = [join(["refs/heads", x], "/") 
                for x in ["master","one","two","three"]]
    test_names = String[]
    for r in iter_refs(repo)
        push!(test_names, name(r))
    end
    sort!(expected)
    sort!(test_names)
    for (exp, tst) in zip(expected, test_names)
        @test exp == tst
    end

    # test glob
    expected = ["refs/heads/two", "refs/heads/three"]
    test_names = String[]
    for r in iter_refs(repo, glob="refs/heads/t*")
        push!(test_names, name(r))
    end
    sort!(expected)
    sort!(test_names)
    for (exp, tst) in zip(expected, test_names)
        @test exp == tst
    end
catch err
    rethrow(err)
finally 
    cleanup_dir(test_path)
end

# -----------------------------------------
# Tests adapted from Ruby's Rugged Library
# -----------------------------------------
@with_repo_access begin
    begin # test_reference validity
        valid = "refs/foobar"
        invalid = "refs/nope^*"
        @test isvalid_ref(valid) == true
        @test isvalid_ref(invalid) == false 
    end
end

@with_repo_access begin
  begin # test_can_open_reference
    ref = lookup_ref(test_repo, "refs/heads/master")
    @test target(ref) == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
    @test isa(ref, GitReference{Oid})
    @test name(ref) ==  "refs/heads/master"
  end

  begin # test_can_open_a_symbolic_reference
    ref = lookup_ref(test_repo, "HEAD")
    @test symbolic_target(ref) == "refs/heads/master"
    @test isa(ref, GitReference{Sym})

    resolved = resolve(ref)
    @test isa(resolved, GitReference{Oid})
    @test target(resolved) == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
  end

  begin # test_looking_up_missing_ref_returns_nil
    ref = lookup_ref(test_repo, "lol/wut")
    @test ref == nothing
  end
end

@with_tmp_repo_access begin
   @test repo_workdir(test_repo) == test_repo_path
   
   # ---------------------------
   # test create ref from oid
   # ---------------------------
   o = Oid("36060c58702ed4c2a40832c51758d5344201d89a")
   ref = create_ref(test_repo, "refs/heads/unit_test", o)
   
   @test o == target(ref)
   @test isa(ref, GitReference{Oid})
   @test name(ref) == "refs/heads/unit_test"
   #delete!(ref)
end

@with_tmp_repo_access begin
    begin # test_write_and_read_unicode_refs
    ref1 = create_ref(test_repo, "refs/heads/Ångström", "refs/heads/master")
    ref2 = create_ref(test_repo, "refs/heads/foobar", "refs/heads/Ångström")
    @test name(ref1) == "refs/heads/Ångström"
    @test symbolic_target(ref2) ==  "refs/heads/Ångström"
  end
end

 

