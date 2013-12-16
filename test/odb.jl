# create a repo with a README file
cleanup_dir(p) = begin
    if isdir(p)
        run(`rm -f -R $p`)
    end
end

# ------------------------------------
# Tests adapted from Git2Go Library
# ------------------------------------
test_path = joinpath(pwd(), "testrepo")
try
    repo = create_test_repo(test_path)
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
    @test eid == oid(stream)

catch err
    rethrow(err)
finally
    cleanup_dir(test_path)
end

# -----------------------------------------
# Tests adapted from Ruby's Rugged Library
# -----------------------------------------
