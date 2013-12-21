# lookup raises error if object type does not match
@with_repo_access begin
end

@with_repo_access begin
    begin # test walk revlist 
        walker = GitRevWalker(test_repo)
        push!(walker, Oid("9fd738e8f7967c078dceed8190330fc8648ee56a"))
        data = collect(walker)
        ids = sort(data, by=oid)
        str = join(map(id -> hex(id)[1:5], ids), ".")
        @test str == "4a202.5b5b0.84960.9fd73"
    end

    begin # test_walk_partial_revlist
        walker = GitRevWalker(test_repo)
        id = Oid("8496071c1b46c854b31185ea97743be6a8774479")
        push!(walker, id)
        walk = collect(walker)
        @test id == oid(walk[1])
        @test length(walk) == 1
    end

    begin # test_hide_part_of_list
        walker = GitRevWalker(test_repo)
        push!(walker, Oid("9fd738e8f7967c078dceed8190330fc8648ee56a"))
        hide!(walker, Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))
        @test length(collect(walker)) == 2
    end

    begin # test_resetting_walker
        walker = GitRevWalker(test_repo)
        id = Oid("8496071c1b46c854b31185ea97743be6a8774479")
        push!(walker, id)
        walk = collect(walker)
        @test id == oid(walk[1])
        @test length(walk) == 1 
        reset!(walker)
        walk = collect(walker)
        @test length(walk) == 0
    end

   begin # test_walk_is_iterable
        walker = GitRevWalker(test_repo)
        push!(walker, Oid("9fd738e8f7967c078dceed8190330fc8648ee56a"))
        vs = collect(walker)
        sort!(vs, by=oid)
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

@with_repo_access begin
    begin # test walk revlist 
        walker = GitRevWalker(test_repo)
        t = revlist_with_sorting(walker, :date)
        @test t ==  "a4a7d.c4780.9fd73.4a202.5b5b0.84960"
    end

    begin #test_sort_by_topo
        walker = GitRevWalker(test_repo)
        sort_list = do_sort(walker, :topo)
        @test is_toposorted(sort_list)
    end

    begin #test_sort_by_date_reversed
        walker = GitRevWalker(test_repo)
        t = revlist_with_sorting(walker, :date, rev=true)
        @test t == "84960.5b5b0.4a202.9fd73.c4780.a4a7d"
    end

    begin #test_sort_by_topo_reverse
        walker = GitRevWalker(test_repo)
        sort_list = do_sort(walker, :topo, rev=true)
        reverse!(sort_list)
        @test is_toposorted(sort_list)
    end
end

