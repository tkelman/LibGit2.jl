export GitPatch, lines

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

