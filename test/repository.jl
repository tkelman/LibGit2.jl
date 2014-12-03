# create bare repo
test_repo_path = joinpath(pwd(), "TestLibGit2")

function cleanup_repo(path)
    p = abspath(path)
    if isdir(p)
        rm(p, recursive=true)
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
context("test creating bare repository") do
    tmp_repo(test_repo_path) do
        init_repo(test_repo_path; bare=true)
        repo = GitRepo(test_repo_path)
        try
            @test isa(repo, GitRepo)
            @test isbare(repo)
            @test isempty(repo)
        finally
            close(repo)
            LibGit2.free!(repo)
        end
    end
end

context("test creating repository") do
    tmp_repo(test_repo_path) do
        init_repo(test_repo_path)
        repo = GitRepo(test_repo_path)
        try
            @test isa(repo, GitRepo)
            @test !isbare(repo)
            @test isempty(repo)
            @test abspath(workdir(repo)) == abspath(test_repo_path)
            @test abspath(path(repo)) == joinpath(test_repo_path, ".git")
            @test isa(GitIndex(repo), GitIndex)
            # empty repo has no head
            @test head(repo) == nothing
            # empty repo has no tags
            @test isempty(tags(repo))
            # empty repo has no commits
            @test isempty(commits(repo))
            # empty repo has no references
            @test isempty(references(repo))

            @test isa(GitConfig(repo), GitConfig)
            @test isa(GitTreeBuilder(repo), GitTreeBuilder)
        finally
            close(repo)
            LibGit2.free!(repo)
        end
    end
end

# -----------------------------------------
# Tests adapted from Ruby's Rugged Library
# -----------------------------------------
sandboxed_test("testrepo.git", "test fails to open repos that dont' exist") do test_repo, path
    @test_throws LibGitError{:OS,:NotFound} GitRepo("fakepath/123")
    @test_throws LibGitError{:OS,:NotFound} GitRepo("test")
end

sandboxed_test("testrepo.git", "test can check if object exist") do test_repo, path
    @test Oid("8496071c1b46c854b31185ea97743be6a8774479") in test_repo
    @test exists(test_repo, Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    @test Oid("1385f264afb75a56a5bec74243be9b367ba4ca08") in test_repo
    @test exists(test_repo, Oid("1385f264afb75a56a5bec74243be9b367ba4ca08"))
    @test !(Oid("ce08fe4884650f067bd5703b6a59a8b3b3c99a09") in test_repo)
    @test !(exists(test_repo, Oid("ce08fe4884650f067bd5703b6a59a8b3b3c99a09")))
    @test !(Oid("8496071c1c46c854b31185ea97743be6a8774479") in test_repo)
    @test !(exists(test_repo, Oid("8496071c1c46c854b31185ea97743be6a8774479")))
end

sandboxed_test("testrepo.git", "test can read a raw object") do test_repo, path
    rawobj = read(test_repo, Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    @test match(r"tree 181037049a54a1eb5fab404658a3a250b44335d7", data(rawobj)) != nothing
    @test sizeof(rawobj) == 172
    @test isa(rawobj, OdbObject{GitCommit})
end

sandboxed_test("testrepo.git", "test can read object headers") do test_repo, path
    h = read_header(test_repo, Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    @test h[:type] == GitCommit
    @test h[:nbytes] == 172
end

sandboxed_test("testrepo.git", "test check reads rail on missing objs") do test_repo, path
    @test_throws LibGitError{:Odb,:NotFound} read(test_repo, Oid("a496071c1b46c854b31185ea97743be6a8774471"))
end

sandboxed_test("testrepo.git", "test check read headers fail on missing objects") do test_repo, path
    @test_throws LibGitError{:Odb,:NotFound} read_header(test_repo, Oid("a496071c1b46c854b31185ea97743be6a8774471"))
end

sandboxed_test("testrepo.git", "test walking with block") do test_repo, path
    oid = Oid("a4a7dce85cf63874e984719f4fdd239f5145052f")
    list = []
    walk(test_repo, oid) do c
       push!(list, c)
    end
    @test join(map(c -> hex(c)[1:5], list), ".") == "a4a7d.c4780.9fd73.4a202.5b5b0.84960"
end

sandboxed_test("testrepo.git", "test walking without block") do test_repo, path
    oid = Oid("a4a7dce85cf63874e984719f4fdd239f5145052f")
    commits = walk(test_repo, oid)
    @test isa(commits, Task)
    @test istaskdone(commits) == false
end

sandboxed_test("testrepo.git", "test lookup object") do test_repo, path
    obj = test_repo[Oid("8496071c1b46c854b31185ea97743be6a8774479")]
    @test isa(obj, GitCommit)
end

sandboxed_test("testrepo.git", "test find reference") do test_repo, path
    ref = lookup_ref(test_repo, "refs/heads/master")
    @test isa(ref, GitReference)
    @test name(ref) == "refs/heads/master"
end

sandboxed_test("testrepo.git", "test match all refs") do test_repo, path
    refs = collect(foreach(GitReference, test_repo, "refs/heads/*"))
    @test length(refs) == 12
end

sandboxed_test("testrepo.git", "test return all ref names") do test_repo, path
    rnames = ref_names(test_repo)
    @test length(rnames) == 21
end

sandboxed_test("testrepo.git", "test return all tags") do test_repo, path
    ts = tags(test_repo)
    @test length(ts) == 7
end

sandboxed_test("testrepo.git", "test return all matching tags") do test_repo, path
    @test length(tags(test_repo, "e90810b")) == 1
    @test length(tags(test_repo, "*tag*")) == 4
end

sandboxed_test("testrepo.git", "test return a list of all remotes") do test_repo, path
    rs = remotes(test_repo)
    @test length(rs) == 5
end

sandboxed_test("testrepo.git", "test lookup head") do test_repo, path
    h = head(test_repo)
    @test isa(h, GitReference)
    @test name(h) == "refs/heads/master"
    @test target(h) == Oid("a65fedf39aefe402d3bb6e24df4d4f5fe4547750")
end

sandboxed_test("testrepo.git", "test set head ref") do test_repo, path
    set_head!(test_repo, "refs/heads/packed")
    @test name(head(test_repo)) == "refs/heads/packed"
end

sandboxed_test("testrepo.git", "test set head invalid") do test_repo, path
    @test_throws LibGitError{:Ref,:InvalidSpec} set_head!(test_repo, "a65fedf39aefe402d3bb6e24df4d4f5fe4547750")
end
#=
sandboxed_test("testrepo.git", "test access a file") do test_repo, path
    id = Oid("a65fedf39aefe402d3bb6e24df4d4f5fe4547750")
    blob = blob_at(test_repo, id, "new.txt")
    @test "my new file\n" == bytestring(blob)
end

sandboxed_test("testrepo.git", "test access a missing file") do test_repo, path
    id = Oid("a65fedf39aefe402d3bb6e24df4d4f5fe4547750")
    blob = blob_at(test_repo, id, "file-not-found.txt")
    @test blob == nothing
end

# TODO: the next two fail on windows because file handles are still open
# and the temp directory cannot be removed
sandboxed_test("testrepo.git", "test enumerate all objects") do test_repo, path
    @test count(x -> true, test_repo) == 1687
end

sandboxed_test("testrepo.git", "test load alternates") do test_repo, _
    alt_path = joinpath(pwd(), "fixtures", "alternate", "objects")
    repo = GitRepo(path(test_repo), alternates=[alt_path])
    try
      @test count(x->true, repo) == 1690
      @test read(repo, Oid("146ae76773c91e3b1d00cf7a338ec55ae58297e2")) != nothing
    finally
      close(repo)
    end
end
=#

sandboxed_test("testrepo.git", "test alternates with invalid path type") do test_repo, _
    @test_throws ArgumentError GitRepo(path(test_repo), alternates=["error"])
end

sandboxed_test("testrepo.git", "test find merge base between ids") do test_repo, path
    commit1 = Oid("a4a7dce85cf63874e984719f4fdd239f5145052f")
    commit2 = Oid("a65fedf39aefe402d3bb6e24df4d4f5fe4547750")
    base    = Oid("c47800c7266a2be04c571c04d5a6614691ea99bd")
    @test base == merge_base(test_repo, commit1, commit2)
end

sandboxed_test("testrepo.git", "test find merge base between commits") do test_repo, path
    commit1 = test_repo[Oid("a4a7dce85cf63874e984719f4fdd239f5145052f")]
    commit2 = test_repo[Oid("a65fedf39aefe402d3bb6e24df4d4f5fe4547750")]
    base    = Oid("c47800c7266a2be04c571c04d5a6614691ea99bd")
    @test base == merge_base(test_repo, commit1, commit2)
end

sandboxed_test("testrepo.git", "test find mere base between ref and id") do test_repo, path
    commit1 = Oid("a4a7dce85cf63874e984719f4fdd239f5145052f")
    commit2 = "refs/heads/master"
    base    = Oid("c47800c7266a2be04c571c04d5a6614691ea99bd")
    @test base == merge_base(test_repo, commit1, commit2)
end

sandboxed_test("testrepo.git", "test find merge base between many") do test_repo, path
    commit1 = Oid("a4a7dce85cf63874e984719f4fdd239f5145052f")
    commit2 = "refs/heads/packed"
    commit3 = test_repo[Oid("a65fedf39aefe402d3bb6e24df4d4f5fe4547750")]

    base    = Oid("c47800c7266a2be04c571c04d5a6614691ea99bd")
    @test base == merge_base(test_repo, commit1, commit2, commit3)
end

sandboxed_test("testrepo.git", "test ahead behind with ids") do test_repo, path
    ahead, behind = ahead_behind(test_repo,
      Oid("a4a7dce85cf63874e984719f4fdd239f5145052f"),
      Oid("a65fedf39aefe402d3bb6e24df4d4f5fe4547750")
    )
    @test ahead == 2
    @test behind == 1
end

sandboxed_test("testrepo.git", "test ahead behind with commits") do test_repo, path
    ahead, behind = ahead_behind(test_repo,
      test_repo[Oid("a4a7dce85cf63874e984719f4fdd239f5145052f")],
      test_repo[Oid("a65fedf39aefe402d3bb6e24df4d4f5fe4547750")]
    )
    @test ahead == 2
    @test behind == 1
end

#---------------------------
# Merge Commits Repo Test
#---------------------------
sandboxed_test("merge-resolve", "test merge commits") do test_repo, path
    our_commit   = lookup_branch(test_repo, "master") |> tip
    their_commit = lookup_branch(test_repo, "branch") |> tip

    index = merge_commits(test_repo, our_commit, their_commit)
    #TODO: BUG very rarely the length of the index is reported as 6??
    @test length(index) == 8

    @test (Oid("233c0919c998ed110a4b6ff36f353aec8b713487") ==
            Oid(index["added-in-master.txt", 0]))
    @test (Oid("f2e1550a0c9e53d5811175864a29536642ae3821") ==
            Oid(index["automergeable.txt", 0]))
    @test (Oid("4eb04c9e79e88f6640d01ff5b25ca2a60764f216") ==
            Oid(index["changed-in-branch.txt", 0]))
    @test (Oid("11deab00b2d3a6f5a3073988ac050c2d7b6655e2") ==
            Oid(index["changed-in-master.txt", 0]))

    @test (Oid("d427e0b2e138501a3d15cc376077a3631e15bd46") ==
            Oid(index["conflicting.txt", 1]))
    @test (Oid("4e886e602529caa9ab11d71f86634bd1b6e0de10") ==
            Oid(index["conflicting.txt", 2]))
    @test (Oid("2bd0a343aeef7a2cf0d158478966a6e587ff3863") ==
            Oid(index["conflicting.txt", 3]))

    @test (Oid("c8f06f2e3bb2964174677e91f0abead0e43c9e5d") ==
            Oid(index["unchanged.txt", 0]))
    @test has_conflicts(index)
end

#---------------------------
# Shallow Repo Test
#---------------------------
sandboxed_test("testrepo.git", "test shallow repo") do test_repo, path
    sandboxed_test("shallow.git") do shallow_repo, shallow_path
        @test !isshallow(test_repo)
        @test isshallow(shallow_repo)
    end
end

with_tmp_repo_access("test shallow repo write") do test_repo, path
    TEST_CONTENT = "my test data\n"

    context("test can hash data") do
        id = hash_data(GitBlob, TEST_CONTENT)
        @test id == Oid("76b1b55ab653581d6f2c7230d34098e837197674")
    end

    context("test write to odb") do
        id = write!(GitBlob, test_repo, TEST_CONTENT)
        @test id == Oid("76b1b55ab653581d6f2c7230d34098e837197674")
        @test Oid("76b1b55ab653581d6f2c7230d34098e837197674") in test_repo
    end

    context("test no merge base between unrelated branches") do
        info = revparse(test_repo, "HEAD")
        @test isa(info, GitCommit)
        sig = Signature("test", "test@test.com")
        #baseless = commit(test_repo, "null", sig, sig, "",
        #@test merge_base(test_repo, "HEAD", baseless) == nothing
    end

    context("test default signature") do
        testname = "Test User"
        testemail = "test@example.com"
        GitConfig(test_repo)["user.name"] = testname
        GitConfig(test_repo)["user.email"] = testemail
        @assert isa(default_signature(test_repo), Signature)
        @test testname == (default_signature(test_repo) |> name)
        @test testemail == (default_signature(test_repo) |> email)
    end
end

#---------------------------
# Repo Discover Test
#---------------------------
teardown_dir(p::AbstractString) = rm(p, recursive=true)

function discover_test(f::Function)
    tmpdir = mktempdir()
    mkdir(joinpath(tmpdir, "foo"))
    try
        f(tmpdir)
    finally
        teardown_dir(tmpdir)
    end
end
discover_test(f::Function, s::AbstractString) = (println(s); discover_test(f))

discover_test("test discover false") do tmpdir
    @test_throws LibGitError{:Repo,:NotFound} repo_discover(tmpdir)
end

discover_test("test discover nested false") do tmpdir
    @test_throws LibGitError{:Repo,:NotFound} repo_discover(joinpath(tmpdir, "foo"))
end

discover_test("test discover true") do tmpdir
    repo = init_repo(tmpdir, bare=true)
    root = repo_discover(tmpdir)
    try
        @test isbare(root) == true
        @test path(root) == path(repo)
    finally
        close(root)
        close(repo)
    end
end

discover_test("test discover nested true") do tmpdir
    repo = init_repo(tmpdir, bare=true)
    root = repo_discover(joinpath(tmpdir, "foo"))
    try
        @test isbare(root) == true
        @test path(root) == path(repo)
    finally
        close(root)
        close(repo)
    end
end

#---------------------------
# Repo Init Test
#---------------------------
function repo_init_test(f::Function)
    tmpdir = mktempdir()
    try
        f(tmpdir)
    finally
        teardown_dir(tmpdir)
    end
end
repo_init_test(f::Function, s::AbstractString) = (println(s); repo_init_test(f))

repo_init_test("test init bare false") do tmpdir
    repo = init_repo(tmpdir, bare=false)
    try
        @test isbare(repo) == false
    finally
        close(repo)
    end
end

repo_init_test("test init bare true") do tmpdir
    repo = init_repo(tmpdir, bare=true)
    try
        @test isbare(repo) == true
    finally
        close
    end
end

repo_init_test("test init non bare default") do tmpdir
    repo = init_repo(tmpdir)
    try
        @test isbare(repo) == false
    finally
        close(repo)
    end
end

#---------------------------
# Repo Clone Test
#---------------------------
#=
repo_clone_test("basic repo clone") do source, dest
    @show source, dest
    repo = repo_clone(source, dest)
    try
      @test isa(repo, GitRepo)
      #@test open(readline, joinpath(tmppath, "README")) |> chomp == "hey"
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

#:test_clone_bare
@repo_clone_test begin
    repo = repo_clone(source_path, tmppath, Dict{Any,Any}(:bare => true))
    try
        @test isbare(repo)
    catch
        close(repo)
    end
end

#:test_clone_with_progress
@repo_clone_test begin
    total_objects = indexed_objects = received_objects = received_bytes = 0
    callsback = 0
    repo = repo_clone(source_path, tmppath, Dict{Any,Any}(
      :callbacks => Dict{Any,Any}(
        :transfer_progress => (args...) -> begin
          total_objects, indexed_objects, received_objects, received_bytes = args
          callsback += 1
          end
        )
      )
    )
    close(repo)
    @test 22 == callsback
    @test 19 == total_objects
    @test 19 == indexed_objects
    @test 19 == received_objects
    @test 1563 == received_bytes
end

#:test_clone_quits_on_error
@repo_clone_test begin
    try
      repo_clone(source_path, tmppath, Dict{Any,Any}(:callbacks => Dict{Any,Any}(
        :transfer_progress => (args...) -> error("boom")
      )))
    catch err
      @test err.msg == "boom"
    end
    @test isdir(joinpath(tmppath, ".git")) == false
end

# test_clone_with_bad_progress_callback
@repo_clone_test begin
    @test_throws repo_clone(source_path, tmppath, Dict{Any,Any}(:callbacks => Dict{Any,Any}(
        :transfer_progress => ()
      )))
    @test isdir(joinpath(tmppath, ".git")) == false
end
=#
#---------------------------
# Repo Namespace Test
#---------------------------
sandboxed_test("testrepo.git", "test repo namespace") do test_repo, path
    @test namespace(test_repo) == nothing
end

sandboxed_test("testrepo.git", "test set repo namespace") do test_repo, path
    set_namespace!(test_repo, "foo")
    @test namespace(test_repo) == "foo"

    set_namespace!(test_repo, "bar")
    @test namespace(test_repo) == "bar"

    set_namespace!(test_repo, "foo/bar")
    @test namespace(test_repo) == "foo/bar"

    set_namespace!(test_repo, nothing)
    @test namespace(test_repo) == nothing
end

sandboxed_test("testrepo.git", "test empty namespace") do test_repo, path
    set_namespace!(test_repo, "foo")
    @test isempty(ref_names(test_repo))
end

#---------------------------
# Repo Push Test
#---------------------------
sandboxed_clone_test("testrepo.git", "test repo push") do test_repo, remote_repo, path
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

sandboxed_clone_test("testrepo.git", "test push to non bare raise err") do test_repo, remote_repo, path
    create_ref(test_repo,
        "refs/heads/unit_test",
        Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    try
        push!(test_repo, "origin", ["refs/heads/master"])
        @test false
    except
        @test true
    end
end

sandboxed_clone_test("testrepo.git", "test push to remote instance") do test_repo, remote_repo, path
    origin = lookup_remote(test_repo, "origin")
    result = push!(test_repo, origin, ["refs/heads/master"])
    @test isempty(result)
end

sandboxed_clone_test("testrepo.git", "test push non ff raise error") do test_repo, remote_repo, path
    create_ref(test_repo,
        "refs/heads/unit_test",
        Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    @test_throws ErrorException push!(test_repo, "origin",
                       ["refs/heads/unit_test:refs/heads/master"])
    @test (target(lookup_ref(remote_repo, "refs/heads/master"))
                == Oid("a65fedf39aefe402d3bb6e24df4d4f5fe4547750"))
end

sandboxed_clone_test("testrepo.git", "test push non ff raise error") do test_repo, remote_repo, path
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
sandboxed_checkout_test("test checkout tree with revspec string") do test_repo, test_clone, test_bare
    checkout_tree!(test_repo, "refs/heads/dir", Dict{Any,Any}(:strategy => :force))
    set_head!(test_repo, "refs/heads/dir")

    @test isfile(joinpath(workdir(test_repo), "README"))
    @test isfile(joinpath(workdir(test_repo), "branch_file.txt"))
    @test isfile(joinpath(workdir(test_repo), "new.txt"))
    @test isfile(joinpath(workdir(test_repo), "a", "b.txt"))

    @test isfile(joinpath(workdir(test_repo), "ab")) == false

    checkout_tree!(test_repo, "refs/heads/subtrees", Dict{Any,Any}(:strategy => :safe))
    set_head!(test_repo, "refs/heads/subtrees")

    @test isfile(joinpath(workdir(test_repo), "README"))
    @test isfile(joinpath(workdir(test_repo), "branch_file.txt"))
    @test isfile(joinpath(workdir(test_repo), "new.txt"))
    @test isfile(joinpath(workdir(test_repo), "ab","4.txt"))
    @test isfile(joinpath(workdir(test_repo), "ab","c", "3.txt"))
    @test isfile(joinpath(workdir(test_repo), "ab","de","2.txt"))
    @test isfile(joinpath(workdir(test_repo), "ab","de","fgh","1.txt"))

    @test isdir(joinpath(workdir(test_repo), "a")) == false
end

sandboxed_checkout_test("test checkout raises errors in callback") do test_repo, test_clone, test_bare
    try
        checkout_tree!(test_repo, "refs/heads/dir",
                Dict{Any,Any}(:strategy => :force,
                              :progress => (x...) -> error("fail")))
    catch err
        @test err.msg == "fail"
    end
end

sandboxed_checkout_test("test checkout tree subdir") do test_repo, test_clone, test_bare
    @test isfile(joinpath(workdir(test_repo), "ab")) == false
    checkout_tree!(test_repo, "refs/heads/subtrees",
                   Dict{Any,Any}(:strategy => :safe, 
                                 :paths => "ab/de/"))

    @test isdir(joinpath(workdir(test_repo)), "ab")
    @test isfile(joinpath(workdir(test_repo)), "ab","de","2.txt")
    @test isfile(joinpath(workdir(test_repo)), "ab","de","fgh","1.txt")
end

sandboxed_checkout_test("test checkout tree subtree dir") do test_repo, test_clone, test_bare
    @test isfile(joinpath(workdir(test_repo), "de")) == false
    checkout_tree!(test_repo, "refs/heads/subtrees:ab",
                  Dict{Any,Any}(:strategy => :safe, :paths => "de/"))

    @test isdir(joinpath(workdir(test_repo)),  "de")
    @test isfile(joinpath(workdir(test_repo)), "de", "2.txt")
    @test isfile(joinpath(workdir(test_repo)), "de", "fgh", "1.txt")
end

sandboxed_checkout_test("test checkout tree raises with bare repo") do test_repo, test_clone, test_bare
    @test_throws LibGitError{:Repo,:BareRepo} checkout_tree!(test_bare, "HEAD", 
                    Dict{Any,Any}(:strategy => :safe_create))
end

sandboxed_checkout_test("test checkout tree works with bare repo and target dir") do test_repo, test_clone, test_bare
    d = mktempdir()
    try
        checkout_tree!(test_bare, "HEAD", Dict{Any,Any}(:strategy => :safe_create, :target_directory => d))
        @test isfile(joinpath(d, "README"))
        @test isfile(joinpath(d, "new.txt"))
    finally
        rm(d, recursive=true)
    end
end

sandboxed_checkout_test() do test_repo, test_clone, test_bare
    checkout!(test_repo, "dir", Dict{Any,Any}(:strategy => :force))
    @test head(test_repo) |> name == "refs/heads/dir"
end

sandboxed_checkout_test("test checkout with head") do test_repo, test_clone, test_bare
    checkout!(test_repo, "dir", Dict{Any,Any}(:strategy => :force))
    rm(joinpath(workdir(test_repo), "README"))

    checkout!(test_repo, "HEAD", Dict{Any,Any}(:strategy => :force))
    @test isfile(joinpath(workdir(test_repo), "README"))
    @test name(head(test_repo)) == "refs/heads/dir"
end

sandboxed_checkout_test("test checkout with commit detaches HEAD") do test_repo, test_clone, test_bare
    checkout!(test_repo, revparse_oid(test_repo, "refs/heads/dir"), Dict{Any,Any}(:strategy => :force))
    @test is_head_detached(test_repo)
    @test revparse_oid(test_repo, "refs/heads/dir") == target(head(test_repo))
end

sandboxed_checkout_test("test checkout with remote branch detaches HEAD") do test_repo, test_clone, test_bare
    checkout!(test_clone, "origin/dir", Dict{Any,Any}(:strategy => :force))
    @test is_head_detached(test_clone)
    @test revparse_oid(test_clone, "refs/remotes/origin/dir") == target(head(test_clone))
end
