@with_repo_access begin
      # commit
    @test_throws lookup_blob(test_repo, Oid("8496071c1b46c854b31185ea97743be6a8774479"))
      # tag
    @test_throws lookup_blob(test_repo, Oid("0c37a5391bbff43c37f0d0371823a5509eed5b1d"))
      # tree
    @test_throws lookup_blob(test_repo, Oid("c4dc1555e4d4fa0e0c9c3fc46734c7c35b3ce90b"))
end


@with_repo_access begin
    begin :test_read_blob_data
        id = Oid("fa49b077972391ad58037050f2a75f74e3671e92")
        b = lookup(test_repo, id)
        @test sizeof(b) == 9 
        @test raw_content(b) == "new file\n"
        @test isa(b, GitBlob)
        @test oid(b) == id
        @test text(b) == "new file\n"
    end

    begin :test_blob_sloc
        id = Oid("7771329dfa3002caf8c61a0ceb62a31d09023f37")
        b = lookup(test_repo, id)
        @test sloc(b) == 328
    end

    begin :test_blob_content_with_size
        id = Oid("7771329dfa3002caf8c61a0ceb62a31d09023f37")
        b = lookup(test_repo, id)
        c =  raw_content(b, 10)
        @test c == "# Rugged\n*"
        @test sizeof(c) == 10
    end

    begin :test_blob_content_with_size_gt_file_size
        id = Oid("7771329dfa3002caf8c61a0ceb62a31d09023f37")
        b = lookup(test_repo, id)
        c =  raw_content(b, 1000000)
        @test sizeof(b) == sizeof(c)
    end

    begin :test_blob_content_with_zero_size
        id = Oid("7771329dfa3002caf8c61a0ceb62a31d09023f37")
        b = lookup(test_repo, id)
        c =  raw_content(b, 0)
        @test c == ""
    end

    begin :test_blob_content_with_negative_size
        id = Oid("7771329dfa3002caf8c61a0ceb62a31d09023f37")
        b = lookup(test_repo, id)
        c =  raw_content(b, -100)
        @test sizeof(b) == sizeof(c)
    end

    begin :test_blob_text_with_max_lines
        id = Oid("7771329dfa3002caf8c61a0ceb62a31d09023f37")
        blob = lookup(test_repo, id)
        @test text(blob, 1) == "# Rugged\n"
    end

    begin :test_blob_text_with_lines_gt_file_lines
        id = Oid("7771329dfa3002caf8c61a0ceb62a31d09023f37")
        b = lookup(test_repo, id)
        txt = text(b, 1000000)
        @test length(split(txt, "\n")) - 1 == 464
    end

    begin :test_blob_text_with_zero_lines
        id = Oid("7771329dfa3002caf8c61a0ceb62a31d09023f37")
        b = lookup(test_repo, id)
        txt = text(b, 0)
        @test txt == "" 
    end

    begin :test_blob_text_with_negative_lines
        id = Oid("7771329dfa3002caf8c61a0ceb62a31d09023f37")
        b = lookup(test_repo, id)
        txt = text(b, -100)
        @test length(split(txt, "\n")) - 1 == 464 
    end

    begin :test_blob_text_default_encoding
        id = Oid("7771329dfa3002caf8c61a0ceb62a31d09023f37")
        b = lookup(test_repo, id)
        #Encoding.default_external, blob.text.encoding
    end

   begin :test_blob_text_set_encoding
        id = Oid("7771329dfa3002caf8c61a0ceb62a31d09023f37")
        b = lookup(test_repo, id)
#        assert_equal Encoding::ASCII_8BIT, blob.text(0, Encoding::ASCII_8BIT).encoding
    end
end

# test write blob data
@with_tmp_repo_access begin
    @test blob_from_buffer(test_repo, "a new blob content") == 
          Oid("1d83f106355e4309a293e42ad2a2c4b8bdbe77ae")
end

# test_write_blob_from_workdir
@with_tmp_repo_access begin
    @test Oid("1385f264afb75a56a5bec74243be9b367ba4ca08") == 
      blob_from_workdir(test_repo, "README")
end

# test_write_blob_from_disk
@with_tmp_repo_access begin
    file_path = joinpath(TESTDIR, joinpath("fixtures", "archive.tar.gz"))
    @test isfile(file_path)
    id = blob_from_disk(test_repo, file_path)
    @test isa(id, Oid)
    b = lookup(test_repo, id)
    fh = open(file_path, "r")
    c = readall(fh)
    rc = raw_content(b)
    @test length(c) == length(rc)
    for i in length(c)
        @assert c[i] == rc[i]
    end
    close(fh)
end

# test_blob_is_binary
@with_tmp_repo_access begin
    binary_file_path = joinpath(TESTDIR, joinpath("fixtures", "archive.tar.gz"))
    binary_blob = lookup(test_repo, blob_from_disk(test_repo, binary_file_path))
    @test isbinary(binary_blob) == true

    text_file_path = joinpath(TESTDIR, joinpath("fixtures", "text_file.md"))
    text_blob = lookup(test_repo, blob_from_disk(test_repo, text_file_path))
    @test isbinary(text_blob) == false
end

#TODO: blob diff 
#TODO; blob io
