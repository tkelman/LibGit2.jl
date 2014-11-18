with_repo_access() do test_repo, path
    context("test read note for object") do
        id = Oid("36060c58702ed4c2a40832c51758d5344201d89a")
        obj = test_repo[id]
        n = notes(obj)
        @test message(n) == "note text\n"
        @test Oid(n) == Oid("94eca2de348d5f672faf56b0decafa5937e3235e")
    end

    context("test read note for object from ref") do
        id = Oid("36060c58702ed4c2a40832c51758d5344201d89a")
        obj = test_repo[id]
        n = notes(obj, "refs/notes/commits")
        @test message(n) == "note text\n"
        @test Oid(n) == Oid("94eca2de348d5f672faf56b0decafa5937e3235e")
    end

    context("test object without note") do
        id = Oid("8496071c1b46c854b31185ea97743be6a8774479")
        obj = test_repo[id]
        @test notes(obj) == nothing
    end

    context("test nothing ref lookup") do
        id = Oid("36060c58702ed4c2a40832c51758d5344201d89a")
        obj = test_repo[id]
        @test notes(obj, "refs/notes/missing") == nothing
    end

    context("test iterate over notes") do
        n = 0
        for (note, oid) in foreach(GitNote, test_repo, "refs/notes/commits")
            n += 1
            @test message(note) == "note text\n"
            @test oid == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
        end
        @test n == 1
    end

    context("test each note iterable") do
        @test isa(foreach(GitNote, test_repo, "refs/notes/commits"), LibGit2.NoteIterator)
    end

    context("test default ref") do
        @test note_default_ref(test_repo) == "refs/notes/commits"
    end
end

with_tmp_repo_access("test create note") do test_repo, path
    sig = Signature("Julia", "julia@julia.com")
    id = Oid("8496071c1b46c854b31185ea97743be6a8774479")
    msg = "This is the note message\n\nThis note is created from Rugged"
    obj = test_repo[id]

    note_id = create_note!(obj, msg, committer=sig, author=sig, ref="refs/notes/test")

    @test note_id == Oid("38c3a690c474d8dcdb13088205a464a60312eec4")
    # note is actually a blob
    blob = test_repo[note_id]
    @test Oid(blob) == note_id
    @test bytestring(blob) == msg
    @test isa(blob, GitBlob)

    n = notes(obj, "refs/notes/test")
    @test Oid(n) == note_id
    @test message(n) == msg
end

with_tmp_repo_access("test create note without signature") do test_repo, path
    testname = "Julia"
    testemail = "julia@julia.com"
    GitConfig(test_repo)["user.name"] = testname
    GitConfig(test_repo)["user.email"] = testemail

    id = Oid("8496071c1b46c854b31185ea97743be6a8774479")
    msg ="This is the note message\n\nThis note is created from Rugged"
    obj = test_repo[id]

    note_id = create_note!(obj, msg, ref="refs/notes/test")

    @test note_id == Oid("38c3a690c474d8dcdb13088205a464a60312eec4")
    note_ref = lookup_ref(test_repo, "refs/notes/test")
    note_commit = test_repo[target(note_ref)]

    @test testname == committer(note_commit).name
    @test testemail == committer(note_commit).email
    @test testname == author(note_commit).name
    @test testemail == author(note_commit).email
end

with_tmp_repo_access("test create note on object with notes raises exception") do test_repo, path
    sig = Signature("Julia", "julia@julia.com")
    id  = Oid("8496071c1b46c854b31185ea97743be6a8774479")
    msg = "This is the note message\n\nThis note is created from Rugged"
    obj = test_repo[id]

    create_note!(obj, msg, committer=sig, author=sig, ref="refs/notes/test")
    @test_throws LibGitError{:Repo,:Exists} create_note!(obj, msg, committer=sig, author=sig, ref="refs/notes/test")
end

with_tmp_repo_access("test overwrite object note") do test_repo, path
    sig = Signature("Julia", "julia@julia.com")
    id = Oid("8496071c1b46c854b31185ea97743be6a8774479")
    msg ="This is the note message\n\nThis note is created from Rugged"
    obj = test_repo[id]

    create_note!(obj, msg, committer=sig, author=sig, ref="refs/notes/test")
    create_note!(obj, "new msg", committer=sig, author=sig, ref="refs/notes/test", force=true)
    note = notes(obj, "refs/notes/test")
    @test message(note) == "new msg"
end

with_tmp_repo_access("test remove note") do test_repo, path
    id = Oid("36060c58702ed4c2a40832c51758d5344201d89a")
    sig = Signature("Julia", "julia@julia.com")
    msg ="This is the note message\n\nThis note is created from Rugged"
    obj = test_repo[id]

    create_note!(obj, msg, author=sig, committer=sig, ref="refs/notes/test")

    @test remove_note!(obj, committer=sig, author=sig, ref="refs/notes/test") == true
    @test notes(obj, "refs/notes/test") == nothing
end

with_tmp_repo_access("test remote without signature") do test_repo, path
    testname = "Julia"
    testemail = "rugged@example.com"
    GitConfig(test_repo)["user.name"] = testname
    GitConfig(test_repo)["user.email"] = testemail
    id = Oid("36060c58702ed4c2a40832c51758d5344201d89a")

    msg ="This is the note message\n\nThis note is created from Rugged"
    obj = test_repo[id]

    create_note!(obj, msg, ref="refs/notes/test")
    create_note!(obj, msg)

    @test remove_note!(obj, ref="refs/notes/test")
    @test remove_note!(obj)
    @test notes(obj, "refs/notes/test") == nothing
    @test notes(obj) == nothing
end

with_tmp_repo_access("test remove missing note") do test_repo, path
    sig = Signature("Julia", "julia@julia.com")
    id = Oid("36060c58702ed4c2a40832c51758d5344201d89a")
    obj = test_repo[id]
    @test remove_note!(obj, committer=sig, author=sig, ref="refs/notes/test") == false
end
