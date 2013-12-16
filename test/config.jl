# -----------------------------------------
# Tests adapted from Ruby's Rugged Library
# -----------------------------------------

#TODO: better way GitConfig(repo)?
@with_repo_access begin
    begin # test read config file
        cfg = config(test_repo)
        @test isa(cfg, GitConfig)
        @test cfg["core.bare"] == "false"
        @test cfg["not.exist"] == nothing
    end

    begin # test read from path
        cfg = GitConfig(joinpath(path(test_repo), "config"))
        @test isa(cfg, GitConfig)
        @test cfg["core.bare"] == "false"
    end

    begin # test read global config file
        cfg = global_config()
        @test cfg["user.name"] != nothing
        @test cfg["core.bare"] == nothing
    end
end

@with_tmp_repo_access begin
   begin # test write config values
       cfg = config(test_repo)
       cfg["custom.value"] = "my value"

       cfg2 = config(test_repo)
       @test cfg2["custom.value"] == "my value"

       content = open(readall, joinpath(path(test_repo), "config"))
       @test match(r"value = my value", content) != nothing
   end

   begin # test delete config values
        cfg = config(test_repo)
        delete!(cfg, "core.bare")
        cfg2 = config(test_repo)
        @test cfg2["core.bare"] == nothing
    end
end
