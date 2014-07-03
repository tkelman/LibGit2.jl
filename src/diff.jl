export GitDiff, parse_git_diff_options, deltas, patches, diff_workdir, patch

type GitDiff
    ptr::Ptr{Void}

    function GitDiff(ptr::Ptr{Void})
        @assert ptr != C_NULL
        d = new(ptr)
        finalizer(d, free!)
        return d
    end
end

free!(d::GitDiff) = begin
    if d.ptr != C_NULL
        ccall((:git_diff_free, :libgit2), Void, (Ptr{Void},), d.ptr)
        d.ptr = C_NULL
    end
end

Base.convert(::Type{Ptr{Void}}, d::GitDiff) = d.ptr

type DiffStats
    files::Int
    adds::Int
    dels::Int
end

DiffStats() = DiffStats(0, 0, 0)

function cb_diff_file_stats(delta_ptr::Ptr{DiffDeltaStruct}, 
                            progress::Cfloat,
                            payload::Ptr{Void})
    delta = unsafe_load(delta_ptr)::DiffDeltaStruct
    stats = unsafe_pointer_to_objref(payload)::DiffStats
    if delta.status == api.DELTA_ADDED ||
       delta.status == api.DELTA_DELETED ||
       delta.status == api.DELTA_MODIFIED ||
       delta.status == api.DELTA_RENAMED ||
       delta.status == api.DELTA_COPIED ||
       delta.status == api.DELTA_TYPECHANGE
        stats.files += 1
    end
    return api.GIT_OK
end

const c_cb_diff_file_stats = cfunction(cb_diff_file_stats, Cint,
                                       (Ptr{DiffDeltaStruct}, Cfloat, Ptr{Void}))

function cb_diff_line_stats(delta_ptr::Ptr{Void},
                            hunk_ptr::Ptr{Void},
                            line_ptr::Ptr{DiffLineStruct},
                            payload::Ptr{Void})
    line  = unsafe_load(line_ptr)
    stats = unsafe_pointer_to_objref(payload)::DiffStats
    if line.origin == api.DIFF_LINE_ADDITION
        stats.adds += 1
    elseif line.origin == api.DIFF_LINE_DELETION
        stats.dels += 1
    end
    return api.GIT_OK
end

const c_cb_diff_line_stats = cfunction(cb_diff_line_stats, Cint,
                                       (Ptr{Void}, Ptr{Void}, Ptr{DiffLineStruct}, Ptr{Void}))
Base.stat(d::GitDiff) = begin
    stats = DiffStats()
    ccall((:git_diff_foreach, :libgit2), Void,
          (Ptr{Void}, Ptr{Void}, Ptr{Void}, Ptr{Void}, Any),
          d, c_cb_diff_file_stats, C_NULL, c_cb_diff_line_stats, &stats)
    return stats
end

type DiffFile
    oid::Oid
    path::ByteString
    size::Int
    flags::Int
    mode::Int
end

function delta_status_symbol(s::Integer)
    s == api.DELTA_UNMODIFIED && return :unmodified
    s == api.DELTA_ADDED      && return :added
    s == api.DELTA_DELETED    && return :deleted
    s == api.DELTA_MODIFIED   && return :modified
    s == api.DELTA_RENAMED    && return :renamed
    s == api.DELTA_COPIED     && return :copied
    s == api.DELTA_IGNORED    && return :ignored
    s == api.DELTA_UNTRACKED  && return :untracked
    s == api.DELTA_TYPECHANGE && return :typechange
    throw(ArgumentError("Unknown status symbol :$s")) 
end

type DiffDelta
    old_file::DiffFile
    new_file::DiffFile
    similarity::Int
    status::Symbol
    isbinary::Bool

    function DiffDelta(ptr::Ptr{DiffDeltaStruct})
        @assert ptr != C_NULL
        d = unsafe_load(ptr)
        #! todo copy contents from offset here
        old_file_id = d.old_file.id::Oid
        fold = DiffFile(old_file_id,
                        d.old_file.path != C_NULL ? bytestring(d.old_file.path) : "",
                        int(d.old_file.size),
                        int(d.old_file.flags),
                        int(d.old_file.mode))
        #! todo copy contents from offset here
        new_file_id = d.new_file.id::Oid 
        fnew = DiffFile(new_file_id,
                        d.new_file.path != C_NULL ? bytestring(d.new_file.path) : "",
                        int(d.new_file.size),
                        int(d.new_file.flags),
                        int(d.new_file.mode))
        return new(fold, fnew, int(d.similarity), delta_status_symbol(d.status),
                   (bool(d.flags & api.DIFF_FLAG_NOT_BINARY) &&
                    bool(d.flags & api.DIFF_FLAG_BINARY)))
    end
end

Base.length(d::GitDiff) = int(ccall((:git_diff_num_deltas, :libgit2), Csize_t,
                                    (Ptr{Void},), d))
function deltas(d::GitDiff)
    ndelta = length(d) 
    if ndelta == 0
        return nothing
    end
    ds = Array(DiffDelta, ndelta)
    for i in 1:ndelta
        delta_ptr = ccall((:git_diff_get_delta, :libgit2), Ptr{DiffDeltaStruct},
                          (Ptr{Void}, Csize_t), d, i-1) 
        ds[i] = DiffDelta(delta_ptr)
    end
    return ds
end

function patches(d::GitDiff)
    ndelta = length(d)
    if ndelta == 0
        return nothing
    end 
    ps = GitPatch[]
    patch_ptr = Ptr{Void}[0]
    err = zero(Cint) 
    for i in 1:ndelta
        err = ccall((:git_patch_from_diff, :libgit2), Cint,
                    (Ptr{Ptr{Void}}, Ptr{Void}, Csize_t), patch_ptr, d, i-1) 
        if err != api.GIT_OK
            break
        end
        push!(ps, GitPatch(patch_ptr[1]))
    end
    if err != api.GIT_OK
        throw(GitError(err))
    end
    return ps
end 

#TODO: memory leaks?
function cb_diff_print(delta_ptr::Ptr{Void},
                       hunk_ptr::Ptr{Void},
                       line_ptr::Ptr{DiffLineStruct},
                       payload::Ptr{Void})
    l = unsafe_load(line_ptr)
    s = unsafe_pointer_to_objref(payload)::Array{Uint8,1}
    add_origin = false
    if l.origin == api.DIFF_LINE_CONTEXT ||
       l.origin == api.DIFF_LINE_ADDITION ||
       l.origin == api.DIFF_LINE_DELETION
       add_origin = true
    end 
    prev_len = length(s)
    if add_origin
        resize!(s, prev_len + l.content_len + 1)
        s[prev_len + 1] = l.origin
        for i in 1:l.content_len
            s[prev_len + i + 1] = unsafe_load(l.content, i)
        end
    else
        resize!(s, prev_len + l.content_len)
        for i in 1:l.content_len
            s[prev_len + i] = unsafe_load(l.content, i)
        end
    end
    return api.GIT_OK
end

const c_cb_diff_print = cfunction(cb_diff_print, Cint,
                                  (Ptr{Void}, Ptr{Void}, Ptr{DiffLineStruct}, Ptr{Void}))

function patch(d::GitDiff; format::Symbol=:patch)
    @assert d.ptr != C_NULL
    cformat = zero(Cint)
    if format === :name_status
        cformat = api.DIFF_FORMAT_NAME_STATUS
    elseif format === :name_only
        cformat = api.DIFF_FORMAT_NAME_ONLY
    elseif format === :raw
        cformat = api.DIFF_FORMAT_RAW
    elseif format === :header
        cformat = api.DIFF_FORMAT_PATCH_HEADER
    elseif format === :patch
        cformat = api.DIFF_FORMAT_PATCH
    else
      throw(ArgumentError(("Unknown diff output format ($format)")))
    end
    s = Uint8[]
    ccall((:git_diff_print, :libgit2), Cint,
           (Ptr{Void}, Cint, Ptr{Void}, Any), d, cformat, c_cb_diff_print, &s)
    return UTF8String(s)
end

# diffable GitTree, GitCommit, GitIndex, or Nothing
typealias Diffable Union(GitTree, GitCommit, GitIndex, Nothing)

Base.diff(repo::GitRepo, left::Nothing, right::Nothing, opts=nothing) = nothing

Base.diff(repo::GitRepo,
          left::Union(Nothing, String),
          right::Union(Nothing, String), 
          opts=nothing) = begin
    l = left  != nothing ? rev_parse(repo, left)  : nothing
    r = right != nothing ? rev_parse(repo, right) : nothing
    if l != nothing
        return diff(repo, l, r, opts)
    elseif r != nothing
        opts = opts == nothing ? {} : opts
        return diff(repo, l, r, 
                merge(opts, {:reverse => !get(opts, :reverse, true)}))
    end
    return nothing
end

Base.diff(repo::GitRepo, left::GitCommit, right::GitCommit, opts=nothing) = begin
    return diff(repo, GitTree(left), GitTree(right), opts)
end

Base.diff(repo::GitRepo, left::GitCommit, right::Nothing, opts=nothing) = begin
    return diff(repo, GitTree(left), nothing, opts)
end

Base.diff(repo::GitRepo, left::Nothing, right::GitCommit, opts=nothing) = begin
    return diff(repo, nothing, GitTree(right), opts)
end

Base.diff(repo::GitRepo, c::GitCommit, opts=nothing) = begin
    ps = parents(c)
    if length(ps) > 0
        p = first(ps)
        return diff(repo, GitTree(c), GitTree(p), opts)
    else
        return diff(repo, GitTree(c), nothing, opts)
    end
end

Base.diff(repo::GitRepo, left::GitTree, right::String, opts=nothing) = begin
    other = rev_parse(repo, right)
    return diff(repo, left, other, opts)
end

Base.diff(repo::GitRepo, left::GitTree, right::GitCommit, opts=nothing) = begin
    return diff(repo, left, GitTree(right), opts)
end

typealias MaybeGitTree Union(Nothing, GitTree)

Base.diff(repo::GitRepo, left::MaybeGitTree, right::MaybeGitTree, opts=nothing) = begin
    gopts = parse_git_diff_options(opts)
    diff_ptr = Ptr{Void}[0]
    @check ccall((:git_diff_tree_to_tree, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, 
                  Ptr{Void}, 
                  Ptr{Void}, 
                  Ptr{Void}, 
                  Ptr{DiffOptionsStruct}),
                 diff_ptr,
                 repo, 
                 left  != nothing ? left.ptr : C_NULL, 
                 right != nothing ? right.ptr : C_NULL,
                 &gopts)
    return GitDiff(diff_ptr[1])
end

Base.diff(repo::GitRepo, left::String, right::GitIndex, opts=nothing) = begin
    other = rev_parse(repo, left)
    return diff(repo, other, right, opts)
end

Base.diff(repo::GitRepo, left::GitCommit, right::GitIndex, opts=nothing) = begin
    return diff(repo, GitTree(left), right, opts)
end

Base.diff(repo::GitRepo, left::GitTree, right::GitIndex, opts=nothing) = begin
    gopts = parse_git_diff_options(opts)
    diff_ptr = Ptr{Void}[0]
    @check ccall((:git_diff_tree_to_index, :libgit2), Cint,
                 (Ptr{Ptr{Void}},
                  Ptr{Void},
                  Ptr{Void}, 
                  Ptr{Void},
                  Ptr{DiffOptionsStruct}),
                 diff_ptr, repo, left, right, &gopts)
    return GitDiff(diff_ptr[1])
end

Base.diff(repo::GitRepo, idx::GitIndex, opts=nothing) = begin
    return diff(repo, idx, nothing, opts)
end

Base.diff(repo::GitRepo, idx::GitIndex, other::Nothing, opts=nothing) = begin
    gopts = parse_git_diff_options(opts)
    diff_ptr = Ptr{Void}[0]
    @check ccall((:git_diff_index_to_workdir, :libgit2), Cint,
                  (Ptr{Ptr{Void}}, 
                   Ptr{Void}, 
                   Ptr{Void}, 
                   Ptr{DiffOptionsStruct}),
                  diff_ptr, repo, idx, &gopts)
    return GitDiff(diff_ptr[1])
end

Base.diff(repo::GitRepo, idx::GitIndex, other::GitCommit, opts=nothing) = begin
    return diff(repo, idx, GitTree(other), opts)
end

Base.diff(repo::GitRepo, idx::GitIndex, other::GitTree, opts=nothing) = begin
    gopts = parse_git_diff_options(opts)
    diff_ptr = Ptr{Void}[0]
    @check ccall((:git_diff_tree_to_index, api.libgit2), Cint,
                 (Ptr{Ptr{Void}},
                  Ptr{Void},
                  Ptr{Void}, 
                  Ptr{Void}, 
                  Ptr{DiffOptionsStruct}),
                  diff_ptr, repo, other, idx, &gopts)
   return GitDiff(diff_ptr[1])
end

Base.merge!(d1::GitDiff, d2::GitDiff) = begin
    @check ccall((:git_diff_merge, :libgit2), Cint, (Ptr{Void}, Ptr{Void}), d1, d2)
    return d1
end

function diff_workdir(repo::GitRepo, left::String, opts=nothing)
    l = rev_parse(repo, left)
    return diff_workdir(repo, l, opts)
end

diff_workdir(repo::GitRepo, left::GitCommit, opts=nothing) = diff_workdir(repo, GitTree(left), opts)

function diff_workdir(repo::GitRepo, left::GitTree, opts=nothing)
    gopts = parse_git_diff_options(opts)
    diff_ptr = Ptr{Void}[0]
    @check ccall((:git_diff_tree_to_workdir, :libgit2), Cint,
                 (Ptr{Ptr{Void}},
                  Ptr{Void}, 
                  Ptr{Void}, 
                  Ptr{DiffOptionsStruct}),
                 diff_ptr, repo, left, &gopts)
    return GitDiff(diff_ptr[1])
end

parse_git_diff_options(o::Nothing) = DiffOptionsStruct()

#! we are doing bad things with memory here 
function parse_git_diff_options(opts::Dict)
    max_size = zero(Coff_t)
    if haskey(opts, :max_size)
        max_size = convert(Coff_t, opts[:max_size])
    end
    context_lines = uint16(3)
    if haskey(opts, :context_lines)
        @assert opts[:context_lines] <= typemax(Uint16)
        context_lines = convert(Uint16, opts[:context_lines])
    end
    interhunk_lines = zero(Uint16)
    if haskey(opts, :interhunk_lines)
        @assert opts[:interhunk_lines] <= typemax(Uint16)
        interhunk_lines = convert(Uint16, opts[:interhunk_lines])
    end
    flags = zero(Uint32) 
    if get(opts, :reverse, false)
        flags |= api.DIFF_REVERSE
    end
    if get(opts, :force_text, false)
        flags |= api.DIFF_FORCE_TEXT
    end
    if get(opts, :ignore_whitespace, false)
        flags |= api.DIFF_IGNORE_WHITESPACE
    end
    if get(opts, :ignore_whitespace_change, false)
        flags |= api.DIFF_IGNORE_WHITESPACE_CHANGE
    end
    if get(opts, :ignore_whitespace_eol, false)
        flags |= api.DIFF_IGNORE_WHITESPACE_EOL
    end
    if get(opts, :ignore_submodules, false)
        flags |= api.DIFF_IGNORE_SUBMODULES
    end
    if get(opts, :patience, false)
        flags |= api.DIFF_PATIENCE
    end
    if get(opts, :minimal, false)
        flags |= api.DIFF_MINIMAL
    end
    if get(opts, :include_ignored, false)
        flags |= api.DIFF_INCLUDE_IGNORED
    end
    if get(opts, :include_untracked, false)
        flags |= api.DIFF_INCLUDE_UNTRACKED
    end
    if get(opts, :include_unmodified, false)
        flags |= api.DIFF_INCLUDE_UNMODIFIED
    end
    if get(opts, :recurse_untracked_dirs, false)
       flags |= api.DIFF_RECURSE_UNTRACKED_DIRS
    end
    if get(opts, :disable_pathspec_match, false)
       flags |= api.DIFF_DISABLE_PATHSPEC_MATCH
    end
    if get(opts, :show_untracked_content, false)
       flags |= api.DIFF_SHOW_UNTRACKED_CONTENT
    end
    if get(opts, :skip_binary_check, false)
       flags |= api.DIFF_SKIP_BINARY_CHECK
    end
    if get(opts, :include_typechange, false)
       flags |= api.DIFF_INCLUDE_TYPECHANGE
    end
    if get(opts, :include_typechange_trees, false)
       flags |= api.DIFF_INCLUDE_TYPECHANGE_TREES
    end
    if get(opts, :ignore_filemode, false)
       flags |= api.DIFF_IGNORE_FILEMODE
    end
    if get(opts, :recurse_ignored_dirs, false)
       flags |= api.DIFF_RECURSE_IGNORED_DIRS
    end
    pathspec = StrArrayStruct()
    if haskey(opts, :paths)
        paths = opts[:paths]
        if !(isa(paths, Vector{ASCIIString}) || isa(paths, Vector{UTF8String}))
            throw(ArgumentError("opts[:paths] must be of type Array{ByteString}"))
        end
        str_ptrs = Array(Ptr{Uint8}, length(paths))
        for i in 1:length(paths)
            str_ptrs[i] = convert(Ptr{Uint8}, bytestring(paths[i]))
        end
        #XXX: this is just wrong 
        pathspec = StrArrayStruct(str_ptrs, length(paths))
    end
    #TODO: rest of the options
    return DiffOptionsStruct(api.DIFF_OPTIONS_VERSION,
                             flags,
                             api.SUBMODULE_IGNORE_DEFAULT,
                             pathspec,
                             zero(Ptr{Void}),
                             zero(Ptr{Void}),
                             context_lines,  # defaults to 3
                             interhunk_lines,
                             convert(Uint16, 0),
                             max_size,
                             zero(Ptr{Void}),
                             zero(Ptr{Void}))
end
