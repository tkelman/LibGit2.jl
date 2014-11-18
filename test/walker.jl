with_repo_access() do test_repo, path

    context("test walk revlist") do
        walker = GitRevWalker(test_repo)
        push!(walker, Oid("9fd738e8f7967c078dceed8190330fc8648ee56a"))
        data = collect(walker)
        ids = sort(data)
        str = join(map(id -> hex(id)[1:5], ids), ".")
        @test str == "4a202.5b5b0.84960.9fd73"
    end

    context("test walk partial revlist") do
        walker = GitRevWalker(test_repo)
        id = Oid("8496071c1b46c854b31185ea97743be6a8774479")
        push!(walker, id)
        walk = collect(walker)
        @test id == Oid(walk[1])
        @test length(walk) == 1
    end

    context("test hide part of list") do
        walker = GitRevWalker(test_repo)
        push!(walker, Oid("9fd738e8f7967c078dceed8190330fc8648ee56a"))
        hide!(walker, Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))
        @test length(collect(walker)) == 2
    end

    context("test reset walker") do
        walker = GitRevWalker(test_repo)
        id = Oid("8496071c1b46c854b31185ea97743be6a8774479")
        push!(walker, id)
        walk = collect(walker)
        @test id == Oid(walk[1])
        @test length(walk) == 1
        reset!(walker)
        walk = collect(walker)
        @test length(walk) == 0
    end

   context("test walker is iterable") do
        walker = GitRevWalker(test_repo)
        push!(walker, Oid("9fd738e8f7967c078dceed8190330fc8648ee56a"))
        vs = sort(collect(walker))
        str = join(map(a -> hex(a)[1:4], vs), ".")
        @test str == "4a20.5b5b.8496.9fd7"
   end
end

function do_sort(walker, sorting; rev=false)
    id = Oid("a4a7dce85cf63874e984719f4fdd239f5145052f")
    sortby!(walker, sorting, rev=rev)
    push!(walker, id)
    return collect(walker)
end

function revlist_with_sorting(walker, sorting; rev=false)
    data = do_sort(walker, sorting, rev=rev)
    return join(map(a -> hex(a)[1:5], data), ".")
end

function is_toposorted(list)
    tfunc = (c) -> begin
        pcs = parents(c)
        for p in pcs
            idx_commit = first(findin(list, [c]))
            idx_parent = first(findin(list, [p]))
            if idx_commit > idx_parent
                return false
            end
        end
        return true
    end
    all(tfunc, list)
end

with_repo_access() do test_repo, path
    context("test walk revlist") do
        walker = GitRevWalker(test_repo)
        t = revlist_with_sorting(walker, :date)
        @test t ==  "a4a7d.c4780.9fd73.4a202.5b5b0.84960"
    end

    context("test sort by topo") do
        walker = GitRevWalker(test_repo)
        sort_list = do_sort(walker, :topo)
        @test is_toposorted(sort_list)
    end

    context("test sort by date reversed") do
        walker = GitRevWalker(test_repo)
        t = revlist_with_sorting(walker, :date, rev=true)
        @test t == "84960.5b5b0.4a202.9fd73.c4780.a4a7d"
    end

    context("test sort by topo reversed") do
        walker = GitRevWalker(test_repo)
        sort_list = do_sort(walker, :topo, rev=true)
        reverse!(sort_list)
        @test is_toposorted(sort_list)
    end
end
