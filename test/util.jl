function create_test_repo(test_path)
    if isdir(abspath(test_path))
        run(`rm -f -r $test_path`)
    end
    repo = repo_init(test_path)
    fh = open(joinpath(test_path, "README"), "w")
    write(fh, "foo\n")
    close(fh)
    return repo
end

function seed_test_repo(repo)
    sig = Signature("test", "test@test.com")
    idx = repo_index(repo)
    add_bypath!(idx, "README")
    tree_id = write_tree!(idx)

    msg = "This is a commit\n"
    tree = repo_lookup(GitTree, repo, tree_id)
    commit_id = commit(repo, "HEAD", sig, sig, msg, tree)
    return commit_id, tree_id
end
