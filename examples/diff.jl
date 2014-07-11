# LibGit2.jl "diff" example - shows how to use the diff API
#
# Written by the LibGit2.jl contributors, based on the libgit2 examples.
#
# To the extent possible under law, the author(s) have dedicated all copyright
# and related and neighboring rights to this software to the public domain
# worldwide. This software is distributed without any warranty.
#
# You should have received a copy of the CC0 Public Domain Dedication along
# with this software. If not, see
# <http://creativecommons.org/publicdomain/zero/1.0/>.

using LibGit2
using ArgParse

# This example demonstrates the use of the LibGit2.jl diff APIs
# emulating a number of core Git `diff` command line options.

const COLORS = {
    :reset => "\033[m",
    :bold =>  "\033[1m",
    :red =>   "\033[31m",
    :green => "\033[32m",
    :cyan =>  "\033[36m"
}

function parse_commandline()
    settings = ArgParseSettings(autofix_names=true)
    @add_arg_table settings begin
        "treeish1"
            help = "oid of the first treeish"

        "treeish2"
            help = "oid of the second treeish"

        "path"
            help = "path of the repository"

        "-p", "-u", "--patch"
            action = :store_true

        "--cached"
            action = :store_true

        "--name-only"
            action = :store_true

        "--name-status"
            action = :store_true

        "--raw"
            action = :store_true

        "--color"
            action = :store_true

        "-R"
            action = :store_true
            dest_name = "reverse"

        "-a", "--text"
            action = :store_true
            dest_name = "force_text"

        "--ignore-space-at-eol"
            action = :store_true
            dest_name = "ignore_whitespace_eol"

        "-b", "--ignore-space-change"
            action = :store_true
            dest_name = "ignore_whitespace_change"

        "-w", "--ignore-all-space"
            action = :store_true
            dest_name = "ignore_whitespace"

        "--ignored" # not an option of git-diff
            action = :store_true
            dest_name = "include_ignored"

        "--untracked" # not an option of git-diff
            action = :store_true
            dest_name = "include_untracked"

        "--patience"
            action = :store_true

        "--minimal"
            action = :store_true

        "--numstat"
            action = :store_true

        "--shortstat"
            action = :store_true
        #=
        "-M", "--find-renames"
          arg_type = Integer

        "-C", "--find-copies"
          arg_type = Integer

        "--find-copies-harder"
          action = :store_true
          dest_name = "copies_from_unmodified"

        "-B", "--break-rewrites"
          action = :store_true
          dest_name = "rewrites"
        =#

        "-U", "--unified"
            arg_type = Integer
            dest_name = "context_lines"

        "--inter-hunk-context"
            arg_type = Integer
            dest_name = "interhunk_lines"
        #=
        "--old", "--src-prefix"
          arg_type = String
          dest_name = "old_prefix"

        "--dst-prefix"
          arg_type = String
          dest_name = "new_prefix"
        =#

    end
    args = parse_args(settings)

    # Convert keys to symbol
    args = {symbol(k) => v for (k,v) in args}

    # prune "nothing" values just for debug and to work in a clearer spaces
    map((k, v) -> is(v, nothing) && delete!(args, k), args)

    format_dic = {i => args[i] for i=(:raw, :patch, :name_only, :name_status)}
    sum(values(format_dic)) > 1 && error("too many format flags")

    diff_format = :patch
    for i in keys(format_dic)
        format_dic[i] && diff_format = i
    end
    return args, diff_format
end

function diff_print_shortstat(d::GitDiff)
    s = LibGit2.stat(d)
    if s.files > 0
        print(" $(s.files) ")
        @printf("%s", 1 == s.files ? "file changed" : "files changed")
        if s.adds > 0
            print(", $(s.adds) ")
            @printf("%s", 1 == s.adds ? "insertion(+)" : "insertions(+)")
        end
        if s.dels > 0
            print(", $(s.dels) ")
            @printf("%s", 1 == s.dels ? "deletion(-)" : "deletions(-)")
        end
        println()
    end
end

#TODO: support iteration for patches
function diff_print_numstat(d::GitDiff) # L278 libgit2/examples/diff.c
    p = LibGit2.patches(d)
    is(p, nothing) && return
    for i=1:length(p)
        a   = LibGit2.stat(p[i])
        del = LibGit2.delta(p[i])
        @printf("%d\t%d\t%s\n", a.adds, a.dels, del.new_file.path)
    end
end

function color_printer(d)
    color, last_color = :reset, nothing
    ps = patches(d)
    for i = 1:length(ps)
        hs = hunks(p[i])
        for j = 1:length(h)
            h, = hs[j]
            head = hj.header
            
            # Hack to color only text between `@@`
            idx = search(head,"@@",3)
            print(COLORS[:cyan],head[1:idx[end]],COLORS[:reset],head[idx[end]+1:end])

          #= FIXME I miss the header like which should be highlited in bold:
          ```
          diff --git a/src/diff.jl b/src/diff.jl
          index c27da2b..a01abcd 100644
          --- a/src/diff.jl
          +++ b/src/diff.jl
          ```
          to recover the file I have to pass through delta
           d = delta(hj.patch)
           d.new_file.path
          =#

            l = lines(hj)
            for k = 1:length(l)
                lo = l[k].line_origin
                if lo == :addition || lo == :eof_newline_added
                    color = :green
                elseif lo == :deletion || lo == :eof_newline_removed
                    color = :red
                # elseif lo == :file_header # TODO
                else
                    color = :reset
                end
                if color != last_color
                    if last_color == :bold || color == :bold
                        print(COLORS[:reset]) # FIXME
                    end
                    print(COLORS[color])
                    last_color = color
                end
                lo == :context && print(" ")
                lo == :addition && print("+")
                lo == :deletion && print("-")
                print(l[k].content)
            end
        end
    end
    return color
end

function main()
    o, diff_format = parse_commandline()
    if haskey(o,:path)
        repo = LibGit2.Repository(o[:path])
    else
        repo = Libgit2.repo_discover()
    end
    if haskey(o,:treeish1) && haskey(o,:treeish2)
        println("diff trees")
        d = LibGit2.diff(repo, o[:treeish1], o[:treeish2], o)
    elseif haskey(o,:treeish1) && o[:cached]
        println("diff tree to index")
        d = LibGit2.diff(repo, o[:treeish1], GitIndex(repo), o)
    elseif haskey(o,:treeish1) # TODO
        println("diff tree to working directory")
        # d = LibGit2.diff_workdir_with_index(repo, o[:treeish1], o)
        error("unimplemented: bindings to git_diff_tree_to_workdir_with_index()")
    elseif o[:cached]
        println("diff head to index")
        d = LibGit2.diff(repo, "HEAD", GitIndex(repo), o)
    else
        println("diff index to working directory")
        d = LibGit2.diff(repo, GitIndex(repo), o)
    end

    if o[:numstat]
        diff_print_numstat(d)
    elseif o[:shortstat]
        diff_print_shortstat(d)
    elseif o[:color]
        color_printer(d)
    else
        println(LibGit2.patch(d, format=diff_format))
    end
end

main()
