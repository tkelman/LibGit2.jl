@with_repo_access begin
    id = Oid("c4dc1555e4d4fa0e0c9c3fc46734c7c35b3ce90b")
    test_tree = lookup_tree(test_repo, id)

  begin # test_read_tree_data
    @test id == oid(tree)
    @test isa(test_tree, GitTree)
    @test length(test_tree) == 3
    @test test_tree[1] |> oid == Oid("1385f264afb75a56a5bec74243be9b367ba4ca08")
    @test test_tree[2] |> oid == Oid("fa49b077972391ad58037050f2a75f74e3671e92")
  end

  begin #test_read_tree_entry_data
    bent = test_tree[1]
    tent = test_tree[2]

    @test name(bent) == "README"
    @test isa(bent, GitBlob)

    @test name(tent) == "subdir"
    @test isa(tent, GitTree)
    @test tent |> oid == Oid("619f9935957e010c419cb9d15621916ddfcc0b96")
    @test isa(lookup(test_repo, oid(tent)), GitTree)
  end

  begin # est_get_entry_by_oid
    bentid = Oid("1385f264afb75a56a5bec74243be9b367ba4ca08")
    bent = test_tree[bentid]
    @test name(bent) == "README"
    @test isa(bent, GitBlob)
  end

  begin # test_get_entry_by_oid_returns_nil_if_no_oid
    nadaid = Oid("1385f264afb75a56a5bec74243be9b367ba4ca07")
    nada = test_tree[nada]
    @test nada == nothing
  end

  begin # test_get_entry_by_oid_throws_error_if_wrong_type
      @test_throws test_tree["123"]
  end
end

println("OK")
 
