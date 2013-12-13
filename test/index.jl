repo = create_test_repo()
@test isdir(repo_workdir(repo)) 
idx = repo_index(repo)
@test isa(idx, Index)
add_bypath!(idx, "README")
tree_id = write_tree!(idx)
@test isa(tree_id, Oid)
@test hex(tree_id) == "b7119b11e8ef7a1a5a34d3ac87f5b075228ac81e"
if isdir(repo_workdir(repo))
    path = repo_workdir(repo)
    run(`rm -R $path`)
end
