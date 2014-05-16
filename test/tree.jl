# lookup raises error if object type does not match
@with_repo_access begin
    # blob
    @test_throws LibGitError{:Invalid,:NotFound} lookup_tree(test_repo, Oid("fa49b077972391ad58037050f2a75f74e3671e92"))
    # commit
    @test_throws LibGitError{:Invalid,:NotFound} lookup_tree(test_repo, Oid("8496071c1b46c854b31185ea97743be6a8774479"))
    # tag
    @test_throws LibGitError{:Invalid,:NotFound} lookup_tree(test_repo, Oid("0c37a5391bbff43c37f0d0371823a5509eed5b1d"))
end

@with_repo_access begin
    id = Oid("c4dc1555e4d4fa0e0c9c3fc46734c7c35b3ce90b")
    test_tree = lookup_tree(test_repo, id)

  begin # test_read_tree_data
    @test id == Oid(test_tree)
    @test isa(test_tree, GitTree)
    @test length(test_tree) == 3
    @test Oid(test_tree[1]) == Oid("1385f264afb75a56a5bec74243be9b367ba4ca08")
    @test Oid(test_tree[2]) == Oid("fa49b077972391ad58037050f2a75f74e3671e92")
  end

  begin #test_read_tree_entry_data
    bent = test_tree[1]
    tent = test_tree[3]

    @test name(bent) == "README"
    @test isa(bent, GitTreeEntry{GitBlob})

    @test name(tent) == "subdir"
    @test isa(tent, GitTreeEntry{GitTree})
    @test Oid(tent) == Oid("619f9935957e010c419cb9d15621916ddfcc0b96")
    @test isa(lookup(test_repo, Oid(tent)), GitTree)
  end

  begin # est_get_entry_by_oid
    bentid = Oid("1385f264afb75a56a5bec74243be9b367ba4ca08")
    bent = test_tree[bentid]
    @test name(bent) == "README"
    @test isa(bent, GitTreeEntry{GitBlob})
  end

  begin # test_get_entry_by_oid_returns_nil_if_no_oid
    nadaid = Oid("1385f264afb75a56a5bec74243be9b367ba4ca07")
    nada = test_tree[nadaid]
    @test nada == nothing
  end

  begin #test tree iteration
      @test length(collect(test_tree)) == length(test_tree)
      tes = sort(collect(test_tree))
      str = join([name(te) for te in tes], ":")
      @test str == "README:subdir:new.txt"
  end

  begin # test tree walk only trees
      walk_trees(test_tree, :postorder) do res
          root, entry = res
          @assert isa(entry, GitTreeEntry{GitTree})
      end
  end

  begin # test tree walk only blob
      walk_blobs(test_tree, :postorder) do res
          root, entry = res
          @test isa(entry, GitTreeEntry{GitBlob})
      end
  end

  begin # test iterate subtrees
      for t in each_tree(test_tree)
          @test isa(t, GitTreeEntry{GitTree})
      end
  end

  begin # test iteratee subtree blobs
      for b in each_blob(test_tree)
          @test isa(b, GitTreeEntry{GitBlob})
      end
  end
end

#TODO: treebuilder api is akward
@with_tmp_repo_access begin
  builder = TreeBuilder(test_repo)

  insert!(builder, "README.txt", 
                   Oid("1385f264afb75a56a5bec74243be9b367ba4ca08"),
                   33188)
  id = write!(builder)
  obj = test_repo[id]
  @test isa(obj, GitTree)
  @test length(raw(obj)) == 38
end

