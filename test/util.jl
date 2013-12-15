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
    
    function setup()
        tmp_dir = mktmpdir()
        tmp_repo = mkdir(joinpath(tmpdir, "LibGit2_jl_SandBox"))
        return tmp_repo
    end

    function teardown(sandbox_path)
        if isdir(sandbox_path)
            run(`rm -f -r $sandbox_path`)
        end
    end

    function init(sandbox_path, repo_name)
        fixture_repo_path = joinpath(SandBoxedTest.LIBGIT2_FIXTURE_DIR, repo_name)
        run(`cp -r $fixture_repo_path $sandbox_path`)
        sandbox_repo_path = joinpath(sandbox_path, repo_name)
        run(`cd $sandbox_repo_path`)
        filename = joinpath(sandbox_repo_path, ".gitted")
        if isfile(filename)
            newfilename = joinpath(sandbox_repo_path, ".git")
            run(`mv $filename $newfilename`)
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
        return Repository(sandbox_repo_path)
    end

    function clone(sandbox_path, repo_path, new_name)
        orig_dir = pwd()
        cd(sandbox_path)
        #TODO: use reference?
        #git clone --quiet -- 
        run(`git clone $repo_path $new_name`)
        cd(orig_dir)
        return Repository(joinpath(sandbox_path, name))
    end

    module RepoAccess
        path = nothing
        repo = nothing

        function setup()
            repo_dir = joinpath(SandBoxedTest.TESTDIR, "fixtures/testrepo.git")
            RepoAccess.path = repo_dir 
            RepoAccess.repo = Repository(RepoAccess.path)
        end
    end

    module TmpRepoAccess
        path = nothing
        repo = nothing
        
        function setup()
            tmpdir = mktmpdir()
            repo_dir = joinpath(SandBoxedTest.TESTDIR,
                                joinpath("fixtures", "testrepo.git", "."))
            TmpRepoAccess.path = repo_dir
            TmpRepoAccess.repo = Repository(repo_dir)
        end

        function teardown()
            close(TmpRepoAccess.repo)
            Base.gc()
            run(`rm -r -f $(TmpRepoAccess.path)`)
        end
    end
end
