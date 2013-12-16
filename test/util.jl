using LibGit2

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

# Reuse the Rugged (Ruby Libgit2) Testing framework

module SandBoxedTest
    
    const PKGDIR = Pkg.dir("LibGit2")
    const TESTDIR = joinpath(PKGDIR, "test")
    const LIBGIT2_FIXTURE_DIR = joinpath(PKGDIR, "vendor/libgit2/test/resources")
    
    path = nothing
    repo = nothing

    function setup()
        global path
        tmp_dir = mktempdir()
        tmp_repo = joinpath(tmp_dir, "LibGit2_jl_SandBoxTest")
        run(`mkdir -v $tmp_repo`)
        path = tmp_repo
        return path
    end

    function teardown()
        global path
        if isdir(path)
            run(`rm -v -f -r $path`)
        end
    end

    function init(repo_name)
        global path
        global repo
        fixture_repo_path = joinpath(LIBGIT2_FIXTURE_DIR, repo_name)
        run(`cp -v -r $fixture_repo_path $path`)
        sandbox_repo_path = joinpath(path, repo_name)
        run(`cd $sandbox_repo_path`)
        filename = joinpath(sandbox_repo_path, ".gitted")
        if isfile(filename)
            newfilename = joinpath(sandbox_repo_path, ".git")
            run(`mv -v $filename $newfilename`)
        end
        filename = joinpath(sandbox_repo_path, "gitattributes")
        if isfile(filename)
            newfilename = joinpath(sandbox_repo_path, ".gitattributes")
            run(`mv -v $filename $newfilename`)
        end
        filename = joinpath(sandbox_repo_path, "gitignore")
        if isfile(filename)
            newfilename = joinpath(sandbox_repo_path, ".gitignore")
            run(`mv -v $filename $newfilename`)
        end
        repo = LibGit2.Repository(sandbox_repo_path)
        return repo
    end

    function clone(repo_path, name)
        global path
        orig_dir = pwd()
        cd(path)
        #TODO: use reference?
        #git clone --quiet -- 
        run(`git clone -- $repo_path $new_name`)
        cd(orig_dir)
        return LibGit2.Repository(joinpath(path, name))
    end

end

macro sandboxed_test(body)
    quote
        SandBoxedTest.setup()
        SandBoxedTest.init("testrepo.git")
        test_repo = SandBoxedTest.repo
        test_repo_path = SandBoxedTest.path
        try
            $body
        catch err
            rethrow(err)
        finally
            close(test_repo)
            SandBoxedTest.teardown()
        end
    end
end

            
module RepoAccess
    import LibGit2

    const TESTDIR = joinpath(Pkg.dir("LibGit2"), "test")
    path = nothing
    repo = nothing

    function setup()
        global path
        global repo
        repo_dir = joinpath(TESTDIR, "fixtures/testrepo.git")
        path = repo_dir 
        repo = LibGit2.Repository(repo_dir)
    end
end

macro with_repo_access(body)
    quote
        RepoAccess.setup()
        let test_repo_path = RepoAccess.path, 
            test_repo  = RepoAccess.repo
            $body
        end
    end
end


module TmpRepoAccess
    import LibGit2
    
    const TESTDIR = joinpath(Pkg.dir("LibGit2"), "test")
    path = nothing
    repo = nothing
    
    function setup()
        global path
        global repo
        tmpdir = mktempdir()
        repo_dir = joinpath(TESTDIR, joinpath("fixtures", "testrepo.git", "."))
        run(`git clone --quiet  -- $repo_dir $tmpdir`)
        path = tmpdir
        repo = LibGit2.Repository(tmpdir)
    end

    function teardown()
        global path
        global repo
        close(repo)
        Base.gc()
        run(`rm -r -f $(path)`)
    end
end

macro with_tmp_repo_access(body)
    quote
        TmpRepoAccess.setup()
        try
            test_repo_path = TmpRepoAccess.path
            test_repo = TmpRepoAccess.repo
            $body
        catch err
            rethrow(err)
        finally
            TmpRepoAccess.teardown()
        end
    end
end
