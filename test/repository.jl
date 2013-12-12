# create bare repo
#TODO: relative repo paths..
const test_repo_path = joinpath(pwd(), "repo")

function cleanup_repo(path)
    p = abspath(path)
    if isdir(p)
        run(`rm -R $p`)
    end
end

cleanup_repo(test_repo_path)

# test creating bare repository
repo_init(test_repo_path; bare=true)
let repo = Repository(test_repo_path)
    @test isa(repo, Repository)
    @test repo_isbare(repo)
    @test repo_isempty(repo)
end
cleanup_repo(test_repo_path)

# test creating repository
#TODO: more tests for relative path repo creation
repo_init(test_repo_path)
let repo = Repository(test_repo_path)
    @test isa(repo, Repository)
    @test !(repo_isbare(repo))
    @test repo_isempty(repo)
    @test repo_workdir(repo) == abspath(test_repo_path)
    @test repo_path(repo) == joinpath(test_repo_path, ".git")

    # empty repo has no head
    @test head(repo) == nothing
    # empty repo has no tags
    @test tags(repo) == nothing
    # empty repo has no commits
    @test commits(repo) == nothing
    # empty repo has no references
    @test references(repo) == nothing
end
cleanup_repo(test_repo_path)



