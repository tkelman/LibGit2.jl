export GitDiff, parse_git_diff_options

type GitDiff
    ptr::Ptr{Void}
end

free!(d::GitDiff) = begin
    if d.ptr != C_NULL
        api.git_diff_free(d.ptr)
        d.ptr = C_NULL
    end
end

# diffable GitTree, GitCommit, GitIndex, or Nothing
typealias Diffable Union(GitTree, GitCommit, GitIndex, Nothing)

Base.diff(left::String, right::String, opts=nothing) = begin
    rleft  = rev_parse(left)
    rright = rev_parse(right)
    if rleft != nothing
        return diff(rleft, rright, opts)
    elseif rright != nothing
        opts = opts == nothing ? {} : opts
        return diff(rleft, rright, merge(opts, {:reverse => !opts[:reverse]}))
    end
    return nothing
end

function diff_workdir(left::String, opts=nothing)
    left = rev_parse(left)
    diff_workdir(left, opts)
end

function diff_workdir(left::GitTree, opts=nothing)
end

function diff_workdir(left::GitCommit, opts=nothing)
end

function parse_git_diff_options()
    return api.GitDiffOptions()
end

#TODO: better type error handling
function parse_git_diff_options(opts::Dict)
    gdiff = api.GitDiffOptions()
    if haskey(opts, :max_size)
        gdiff.max_size = int64(opts[:max_size])
    end
    if haskey(opts, :context_lines)
        gdiff.context_lines = uint16(opts[:context_lines])
    end
    if haskey(opts, :interhunk_lines)
        gdiff.interhunk_lines = uint16(opts[:interhunk_lines])
    end
    if get(opts, :reverse, false)
        gdiff.flags |= api.DIFF_REVERSE
    end
    if get(opts, :force_text, false)
        gdiff.flags |= api.DIFF_FORCE_TEXT
    end
    if get(opts, :ignore_whitespace, false)
        gdiff.flags |= api.DIFF_IGNORE_WHITESPACE
    end
    if get(opts, :ignore_whitespace_change, false)
        gdiff.flags |= api.DIFF_IGNORE_WHITESPACE_CHANGE
    end
    if get(opts, :ignore_whitespace_eol, false)
        gdiff.flags |= api.DIFF_IGNORE_WHITESPACE_EOL
    end
    if get(opts, :ignore_submodules, false)
        gdiff.flags |= api.DIFF_IGNORE_SUBMODULES
    end
    if get(opts, :patience, false)
        gdiff.flags |= api.DIFF_PATIENCE
    end
    if get(opts, :include_ignored, false)
        gdiff.flags |= api.DIFF_INCLUDE_IGNORED
    end
    if get(opts, :include_untracked, false)
        gdiff.flags |= api.DIFF_INCLUDE_UNTRACKED
    end
    if get(opts, :include_unmodified, false)
       gdiff.flags |= api.DIFF_INCLUDE_UNMODIFIED
    end
    if get(opts, :recurse_untracked_dirs, false)
       gdiff.flags |= api.DIFF_RECURSE_UNTRACKED_DIRS
    end
    if get(opts, :disable_pathspec_match, false)
       gdiff.flags |= api.DIFF_DISABLE_PATHSPEC_MATCH
    end
    if get(opts, :show_untracked_content, false)
       gdiff.flags |= api.DIFF_SHOW_UNTRACKED_CONTENT
    end
    if get(opts, :skip_binary_check, false)
       gdiff.flags |= api.DIFF_SKIP_BINARY_CHECK
    end
    if get(opts, :include_typechange, false)
       gdiff.flags |= api.DIFF_INCLUDE_TYPECHANGE
    end
    if get(opts, :include_typechange_trees, false)
       gdiff.flags |= api.DIFF_INCLUDE_TYPECHANGE_TREES
    end
    if get(opts, :ignore_filemode, false)
       gdiff.flags |= api.DIFF_IGNORE_FILEMODE
    end
    if get(opts, :recurse_ignored_dirs, false)
       gdiff.flags |= api.DIFF_RECURSE_IGNORED_DIRS
    end
    if haskey(opts, :paths)
        paths = opts[:paths]
        if !(isa(paths, Array{String, 1}))
            throw(TypeError("opts[:paths] must be of type Array{String}"))
        end
        gdiff.pathspec_count = convert(Csize_t, length(paths))
        str_ptrs = Array(Ptr{Cchar}, length(paths))
        for i in 1:length(paths)
            str_ptrs[i] = convert(Ptr{Cchar}, bytestring(paths[i]))
        end
        gdiff.pathspec_strings = convert(Ptr{Ptr{Cchar}}, str_ptrs)
    end 
    return gdiff
end
