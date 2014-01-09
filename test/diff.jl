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
  hs = vcat([hunks(p) for p in ps]...)
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

