function create_test_repo()
    test_path = joinpath(pwd(), "TestLibGit2")
    if isdir(abspath(test_path))
        run(`rm -f -R $test_path`)
    end
    repo = repo_init(test_path)
    fh = open(joinpath(test_path, "README"), "w")
    write(fh, "foo\n")
    close(fh)
    return repo
end

function seed_test_repo(repo)
    sig = Signiture("test", "test@test.com")
    idx = repo_index(repo)
    add_bypath!(idx, "README")
    tree_id = write_tree(idx)

    msg = "test commit message"
    tree = lookup_tree(repo, treeid)
    commit_id = create_commit("HEAD", sig, sig, msg, tree)
    return commit_id, tree_id
end
