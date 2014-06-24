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
        ccall((:git_patch_free, :libgit2), Void, (Ptr{Void},), p.ptr)
        p.ptr = C_NULL
    end
end

Base.convert(::Type{Ptr{Void}}, p::GitPatch) = p.ptr

Base.diff(repo::Repository, blob::GitBlob, other::Nothing, opts=nothing) = begin
    old_path_ptr = zero(Ptr{Uint8})
    new_path_ptr = zero(Ptr{Uint8})
    if opts != nothing
        if get(opts, :old_path, nothing) != nothing
            old_path_ptr = convert(Ptr{Uint8}, opts[:old_path]::ByteString)
        end
        if get(opts, :new_path, nothing) != nothing
            new_path_ptr = convert(Ptr{Uint8}, opts[:new_path]::ByteString)
        end
    end
    gopts = parse_git_diff_options(opts)
    patch_ptr = Ptr{Void}[0]
    @check ccall((:git_patch_from_blobs, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Cchar}, Ptr{Void}, Ptr{Uint8}, Ptr{DiffOptionsStruct}),
                 patch_ptr, blob, old_path_ptr, C_NULL, new_path_ptr, &gopts)
    return GitPatch(patch_ptr[1])
end

Base.diff(repo::Repository, blob::GitBlob, other::GitBlob, opts=nothing) = begin
    old_path_ptr = zero(Ptr{Uint8})
    new_path_ptr = zero(Ptr{Uint8})
    if opts != nothing
        if get(opts, :old_path, nothing) != nothing
            old_path_ptr = convert(Ptr{Uint8}, pointer(opts[:old_path]::ByteString))
        end
        if get(opts, :new_path, nothing) != nothing
            new_path_ptr = convert(Ptr{Uint8}, pointer(opts[:new_path]::ByteString))
        end
    end
    gopts = parse_git_diff_options(opts)
    patch_ptr = Ptr{Void}[0]
    @check ccall((:git_patch_from_blobs, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}, Ptr{Void}, Ptr{Uint8}, Ptr{DiffOptionsStruct}),
                 patch_ptr, blob, old_path_ptr, other, new_path_ptr, &gopts)
    return GitPatch(patch_ptr[1])
end

Base.diff(repo::Repository, blob::GitBlob, other::String, opts= nothing) = begin
    old_path_ptr = zero(Ptr{Uint8})
    new_path_ptr = zero(Ptr{Uint8})
    if opts != nothing
        if get(opts, :old_path, nothing) != nothing
            old_path_ptr = convert(Ptr{Uint8}, pointer(opts[:old_path]::ByteString))
        end
        if get(opts, :new_path, nothing) != nothing
            new_path_ptr = convert(Ptr{Uint8}, pointer(opts[:new_path]::ByteString))
        end
    end
    gopts = parse_git_diff_options(opts)
    patch_ptr = Ptr{Void}[0]
    @check ccall((:git_patch_from_blob_and_buffer, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8},
                  Ptr{Cchar}, Csize_t, Ptr{Uint8}, Ptr{DiffOptionsStruct}),
                 patch_ptr, blob, old_path_ptr, buffer, length(buffer), new_path_ptr, &gopts)
    return GitPatch(patch_ptr[1])
end

type PatchStat
    adds::Int
    dels::Int
end

Base.stat(p::GitPatch) = begin
    adds = Csize_t[0]
    dels = Csize_t[0]
    @check ccall((:git_patch_line_stats, :libgit2), Cint,
                 (Ptr{Csize_t}, Ptr{Csize_t}, Ptr{Csize_t}, Ptr{Void}),
                 C_NULL, adds, dels, p)
    return PatchStat(int(adds[1]), int(dels[1]))
end

function nchanges(p::GitPatch)
    s = stat(p)
    return s.adds + s.dels
end

@eval begin
    $(Expr(:type, false, :HeaderStruct,
        Expr(:block, 
            [Expr(:(::), symbol("c$i"), :Uint8) for i=1:128]...)))
end

immutable DiffHunkStruct
    old_start::Cint
    old_lines::Cint
    new_start::Cint
    new_lines::Cint
    header_len::Csize_t
    header::HeaderStruct
end

type DiffHunk
    patch::GitPatch
    header::String 
    line_count::Int
    hunk_index::Int
    old_start::Int
    old_lines::Int
    new_start::Int 
    new_lines::Int

    function DiffHunk(p::GitPatch, ptr::Ptr{DiffHunkStruct}, idx::Integer, lc::Integer)
        @assert ptr != C_NULL
        h = unsafe_load(ptr)
        head_arr = zeros(Uint8, 128)
        head = h.header
        for i=1:128
            head_arr[i] = getfield(head, symbol("c$i"))
        end
        return new(p,
                   bytestring(convert(Ptr{Uint8}, head_arr)),
                   lc,
                   idx,
                   h.old_start,
                   h.old_lines,
                   h.new_start,
                   h.new_lines)
    end
end 

function hunks(p::GitPatch)
    nhunks = ccall((:git_patch_num_hunks, :libgit2), Csize_t, (Ptr{Void},), p)
    if nhunks == 0
        return nothing
    end
    err::Cint = 0
    hunk_ptr  = Ptr{DiffHunkStruct}[0]
    lines_ptr = Csize_t[0]
    hs = DiffHunk[]
    for i in 1:nhunks
        err = ccall((:git_patch_get_hunk, :libgit2), Cint,
                    (Ptr{Ptr{DiffHunkStruct}}, Ptr{Csize_t}, Ptr{Void}, Csize_t),
                    hunk_ptr, lines_ptr, p, i-1)
        if err != api.GIT_OK
            break
        end
        push!(hs, DiffHunk(p, hunk_ptr[1], i, lines_ptr[1]))
    end
    if err != api.GIT_OK
        throw(GitError(err))
    end
    return hs
end

function line_origin_to_symbol(o::Cchar)
    if o == api.DIFF_LINE_CONTEXT
        return :context
    end
    if o == api.DIFF_LINE_ADDITION
        return :addition
    end
    if o == api.DIFF_LINE_DELETION
        return :deletion
    end
    if o == api.DIFF_LINE_CONTEXT_EOFNL
        return :eof_no_newline
    end
    if o == api.DIFF_LINE_ADD_EOFNL
        return :eof_newline_added
    end
    if o == api.DIFF_LINE_DEL_EOFNL
        return :eof_newline_removed
    end
    return :unknown
end

type DiffLine
    hunk::DiffHunk
    line_origin::Symbol
    content::ByteString
    old_lineno::Int
    new_lineno::Int
    content_offset::Union(Nothing, Int)

    function DiffLine(h::DiffHunk, ptr::Ptr{DiffLineStruct})
        @assert ptr != C_NULL
        l = unsafe_load(ptr)
        c = Array(Uint8, l.content_len)
        for i in 1:l.content_len
            c[i] = unsafe_load(l.content, i)
        end
        return new(h,
                   line_origin_to_symbol(l.origin),
                   bytestring(convert(Ptr{Uint8}, c), l.content_len),
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
        err = ccall((:git_patch_get_line_in_hunk, :libgit2), Cint,
                    (Ptr{Ptr{DiffLineStruct}}, Ptr{Void}, Csize_t, Csize_t),
                    line_ptr, h.patch, hi-1, i-1)
        if err != api.GIT_OK 
            break
        end
        push!(ls, DiffLine(h, line_ptr[1]))
    end
    if err != api.GIT_OK
        throw(GitError(err))
    end
    return ls
end

#TODO: memory leaks?
#TODO: unsafe_pointer_to_objref for payload?
function cb_patch_print(delta_ptr::Ptr{Void}, hunk_ptr::Ptr{Void},
                        line_ptr::Ptr{DiffLineStruct}, payload::Ptr{Void})
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

const c_cb_patch_print = cfunction(cb_patch_print, Cint,
                                  (Ptr{Void}, Ptr{Void}, Ptr{DiffLineStruct}, Ptr{Void}))

Base.string(p::GitPatch) = begin
    s = Uint8[]
    @check ccall((:git_patch_print, api.libgit2), Cint,
                 (Ptr{Void}, Ptr{Void}, Any),
                 p, c_cb_patch_print, &s)
    return bytestring(convert(Ptr{Uint8}, s))
end

nhunks(p::GitPatch) = int(ccall((:git_patch_num_hunks, :libgit2), Cint, (Ptr{Void},), p))

function delta(p::GitPatch)
    delta_ptr = ccall((:git_patch_get_delta, :libgit2), Ptr{DiffDeltaStruct}, (Ptr{Void},), p)
    return DiffDelta(delta_ptr)
end

function line_stats(p::GitPatch)
    lines = Csize_t[0]
    additions = Csize_t[0]
    deletions = Csize_t[0]
    @check ccall((:git_patch_line_stats, :libgit2), Cint,
                 (Ptr{Csize_t}, Ptr{Csize_t}, Ptr{Csize_t}, Ptr{Void}),
                 lines, additions, deletions, p)
    return (int(lines[1]), int(additions[1]), int(deletions[1]))
end

nlines(p::GitPatch) = reduce(+, 0, line_stats(p))
