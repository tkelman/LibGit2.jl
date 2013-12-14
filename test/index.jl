# create a repo with a README file
cleanup_dir(p) = begin
    if isdir(p)
        run(`rm -f -R $p`)
    end
end

test_path = joinpath(pwd(), "testrepo")
try
    repo = create_test_repo(test_path)
    @test isdir(repo_workdir(repo)) 
    idx = repo_index(repo)
    @test isa(idx, Index)
    add_bypath!(idx, "README")
    tree_id = write_tree!(idx)
    @test isa(tree_id, Oid)
    @test isequal(hex(tree_id), "b7119b11e8ef7a1a5a34d3ac87f5b075228ac81e")
    tree1 = repo_lookup(GitTree, repo, tree_id)
    tree2 = repo_lookup_tree(repo, tree_id)

    @test tree1 == tree2
    tree = tree1
    @test isa(tree, GitTree)
    @test tree.ptr != C_NULL
    @test isa(oid(tree), Oid)
    @test isa(hex(tree), ASCIIString)
catch err
    cleanup_dir(test_path)
    rethrow(err)
end 
cleanup_dir(test_path)
