using LibGit2

const PKGDIR = Pkg.dir("LibGit2")
const TESTDIR = joinpath(PKGDIR, "test")
const LIBGIT2_FIXTURE_DIR = joinpath(PKGDIR, "vendor/libgit2/tests/resources")


macro repo_clone_test(body)
    local tmp_dir = tempname()
    quote
        mkdir($tmp_dir)
        let tmppath = $tmp_dir
            source_path = joinpath(TESTDIR, "fixtures", "testrepo.git")
            try
               $body
            finally
               #run($(`rm -r -f $tmp_dir`))
           end
        end
    end
end

macro remote_transport_test(body)
    local tmp_dir = joinpath(tempname(), "dir")
    quote
        mkpath($tmp_dir)
        let test_repo = repo_init($tmp_dir, bare=false)
            test_repo_dir = joinpath(TESTDIR, joinpath("fixtures", "testrepo.git", "."))
            test_remote = remote_add!(test_repo, "origin", test_repo_dir)
            try
                $body
            finally
                close(test_repo)
                run($(`rm -r -f $tmp_dir`))
            end
        end
    end
end

macro with_test_index(body)
    quote
        let test_index_path = joinpath(TESTDIR, "fixtures/testrepo.git/index")
            test_index = GitIndex(test_index_path)
            $body
        end
    end
end

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
    repo::Repository
    torndown::Bool
end

function clone(sbt::SandBoxedTest, repo_path, new_path)
        orig_dir = pwd()
        cd(sbt.path)
        run(`git clone --quiet  -- $repo_path $new_path`)
        cd(orig_dir)
        return Repository(joinpath(sbt.path, new_path))
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
    repo = Repository(sandbox_repo_path)
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

macro sandboxed_test(reponame, body)
    quote
        sbt = setup(SandBoxedTest, $reponame)
        test_repo = sbt.repo
        test_repo_path = sbt.path
        try
            $body
        catch err
            rethrow(err)
        finally
            close(test_repo)
            teardown(sbt)
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

macro sandboxed_checkout_test(body)
    quote
        sbt = setup(SandBoxedTest, "testrepo")
        test_repo = sbt.repo
        test_clone = clone(sbt, "testrepo", "cloned_testrepo")
        _bare = setup(SandBoxedTest, "testrepo.git")
        test_bare = repo_init(repo_path(_bare.repo), bare=true)
        try
            $body
        finally
            close(test_repo)
            close(test_clone)
            close(test_bare)
            teardown(sbt)
            teardown(_bare)
        end
    end
end

type RepoAccess
    path::String
    repo::Repository
end

setup(::Type{RepoAccess}) = begin
    dir = joinpath(TESTDIR, "fixtures/testrepo.git")
    return RepoAccess(dir, Repository(dir))
end

macro with_repo_access(body)
    quote
        ra = setup(RepoAccess)
        let test_repo_path = ra.path, 
            test_repo  = ra.repo
            $body
        end
    end
end

type TmpRepoAccess
    path::String
    repo::Repository
    torndown::Bool
end

setup(::Type{TmpRepoAccess}) = begin
    tmpdir = mktempdir()
    repo_dir = joinpath(TESTDIR, joinpath("fixtures", "testrepo.git", "."))
    run(`git clone --quiet  -- $repo_dir $tmpdir`)
    ra = TmpRepoAccess(tmpdir, Repository(tmpdir), false)
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

macro with_tmp_repo_access(body)
    quote
        ra = setup(TmpRepoAccess)
        try
            test_repo = ra.repo
            test_repo_path = ra.path
            $body
        catch err
            rethrow(err)
        finally
            teardown(ra)
        end
    end
end
