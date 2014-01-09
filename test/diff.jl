@sandboxed_test "attr" begin
    opts = parse_git_diff_options({:context_lines=>1, :interhunk_lines=>1})
    @test opts.context_lines == 1
    @test opts.interhunk_lines == 1
end

@sandboxed_test "attr" begin
  d = diff(test_repo, "605812a", "370fe9ec22", 
           {:context_lines=>1, :interhunk_lines=>1})
  @test isa(d, GitDiff)
  
  ds = deltas(d)
  ps = patches(d)

  hs = DiffHunk[]
  for p in ps
      hks = hunks(p)
      if hks == nothing
          continue
      end
      for h in hks
          push!(hs, h)
      end
  end
  ls = vcat([lines(h) for h in hs]...)
  
  @test length(d) == 5
  @test length(ds) == 5
  @test length(ps) == 5

  @test sum(x -> x.status == :added? 1 : 0, ds) == 2
  @test sum(x -> x.status == :deleted? 1 : 0, ds) == 1
  @test sum(x -> x.status == :modified? 1 : 0, ds) == 2

  @test length(hs) == 5

  @test (7 + 24 + 1 + 6 + 6) == length(ls)
  @test sum(x -> x.line_origin == :context? 1 : 0, ls) == 1
  @test sum(x -> x.line_origin == :addition? 1 : 0, ls) == (24 + 1 + 5 + 5)
  @test sum(x -> x.line_origin == :deletion? 1 : 0, ls) == (7 + 1)
end

@sandboxed_test "attr" begin
  d = diff(test_repo, "605812a", nothing,
           {:context_lines=>1, :interhunk_lines=>1})
  @test isa(d, GitDiff)

  ds = deltas(d)
  ps = patches(d)
  
  hs = DiffHunk[]
  for p in ps
      hks = hunks(p)
      if hks == nothing
          continue
      end
      for h in hks
          push!(hs, h)
      end
  end
  ls = vcat([lines(h) for h in hs]...)
  
  @test length(d) == 16
  @test length(ds) == 16
  @test length(ps) == 16

  @test sum(x -> x.status == :added? 1 : 0, ds) == 0
  @test sum(x -> x.status == :deleted? 1 : 0, ds) == 16
  @test sum(x -> x.status == :modified? 1 : 0, ds) == 0

  @test length(hs) == 15

  @test length(ls) == 115
  @test sum(x -> x.line_origin == :context? 1 : 0, ls) == 0
  @test sum(x -> x.line_origin == :addition? 1 : 0, ls) == 0
  @test sum(x -> x.line_origin == :deletion? 1 : 0, ls) == 113
end

@sandboxed_test "attr" begin
  d = diff(test_repo, nothing, "605812a", 
           {:context_lines=>1, :interhunk_lines=>1})
  @test isa(d, GitDiff)
  
  ds = deltas(d)
  ps = patches(d)
  
  hs = DiffHunk[]
  for p in ps
      hks = hunks(p)
      if hks == nothing
          continue
      end
      for h in hks
          push!(hs, h)
      end
  end
  ls = vcat([lines(h) for h in hs]...)
  
  @test length(d) == 16
  @test length(ds) == 16
  @test length(ps) == 16

  @test sum(x -> x.status == :added? 1 : 0, ds) == 16
  @test sum(x -> x.status == :deleted? 1 : 0, ds) == 0
  @test sum(x -> x.status == :modified? 1 : 0, ds) == 0

  @test length(hs) == 15
  
  @test length(ls) == 115
  @test sum(x -> x.line_origin == :context? 1 : 0, ls) == 0
  @test sum(x -> x.line_origin == :addition? 1 : 0, ls) == 113
  @test sum(x -> x.line_origin == :deletion? 1 : 0, ls) == 0
end


@sandboxed_test "status" begin
    d = diff_workdir(
             test_repo, "26a125ee1bf",
             {:context_lines => 3,
              :interhunk_lines => 1,
              :include_ignored => true,
              :include_untracked => true})
    
    ds = deltas(d)
    ps = patches(d)
      
    hs = DiffHunk[]
    for p in ps
        hks = hunks(p)
        if hks == nothing
            continue
        end
        for h in hks
            push!(hs, h)
        end
    end
    ls = vcat([lines(h) for h in hs]...)
      
    @test length(ds) == 14 
    @test length(ps) == 14

    @test sum(x -> x.status == :added? 1 : 0, ds) == 0
    @test sum(x -> x.status == :deleted? 1 : 0, ds) == 4
    @test sum(x -> x.status == :modified? 1 : 0, ds) == 4
    @test sum(x -> x.status == :ignored? 1 : 0, ds) == 1
    @test sum(x -> x.status == :untracked? 1 : 0, ds) == 5

    @test length(hs) == 8

    @test length(ls) == 13
    @test sum(x -> x.line_origin == :context? 1 : 0, ls) == 4
    @test sum(x -> x.line_origin == :addition? 1 : 0, ls) == 5
    @test sum(x -> x.line_origin == :deletion? 1 : 0, ls) == 4
end

@sandboxed_test "attr" begin
    c = lookup_commit(test_repo, "605812a")
    @test isa(c, GitCommit)
    
    d = diff(test_repo, c, {:context_lines=>1, :interhunk_lines=>1})
    @test isa(d, GitDiff)

    ds = deltas(d)
    ps = patches(d)
      
    hs = DiffHunk[]
    for p in ps
        hks = hunks(p)
        if hks == nothing
            continue
        end
        for h in hks
            push!(hs, h)
        end
    end
    ls = vcat([lines(h) for h in hs]...)
    
    @test length(d)  == 5
    @test length(ds) == 5 
    @test length(ps) == 5

    @test sum(x -> x.status == :added? 1 : 0, ds) == 0
    @test sum(x -> x.status == :deleted? 1 : 0, ds) == 3
    @test sum(x -> x.status == :modified? 1 : 0, ds) == 2

    @test length(hs) == 4

    @test length(ls) == 51
    @test sum(x -> x.line_origin == :context? 1 : 0, ls) == 2
    @test sum(x -> x.line_origin == :addition? 1 : 0, ls) == 3
    @test sum(x -> x.line_origin == :deletion? 1 : 0, ls) == 46
end

@sandboxed_test "attr" begin
    c = lookup_commit(test_repo, 
                Oid("6bab5c79cd5140d0f800917f550eb2a3dc32b0da"))
    @test isa(c, GitCommit)
    
    d = diff(test_repo, c, 
        {:context_lines => 1, :interhunk_lines => 1, :reverse => true})
    @test isa(d, GitDiff)
    
    ds = deltas(d)
    ps = patches(d)
      
    hs = DiffHunk[]
    for p in ps
        hks = hunks(p)
        if hks == nothing
            continue
        end
        for h in hks
            push!(hs, h)
        end
    end
    ls = vcat([lines(h) for h in hs]...)
     
    @test length(d)  == 13
    @test length(ds) == 13
    @test length(ps) == 13
    
    @test sum(x -> x.status == :added? 1 : 0, ds) == 13
    @test sum(x -> x.status == :deleted? 1 : 0, ds) == 0
    @test sum(x -> x.status == :modified? 1 : 0, ds) == 0

    @test length(hs) == 13

    @test length(ls) == 72
    @test sum(x -> x.line_origin == :context? 1 : 0, ls) == 0
    @test sum(x -> x.line_origin == :addition? 1 : 0, ls) == 70
    @test sum(x -> x.line_origin == :deletion? 1 : 0, ls) == 0
end

@sandboxed_test "status" begin
    c = lookup_commit(test_repo, "26a125ee1bf")
    @test isa(c, GitCommit)
    
    d= diff_workdir(test_repo, c,
     {:context_lines => 3,
      :interhunk_lines => 1,
      :include_ignored => true,
      :include_untracked => true}
    )
    @test isa(d, GitDiff)
    
    ds = deltas(d)
    ps = patches(d)
      
    hs = DiffHunk[]
    for p in ps
        hks = hunks(p)
        if hks == nothing
            continue
        end
        for h in hks
            push!(hs, h)
        end
    end
    ls = vcat([lines(h) for h in hs]...)
     
    @test length(ds) == 14
    @test length(ps) == 14
    
    @test sum(x -> x.status == :added? 1 : 0, ds) == 0
    @test sum(x -> x.status == :deleted? 1 : 0, ds) == 4
    @test sum(x -> x.status == :modified? 1 : 0, ds) == 4
    @test sum(x -> x.status == :ignored? 1 : 0, ds) == 1
    @test sum(x -> x.status == :untracked? 1 : 0, ds) == 5

    @test length(hs) == 8

    @test length(ls) == 13
    @test sum(x -> x.line_origin == :context? 1 : 0, ls) == 4
    @test sum(x -> x.line_origin == :addition? 1 : 0, ls) == 5 
    @test sum(x -> x.line_origin == :deletion? 1 : 0, ls) == 4 
end 

@sandboxed_test "status" begin
    c = lookup_commit(test_repo, "26a125ee1bf")
    t = GitTree(c)
    @test isa(t, GitTree)
    
    d = diff_workdir(test_repo, t,
     {:context_lines => 3,
      :interhunk_lines => 1,
      :include_ignored => true,
      :include_untracked => true}
    )
    @test isa(d, GitDiff)
    
    ds = deltas(d)
    ps = patches(d)
      
    hs = DiffHunk[]
    for p in ps
        hks = hunks(p)
        if hks == nothing
            continue
        end
        for h in hks
            push!(hs, h)
        end
    end
    ls = vcat([lines(h) for h in hs]...)
     
    @test length(ds) == 14
    @test length(ps) == 14
    
    @test sum(x -> x.status == :added? 1 : 0, ds) == 0
    @test sum(x -> x.status == :deleted? 1 : 0, ds) == 4
    @test sum(x -> x.status == :modified? 1 : 0, ds) == 4
    @test sum(x -> x.status == :ignored? 1 : 0, ds) == 1
    @test sum(x -> x.status == :untracked? 1 : 0, ds) == 5

    @test length(hs) == 8

    @test length(ls) == 13
    @test sum(x -> x.line_origin == :context? 1 : 0, ls) == 4
    @test sum(x -> x.line_origin == :addition? 1 : 0, ls) == 5 
    @test sum(x -> x.line_origin == :deletion? 1 : 0, ls) == 4 
end 

