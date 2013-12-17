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
        @test isa(repo_index(repo), Index)
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

#TODO:
# test walking with block
#@sandboxed_test "testrepo.git" begin
#    oid = Oid("a4a7dce85cf63874e984719f4fdd239f5145052f")
#    list = {}
#    walk(test_repo) do c
#       push!(list, c)
#    end
#    @test join(map(c -> hex(oid(c))[1:5]), ".") == "a4a7d.c4780.9fd73.4a202.5b5b0.84960"
#end

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

# TODO: match all refs
@sandboxed_test "testrepo.git" begin
    refs = {}
    for r in iter_refs(test_repo; glob="refs/heads/*")
        push!(refs, r)
    end
    @test length(refs) == 12
end

# TODO: return all ref names
@sandboxed_test "testrepo.git" begin
    ref_names = {}
    for r in iter_refs(test_repo)
        n = name(r)
        @test isa(n, String)
        push!(ref_names, n)
    end
    @test length(ref_names) == 21
end
