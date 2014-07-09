# -----------------------------------------
# Tests adapted from Ruby's Rugged Library
# -----------------------------------------
with_repo_access() do test_repo, test_repo_path
    context("test read config file") do
        cfg = GitConfig(test_repo)
        @test isa(cfg, GitConfig)
        @test cfg["core.bare"] == "false"
        @test cfg["not.exist"] == nothing
    end

    context("test read from path") do
        cfg = GitConfig(joinpath(path(test_repo), "config"))
        @test isa(cfg, GitConfig)
        @test cfg["core.bare"] == "false"
    end

    context("test read global config file") do
        cfg = global_config()
        @test isa(cfg, GitConfig)
        @test cfg["user.name"] != nothing
        @test cfg["core.bare"] == nothing
    end
end

with_tmp_repo_access() do test_repo, test_repo_path
   context("test write config values") do
       cfg = GitConfig(test_repo)
       cfg["custom.value"] = "my value"

       cfg2 = GitConfig(test_repo)
       @test cfg2["custom.value"] == "my value"

       content = open(readall, joinpath(path(test_repo), "config"))
       @test match(r"value = my value", content) != nothing
   end

   context("test delete config values") do
        cfg = GitConfig(test_repo)
        delete!(cfg, "core.bare")
        cfg2 = GitConfig(test_repo)
        @test cfg2["core.bare"] == nothing
    end
end
