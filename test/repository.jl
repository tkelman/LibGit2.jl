# create bare repo
test_repo_path = joinpath(pwd(), "TestLibGit2")

function cleanup_repo(path)
    p = abspath(path)
    if isdir(p)
        run(`rm -f -R $p`)
    end
end

function tmp_repo(body, tmp_path)
   cleanup_repo(tmp_path)
   try
        body()
   catch err
       cleanup_repo(tmp_path)
       rethrow(err)
   end
   cleanup_repo(tmp_path)
end

# test creating bare repository
tmp_repo(test_repo_path) do
    repo_init(test_repo_path; bare=true)
    let repo = Repository(test_repo_path)
        @test isa(repo, Repository)
        @test repo_isbare(repo)
        @test repo_isempty(repo)
    end
end

# test creating repository
tmp_repo(test_repo_path) do
    repo_init(test_repo_path)
    let repo = Repository(test_repo_path)
        @test isa(repo, Repository)
        @test !(repo_isbare(repo))
        @test repo_isempty(repo)
        @test repo_workdir(repo) == abspath(test_repo_path)
        @test repo_path(repo) == joinpath(test_repo_path, ".git")
        @test isa(repo_index(repo), Index)
        # empty repo has no head
        @test head(repo) == nothing
        # empty repo has no tags
        @test tags(repo) == nothing
        # empty repo has no commits
        @test commits(repo) == nothing
        # empty repo has no references
        @test references(repo) == nothing
    end

    # test if we can write to it...
    fh = open(joinpath(test_repo_path, "README"), "w")
    write(fh, "this is a test")
    close(fh)
end

#TODO: more tests for relative path repo creation
