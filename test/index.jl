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
    @test isdir(repo_workdir(repo)) 
    idx = repo_index(repo)
    @test isa(idx, GitIndex)
    add!(idx, "README")
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
catch err
    rethrow(err)
finally 
    cleanup_dir(test_path)
end

# -----------------------------------------
# Tests adapted from Ruby's Rugged Library
# -----------------------------------------

function new_idx_entry()
    now = time()
    return IndexEntry("new_path",
                      Oid("d385f264afb75a56a5bec74243be9b367ba4ca08"),
                      now,
                      now,
                      1000,
                      234881027,
                      88888,
                      33199,
                      502,
                      502,
                      false,
                      3)
end

# test index size
@with_test_index begin
    @test length(test_index) == 2
end

# test empty index
@with_test_index begin
    clear!(test_index)
    @test length(test_index) == 0
end

# test remove entries
@with_test_index begin
    remove!(test_index, "new.txt")
    @test length(test_index) == 1
end

# test remove dir
@with_test_index begin
    remove_dir!(test_index, "does-not-exist")
    @test length(test_index) == 2

    remove_dir!(test_index, "", 2)
    @test length(test_index) == 2

    remove_dir!(test_index, "")
    @test length(test_index) == 0
end

# test get entry data
@with_test_index begin
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

# test iterate entries
@with_test_index begin
    c = sort(collect(test_index), by=x->Oid(x))
    @test join(map(x->x.path, c), ":") == "README:new.txt"
end

# test update entries
@with_test_index begin
    now = int(time())
    entry = test_index[1]
    Oid(entry) = Oid("12ea3153a78002a988bb92f4123e7e831fd1138a")
    entry.mtime = now
    entry.ctime = now
    entry.file_size = 1000
    entry.dev = 234881027
    entry.ino = 88888
    entry.mode = 33199
    entry.uid = 502
    entry.gid = 502
    entry.stage = 3
    add!(test_index, entry)
    new_entry = getentry(test_index, entry.path, 3)
    @test isa(new_entry, IndexEntry)
    @test new_entry == entry
end

# test add new entries
@with_test_index begin
    add!(test_index, new_idx_entry())
    @test length(test_index) == 3
    c = sort(collect(test_index), by=x->Oid(x))
    @test join(map(x -> x.path, c), ":") == "README:new_path:new.txt"
end

# test can write index
@with_test_index begin
    tmp_path, tmp_io = mktemp()
    write(tmp_io, readall(test_index_path))
    close(tmp_io)
    test_index1 = GitIndex(tmp_path)

    entry = new_idx_entry()
    add!(test_index1, entry)
    entry.path = "else.txt"
    add!(test_index1, entry)
    write!(test_index1)

    test_index2 = GitIndex(tmp_path)
    c = sort(collect(test_index2), by=x->Oid(x))
    @test join(map(x -> x.path, c), ":") == "README:else.txt:new_path:new.txt"
    @test length(test_index2) == 4
end

# ------------------
# test adding a path
# ------------------
tmp_path = mktempdir()
test_repo  = repo_init(tmp_path, bare=false)
test_index1 = repo_index(test_repo)
fh = open(joinpath(tmp_path, "test.txt"), "w")
write(fh, "test content")
close(fh)
add!(test_index1, "test.txt")
write!(test_index1)

test_index2 = GitIndex(joinpath(tmp_path, ".git/index"))
@test test_index2[1].path == "test.txt"

close(test_repo)
run(`rm -rf $tmp_path`)

# --------------------
# test reloading index
# --------------------
tmp_path = mktempdir()
test_repo = repo_init(tmp_path, bare=false)
index = repo_index(test_repo)
fh = open(joinpath(tmp_path, "test.txt"), "w")
write(fh, "test content")
close(fh)
add!(index, "test.txt")
write!(index)

rindex = GitIndex(joinpath(tmp_path, ".git/index"))
entry = rindex["test.txt"]
@test entry.stage == 0

add!(rindex, new_idx_entry())
write!(rindex)

@test length(index) == 1
reload!(index)
@test length(index) == 2

entry = getentry(index, "new_path", 3)
@test entry.mode == 33199

close(test_repo)
run(`rm -rf $tmp_path`)

# test idempotent read write
@with_tmp_repo_access begin
    head_id = lookup_ref(test_repo, "HEAD") |> resolve |> target
    tree = GitTree(lookup(test_repo, head_id))
    index = repo_index(test_repo)
    read_tree!(index, tree)
    
    index_tree_id = write_tree!(index)
    index_tree = test_repo[index_tree_id]
    @test Oid(index_tree) == Oid(tree)
end

# test build tree from index
@with_tmp_repo_access begin
    head_id = lookup_ref(test_repo,
                "refs/remotes/origin/packed") |> resolve |> target
    tree = GitTree(test_repo[head_id])
    index = repo_index(test_repo)
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
@sandboxed_test "testrepo.git" begin 
    test_repo = repo_init(joinpath(test_repo_path, "add-all"))
    cd(repo_workdir(test_repo)) do
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

        index = repo_index(test_repo)
        
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
end

# test update all
@sandboxed_test "testrepo.git" begin 
    test_repo = repo_init(joinpath(test_repo_path, "add-all"))
    cd(repo_workdir(test_repo)) do
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

        index = repo_index(test_repo)
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
end

# test remove all
@sandboxed_test "testrepo.git" begin 
    test_repo = repo_init(joinpath(test_repo_path, "add-all"))
    cd(repo_workdir(test_repo)) do
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

        index = repo_index(test_repo)
        
        add_all!(index, "file.*")
        remove_all!(index, "*.zzz")

        @test index["file.bar"] != nothing 
        @test index["file.zzz"] == nothing
    end
end

