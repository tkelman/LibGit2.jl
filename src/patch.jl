export GitPatch, lines, nlines, DiffHunk, hunks, nchanges, delta

type GitPatch
    ptr::Ptr{Void}

    function GitPatch(ptr::Ptr{Void})
        @assert ptr != C_NULL
        p = new(ptr)
        finalizer(p, free!)
        return p
    end
end

function free!(p::GitPatch)
    if p.ptr != C_NULL
        ccall((:git_patch_free, libgit2), Void, (Ptr{Void},), p.ptr)
        p.ptr = C_NULL
    end
end

Base.convert(::Type{Ptr{Void}}, p::GitPatch) = p.ptr

Base.diff(repo::GitRepo, blob::GitBlob, other::Void, opts=nothing) = begin
    new_path_ptr = Ptr{UInt8}(0)
    old_path_ptr = Ptr{UInt8}(0)
    if opts != nothing
        if get(opts, :old_path, nothing) != nothing
            old_path = convert(Ptr{UInt8}, opts[:old_path]::AbstractString)
        end
        if get(opts, :new_path, nothing) != nothing
            new_path = convert(Ptr{UInt8}, opts[:new_path]::AbstractString)
        end
    end
    gopts = parse_git_diff_options(opts)
    patch_ptr = Ptr{Void}[0]
    @check ccall((:git_patch_from_blobs, libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{UInt8}, Ptr{Void}, Ptr{UInt8}, Ptr{DiffOptionsStruct}),
                 patch_ptr, blob, old_path_ptr, C_NULL, new_path_ptr, &gopts)
    return GitPatch(patch_ptr[1])
end

Base.diff(repo::GitRepo, blob::GitBlob, other::GitBlob, opts::MaybeDict=nothing) = begin
    new_path_ptr = Ptr{UInt8}(0)
    old_path_ptr = Ptr{UInt8}(0)
    if opts != nothing
        if get(opts, :old_path, nothing) != nothing
            old_path_ptr = convert(Ptr{UInt8}, opts[:old_path]::AbstractString)
        end
        if get(opts, :new_path, nothing) != nothing
            new_path_ptr = convert(Ptr{UInt8}, opts[:new_path]::AbstractString)
        end
    end
    gopts = parse_git_diff_options(opts)
    patch_ptr = Ptr{Void}[0]
    @check ccall((:git_patch_from_blobs, libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{UInt8}, Ptr{Void}, Ptr{UInt8}, Ptr{DiffOptionsStruct}),
                 patch_ptr, blob, old_path_ptr, other, new_path_ptr, &gopts)
    return GitPatch(patch_ptr[1])
end

Base.diff(repo::GitRepo, blob::GitBlob, other::AbstractString, opts::MaybeDict=nothing) = begin
    old_path_ptr = Ptr{UInt8}(0)
    new_path_ptr = Ptr{UInt8}(0)
    if opts != nothing
        if get(opts, :old_path, nothing) != nothing
            old_path_ptr = convert(Ptr{UInt8}, opts[:old_path]::AbstractString)
        end
        if get(opts, :new_path, nothing) != nothing
            new_path_ptr = convert(Ptr{UInt8}, opts[:new_path]::AbstractString)
        end
    end
    gopts = parse_git_diff_options(opts)
    patch_ptr = Ptr{Void}[0]
    @check ccall((:git_patch_from_blob_and_buffer, libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{UInt8},
                  Ptr{UInt8}, Csize_t, Ptr{UInt8}, Ptr{DiffOptionsStruct}),
                 patch_ptr, blob, old_path_ptr, buffer, length(buffer), new_path_ptr, &gopts)
    return GitPatch(patch_ptr[1])
end

type GitPatchStat
    adds::Int
    dels::Int
end

Base.stat(p::GitPatch) = begin
    adds = Csize_t[0]
    dels = Csize_t[0]
    @check ccall((:git_patch_line_stats, libgit2), Cint,
                 (Ptr{Csize_t}, Ptr{Csize_t}, Ptr{Csize_t}, Ptr{Void}),
                 C_NULL, adds, dels, p)
    return GitPatchStat(int(adds[1]), int(dels[1]))
end

nchanges(p::GitPatch) = (s = stat(p); s.adds + s.dels)

type DiffHunk
    patch::GitPatch
    header::UTF8String
    line_count::Int
    hunk_index::Int
    old_start::Int
    old_lines::Int
    new_start::Int
    new_lines::Int

    function DiffHunk(p::GitPatch, ptr::Ptr{DiffHunkStruct}, idx::Integer, lc::Integer)
        @assert ptr != C_NULL
        h = unsafe_load(ptr)::DiffHunkStruct
        head_arr = zeros(UInt8, 128)
        #TODO: get rid of this ugly hack
        for i=1:128
            head_arr[i] = getfield(h.header, symbol("c$i"))
        end
        return new(p,
                   utf8(bytestring(convert(Ptr{UInt8}, head_arr))),
                   lc,
                   idx,
                   h.old_start,
                   h.old_lines,
                   h.new_start,
                   h.new_lines)
    end
end

function hunks(p::GitPatch)
    nhunks = ccall((:git_patch_num_hunks, libgit2), Csize_t, (Ptr{Void},), p)
    if nhunks == 0
        return nothing
    end
    err = Cint(0)
    hunk_ptr  = Ptr{DiffHunkStruct}[0]
    lines_ptr = Csize_t[0]
    hs = DiffHunk[]
    for i in 1:nhunks
        err = ccall((:git_patch_get_hunk, libgit2), Cint,
                    (Ptr{Ptr{DiffHunkStruct}}, Ptr{Csize_t}, Ptr{Void}, Csize_t),
                    hunk_ptr, lines_ptr, p, i-1)
        err == GitErrorConst.GIT_OK || break
        push!(hs, DiffHunk(p, hunk_ptr[1], i, lines_ptr[1]))
    end
    if err != GitErrorConst.GIT_OK
        throw(GitError(err))
    end
    return hs
end

function line_origin_to_symbol(o)
    o == GitConst.DIFF_LINE_CONTEXT   && return :context
    o == GitConst.DIFF_LINE_ADDITION  && return :addition
    o == GitConst.DIFF_LINE_DELETION  && return :deletion
    o == GitConst.DIFF_LINE_ADD_EOFNL && return :eof_newline_added
    o == GitConst.DIFF_LINE_DEL_EOFNL && return :eof_newline_removed
    o == GitConst.DIFF_LINE_CONTEXT_EOFNL && return :eof_no_newline
    throw(ArgumentError("Unknown line origin constant $o"))
end

type DiffLine
    hunk::DiffHunk
    line_origin::Symbol
    content::ByteString
    old_lineno::Int
    new_lineno::Int
    content_offset::Union(Void, Int64)

    function DiffLine(h::DiffHunk, ptr::Ptr{DiffLineStruct})
        @assert ptr != C_NULL
        l = unsafe_load(ptr)::DiffLineStruct
        c = Array(UInt8, l.content_len)
        for i in 1:l.content_len
            c[i] = unsafe_load(l.content, i)
        end
        return new(h,
                   line_origin_to_symbol(l.origin),
                   bytestring(convert(Ptr{UInt8}, c), l.content_len),
                   l.old_lineno,
                   l.new_lineno,
                   l.content_offset == -1 ? nothing : l.content_offset)
    end
end

function lines(h::DiffHunk)
    err::Cint = 0
    ls = DiffLine[]
    lc = h.line_count
    hi = h.hunk_index
    line_ptr = Ptr{DiffLineStruct}[0]
    for i in 1:lc
        err = ccall((:git_patch_get_line_in_hunk, libgit2), Cint,
                    (Ptr{Ptr{DiffLineStruct}}, Ptr{Void}, Csize_t, Csize_t),
                    line_ptr, h.patch, hi-1, i-1)
        err == GitErrorConst.GIT_OK || break
        push!(ls, DiffLine(h, line_ptr[1]))
    end
    if err != GitErrorConst.GIT_OK
        throw(GitError(err))
    end
    return ls
end

function cb_patch_print(delta_ptr::Ptr{Void}, hunk_ptr::Ptr{Void},
                        line_ptr::Ptr{DiffLineStruct}, payload::Ptr{Void})
    l = unsafe_load(line_ptr)::DiffLineStruct
    s = unsafe_pointer_to_objref(payload)::Vector{UInt8}
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

const c_cb_patch_print = cfunction(cb_patch_print, Cint,
                                  (Ptr{Void}, Ptr{Void}, Ptr{DiffLineStruct}, Ptr{Void}))

Base.string(p::GitPatch) = begin
    s = UInt8[]
    @check ccall((:git_patch_print, libgit2), Cint,
                 (Ptr{Void}, Ptr{Void}, Any), p, c_cb_patch_print, &s)
    return utf8(bytestring(convert(Ptr{UInt8}, s)))
end

nhunks(p::GitPatch) = int(ccall((:git_patch_num_hunks, libgit2), Cint, (Ptr{Void},), p))

function delta(p::GitPatch)
    delta_ptr = ccall((:git_patch_get_delta, libgit2), Ptr{DiffDeltaStruct}, (Ptr{Void},), p)
    return DiffDelta(delta_ptr)
end

function line_stats(p::GitPatch)
    lines = Csize_t[0]
    additions = Csize_t[0]
    deletions = Csize_t[0]
    @check ccall((:git_patch_line_stats, libgit2), Cint,
                 (Ptr{Csize_t}, Ptr{Csize_t}, Ptr{Csize_t}, Ptr{Void}),
                 lines, additions, deletions, p)
    return (int(lines[1]), int(additions[1]), int(deletions[1]))
end

nlines(p::GitPatch) = reduce(+, 0, line_stats(p))
