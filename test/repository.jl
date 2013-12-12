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
#TODO: more tests for relative repo creation
repo_init(test_repo_path)
let repo = Repository(test_repo_path)
    @test isa(repo, Repository)
    @test !(repo_isbare(repo))
    @test repo_isempty(repo)
    @show repo_workdir(repo)
    @show repo_path(repo) 
    @show test_repo_path
    @test repo_workdir(repo) == abspath(test_repo_path)
    @test repo_path(repo) == joinpath(test_repo_path, ".git")
end
cleanup_repo(test_repo_path)



