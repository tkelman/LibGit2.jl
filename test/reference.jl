# ------------------------------------
# Tests adapted from Git2Go Library
# ------------------------------------
context("test create / lookup ref") do
    test_path = joinpath(pwd(), "testrepo")
    repo = create_test_repo(test_path)
    try
        cid, tid = seed_test_repo(repo)

        _ = create_ref(repo, "refs/tags/tree", tid, force=true)
        tag = lookup_ref(repo, "refs/tags/tree")
        @test isa(tag, GitReference{Oid})

        ref = lookup_ref(repo, "HEAD")
        @test isa(ref, GitReference{Sym})

        @test target(ref) == nothing
        ref = resolve(ref)
        @test isa(ref, GitReference{Oid})
        @test isa(target(ref), Oid)
        @test symbolic_target(ref) == ""
        @test hex(cid) == hex(target(ref))

        _ = rename(tag, "refs/tags/renamed", force=false)
        tag = lookup_ref(repo, "refs/tags/renamed")
        @test isa(tag, GitReference{Oid})
    finally
        close(repo)
        LibGit2.free!(repo)
        Base.gc()
        rm(test_path, recursive=true)
    end
end

#=
context() do
    test_path = joinpath(pwd(), "testrepo")
    repo = create_test_repo(test_path)
    try
        cid, tid = seed_test_repo(repo)

        sig = Signature("test", "test@test.com")
        idx = GitIndex(repo)
        add!(idx, "README")
        tid = write_tree!(idx)

        message = "This is a commit\n"
        tree = lookup_tree(repo, tid)

        cid = commit(repo, "HEAD", sig, sig, message, tree)

        _ = create_ref(repo, "refs/heads/one",   cid, force=true)
        _ = create_ref(repo, "refs/heads/two",   cid, force=true)
        _ = create_ref(repo, "refs/heads/three", cid, force=true)

        expected = [join(["refs/heads", x], "/")
                    for x in ["master","one","two","three"]]
        test_names = AbstractString[]
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
        test_names = AbstractString[]
        for r in iter_refs(repo, "refs/heads/t*")
            push!(test_names, name(r))
        end
        sort!(expected)
        sort!(test_names)
        for (exp, tst) in zip(expected, test_names)
            @test exp == tst
        end
    finally
        close(repo)
        LibGit2.free!(repo)
        Base.gc()
        rm(test_path, recursive=true)
    end
end
=#

# -----------------------------------------
# Tests adapted from Ruby's Rugged Library
# -----------------------------------------
with_repo_access() do test_repo, path
    context("test reference validity") do
        valid = "refs/foobar"
        invalid = "refs/nope^*"
        @test is_valid_ref(valid) == true
        @test is_valid_ref(invalid) == false
    end

    # test can handle exceptions

    context("test list references") do
        tmp = map((r) -> replace(name(r), "refs/", ""), foreach(GitReference, test_repo))
        @test join(sort(tmp), ":") == "heads/master:heads/packed:notes/commits:tags/v0.9:tags/v1.0"
    end

    context("test can filter refs with regex") do
        tmp = map((r) -> replace(name(r), "refs/", ""), foreach(GitReference, test_repo, "refs/tags/*"))
        refs = join(sort(tmp), ":")
        @test refs == "tags/v0.9:tags/v1.0"
    end

    context("test can filter refs with string") do
        tmp = map((r) -> replace(name(r), "refs/", ""), foreach(GitReference, test_repo, "*0.9*"))
        refs = join(sort(tmp), ":")
        @test refs == "tags/v0.9"
    end
end

with_repo_access() do test_repo, path

  context("test can open reference") do
    ref = lookup_ref(test_repo, "refs/heads/master")
    @test target(ref) == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
    @test isa(ref, GitReference{Oid})
    @test name(ref) ==  "refs/heads/master"
    @test peel(ref) == nothing
  end

  context("test can open a symbolic reference") do
    ref = lookup_ref(test_repo, "HEAD")
    @test symbolic_target(ref) == "refs/heads/master"
    @test isa(ref, GitReference{Sym})

    resolved = resolve(ref)
    @test isa(resolved, GitReference{Oid})
    @test target(resolved) == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
    @test target(resolved) == peel(ref)
  end

  context("test looking up missing ref returns nil") do
    ref = lookup_ref(test_repo, "lol/wut")
    @test ref == nothing
  end

  context("test load reflog") do
      ref = lookup_ref(test_repo, "refs/heads/master")
      #@test has_reflog(ref) == true
      rlog = GitReflog(ref)
      entry = rlog[2]
      @test isa(entry, GitReflogEntry)
      @test entry.id_old == Oid("8496071c1b46c854b31185ea97743be6a8774479")
      @test entry.id_new == Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644")
      @test entry.message == "commit: another commit"
      @test isa(entry.committer, Signature)
      @test email(entry.committer) == "schacon@gmail.com"
  end

  context("test reference exists") do
    @test exists(test_repo, "refs/heads/master") == true
    @test exists(test_repo, "lol/wut") == false
  end

  context("test load packed ref") do
    ref = lookup_ref(test_repo, "refs/heads/packed")
    @test target(ref) == Oid("41bc8c69075bbdb46c5c6f0566cc8cc5b46e8bd9")
    @test isa(ref, GitReference{Oid})
    @test name(ref) == "refs/heads/packed"
  end

  context("test resolve head") do
    ref = lookup_ref(test_repo, "HEAD")
    #TODO: make target work for both direct and symboloic
    @test symbolic_target(ref) == "refs/heads/master"
    @test isa(ref, GitReference{Sym})

    head = resolve(ref)
    @test target(head) == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
    @test isa(head, GitReference{Oid})
  end

  context("test reference to tag") do
    ref = lookup_ref(test_repo, "refs/tags/v1.0")
    @test target(ref) == Oid("0c37a5391bbff43c37f0d0371823a5509eed5b1d")
    @test peel(ref) == Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644")
  end
end

with_tmp_repo_access("test create ref") do test_repo, path
    create_ref(test_repo,
               "refs/heads/unit_test",
               "refs/heads/master")

    create_ref(test_repo,
               "refs/heads/unit_test",
               "refs/heads/master",
               force=true)
end

with_tmp_repo_access("test create ref with unicode") do test_repo, path
    UNICODE_REF_NAME = "A\314\212ngstro\314\210m"
    create_ref(test_repo,
               "refs/heads/$UNICODE_REF_NAME",
               "refs/heads/master")
    refs = map(r -> normalize_string(replace(name(r), "refs/", ""), :NFC), foreach(GitReference, test_repo))
    @test normalize_string("heads/$UNICODE_REF_NAME", :NFC) in refs
end

with_tmp_repo_access("test lookup non-existant ref") do test_repo, path
    ref = lookup_ref(test_repo, "lol/wut")
    @test ref == nothing
end

with_tmp_repo_access("test name ref") do test_repo, path
    @test realpath(workdir(test_repo)) == realpath(path)

    o = Oid("36060c58702ed4c2a40832c51758d5344201d89a")
    ref = create_ref(test_repo, "refs/heads/unit_test", o)

    @test o == target(ref)
    @test isa(ref, GitReference{Oid})
    @test name(ref) == "refs/heads/unit_test"
    #delete!(test_repo, ref)
end

with_tmp_repo_access("test rename ref") do test_repo, path
    ref = create_ref(test_repo,
      "refs/heads/unit_test",
      Oid("36060c58702ed4c2a40832c51758d5344201d89a"))

    @test target(ref) == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
    @test isa(ref, GitReference{Oid})
    @test name(ref) == "refs/heads/unit_test"

    new_ref = rename(ref, "refs/heads/rug_new_name")
    @test name(new_ref) == "refs/heads/rug_new_name"
    #delete!(test_repo, new_ref)
end

with_tmp_repo_access("test set target ref") do test_repo, path
    ref = create_ref(test_repo,
                     "refs/heads/unit_test",
                     Oid("36060c58702ed4c2a40832c51758d5344201d89a"))

    @test target(ref) == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
    @test isa(ref, GitReference{Oid})
    @test name(ref) == "refs/heads/unit_test"
    new_ref = set_target(ref, Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))
    t = target(new_ref)
    @test t == Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644")
    #delete!(test_repo, new_ref)
end

with_tmp_repo_access("test create symbolic target") do test_repo, path
    ref1 = create_ref(test_repo, "refs/heads/Ångström", "refs/heads/master")
    ref2 = create_ref(test_repo, "refs/heads/foobar", "refs/heads/Ångström")
    @test name(ref1) == "refs/heads/Ångström"
    @test symbolic_target(ref2) ==  "refs/heads/Ångström"
end

with_tmp_repo_access("test reflog") do test_repo, path
    ref = create_ref(test_repo,
                     "refs/heads/test-reflog",
                     Oid("36060c58702ed4c2a40832c51758d5344201d89a"))
    log!(ref, "", Signature("foo", "foo@bar"))
    log!(ref, "commit: bla bla", Signature("foo", "foo@bar"))
    rlog = GitReflog(ref)
    # TODO: this fails for travis (cannot reproduce in local tests)
    # travis states that length(rlog) == 3 with fist reflog entry
    # containing no information (unknown user/email)
    @test length(rlog) == 3

    #@test rlog[2].id_old == Oid("0000000000000000000000000000000000000000")
    @test rlog[2].id_old == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
    @test rlog[2].id_new == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
    @test rlog[2].message == ""
    @test name(rlog[2].committer) == "foo"

    @test rlog[end].id_old == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
    @test rlog[end].id_new == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
    @test rlog[end].message == "commit: bla bla"
    @test name(rlog[end].committer) == "foo"
    @test email(rlog[end].committer) == "foo@bar"
end

with_tmp_repo_access("test ref log with config") do test_repo, path
    ref = create_ref(test_repo,
                     "refs/heads/test-reflog",
                     Oid("36060c58702ed4c2a40832c51758d5344201d89a"))
    testname = "Julia User"
    testemail = "user@julia.com"

    cfg = GitConfig(test_repo)
    cfg["user.name"] = testname
    cfg["user.email"] = testemail

    log!(ref)
    log!(ref, "commit: bla bla")

    rlog = GitReflog(ref)
    # TODO: this fails for travis (cannot reproduce in local tests)
    # travis states that length(rlog) == 3 with fist reflog entry
    # containing no information (unknown user/email)
    @test length(rlog) == 3

    #@test rlog[end-1].id_old == Oid("0000000000000000000000000000000000000000")
    @test rlog[2].id_old == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
    @test rlog[2].id_new == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
    @test rlog[2].message == ""
    @test name(rlog[2].committer) == "Julia User"
    @test email(rlog[2].committer) == "user@julia.com"

    @test rlog[end].id_old == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
    @test rlog[end].id_new == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
    @test rlog[end].message == "commit: bla bla"
    @test name(rlog[end].committer) == "Julia User"
    @test email(rlog[end].committer) == "user@julia.com"
end
