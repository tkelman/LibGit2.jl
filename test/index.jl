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

