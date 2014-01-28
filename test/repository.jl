# create bare repo
test_repo_path = joinpath(pwd(), "TestLibGit2")

function cleanup_repo(path)
    p = abspath(path)
    if isdir(p)
        run(`rm -f -R $p`)
    end
end

function tmp_repo(body, tmp_path)
   cleanup_repo(tmp_path)
   try
        body()
   catch err
       cleanup_repo(tmp_path)
       rethrow(err)
   end
   cleanup_repo(tmp_path)
end

# ------------------------------------
# Tests adapted from Git2Go Library
# ------------------------------------

# test creating bare repository
tmp_repo(test_repo_path) do
    repo_init(test_repo_path; bare=true)
    let repo = Repository(test_repo_path)
        @test isa(repo, Repository)
        @test repo_isbare(repo)
        @test repo_isempty(repo)
    end
end

# test creating repository
tmp_repo(test_repo_path) do
    repo_init(test_repo_path)
    let repo = Repository(test_repo_path)
        @test isa(repo, Repository)
        @test !(repo_isbare(repo))
        @test repo_isempty(repo)
        @test repo_workdir(repo) == abspath(test_repo_path)
        @test repo_path(repo) == joinpath(test_repo_path, ".git")
        @test isa(repo_index(repo), GitIndex)
        # empty repo has no head
        @test head(repo) == nothing
        # empty repo has no tags
        @test tags(repo) == nothing
        # empty repo has no commits
        @test commits(repo) == nothing
        # empty repo has no references
        @test references(repo) == nothing
        
        @test isa(config(repo), GitConfig)
        @test isa(repo_treebuilder(repo), TreeBuilder)
    end
end

# -----------------------------------------
# Tests adapted from Ruby's Rugged Library
# -----------------------------------------
# test fails to open repos that don't exist
@sandboxed_test "testrepo.git" begin
    @test_throws Repository("fakepath/123")
    @test_throws Repository("test")
end
   
# can check if objects exist 
@sandboxed_test "testrepo.git" begin
    @test Oid("8496071c1b46c854b31185ea97743be6a8774479") in test_repo
    @test exists(test_repo, Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    @test Oid("1385f264afb75a56a5bec74243be9b367ba4ca08") in test_repo
    @test exists(test_repo, Oid("1385f264afb75a56a5bec74243be9b367ba4ca08"))
    @test !(Oid("ce08fe4884650f067bd5703b6a59a8b3b3c99a09") in test_repo)
    @test !(exists(test_repo, Oid("ce08fe4884650f067bd5703b6a59a8b3b3c99a09")))
    @test !(Oid("8496071c1c46c854b31185ea97743be6a8774479") in test_repo)
    @test !(exists(test_repo, Oid("8496071c1c46c854b31185ea97743be6a8774479")))
end

# can read a raw object
@sandboxed_test "testrepo.git" begin
    rawobj = read(test_repo, Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    @test match(r"tree 181037049a54a1eb5fab404658a3a250b44335d7", data(rawobj)) != nothing
    @test sizeof(rawobj) == 172
    @test isa(rawobj, OdbObject{GitCommit})
end

# can read object headers
@sandboxed_test "testrepo.git" begin
    h = read_header(test_repo, Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    @test h[:type] == GitCommit
    @test h[:nbytes] == 172
end

# test check reads fail on missing objects
@sandboxed_test "testrepo.git" begin
    @test_throws read(Oid("a496071c1b46c854b31185ea97743be6a8774471"))
end

# test check read headers fail on missing objects
@sandboxed_test "testrepo.git" begin
    @test_throws read_header(Oid("a496071c1b46c854b31185ea97743be6a8774471"))
end

# test walking with block
@sandboxed_test "testrepo.git" begin
    oid = Oid("a4a7dce85cf63874e984719f4fdd239f5145052f")
    list = {}
    walk(test_repo, oid) do c
       push!(list, c)
    end
    @test join(map(c -> hex(c)[1:5], list), ".") == "a4a7d.c4780.9fd73.4a202.5b5b0.84960"
end

# test walking without block
@sandboxed_test "testrepo.git" begin
    oid = Oid("a4a7dce85cf63874e984719f4fdd239f5145052f")
    commits = walk(test_repo, oid)
    @test isa(commits, Task)
    @test istaskdone(commits) == false
end

# test lookup object
@sandboxed_test "testrepo.git" begin
    obj = lookup(test_repo, Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    @test isa(obj, GitCommit)
end

# test find reference
@sandboxed_test "testrepo.git" begin
    ref = lookup_ref(test_repo, "refs/heads/master")
    @test isa(ref, GitReference)
    @test name(ref) == "refs/heads/master"
end

# match all refs
@sandboxed_test "testrepo.git" begin
    refs = collect(iter_refs(test_repo, "refs/heads/*"))
    @test length(refs) == 12
end

# return all ref names
@sandboxed_test "testrepo.git" begin
    rnames = ref_names(test_repo)
    @test length(rnames) == 21
end

# return all tags
@sandboxed_test "testrepo.git" begin
    ts = tags(test_repo)
    @test length(ts) == 7
end

# return all matching tags
@sandboxed_test "testrepo.git" begin
    @test length(tags(test_repo, "e90810b")) == 1
    @test length(tags(test_repo, "*tag*")) == 4
end

# return a list of all remotes
@sandboxed_test "testrepo.git" begin
    rs = remotes(test_repo)
    @test length(rs) == 5
end

# test_lookup_head
@sandboxed_test "testrepo.git" begin
    h = head(test_repo)
    @test isa(h, GitReference)
    @test name(h) == "refs/heads/master"
    @test target(h) == Oid("a65fedf39aefe402d3bb6e24df4d4f5fe4547750")
    #@test isa
end

# test_set_head_ref
@sandboxed_test "testrepo.git" begin
    set_head!(test_repo, "refs/heads/packed")
    @test name(head(test_repo)) == "refs/heads/packed"
end

# test_set_head_invalid
@sandboxed_test "testrepo.git" begin
    @test_throws set_head!(test_repo, "a65fedf39aefe402d3bb6e24df4d4f5fe4547750")
end

# test_access_a_file
@sandboxed_test "testrepo.git" begin
    id = Oid("a65fedf39aefe402d3bb6e24df4d4f5fe4547750")
    blob = blob_at(test_repo, id, "new.txt")
    @test "my new file\n" == raw_content(blob)
end

# test_access_a_missing_file
@sandboxed_test "testrepo.git" begin
    id = Oid("a65fedf39aefe402d3bb6e24df4d4f5fe4547750")
    blob = blob_at(test_repo, id, "file-not-found.txt")
    @test blob == nothing
end

# test_enumerate_all_objects
@sandboxed_test "testrepo.git" begin
    @test count(x -> true, test_repo) == 1687
end

# test_loading_alternates
@sandboxed_test "testrepo.git" begin
    alt_path = joinpath(pwd(), "fixtures/alternate/objects")
    repo = Repository(repo_path(test_repo); alternates=[alt_path])
    try 
      @test count(x->true, repo) == 1690
      @test read(repo, Oid("146ae76773c91e3b1d00cf7a338ec55ae58297e2")) != nothing
    catch
        rethrow(err)
    finally 
      close(repo)
    end
end

# test_alternates_with_invalid_path_type
@sandboxed_test "testrepo.git" begin
    @test_throws Repository(repo_path(test_repo), alternates=["error"])
end

# test_find_merge_base_between_oids
@sandboxed_test "testrepo.git" begin
    commit1 = Oid("a4a7dce85cf63874e984719f4fdd239f5145052f")
    commit2 = Oid("a65fedf39aefe402d3bb6e24df4d4f5fe4547750")
    base    = Oid("c47800c7266a2be04c571c04d5a6614691ea99bd")
    @test base == merge_base(test_repo, commit1, commit2)
end

# test_find_merge_base_between_commits
@sandboxed_test "testrepo.git" begin
    commit1 = lookup(test_repo, Oid("a4a7dce85cf63874e984719f4fdd239f5145052f"))
    commit2 = lookup(test_repo, Oid("a65fedf39aefe402d3bb6e24df4d4f5fe4547750"))
    base    = Oid("c47800c7266a2be04c571c04d5a6614691ea99bd")
    @test base == merge_base(test_repo, commit1, commit2)
end

# test_find_merge_base_between_ref_and_oid
@sandboxed_test "testrepo.git" begin
    commit1 = Oid("a4a7dce85cf63874e984719f4fdd239f5145052f")
    commit2 = "refs/heads/master"
    base    = Oid("c47800c7266a2be04c571c04d5a6614691ea99bd")
    @test base == merge_base(test_repo, commit1, commit2)
end

# test_find_merge_base_between_many
@sandboxed_test "testrepo.git" begin
    commit1 = Oid("a4a7dce85cf63874e984719f4fdd239f5145052f")
    commit2 = "refs/heads/packed"
    commit3 = lookup(test_repo, Oid("a65fedf39aefe402d3bb6e24df4d4f5fe4547750"))

    base    = Oid("c47800c7266a2be04c571c04d5a6614691ea99bd")
    @test base == merge_base(test_repo, commit1, commit2, commit3)
end

# test_ahead_behind_with_oids
@sandboxed_test "testrepo.git" begin
    ahead, behind = ahead_behind(test_repo,
      Oid("a4a7dce85cf63874e984719f4fdd239f5145052f"),
      Oid("a65fedf39aefe402d3bb6e24df4d4f5fe4547750")
    )
    @test ahead == 2 
    @test behind == 1
end

# test_ahead_behind_with_commits
@sandboxed_test "testrepo.git" begin
    ahead, behind = ahead_behind(test_repo, 
      lookup(test_repo, Oid("a4a7dce85cf63874e984719f4fdd239f5145052f")),
      lookup(test_repo, Oid("a65fedf39aefe402d3bb6e24df4d4f5fe4547750"))
    )
    @test ahead == 2 
    @test behind == 1
end

#---------------------------
# Merge Commits Repo Test
#---------------------------
@sandboxed_test "merge-resolve" begin
    our_commit = lookup_branch(test_repo, "master") |> tip
    their_commit = lookup_branch(test_repo, "branch") |> tip

    index = merge_commits(test_repo, our_commit, their_commit)
    @test length(index) == 8

    @test (Oid("233c0919c998ed110a4b6ff36f353aec8b713487") == 
            oid(getentry(index, "added-in-master.txt", 0)))
    @test (Oid("f2e1550a0c9e53d5811175864a29536642ae3821") ==
            oid(getentry(index, "automergeable.txt", 0)))
    @test (Oid("4eb04c9e79e88f6640d01ff5b25ca2a60764f216") ==
            oid(getentry(index, "changed-in-branch.txt", 0)))
    @test (Oid("11deab00b2d3a6f5a3073988ac050c2d7b6655e2") ==
            oid(getentry(index, "changed-in-master.txt", 0)))

    @test (Oid("d427e0b2e138501a3d15cc376077a3631e15bd46") == 
            oid(getentry(index, "conflicting.txt", 1)))
    @test (Oid("4e886e602529caa9ab11d71f86634bd1b6e0de10") ==
            oid(getentry(index, "conflicting.txt", 2)))
    @test (Oid("2bd0a343aeef7a2cf0d158478966a6e587ff3863") == 
            oid(getentry(index, "conflicting.txt", 3)))

    @test (Oid("c8f06f2e3bb2964174677e91f0abead0e43c9e5d") ==
            oid(getentry(index, "unchanged.txt", 0)))
    @test has_conflicts(index) 
end

#---------------------------
# Shallow Repo Test
#---------------------------
@sandboxed_test "testrepo.git" begin
    shallow_sbt = setup(SandBoxedTest, "shallow.git")
    shallow = shallow_sbt.repo
    @test is_shallow(test_repo) == false
    @test is_shallow(shallow) == true
    teardown(shallow_sbt)
end

#---------------------------
# Repo Write Test
#---------------------------
@with_tmp_repo_access begin
  TEST_CONTENT = "my test data\n"

  begin # test_can_hash_data
    id = hash_data(GitBlob, TEST_CONTENT)
    @test id == Oid("76b1b55ab653581d6f2c7230d34098e837197674")
  end

  begin # test_write_to_odb
    id = write!(GitBlob, test_repo, TEST_CONTENT)
    @test id == Oid("76b1b55ab653581d6f2c7230d34098e837197674")
    @test Oid("76b1b55ab653581d6f2c7230d34098e837197674") in test_repo
  end

  begin # test_no_merge_base_between_unrelated_branches
    info = rev_parse(test_repo, "HEAD")
    @test isa(info, GitCommit)
    sig = Signature("test", "test@test.com")
    #baseless = commit(test_repo, "null", sig, sig, "", 
    #@test merge_base(test_repo, "HEAD", baseless) == nothing
  end

  begin # test_default_signature
    testname = "Test User"
    testemail = "test@example.com"
    config(test_repo)["user.name"] = testname
    config(test_repo)["user.email"] = testemail
    @assert isa(default_signature(test_repo), Signature)
    @test testname == (default_signature(test_repo) |> name)
    @test testemail == (default_signature(test_repo) |> email)
  end
end

#---------------------------
# Repo Discover Test
#---------------------------
teardown_dir(p::String) = run(`rm -r -f $p`)

macro discover_test(body)
    quote
        tmpdir = mktempdir()
        mkdir(joinpath(tmpdir, "foo"))
        try
            $body
        catch err
            rethrow(err)
        finally
            teardown_dir(tmpdir)
        end
    end
end

# test discover false
@discover_test begin
    @test_throws repo_discover(tmpdir)
end

# test discover nested false
@discover_test begin
    @test_throws repo_disover(joinpath(tmpdir, "foo"))
end

# test discover true
@discover_test begin
    repo = repo_init(tmpdir; bare=true)
    root = repo_discover(tmpdir)
    try 
        @test is_bare(root) == true
        @test path(root) == path(repo)
    finally
        close(root)
        close(repo)
    end
end

# test discover nested true
@discover_test begin
    repo = repo_init(tmpdir; bare=true)
    root = repo_discover(joinpath(tmpdir, "foo"))
    try 
        @test is_bare(root) == true
        @test path(root) == path(repo)
    finally
        close(root)
        close(repo)
    end
end


#---------------------------
# Repo Init Test
#---------------------------
macro repo_init_test(body)
    quote
        tmpdir = mktempdir()
        try
            $body
        catch err
            rethrow(err)
        finally
            teardown_dir(tmpdir)
        end
    end
end
# test init bare false
@repo_init_test begin
    repo = repo_init(tmpdir; bare=false)
    try
        @test is_bare(repo) == false
    finally
        close(repo)
    end
end

# test init bare true
@repo_init_test begin
    repo = repo_init(tmpdir; bare=true)
    try 
        @test is_bare(repo) == true
    finally
        close
    end
end

# test init non bare default
@repo_init_test begin 
    repo = repo_init(tmpdir)
    try
        @test is_bare(repo) == false
    finally
        close(repo)
    end
end

#---------------------------
# Repo Clone Test
#---------------------------
# test clone repo
@repo_clone_test begin
    repo = repo_clone(source_path, tmppath)
    try
#      @test open(readline, joinpath(tmppath, "README")) |> chomp == "hey"
      @test (target(head(repo)) 
                == Oid("36060c58702ed4c2a40832c51758d5344201d89a"))
      @test (target(lookup_ref(repo, "refs/heads/master")) 
                == Oid("36060c58702ed4c2a40832c51758d5344201d89a"))
      @test (target(lookup_ref(repo, "refs/remotes/origin/master"))
                == Oid("36060c58702ed4c2a40832c51758d5344201d89a"))
      @test (target(lookup_ref(repo, "refs/remotes/origin/packed")) 
                == Oid("41bc8c69075bbdb46c5c6f0566cc8cc5b46e8bd9"))
    finally
      close(repo)
    end
end

## test clone bare
@repo_clone_test begin
    repo = repo_clone(source_path, tmppath, {:bare => true})
    try
        @test is_bare(repo)
    catch
        close(repo)
    end
end

## test_clone_with_progress
@repo_clone_test begin
    total_objects = indexed_objects = received_objects = received_bytes = 0
    callsback = 0
    repo = repo_clone(source_path, tmppath, {
      :callbacks => {
        :transfer_progress => (args...) -> begin
          total_objects, indexed_objects, received_objects, received_bytes = args
          callsback += 1
          end
        }
      }
    )
    close(repo)
    @test 22 == callsback
    @test 19 == total_objects
    @test 19 == indexed_objects
    @test 19 == received_objects
    @test 1563 == received_bytes
end

## test_clone_quits_on_error
@repo_clone_test begin
    try
      repo_clone(source_path, tmppath, {:callbacks => {
        :transfer_progress => (args...) -> error("boom")
      }})
    catch err
      @test err.msg == "boom"
    end
    @test isdir(joinpath(tmppath, ".git")) == false
end

# test_clone_with_bad_progress_callback
@repo_clone_test begin
    @test_throws repo_clone(source_path, tmppath, {:callbacks => {
        :transfer_progress => ()
      }})
    @test isdir(joinpath(tmppath, ".git")) == false
end

#---------------------------
# Repo Namespace Test
#---------------------------
@sandboxed_test "testrepo.git" begin 
    @test namespace(test_repo) == nothing
end

@sandboxed_test "testrepo.git" begin 
    set_namespace!(test_repo, "foo")
    @test namespace(test_repo) == "foo"

    set_namespace!(test_repo, "bar")
    @test namespace(test_repo) == "bar"

    set_namespace!(test_repo, "foo/bar")
    @test namespace(test_repo) == "foo/bar"

    set_namespace!(test_repo, nothing)
    @test namespace(test_repo) == nothing
end

@sandboxed_test "testrepo.git" begin 
    set_namespace!(test_repo, "foo")
    @test isempty(ref_names(test_repo)) 
end

#---------------------------
# Repo Push Test
#---------------------------
# test_push_single_ref
@sandboxed_test "testrepo.git" begin
    remote_repo = test_repo
    source_path = joinpath(TESTDIR, "fixtures", "testrepo.git")
    test_repo = clone(sbt, "testrepo.git", "testrepo")
    config(remote_repo)["core.bare"] = "true"
    create_ref(test_repo,
        "refs/heads/unit_test",
        Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    
    result = push!(test_repo, "origin", 
                ["refs/heads/master",
                "refs/heads/master:refs/heads/foobar", 
                "refs/heads/unit_test"])
    @test isempty(result)

    @test (target(lookup_ref(remote_repo, "refs/heads/foobar"))
                == Oid("a65fedf39aefe402d3bb6e24df4d4f5fe4547750"))
    @test (target(lookup_ref(remote_repo, "refs/heads/unit_test"))
                == Oid("8496071c1b46c854b31185ea97743be6a8774479")) 
end

# test_push_to_non_bare_raise_error
@sandboxed_test "testrepo.git" begin
    remote_repo = test_repo
    source_path = joinpath(TESTDIR, "fixtures", "testrepo.git")
    test_repo = clone(sbt, "testrepo.git", "testrepo")
    config(remote_repo)["core.bare"] = "false"
    create_ref(test_repo,
        "refs/heads/unit_test",
        Oid("8496071c1b46c854b31185ea97743be6a8774479"))

    @test_throws push!(test_repo, "origin", ["refs/heads/master"])
end

# tets_push_to_remote_instance
@sandboxed_test "testrepo.git" begin
    remote_repo = test_repo
    source_path = joinpath(TESTDIR, "fixtures", "testrepo.git")
    test_repo = clone(sbt, "testrepo.git", "testrepo")
    config(remote_repo)["core.bare"] = "true"

    origin = lookup_remote(test_repo, "origin")
    result = push!(test_repo, origin, ["refs/heads/master"])
    @test isempty(result)
end

# test_push_non_forward_raise_error
@sandboxed_test "testrepo.git" begin
    remote_repo = test_repo
    source_path = joinpath(TESTDIR, "fixtures", "testrepo.git")
    test_repo = clone(sbt, "testrepo.git", "testrepo")
    config(remote_repo)["core.bare"] = "true"
    create_ref(test_repo,
        "refs/heads/unit_test",
        Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    @test_throws push!(test_repo, "origin",
                       ["refs/heads/unit_test:refs/heads/master"])
    @test (target(lookup_ref(remote_repo, "refs/heads/master"))
                == Oid("a65fedf39aefe402d3bb6e24df4d4f5fe4547750"))
end

# test_push_non_forward_raise_error 
@sandboxed_test "testrepo.git" begin
    remote_repo = test_repo
    source_path = joinpath(TESTDIR, "fixtures", "testrepo.git")
    test_repo = clone(sbt, "testrepo.git", "testrepo")
    config(remote_repo)["core.bare"] = "true"
    create_ref(test_repo,
        "refs/heads/unit_test",
        Oid("8496071c1b46c854b31185ea97743be6a8774479"))

    result = push!(test_repo, "origin", 
                   ["+refs/heads/unit_test:refs/heads/master"])
    @test isempty(result) 

    @test (target(lookup_ref(remote_repo, "refs/heads/master")) 
               == Oid("8496071c1b46c854b31185ea97743be6a8774479"))
end

#---------------------------
# Repo Checkout Test
#---------------------------
# test_checkout_tree_with_revspec_string
@sandboxed_checkout_test begin 
    checkout_tree!(test_repo, "refs/heads/dir", {:strategy => :force})
    set_head!(test_repo, "refs/heads/dir")

    @test isfile(joinpath(repo_workdir(test_repo), "README"))
    @test isfile(joinpath(repo_workdir(test_repo), "branch_file.txt"))
    @test isfile(joinpath(repo_workdir(test_repo), "new.txt"))
    @test isfile(joinpath(repo_workdir(test_repo), "a/b.txt"))

    @test isfile(joinpath(repo_workdir(test_repo), "ab")) == false

    checkout_tree!(test_repo, "refs/heads/subtrees", {:strategy => :safe})
    set_head!(test_repo, "refs/heads/subtrees")
    
    @test isfile(joinpath(repo_workdir(test_repo), "README"))
    @test isfile(joinpath(repo_workdir(test_repo), "branch_file.txt"))
    @test isfile(joinpath(repo_workdir(test_repo), "new.txt"))
    @test isfile(joinpath(repo_workdir(test_repo), "ab/4.txt"))
    @test isfile(joinpath(repo_workdir(test_repo), "ab/c/3.txt"))
    @test isfile(joinpath(repo_workdir(test_repo), "ab/de/2.txt"))
    @test isfile(joinpath(repo_workdir(test_repo), "ab/de/fgh/1.txt"))
    
    @test isdir(joinpath(repo_workdir(test_repo), "a")) == false
end

# test_checkout_tree_raises_errors_in_progress_cb
@sandboxed_checkout_test begin 
    try
        checkout_tree!(test_repo, "refs/heads/dir",
                {:strategy => :force,
                 :progress => (x...) -> error("fail")})
    catch err
        @test err.msg == "fail"
    end
end

@sandboxed_checkout_test begin 
    try
        checkout_tree!(test_repo, "refs/heads/dir",
                {:strategy => :force,
                 :notify => (x...) -> error("fail")})
    catch err
        @test err.msg == "fail"
    end
end

#test_checkout_tree_subdirectory
@sandboxed_checkout_test begin 
    @test isfile(joinpath(repo_workdir(test_repo), "ab")) == false
    checkout_tree!(test_repo, "refs/heads/subtrees", 
                   {:strategy => :safe, :paths => "ab/de/"})

    @test isdir(joinpath(repo_workdir(test_repo)), "ab")
    @test isfile(joinpath(repo_workdir(test_repo)), "ab/de/2.txt")
    @test isfile(joinpath(repo_workdir(test_repo)), "ab/de/fgh/1.txt")
end

#test_checkout_tree_subtree_directory
@sandboxed_checkout_test begin 
    @test isfile(joinpath(repo_workdir(test_repo), "de")) == false
    checkout_tree!(test_repo, "refs/heads/subtrees:ab",
                   {:strategy => :safe, :paths => "de/"})

    @test isdir(joinpath(repo_workdir(test_repo)), "de")
    @test isfile(joinpath(repo_workdir(test_repo)), "de/2.txt")
    @test isfile(joinpath(repo_workdir(test_repo)), "de/fgh/1.txt")
end

#test_checkout_tree_raises_with_bare_repo
@sandboxed_checkout_test begin 
    @test_throws checkout_tree!(test_bare, "HEAD", {:strategy => :safe_create})
end

#test checkout tree works with bare repo and target directory
@sandboxed_checkout_test begin
    d = tempdir()
    try
        checkout_tree!(test_bare, "HEAD", 
                       {:strategy => :safe_create, :target_directory => d})
        @test isfile(joinpath(d, "README"))
        @test isfile(joinpath(d, "new.txt"))
    finally
       # XXX: clean up here
       # run(`rm -r -f $d`)
    end
end

@sandboxed_checkout_test begin
    checkout!(test_repo, "dir", {:strategy => :force})
    @test head(test_repo) |> name == "refs/heads/dir"
end

# test_checkout_with_HEAD
@sandboxed_checkout_test begin
    checkout!(test_repo, "dir", {:strategy => :force})
    rm(joinpath(repo_workdir(test_repo), "README"))

    checkout!(test_repo, "HEAD", {:strategy => :force})
    @test isfile(joinpath(repo_workdir(test_repo), "README"))
    @test name(head(test_repo)) == "refs/heads/dir"
end

# test_checkout_with_commit_detaches_HEAD
@sandboxed_checkout_test begin
    checkout!(test_repo, rev_parse_oid(test_repo, "refs/heads/dir"), 
              {:strategy => :force})
    @test ishead_detached(test_repo)
    @test rev_parse_oid(test_repo, "refs/heads/dir") == target(head(test_repo))
end

# test_checkout_with_remote_branch_detaches_HEAD
@sandboxed_checkout_test begin
    checkout!(test_clone, "origin/dir", {:strategy => :force})
    @test ishead_detached(test_clone)
    @test rev_parse_oid(test_clone, "refs/remotes/origin/dir") == target(head(test_clone))
end
