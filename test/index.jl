# ------------------------------------
# Tests adapted from Git2Go Library
# ------------------------------------
context("test lookup tree") do
    test_path = joinpath(pwd(), "testrepo")
    repo = create_test_repo(test_path)
    try
        @test isdir(workdir(repo))
        idx = GitIndex(repo)
        @test isa(idx, GitIndex)
        push!(idx, "README")
        tree_id = write_tree!(idx)
        @test isa(tree_id, Oid)
        @test isequal(hex(tree_id), "b7119b11e8ef7a1a5a34d3ac87f5b075228ac81e")
        tree1 = lookup(GitTree, repo, tree_id)
        tree2 = lookup_tree(repo, tree_id)

        @test tree1 == tree2
        tree = tree1
        @test isa(tree, GitTree)
        @test tree.ptr != C_NULL
        @test isa(Oid(tree), Oid)
        @test isa(hex(tree), ASCIIString)
    finally
        close(repo)
        LibGit2.free!(repo)
        Base.gc()
        rm(test_path, recursive=true)
    end
end

# -----------------------------------------
# Tests adapted from Ruby's Rugged Library
# -----------------------------------------

function new_idx_entry()
    now = time()
    return GitIndexEntry("new_path",
                      Oid("d385f264afb75a56a5bec74243be9b367ba4ca08"),
                      now,
                      now,
                      1000,
                      234881027,
                      88888,
                      33188,
                      502,
                      502,
                      false,
                      3)
end

with_test_index("test index size") do test_index, path
    @test length(test_index) == 2
end

with_test_index("test empty index") do test_index, path
    clear!(test_index)
    @test length(test_index) == 0
end

with_test_index("test remove entries") do test_index, path
    remove!(test_index, "new.txt")
    @test length(test_index) == 1
end

with_test_index("test rmeove dir") do test_index, path
    removedir!(test_index, "does-not-exist")
    @test length(test_index) == 2

    removedir!(test_index, "", 2)
    @test length(test_index) == 2

    removedir!(test_index, "")
    @test length(test_index) == 0
end

with_test_index("test get entry data") do test_index, path
    entry = test_index[1]
    @test "README" == entry.path
    @test Oid("1385f264afb75a56a5bec74243be9b367ba4ca08") == Oid(entry)
    @test 1273360380 == int(entry.mtime)
    @test 1273360380 == int(entry.ctime)
    @test 4 == entry.file_size

    @test 234881026 == entry.dev
    @test 6674088 == entry.ino
    @test 33188 == entry.mode
    @test 501 == entry.uid
    @test 0 == entry.gid
    @test false == entry.valid
    @test 0 == entry.stage

    entry = test_index[2]
    @test "new.txt" == entry.path
    @test Oid("fa49b077972391ad58037050f2a75f74e3671e92") == Oid(entry)
end

with_test_index("test iterate entries") do test_index, path
    c = sort(collect(test_index), by=x->Oid(x))
    @test join(map(x->x.path, c), ":") == "README:new.txt"
end

with_test_index("test update entries") do test_index, path
    now = int(time())
    entry = test_index[1]
    Oid(entry) = Oid("12ea3153a78002a988bb92f4123e7e831fd1138a")
    entry.mtime = now
    entry.ctime = now
    entry.file_size = 1000
    entry.dev = 234881027
    entry.ino = 88888
    entry.mode = 33188
    entry.uid = 502
    entry.gid = 502
    entry.stage = 3
    push!(test_index, entry)
    newentry = test_index[entry.path, 3]
    @test isa(newentry, GitIndexEntry)
    #TODO: rounding in times causes this test to fail
    @test newentry == entry
end

with_test_index("test add new entries") do test_index, path
    push!(test_index, new_idx_entry())
    @test length(test_index) == 3
    c = sort(collect(test_index), by=x->Oid(x))
    @test join(map(x -> x.path, c), ":") == "README:new_path:new.txt"
end

with_test_index("test can write index") do test_index, path
    tmp_path, tmp_io = mktemp()
    try
        write(tmp_io, readall(path))
        close(tmp_io)
        test_index1 = GitIndex(tmp_path)

        entry = new_idx_entry()
        push!(test_index1, entry)
        entry.path = "else.txt"
        push!(test_index1, entry)
        write!(test_index1)

        test_index2 = GitIndex(tmp_path)
        c = sort(collect(test_index2), by=x->Oid(x))
        @test join(map(x -> x.path, c), ":") == "README:else.txt:new_path:new.txt"
        @test length(test_index2) == 4
    finally
        close(tmp_io)
        rm(tmp_path, recursive=true)
    end
end

context("test adding a path") do
    tmp_path = mktempdir()
    test_repo = init_repo(tmp_path, bare=false)
    try
        test_index1 = GitIndex(test_repo)
        fh = open(joinpath(tmp_path, "test.txt"), "w")
        write(fh, "test content")
        close(fh)
        push!(test_index1, "test.txt")
        write!(test_index1)

        test_index2 = GitIndex(joinpath(tmp_path, ".git", "index"))
        @test test_index2[1].path == "test.txt"
    finally
        close(test_repo)
        LibGit2.free!(test_repo)
        Base.gc()
        rm(tmp_path, recursive=true)
    end
end

context("test reloading index") do
    tmp_path = mktempdir()
    test_repo = init_repo(tmp_path, bare=false)
    try
        index = GitIndex(test_repo)
        fh = open(joinpath(tmp_path, "test.txt"), "w")
        write(fh, "test content")
        close(fh)
        push!(index, "test.txt")
        write!(index)

        rindex = GitIndex(joinpath(tmp_path, ".git", "index"))
        entry = rindex["test.txt"]
        @test entry.stage == 0

        push!(rindex, new_idx_entry())
        write!(rindex)

        @test length(index) == 1
        reload!(index)
        @test length(index) == 2

        entry = index["new_path", 3]
        @test entry.mode == 33188
    finally
        close(test_repo)
        LibGit2.free!(test_repo)
        Base.gc()
        rm(tmp_path, recursive=true)
    end
end

with_tmp_repo_access("test idempotent read write") do test_repo, path
    head_id = lookup_ref(test_repo, "HEAD") |> resolve |> target
    tree = GitTree(lookup(test_repo, head_id))
    index = GitIndex(test_repo)
    read_tree!(index, tree)

    index_tree_id = write_tree!(index)
    index_tree = test_repo[index_tree_id]
    @test Oid(index_tree) == Oid(tree)
end

with_tmp_repo_access("test build tree from index") do test_repo, path
    head_id = lookup_ref(test_repo,
                "refs/remotes/origin/packed") |> resolve |> target
    tree = GitTree(test_repo[head_id])
    index = GitIndex(test_repo)
    read_tree!(index, tree)
    remove!(index, "second.txt")

    new_tree_id = write_tree!(index)
    @test head_id != new_tree_id
    @test test_repo[new_tree_id]["second.txt"] == nothing
end

# --------------------
# test index all
# --------------------

# test add all lifecycle
sandboxed_test("testrepo.git") do _, path
    test_repo = init_repo(joinpath(path, "add-all"))
    cd(workdir(test_repo)) do
        open("file.foo", "w") do fh
            write(fh, "a file")
        end
        open("file.bar", "w") do fh
            write(fh, "another file")
        end
        open("file.zzz", "w") do fh
            write(fh, "yet another one")
        end
        open("other.zzz", "w") do fh
            write(fh, "yet another one")
        end
        open("more.zzz", "w") do fh
            write(fh, "yet another one")
        end
        open(".gitignore", "w") do fh
            write(fh, "*.foo\n")
        end

        index = GitIndex(test_repo)

        add_all!(index, "file.*")
        @test index["file.foo"]  == nothing
        @test index["file.bar"]  != nothing
        @test index["file.zzz"]  != nothing
        @test index["other.zzz"] == nothing
        @test index["more.zzz"]  == nothing

        add_all!(index, "*.zzz")
        @test index["file.foo"]  == nothing
        @test index["file.bar"]  != nothing
        @test index["file.zzz"]  != nothing
        @test index["other.zzz"] != nothing
        @test index["more.zzz"]  != nothing
    end
    close(test_repo)
    LibGit2.free!(test_repo)
end

# test update all
sandboxed_test("testrepo.git") do _, path
    test_repo = init_repo(joinpath(path, "add-all"))
    cd(workdir(test_repo)) do
        open("file.foo", "w") do fh
            write(fh, "a file")
        end
        open("file.bar", "w") do fh
            write(fh, "another file")
        end
        open("file.zzz", "w") do fh
            write(fh, "yet another one")
        end
        open("other.zzz", "w") do fh
            write(fh, "yet another one")
        end
        open("more.zzz", "w") do fh
            write(fh, "yet another one")
        end
        open(".gitignore", "w") do fh
            write(fh, "*.foo\n")
        end

        index = GitIndex(test_repo)
        add_all!(index, "file.*")

        open("file.bar", "w") do fh
            write(fh, "new content for file")
        end
        update_all!(index, "file.*")

        @test index["file.bar"] != nothing
        @test test_repo[Oid(index["file.bar"])] |> bytestring == "new content for file"

        @test index["other.zzz"] == nothing
        @test index["more.zzz"]  == nothing

        rm("file.bar")
        update_all!(index)

        @test index["file.bar"] == nothing
    end
    close(test_repo)
    LibGit2.free!(test_repo)
end

# test remove all
sandboxed_test("testrepo.git") do _, path
    test_repo = init_repo(joinpath(path, "add-all"))
    cd(workdir(test_repo)) do
        open("file.foo", "w") do fh
            write(fh, "a file")
        end
        open("file.bar", "w") do fh
            write(fh, "another file")
        end
        open("file.zzz", "w") do fh
            write(fh, "yet another one")
        end
        open("other.zzz", "w") do fh
            write(fh, "yet another one")
        end
        open("more.zzz", "w") do fh
            write(fh, "yet another one")
        end
        open(".gitignore", "w") do fh
            write(fh, "*.foo\n")
        end

        index = GitIndex(test_repo)

        add_all!(index, "file.*")
        remove_all!(index, "*.zzz")

        @test index["file.bar"] != nothing
        @test index["file.zzz"] == nothing
    end
    close(test_repo)
    LibGit2.free!(test_repo)
end
