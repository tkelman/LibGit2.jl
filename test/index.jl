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
    @test isdir(repo_workdir(repo)) 
    idx = repo_index(repo)
    @test isa(idx, GitIndex)
    add_bypath!(idx, "README")
    tree_id = write_tree!(idx)
    @test isa(tree_id, Oid)
    @test isequal(hex(tree_id), "b7119b11e8ef7a1a5a34d3ac87f5b075228ac81e")
    tree1 = lookup(GitTree, repo, tree_id)
    tree2 = lookup_tree(repo, tree_id)

    @test tree1 == tree2
    tree = tree1
    @test isa(tree, GitTree)
    @test tree.ptr != C_NULL
    @test isa(oid(tree), Oid)
    @test isa(hex(tree), ASCIIString)
catch err
    rethrow(err)
finally 
    cleanup_dir(test_path)
end

# -----------------------------------------
# Tests adapted from Ruby's Rugged Library
# -----------------------------------------

function new_idx_entry()
    now = int(time())
    return IndexEntry("new_path",
                      Oid("d385f264afb75a56a5bec74243be9b367ba4ca08"),
                      now,
                      now,
                      1000,
                      234881027,
                      88888,
                      33199,
                      502,
                      502,
                      3)
end

@with_test_index begin
    @test length(test_index) == 2
end

@with_test_index begin
    clear!(test_index)
    @test length(test_index) == 0
end

@with_test_index begin
    remove!(test_index, "new.txt")
    @test length(test_index) == 1
end

@with_test_index begin
    remove_dir!(test_index, "does-not-exist")
    @test length(test_index) == 2

    remove_dir!(test_index, "", 2)
    @test length(test_index) == 2

    remove_dir!(test_index, "")
    @test length(test_index) == 0
end

@with_test_index begin
    entry = test_index[1]
    @test "README" == entry.path 
    #@test Oid("1385f264afb75a56a5bec74243be9b367ba4ca08") == entry.oid
    @test 1273360380 == int(entry.mtime)
    @test 1273360380 == int(entry.ctime)
    #@test 4 == entry.file_size
    @show entry.dev
    @show entry.ino
    @show entry.mode
    @show entry.uid
    @show entry.gid
    @show entry.file_size
    
    @test 234881026 == entry.dev
    @test 6674088 == entry.ino
    @test 33188 == entry.mode
    @test 501 == entry.uid
    @test 0 == entry.gid
    @test false == entry.valid
    @test 0 == entry.stage

    entry = test_index[2]
    @test "new.txt" == entry.path
    @test Oid("fa49b077972391ad58037050f2a75f74e3671e92") == entry.oid
end
