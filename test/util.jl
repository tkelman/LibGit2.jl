using LibGit2

const PKGDIR = Pkg.dir("LibGit2")
const TESTDIR = joinpath(PKGDIR, "test")
const LIBGIT2_FIXTURE_DIR = joinpath(PKGDIR, "vendor/libgit2/tests/resources")

context(f::Function) = f()
context(f::Function, s::String) = (println(s); context(f))

function remote_transport_test(f::Function) 
    local tmp_dir = joinpath(tempname(), "dir")
    mkpath(tmp_dir)
    test_repo = repo_init(tmp_dir, bare=false)
    test_repo_dir = joinpath(TESTDIR, joinpath("fixtures", "testrepo.git", "."))
    try
        test_remote = remote_add!(test_repo, "origin", test_repo_dir)
        f(test_repo, test_remote)
    finally
        close(test_repo)
        run(`rm -r -f $tmp_dir`)
    end
end 
remote_transport_test(f::Function, s::String) = (println(s); remote_transport_test(f))


function with_test_index(f::Function)
    try
        test_index_path = joinpath(TESTDIR, "fixtures/testrepo.git/index")
        test_index = GitIndex(test_index_path)
        f(test_index, test_index_path)
    finally
    end
end 
with_test_index(f::Function, s::String) = (println(s); with_test_index(f))

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
    idx = GitIndex(repo)
    add!(idx, "README")
    tree_id = write_tree!(idx)

    msg = "This is a commit\n"
    tree = lookup(GitTree, repo, tree_id)
    commit_id = commit(repo, "HEAD", sig, sig, msg, tree)
    return commit_id, tree_id
end

# Reuse the Rugged (Ruby Libgit2) Testing framework

type SandBoxedTest
    path::String
    repo::GitRepo
    torndown::Bool
end

function clone(sbt::SandBoxedTest, repo_path, new_path)
        orig_dir = pwd()
        cd(sbt.path)
        run(`git clone --quiet  -- $repo_path $new_path`)
        cd(orig_dir)
        return GitRepo(joinpath(sbt.path, new_path))
end

function setup(::Type{SandBoxedTest}, repo_name::String)
    tmpdir = mktempdir()
    repo_dir = joinpath(tmpdir, "LibGit2_jl_SandBoxTest")
    run(`mkdir $repo_dir`)
    
    fixture_repo_path = joinpath(LIBGIT2_FIXTURE_DIR, repo_name)
    run(`cp -r $fixture_repo_path $repo_dir`)
    sandbox_repo_path = joinpath(repo_dir, repo_name)
    origdir = pwd()
    cd(sandbox_repo_path)
    dirname = joinpath(sandbox_repo_path, ".gitted")
    if isdir(dirname)
        newdirname = joinpath(sandbox_repo_path, ".git")
        run(`mv $dirname $newdirname`)
    end 
    filename = joinpath(sandbox_repo_path, "gitattributes")
    if isfile(filename)
        newfilename = joinpath(sandbox_repo_path, ".gitattributes")
        run(`mv $filename $newfilename`)
    end
    filename = joinpath(sandbox_repo_path, "gitignore")
    if isfile(filename)
        newfilename = joinpath(sandbox_repo_path, ".gitignore")
        run(`mv $filename $newfilename`)
    end
    cd(origdir)
    repo = GitRepo(sandbox_repo_path)
    sbt = SandBoxedTest(repo_dir, repo, false)
    finalizer(sbt, teardown)
    return sbt
end

function teardown(sbt::SandBoxedTest)
    if !sbt.torndown
        try
            run(`rm -r -f $(sbt.path)`)
        catch err
            rethrow(err)
        finally
            sbt.torndown = true
        end
    end
end

function sandboxed_test(f::Function, reponame::String)
    sbt = setup(SandBoxedTest, reponame)
    try
        f(sbt.repo, sbt.path)
    finally
        close(sbt.repo)
        teardown(sbt)
    end
end
sandboxed_test(f::Function, reponame::String, s::String) = (println(s); 
                                                            sandboxed_test(f, reponame))
function sandboxed_clone_test(f::Function, reponame::String)
    sbt = setup(SandBoxedTest, reponame)
    remote = sbt.repo
    repo = clone(sbt, reponame, splitext(reponame)[1]) 
    config(remote)["core.bare"] = true
    try
        f(repo, remote, sbt.path)
    finally
        close(repo)
        close(remote)
        teardown(sbt)
    end
end 
sandboxed_clone_test(f::Function, reponame::String, s::String) = (println(s); 
                                                                  sandboxed_clone_test(f, reponame))

function sandboxed_checkout_test(f::Function)
    sbt = setup(SandBoxedTest, "testrepo")
    test_repo  = sbt.repo
    test_clone = clone(sbt, "testrepo", "cloned_testrepo")
    bare = setup(SandBoxedTest, "testrepo.git")
    test_bare = repo_init(path(bare.repo), bare=true)
    try
        f(test_repo, test_clone, test_bare)
    finally
        close(test_repo)
        close(test_clone)
        close(test_bare)
        teardown(sbt)
        teardown(bare)
    end
end
sandboxed_checkout_test(f::Function, s::String) = (println(s); 
                                                   sandboxed_checkout_test(f))

type RepoAccess
    path::String
    repo::GitRepo
end

setup(::Type{RepoAccess}) = begin
    dir = joinpath(TESTDIR, "fixtures/testrepo.git")
    return RepoAccess(dir, GitRepo(dir))
end

function with_repo_access(f::Function)
    ra = setup(RepoAccess)
    try
        f(ra.repo, ra.path)
    finally
        close(ra.repo)
    end
end
with_repo_access(f::Function, s::String) = (println(s); with_repo_access(f))

type TmpRepoAccess
    path::String
    repo::GitRepo
    torndown::Bool
end

setup(::Type{TmpRepoAccess}) = begin
    tmpdir = mktempdir()
    repo_dir = joinpath(TESTDIR, joinpath("fixtures", "testrepo.git", "."))
    run(`git clone --quiet  -- $repo_dir $tmpdir`)
    ra = TmpRepoAccess(tmpdir, GitRepo(tmpdir), false)
    finalizer(ra, teardown)
    return ra
end

teardown(ra::TmpRepoAccess) = begin
    if !ra.torndown
        try
            close(ra.repo)
            Base.gc()
            run(`rm -r -f $(ra.path)`)
        catch err
            rethrow(err)
        finally
            ra.torndown = true
        end
    end
end

function with_tmp_repo_access(f::Function)
    ra = setup(TmpRepoAccess)
    try
        f(ra.repo, ra.path)
    finally
        teardown(ra)
    end
end
with_tmp_repo_access(f::Function, s::String) = (println(s); with_tmp_repo_access(f))
