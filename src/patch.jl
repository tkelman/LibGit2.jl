export GitPatch, lines, DiffHunk, hunks

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
        api.git_patch_free(p.ptr)
        p.ptr = C_NULL
    end
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

    function DiffHunk(p::GitPatch, 
                      ptr::Ptr{api.GitDiffHunk}, 
                      idx::Integer,
                      lc::Integer)
        @assert ptr != C_NULL
        h = unsafe_load(ptr)
        head_arr = zeros(Cchar, h.header_len)
        for i in 1:h.header_len
            head_arr[i] = getfield(h, symbol("header$i"))
        end
        return new(p,
                   bytestring(convert(Ptr{Cchar}, head_arr)),
                   lc,
                   idx,
                   h.old_start,
                   h.old_lines,
                   h.new_start,
                   h.new_lines)
    end
end 

function hunks(p::GitPatch)
    @assert p.ptr != C_NULL
    nhunks = api.git_patch_num_hunks(p.ptr)
    if nhunks == 0
        return nothing
    end
    hunk_ptr = Array(Ptr{api.GitDiffHunk}, 1)
    lines_ptr = Csize_t[0]
    hs = DiffHunk[]
    for i in 1:nhunks
        err = api.git_patch_get_hunk(hunk_ptr, lines_ptr, p.ptr, i-1)
        if bool(err)
            break
        end
        @check_null hunk_ptr
        push!(hs, DiffHunk(p, hunk_ptr[1], i, lines_ptr[1]))
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
    content::String
    old_lineno::Int
    new_lineno::Int
    content_offset::Union(Nothing, Int)

    function DiffLine(h::DiffHunk, ptr::Ptr{api.GitDiffLine})
        @assert ptr != C_NULL
        l = unsafe_load(ptr)
        return new(h,
                   line_origin_to_symbol(l.origin),
                   bytestring(l.content),
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
    line_ptr = Array(Ptr{api.GitDiffLine}, 1) 
    for i in 1:lc
        err = api.git_patch_get_line_in_hunk(
                        line_ptr, h.patch.ptr, hi - 1, i-1)
        if err != 0
            break
        end
        @check_null line_ptr
        push!(ls, DiffLine(h, line_ptr[1]))
    end
    if err != api.GIT_OK
        throw(GitError(err))
    end
    return ls
end

function cb_patch_print(delta::Ptr{Void},
                        hunk::Ptr{Void},
                        line::Ptr{Void},
                        payload::Ptr{Void})
     return api.GIT_OK
 end

const c_cb_patch_print = cfunction(cb_patch_print, Cint,
                                   (Ptr{Void}, Ptr{Void}, Ptr{Void}, Ptr{Void}))
                                               
Base.string(p::GitPatch) = begin
    @assert p.ptr != C_NULL
    str = Array(Cchar, 1)
    #@check api.git_patch_print(p.ptr
end

function lines(p::GitPatch)
    @assert p.ptr != C_NULL
    ctx  = Array(Csize_t, 1)
    adds = Array(Csize_t, 1)
    dels = Array(Csize_t, 1)
    @check api.git_patch_line_stats(ctx, adds, dels, p.ptr)
    return ctx[1] + adds[1] + dels[1]
end

function nhunks(p::GitPatch)
    @assert p.ptr != C_NULL
    return int(api.git_patch_num_hunks(p.ptr))
end

function delta(p::GitPatch)
    @assert p.ptr != C_NULL
end

function line_stats(p::GitPatch)
    @assert p.ptr != C_NULL
    lines = Array(Csize_t, 1)
    additions = Array(Csize_t, 1)
    deletions = Array(Csize_t, 1)
    @check api.git_patch_line_stats(lines, additions, deletions, p.ptr)
    return (lines[1], additions[1], deletions[1])
end
