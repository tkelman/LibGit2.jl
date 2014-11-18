with_repo_access() do test_repo, path
    context("test packfile object exists") do
        @test exists(test_repo, Oid("41bc8c69075bbdb46c5c6f0566cc8cc5b46e8bd9"))
        @test exists(test_repo, Oid("f82a8eb4cb20e88d1030fd10d89286215a715396"))
    end

    context("test read packed object") do
        rawobj = read(test_repo, Oid("41bc8c69075bbdb46c5c6f0566cc8cc5b46e8bd9"))
        @test match(r"tree f82a8eb4cb20e88d1030fd10d89286215a715396", data(rawobj)) != nothing
        @test length(rawobj) == 230
        @test isa(rawobj, OdbObject{GitCommit})
    end

    context("test read packed header") do
         h = read_header(test_repo, Oid("41bc8c69075bbdb46c5c6f0566cc8cc5b46e8bd9"))
         @test h[:nbytes] == 230
         @test h[:type] == GitCommit
    end
end
