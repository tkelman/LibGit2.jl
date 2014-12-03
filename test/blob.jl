with_repo_access("test lookup fails with wrong git obj") do test_repo, path
    # commit
    @test_throws LibGitError{:Invalid,:NotFound} lookup_blob(test_repo,
                                                    Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    # tag
    @test_throws LibGitError{:Invalid,:NotFound} lookup_blob(test_repo,
                                                    Oid("0c37a5391bbff43c37f0d0371823a5509eed5b1d"))
    # tree
    @test_throws LibGitError{:Invalid,:NotFound} lookup_blob(test_repo,
                                                    Oid("c4dc1555e4d4fa0e0c9c3fc46734c7c35b3ce90b"))
end

with_repo_access() do test_repo, path

    context("test read blob data")  do
        id = Oid("fa49b077972391ad58037050f2a75f74e3671e92")
        b = lookup(test_repo, id)
        @test sizeof(b) == 9
        @test bytestring(b) == "new file\n"
        @test isa(b, GitBlob)
        @test Oid(b) == id
        @test text(b) == "new file\n"
    end

    context("test blob sloc") do
        id = Oid("7771329dfa3002caf8c61a0ceb62a31d09023f37")
        b = lookup(test_repo, id)
        @test sloc(b) == 328
    end

    context("test blob content with size") do
        id = Oid("7771329dfa3002caf8c61a0ceb62a31d09023f37")
        b = lookup(test_repo, id)
        c =  rawcontent(b, 10)
        @test c == convert(Vector{UInt8}, "# Rugged\n*")
        @test sizeof(c) == 10
    end

    context("test blob content with size gt file size") do
        id = Oid("7771329dfa3002caf8c61a0ceb62a31d09023f37")
        b = lookup(test_repo, id)
        c =  rawcontent(b, 1000000)
        @test sizeof(b) == sizeof(c)
    end

    context("test blob content with zero size") do
        id = Oid("7771329dfa3002caf8c61a0ceb62a31d09023f37")
        b = lookup(test_repo, id)
        c =  rawcontent(b, 0)
        @test isempty(c)
    end

    context("test blob content with negative size") do
        id = Oid("7771329dfa3002caf8c61a0ceb62a31d09023f37")
        b = lookup(test_repo, id)
        c =  rawcontent(b, -100)
        @test sizeof(b) == sizeof(c)
    end

    context("test blob text with max lines") do
        id = Oid("7771329dfa3002caf8c61a0ceb62a31d09023f37")
        blob = lookup(test_repo, id)
        @test text(blob, 1) == "# Rugged\n"
    end

    context("test blob text with lines gt file lines") do
        id = Oid("7771329dfa3002caf8c61a0ceb62a31d09023f37")
        b = lookup(test_repo, id)
        txt = text(b, 1000000)
        @test length(split(txt, "\n")) - 1 == 464
    end

    context("test blob text with zero lines") do
        id = Oid("7771329dfa3002caf8c61a0ceb62a31d09023f37")
        b = lookup(test_repo, id)
        txt = text(b, 0)
        @test txt == ""
    end

    context("test blob text with negative lines") do
        id = Oid("7771329dfa3002caf8c61a0ceb62a31d09023f37")
        b = lookup(test_repo, id)
        txt = text(b, -100)
        @test length(split(txt, "\n")) - 1 == 464
    end

    #= TODO: blob encoding
    begin :test_blob_text_default_encoding
        id = Oid("7771329dfa3002caf8c61a0ceb62a31d09023f37")
        b = lookup(test_repo, id)
    end

    begin :test_blob_text_set_encoding
        id = Oid("7771329dfa3002caf8c61a0ceb62a31d09023f37")
        b = lookup(test_repo, id)
    end
    =#
end


with_tmp_repo_access("test write blob data") do test_repo, path
    @test blob_from_buffer(test_repo, "a new blob content") ==
          Oid("1d83f106355e4309a293e42ad2a2c4b8bdbe77ae")
end

with_tmp_repo_access("test write blob from workdir") do test_repo, path
    @test Oid("1385f264afb75a56a5bec74243be9b367ba4ca08") ==
      blob_from_workdir(test_repo, "README")
end

with_tmp_repo_access("test write blob from disk") do test_repo, path
    file_path = joinpath(TESTDIR, joinpath("fixtures", "archive.tar.gz"))
    @test isfile(file_path)
    id = blob_from_disk(test_repo, file_path)
    @test isa(id, Oid)
    b = test_repo[id]
    open(file_path, "r") do io
        c,rc  = readbytes(io), rawcontent(b)
        @test length(c) == length(rc)
        for i in length(c)
            @assert c[i] == rc[i]
        end
    end
end

with_tmp_repo_access("test blob is binary") do test_repo, path
    binary_file_path = joinpath(TESTDIR, joinpath("fixtures", "archive.tar.gz"))
    binary_blob = lookup(test_repo, blob_from_disk(test_repo, binary_file_path))
    @test isbinary(binary_blob) == true

    text_file_path = joinpath(TESTDIR, joinpath("fixtures", "text_file.md"))
    text_blob = lookup(test_repo, blob_from_disk(test_repo, text_file_path))
    @test isbinary(text_blob) == false
end


# test blob diff
sandboxed_test("diff") do test_repo, path
    t1 = GitTree(lookup(test_repo, Oid("d70d245ed97ed2aa596dd1af6536e4bfdb047b69")))
    t2 = GitTree(lookup(test_repo, Oid("7a9e0b02e63179929fed24f0a3e0f19168114d10")))

    b = lookup(test_repo, Oid(t1["readme.txt"]))
    o = lookup(test_repo, Oid(t2["readme.txt"]))
    p = diff(test_repo, b, o)

    @test delta(p).status == :modified

    hs = hunks(p)
    @test length(hs) == 3

    @test beginswith(hs[1].header, "@@ -1,4 +1,4 @@")
    @test beginswith(hs[2].header, "@@ -7,10 +7,6 @@")
    @test beginswith(hs[3].header, "@@ -24,12 +20,9 @@")

    ls = lines(hs[1])
    @test length(ls) == 5
    @test :deletion == ls[1].line_origin
    @test "The Git feature that really makes it stand apart from nearly every other SCM\n" == ls[1].content

    @test :addition == ls[2].line_origin
    @test "The Git feature that r3ally mak3s it stand apart from n3arly 3v3ry other SCM\n" == ls[2].content

    @test :context == ls[3].line_origin
    @test "out there is its branching model.\n" == ls[3].content

    @test :context == ls[4].line_origin
    @test "\n" == ls[4].content

    @test :context == ls[5].line_origin
    @test "Git allows and encourages you to have multiple local branches that can be\n" == ls[5].content
end

sandboxed_test("diff", "test diff nothing") do test_repo, path
    t1 = GitTree(lookup(test_repo, Oid("d70d245ed97ed2aa596dd1af6536e4bfdb047b69")))
    b  = lookup(test_repo, Oid(t1["readme.txt"]))
    p  = diff(test_repo, b, nothing)

    @test delta(p).status == :deleted

    hs = hunks(p)
    @test length(hs) == 1

    @test beginswith(first(hs).header, "@@ -1,35 +0,0 @@")
    ls = lines(first(hs))

    @test length(ls) == 35
    for l in ls
      @test l.line_origin == :deletion
    end
end

sandboxed_test("diff", "test diff with paths") do test_repo, path
    t1 = GitTree(lookup(test_repo, Oid("d70d245ed97ed2aa596dd1af6536e4bfdb047b69")))
    t2 = GitTree(lookup(test_repo, Oid("7a9e0b02e63179929fed24f0a3e0f19168114d10")))

    b = lookup(test_repo, Oid(t1["readme.txt"]))
    o = lookup(test_repo, Oid(t2["readme.txt"]))
    p = diff(test_repo, b, o, Dict{Any,Any}(:old_path => "old_readme.txt", :new_path => "new_readme.txt"))

    @test "old_readme.txt" == delta(p).old_file.path
    @test "new_readme.txt" == delta(p).new_file.path
end

with_tmp_repo_access("test write blob from io with hintpath") do test_repo, path
    file_path = joinpath(TESTDIR, joinpath("fixtures", "archive.tar.gz"))
    open(file_path, "r") do io
        id = blob_from_stream(test_repo, io, "archive.tar.gz2")
        seekstart(io)
        blob = lookup(test_repo, id)
        c,rc = readbytes(io), rawcontent(blob)
        @test length(c) == length(rc)
        for i in length(rc)
            @assert c[i] == rc[i]
        end
    end
end

with_tmp_repo_access("test write blob from io without hintpath") do test_repo, path
    file_path = joinpath(TESTDIR, joinpath("fixtures", "archive.tar.gz"))
    open(file_path, "r") do io
        id = blob_from_stream(test_repo, io)
        seekstart(io)
        blob = lookup(test_repo, id)
        c,rc = readbytes(io), rawcontent(blob)
        @test length(c) == length(rc)
        for i in length(rc)
            @assert c[i] == rc[i]
        end
    end
end
