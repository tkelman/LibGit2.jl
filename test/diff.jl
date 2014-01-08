@sandboxed_test "attr" begin
    opts = parse_git_diff_options({:context_lines=>1, :interhunk_lines=>1})
    @test opts.context_lines == 1
    @test opts.interhunk_lines == 1
end

