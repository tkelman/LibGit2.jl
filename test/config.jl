# -----------------------------------------
# Tests adapted from Ruby's Rugged Library
# -----------------------------------------

#TODO: better way GitConfig(repo)?
with_repo_access() do test_repo, path
    context("test read config file") do
        cfg = config(test_repo)
        @test isa(cfg, GitConfig)
        @test cfg["core.bare"] == "false"
        @test cfg["not.exist"] == nothing
    end

    context("test read from path") do
        cfg = GitConfig(joinpath(LibGit2.path(test_repo), "config"))
        @test isa(cfg, GitConfig)
        @test cfg["core.bare"] == "false"
    end

    context("test read global config file") do
        cfg = global_config()
        @test cfg["user.name"] != nothing
        @test cfg["core.bare"] == nothing
    end
end

with_tmp_repo_access() do test_repo, path
   context("test write config values") do
       cfg = config(test_repo)
       cfg["custom.value"] = "my value"

       cfg2 = config(test_repo)
       @test cfg2["custom.value"] == "my value"

       content = open(readall, joinpath(LibGit2.path(test_repo), "config"))
       @test match(r"value = my value", content) != nothing
   end

   context("test delete config values") do
        cfg = config(test_repo)
        delete!(cfg, "core.bare")
        cfg2 = config(test_repo)
        @test cfg2["core.bare"] == nothing
    end
end
