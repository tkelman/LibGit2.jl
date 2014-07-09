using LibGit2

const PKGDIR = Pkg.dir("LibGit2")
const TESTDIR = joinpath(PKGDIR, "test")
const LIBGIT2_FIXTURE_DIR = joinpath(PKGDIR, "vendor", "libgit2", "tests", "resources")

context(f::Function) = f()
context(f::Function, s::String) = (println(s); context(f))

cleanup_dir(p) = begin
    if isdir(p)
        @unix_only rm(p, recursive=true) 
    end
end

function remote_transport_test(f::Function) 
    tmp_dir = mktempdir()
    test_repo = repo_init(tmp_dir, bare=false)
    test_repo_dir = joinpath(TESTDIR, joinpath("fixtures", "testrepo.git", "."))
    try
        test_remote = remote_add!(test_repo, "origin", test_repo_dir)
        f(test_repo, test_remote)
    finally
        close(test_repo)
        @unix_only rm(tmp_dir, recursive=true)
    end
end 
remote_transport_test(f::Function, s::String) = (println(s); remote_transport_test(f))

function repo_clone_test(f::Function)
    tmp_dir = mktempdir()
    source = joinpath(TESTDIR, "fixtures", "testrepo.git")
    try
        f(source, tmp_dir)
    finally
        @unix_only rm(tmp_dir, recursive=true)
    end
end 
repo_clone_test(f::Function, s::String) = (println(s); repo_clone_test(f))

function with_test_index(f::Function)
    try
        test_index_path = joinpath(TESTDIR, "fixtures", "testrepo.git", "index")
        test_index = GitIndex(test_index_path)
        f(test_index, test_index_path)
    finally
    end
end 
with_test_index(f::Function, s::String) = (println(s); with_test_index(f))

function create_test_repo(test_path)
    if isdir(abspath(test_path))
        @unix_only rm(test_path, recursive=true)
    end
    repo = repo_init(test_path)
    open(joinpath(test_path, "README"), "w") do fh
        write(fh, "foo\n")
    end
    return repo
end

function seed_test_repo(repo)
    sig = Signature("test", "test@test.com")
    idx = GitIndex(repo)
    add!(idx, "README")
    tree_id = write_tree!(idx)

    msg = "This is a commit\n"
    tree = lookup(GitTree, repo, tree_id)
    commit_id = commit(repo, "HEAD", sig, sig, msg, tree)
    return commit_id, tree_id
end

function clone_sandbox(repo_path::String)
        tmp_dir  = mktempdir()
        repo_path = abspath(repo_path)
        run(`git clone --quiet -- $repo_path $tmp_dir`)
        return GitRepo(tmp_dir), tmp_dir
end

function setup_sandbox(repo_name::String)
    tmp_dir = mktempdir()
    fixture_dir = joinpath(LIBGIT2_FIXTURE_DIR, repo_name, ".")
    
    #TODO: cp(fixture_repo_path, repo_dir)
    run(`cp -r $fixture_dir $tmp_dir`)
    
    dirname = joinpath(tmp_dir, ".gitted")
    if isdir(dirname)
        newdirname = joinpath(tmp_dir, ".git")
        mv(dirname, newdirname)
    end 
    filename = joinpath(tmp_dir, "gitattributes")
    if isfile(filename)
        newfilename = joinpath(tmp_dir, ".gitattributes")
        mv(filename, newfilename)
    end
    filename = joinpath(tmp_dir, "gitignore")
    if isfile(filename)
        newfilename = joinpath(tmp_dir, ".gitignore")
        mv(filename, newfilename)
    end
    return GitRepo(tmp_dir), tmp_dir
end

function sandboxed_test(f::Function, reponame::String)
    repo, tmp_dir = setup_sandbox(reponame)
    try
        f(repo, tmp_dir)
    finally
        close(repo)
        @unix_only rm(tmp_dir, recursive=true)
    end
end
sandboxed_test(f::Function, reponame::String, s::String) = (println(s); 
                                                            sandboxed_test(f, reponame))

function sandboxed_clone_test(f::Function, reponame::String)
    remote, tmp_dir1 = setup_sandbox(reponame)
    GitConfig(remote)["core.bare"] = true
    repo, tmp_dir2 = clone_sandbox(tmp_dir1)
    try
        f(repo, remote, tmp_dir1)
    finally
        close(repo)
        close(remote)
        rm(tmp_dir1, recursive=true)
        rm(tmp_dir2, recursive=true)
    end
end 
sandboxed_clone_test(f::Function, reponame::String, s::String) = (println(s); 
                                                                  sandboxed_clone_test(f, reponame))

function sandboxed_checkout_test(f::Function)
    test_repo,  test_repo_dir  = setup_sandbox("testrepo")
    test_clone, test_clone_dir = clone_sandbox(test_repo_dir)
    test_bare,  test_bare_dir  = setup_sandbox("testrepo.git")
    GitConfig(test_bare)["core.bare"] = true
    try
        f(test_repo, test_clone, test_bare)
    finally
        close(test_repo)
        close(test_clone)
        close(test_bare)
        @unix_only rm(test_repo_dir, recursive=true)
        @unix_only rm(test_clone_dir, recursive=true)
        @unix_only rm(test_bare_dir, recursive=true)
    end
end
sandboxed_checkout_test(f::Function, s::String) = (println(s); 
                                                   sandboxed_checkout_test(f))
function with_repo_access(f::Function)
    path = joinpath(TESTDIR, "fixtures", "testrepo.git")
    repo = GitRepo(path)
    try
        f(repo, path)
    finally
        close(repo)
    end
end
with_repo_access(f::Function, s::String) = (println(s); with_repo_access(f))

function with_tmp_repo_access(f::Function)
    tmp_dir  = mktempdir()
    repo_dir = joinpath(TESTDIR, "fixtures", "testrepo.git", ".")
    run(`git clone --quiet -- $repo_dir $tmp_dir`)
    repo = GitRepo(tmp_dir)
    try
        f(repo, tmp_dir)
    finally
        close(repo)
        @unix_only rm(tmp_dir, recursive=true)
    end
end
with_tmp_repo_access(f::Function, s::String) = (println(s); with_tmp_repo_access(f))
