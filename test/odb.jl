# create a repo with a README file
cleanup_dir(p) = begin
    if isdir(p)
        run(`rm -f -R $p`)
    end
end

# ------------------------------------
# Tests adapted from Git2Go Library
# ------------------------------------
context("odb test") do 
    test_path = joinpath(pwd(), "testrepo")
    repo = create_test_repo(test_path)
    try
        cid, tid = seed_test_repo(repo)

        str = "hello, world!"
        odb = repo_odb(repo)
        stream = open_wstream(GitBlob, odb, length(str))
        @test iswriteable(stream)
        @test isreadable(stream) == false
        n = write(stream, str)
        @test n == length(str)
        close(stream)

        eid = Oid("30f51a3fba5274d53522d0f19748456974647b4f")
        @test eid == Oid(stream)
    finally
        close(repo)
        cleanup_dir(test_path)
    end
end
