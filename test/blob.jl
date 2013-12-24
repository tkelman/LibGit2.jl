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


