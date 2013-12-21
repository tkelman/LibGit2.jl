@with_repo_access begin
    
    begin # test read note for object
        id = Oid("36060c58702ed4c2a40832c51758d5344201d89a")
        obj = lookup(test_repo, id)
        n = notes(obj)
        @test message(n) == "note text\n" 
        @test oid(n) == Oid("94eca2de348d5f672faf56b0decafa5937e3235e")
    end

    begin # test read note for object from ref
        id = Oid("36060c58702ed4c2a40832c51758d5344201d89a")
        obj = lookup(test_repo, id)
        n = notes(obj, "refs/notes/commits")
        @test message(n) == "note text\n" 
        @test oid(n) == Oid("94eca2de348d5f672faf56b0decafa5937e3235e")
    end

    begin # test_object_without_note
        id = Oid("8496071c1b46c854b31185ea97743be6a8774479")
        obj = lookup(test_repo, id)
        @test notes(obj) == nothing
    end

    begin # test_nil_ref_lookup
        id = Oid("36060c58702ed4c2a40832c51758d5344201d89a")
        obj = lookup(test_repo, id)
        @test notes(obj, "refs/notes/missing") == nothing
    end

    begin # iterate over notes
    end

    begin # test each note iterable
    end

    begin # test default ref
        @test note_default_ref(test_repo) == "refs/notes/commits"
    end
end

