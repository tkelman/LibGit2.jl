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

    begin # test object without note
    end

    begin # test nil reference lookup
    end

    begin # iterate over notes
    end

    begin # test default ref
    end
end

