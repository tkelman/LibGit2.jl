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
        ccall((:git_diff_free, libgit2), Void, (Ptr{Void},), d.ptr)
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

function cb_diff_file_stats(delta_ptr::Ptr{DiffDeltaStruct}, progress::Cfloat, payload::Ptr{Void})
    delta = unsafe_load(delta_ptr)::DiffDeltaStruct
    stats = unsafe_pointer_to_objref(payload)::DiffStats
    if delta.status == GitConst.DELTA_ADDED ||
       delta.status == GitConst.DELTA_DELETED ||
       delta.status == GitConst.DELTA_MODIFIED ||
       delta.status == GitConst.DELTA_RENAMED ||
       delta.status == GitConst.DELTA_COPIED ||
       delta.status == GitConst.DELTA_TYPECHANGE
        stats.files += 1
    end
    return GitErrorConst.GIT_OK
end

const c_cb_diff_file_stats = cfunction(cb_diff_file_stats, Cint,
                                       (Ptr{DiffDeltaStruct}, Cfloat, Ptr{Void}))

function cb_diff_line_stats(delta_ptr::Ptr{Void},
                            hunk_ptr::Ptr{Void},
                            line_ptr::Ptr{DiffLineStruct},
                            payload::Ptr{Void})
    line  = unsafe_load(line_ptr)
    stats = unsafe_pointer_to_objref(payload)::DiffStats
    if line.origin == GitConst.DIFF_LINE_ADDITION
        stats.adds += 1
    elseif line.origin == GitConst.DIFF_LINE_DELETION
        stats.dels += 1
    end
    return GitErrorConst.GIT_OK
end

const c_cb_diff_line_stats = cfunction(cb_diff_line_stats, Cint,
                                       (Ptr{Void}, Ptr{Void}, Ptr{DiffLineStruct}, Ptr{Void}))
Base.stat(d::GitDiff) = begin
    stats = DiffStats()
    ccall((:git_diff_foreach, libgit2), Void,
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

DiffFile(struct::DiffFileStruct) = begin
    DiffFile(Oid(string(struct.id)),
             bytestring(struct.path),
             struct.size,
             struct.flags,
             struct.mode)
end

function delta_status_symbol(s::Integer)
    s == GitConst.DELTA_UNMODIFIED && return :unmodified
    s == GitConst.DELTA_ADDED      && return :added
    s == GitConst.DELTA_DELETED    && return :deleted
    s == GitConst.DELTA_MODIFIED   && return :modified
    s == GitConst.DELTA_RENAMED    && return :renamed
    s == GitConst.DELTA_COPIED     && return :copied
    s == GitConst.DELTA_IGNORED    && return :ignored
    s == GitConst.DELTA_UNTRACKED  && return :untracked
    s == GitConst.DELTA_TYPECHANGE && return :typechange
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
        d = unsafe_load(ptr)::DiffDeltaStruct
        old_file_id = Oid(hex(d.old_file.id))
        fold = DiffFile(old_file_id,
                        d.old_file.path != C_NULL ? bytestring(d.old_file.path) : "",
                        int(d.old_file.size),
                        int(d.old_file.flags),
                        int(d.old_file.mode))
        new_file_id = Oid(hex(d.new_file.id))
        fnew = DiffFile(new_file_id,
                        d.new_file.path != C_NULL ? bytestring(d.new_file.path) : "",
                        int(d.new_file.size),
                        int(d.new_file.flags),
                        int(d.new_file.mode))
        return new(fold, fnew, int(d.similarity), delta_status_symbol(d.status),
                   (bool(d.flags & GitConst.DIFF_FLAG_NOT_BINARY) &&
                    bool(d.flags & GitConst.DIFF_FLAG_BINARY)))
    end
end

Base.length(d::GitDiff) = int(ccall((:git_diff_num_deltas, libgit2), Csize_t, (Ptr{Void},), d))

function deltas(d::GitDiff)
    ndelta = length(d)
    if ndelta == 0
        return nothing
    end
    ds = Array(DiffDelta, ndelta)
    for i in 1:ndelta
        delta_ptr = ccall((:git_diff_get_delta, libgit2), Ptr{DiffDeltaStruct},
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
    err = Cint(0)
    for i in 1:ndelta
        err = ccall((:git_patch_from_diff, libgit2), Cint,
                    (Ptr{Ptr{Void}}, Ptr{Void}, Csize_t), patch_ptr, d, i-1)
        if err != GitErrorConst.GIT_OK
            break
        end
        push!(ps, GitPatch(patch_ptr[1]))
    end
    if err != GitErrorConst.GIT_OK
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
    s = unsafe_pointer_to_objref(payload)::Array{UInt8,1}
    add_origin = false
    if l.origin == GitConst.DIFF_LINE_CONTEXT ||
       l.origin == GitConst.DIFF_LINE_ADDITION ||
       l.origin == GitConst.DIFF_LINE_DELETION
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
    return GitErrorConst.GIT_OK
end

const c_cb_diff_print = cfunction(cb_diff_print, Cint, (Ptr{Void}, Ptr{Void}, Ptr{DiffLineStruct}, Ptr{Void}))

function patch(d::GitDiff; format::Symbol=:patch)
    cformat = Cint(0)
    if format === :name_status
        cformat = GitConst.DIFF_FORMAT_NAME_STATUS
    elseif format === :name_only
        cformat = GitConst.DIFF_FORMAT_NAME_ONLY
    elseif format === :raw
        cformat = GitConst.DIFF_FORMAT_RAW
    elseif format === :header
        cformat = GitConst.DIFF_FORMAT_PATCH_HEADER
    elseif format === :patch
        cformat = GitConst.DIFF_FORMAT_PATCH
    else
        throw(ArgumentError(("Unknown diff output format ($format)")))
    end
    s = UInt8[]
    ccall((:git_diff_print, libgit2), Cint,
           (Ptr{Void}, Cint, Ptr{Void}, Any), d, cformat, c_cb_diff_print, &s)
    return UTF8String(s)
end

# diffable GitTree, GitCommit, GitIndex, or Void
typealias Diffable Union(GitTree, GitCommit, GitIndex, Void)

Base.diff(repo::GitRepo, left::Void, right::Void, opts::MaybeDict=nothing) = nothing

Base.diff(repo::GitRepo, left::MaybeString, right::MaybeString, opts::MaybeDict=nothing) = begin
    l = left  != nothing ? revparse(repo, left)  : nothing
    r = right != nothing ? revparse(repo, right) : nothing
    if l != nothing
        return diff(repo, l, r, opts)
    elseif r != nothing
        opts = opts == nothing ? Dict{Any,Any}() : opts
        return diff(repo, l, r,
                merge(opts, Dict{Any,Any}(:reverse => !get(opts, :reverse, true))))
    end
    return nothing
end

Base.diff(repo::GitRepo, left::GitCommit, right::GitCommit, opts::MaybeDict=nothing) = begin
    return diff(repo, GitTree(left), GitTree(right), opts)
end

Base.diff(repo::GitRepo, left::GitCommit, right::Void, opts::MaybeDict=nothing) = begin
    return diff(repo, GitTree(left), nothing, opts)
end

Base.diff(repo::GitRepo, left::Void, right::GitCommit, opts::MaybeDict=nothing) = begin
    return diff(repo, nothing, GitTree(right), opts)
end

Base.diff(repo::GitRepo, c::GitCommit, opts::MaybeDict=nothing) = begin
    ps = parents(c)
    if length(ps) > 0
        return diff(repo, GitTree(c), GitTree(ps[1]), opts)
    else
        return diff(repo, GitTree(c), nothing, opts)
    end
end

Base.diff(repo::GitRepo, left::GitTree, right::AbstractString, opts::MaybeDict=nothing) = begin
    return diff(repo, left, revparse(repo, right), opts)
end

Base.diff(repo::GitRepo, left::GitTree, right::GitCommit, opts::MaybeDict=nothing) = begin
    return diff(repo, left, GitTree(right), opts)
end

typealias MaybeGitTree Union(Void, GitTree)

Base.diff(repo::GitRepo, left::MaybeGitTree, right::MaybeGitTree, opts::MaybeDict=nothing) = begin
    gopts = parse_git_diff_options(opts)
    diff_ptr = Ptr{Void}[0]
    @check ccall((:git_diff_tree_to_tree, libgit2), Cint,
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
    free!(gopts.pathspec)
    return GitDiff(diff_ptr[1])
end

Base.diff(repo::GitRepo, left::Oid, right::Oid, opts::MaybeDict=nothing) = begin
    return diff(repo, lookup(repo, left), lookup(repo, right), opts)
end

Base.diff(repo::GitRepo, left::AbstractString, right::GitIndex, opts::MaybeDict=nothing) = begin
    return diff(repo, revparse(repo, left), right, opts)
end

Base.diff(repo::GitRepo, left::GitCommit, right::GitIndex, opts::MaybeDict=nothing) = begin
    return diff(repo, GitTree(left), right, opts)
end

Base.diff(repo::GitRepo, left::GitTree, right::GitIndex, opts::MaybeDict=nothing) = begin
    gopts = parse_git_diff_options(opts)
    diff_ptr = Ptr{Void}[0]
    @check ccall((:git_diff_tree_to_index, libgit2), Cint,
                 (Ptr{Ptr{Void}},
                  Ptr{Void},
                  Ptr{Void},
                  Ptr{Void},
                  Ptr{DiffOptionsStruct}),
                 diff_ptr, repo, left, right, &gopts)
    free!(gopts.pathspec)
    return GitDiff(diff_ptr[1])
end

Base.diff(repo::GitRepo, idx::GitIndex, opts::MaybeDict=nothing) = begin
    return diff(repo, idx, nothing, opts)
end

Base.diff(repo::GitRepo, idx::GitIndex, other::Void, opts::MaybeDict=nothing) = begin
    gopts = parse_git_diff_options(opts)
    diff_ptr = Ptr{Void}[0]
    @check ccall((:git_diff_index_to_workdir, libgit2), Cint,
                  (Ptr{Ptr{Void}},
                   Ptr{Void},
                   Ptr{Void},
                   Ptr{DiffOptionsStruct}),
                  diff_ptr, repo, idx, &gopts)
    free!(gopts.pathspec)
    return GitDiff(diff_ptr[1])
end

Base.diff(repo::GitRepo, idx::GitIndex, other::GitCommit, opts::MaybeDict=nothing) = begin
    return diff(repo, idx, GitTree(other), opts)
end

Base.diff(repo::GitRepo, idx::GitIndex, other::GitTree, opts::MaybeDict=nothing) = begin
    gopts = parse_git_diff_options(opts)
    diff_ptr = Ptr{Void}[0]
    @check ccall((:git_diff_tree_to_index, libgit2), Cint,
                 (Ptr{Ptr{Void}},
                  Ptr{Void},
                  Ptr{Void},
                  Ptr{Void},
                  Ptr{DiffOptionsStruct}),
                  diff_ptr, repo, other, idx, &gopts)
    free!(gopts.pathspec)
    return GitDiff(diff_ptr[1])
end

Base.merge!(d1::GitDiff, d2::GitDiff) = begin
    @check ccall((:git_diff_merge, libgit2), Cint, (Ptr{Void}, Ptr{Void}), d1, d2)
    return d1
end

function diff_workdir(repo::GitRepo, opts::MaybeDict=nothing)
    gopts = parse_git_diff_options(opts)
    diff_ptr = Ptr{Void}[0]
    @check ccall((:git_diff_index_to_workdir, libgit2), Cint,
                 (Ptr{Ptr{Void}},
                  Ptr{Void},
                  Ptr{Void},
                  Ptr{DiffOptionsStruct}),
                 diff_ptr, repo, C_NULL, &gopts)
    free!(gopts.pathspec)
    return GitDiff(diff_ptr[1])
end

function diff_workdir(repo::GitRepo, left::AbstractString, opts::MaybeDict=nothing)
    return diff_workdir(repo, revparse(repo, left), opts)
end

function diff_workdir(repo::GitRepo, left::GitCommit, opts::MaybeDict=nothing)
    return diff_workdir(repo, GitTree(left), opts)
end

function diff_workdir(repo::GitRepo, left::GitTree, opts::MaybeDict=nothing)
    gopts = parse_git_diff_options(opts)
    diff_ptr = Ptr{Void}[0]
    @check ccall((:git_diff_tree_to_workdir, libgit2), Cint,
                 (Ptr{Ptr{Void}},
                  Ptr{Void},
                  Ptr{Void},
                  Ptr{DiffOptionsStruct}),
                 diff_ptr, repo, left, &gopts)
    free!(gopts.pathspec)
    return GitDiff(diff_ptr[1])
end

parse_git_diff_options(o::Void) = DiffOptionsStruct()

function parse_git_diff_options(opts::Dict)
    max_size = Coff_t(0)
    if haskey(opts, :max_size)
        max_size = convert(Coff_t, opts[:max_size])
    end
    context_lines = UInt16(3)
    if haskey(opts, :context_lines)
        @assert opts[:context_lines] <= typemax(UInt16)
        context_lines = convert(UInt16, opts[:context_lines])
    end
    interhunk_lines = UInt16(0)
    if haskey(opts, :interhunk_lines)
        @assert opts[:interhunk_lines] <= typemax(UInt16)
        interhunk_lines = convert(UInt16, opts[:interhunk_lines])
    end
    flags = UInt32(0)
    if get(opts, :reverse, false)
        flags |= GitConst.DIFF_REVERSE
    end
    if get(opts, :force_text, false)
        flags |= GitConst.DIFF_FORCE_TEXT
    end
    if get(opts, :ignore_whitespace, false)
        flags |= GitConst.DIFF_IGNORE_WHITESPACE
    end
    if get(opts, :ignore_whitespace_change, false)
        flags |= GitConst.DIFF_IGNORE_WHITESPACE_CHANGE
    end
    if get(opts, :ignore_whitespace_eol, false)
        flags |= GitConst.DIFF_IGNORE_WHITESPACE_EOL
    end
    if get(opts, :ignore_submodules, false)
        flags |= GitConst.DIFF_IGNORE_SUBMODULES
    end
    if get(opts, :patience, false)
        flags |= GitConst.DIFF_PATIENCE
    end
    if get(opts, :minimal, false)
        flags |= GitConst.DIFF_MINIMAL
    end
    if get(opts, :include_ignored, false)
        flags |= GitConst.DIFF_INCLUDE_IGNORED
    end
    if get(opts, :include_untracked, false)
        flags |= GitConst.DIFF_INCLUDE_UNTRACKED
    end
    if get(opts, :include_unmodified, false)
        flags |= GitConst.DIFF_INCLUDE_UNMODIFIED
    end
    if get(opts, :recurse_untracked_dirs, false)
       flags |= GitConst.DIFF_RECURSE_UNTRACKED_DIRS
    end
    if get(opts, :disable_pathspec_match, false)
       flags |= GitConst.DIFF_DISABLE_PATHSPEC_MATCH
    end
    if get(opts, :show_untracked_content, false)
       flags |= GitConst.DIFF_SHOW_UNTRACKED_CONTENT
    end
    if get(opts, :skip_binary_check, false)
       flags |= GitConst.DIFF_SKIP_BINARY_CHECK
    end
    if get(opts, :include_typechange, false)
       flags |= GitConst.DIFF_INCLUDE_TYPECHANGE
    end
    if get(opts, :include_typechange_trees, false)
       flags |= GitConst.DIFF_INCLUDE_TYPECHANGE_TREES
    end
    if get(opts, :ignore_filemode, false)
       flags |= GitConst.DIFF_IGNORE_FILEMODE
    end
    if get(opts, :recurse_ignored_dirs, false)
       flags |= GitConst.DIFF_RECURSE_IGNORED_DIRS
    end
    if haskey(opts, :paths)
        paths = opts[:paths]
        if !(isa(paths, Vector{ASCIIString}) || isa(paths, Vector{UTF8String}))
            throw(ArgumentError("opts[:paths] must be of type Vector{ByteString}"))
        end
        pathspec = StrArrayStruct(paths)
    else
        pathspec = StrArrayStruct()
    end
    #TODO: rest of the options
    return DiffOptionsStruct(GitConst.DIFF_OPTIONS_VERSION,
                             flags,
                             GitConst.SUBMODULE_IGNORE_DEFAULT,
                             pathspec,
                             C_NULL,
                             C_NULL,
                             context_lines,  # defaults to 3
                             interhunk_lines,
                             0,
                             max_size,
                             C_NULL,
                             C_NULL)
end
