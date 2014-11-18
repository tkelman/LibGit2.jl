export GitRevWalker, hide!, reset!, walk, sortby!

type GitRevWalker
    repo::GitRepo
    ptr::Ptr{Void}

    function GitRevWalker(repo::GitRepo, ptr::Ptr{Void})
        @assert ptr != C_NULL
        w = new(repo, ptr)
        finalizer(w, free!)
        return w
    end
end

GitRevWalker(r::GitRepo) = begin
    wptr = Ptr{Void}[0]
    @check ccall((:git_revwalk_new, libgit2), Cint,
                  (Ptr{Ptr{Void}}, Ptr{Void}), wptr, r)
    return GitRevWalker(r, wptr[1])
end

free!(w::GitRevWalker) = begin
    if w.ptr != C_NULL
        ccall((:git_revwalk_free, libgit2), Void, (Ptr{Void},), w.ptr)
        w.ptr = C_NULL
    end
end

Base.convert(::Type{Ptr{Void}}, w::GitRevWalker) = w.ptr

Base.start(w::GitRevWalker) = begin
    id_ptr = [Oid()]
    err = ccall((:git_revwalk_next, libgit2), Cint, (Ptr{Oid}, Ptr{Void}), id_ptr, w)
    if err == GitErrorConst.ITEROVER
        return (nothing, true)
    elseif err != GitErrorConst.GIT_OK
        throw(LibGitError(err))
    end
    return (lookup_commit(w.repo, id_ptr[1]), false)
end

Base.done(w::GitRevWalker, state) = state[2]::Bool

Base.next(w::GitRevWalker, state) = begin
    id_ptr = [Oid()]
    err = ccall((:git_revwalk_next, libgit2), Cint,
                (Ptr{Oid}, Ptr{Void}), id_ptr, w)
    if err == GitErrorConst.ITEROVER
        return (state[1], (nothing, true))
    elseif err != GitErrorConst.GIT_OK
        throw(LibGitError(err))
    end
    return (state[1], (lookup_commit(w.repo, id_ptr[1]), false))
end

Base.push!(w::GitRevWalker, cid::Oid) = begin
    @check ccall((:git_revwalk_push, libgit2), Cint,
                 (Ptr{Void}, Ptr{Oid}), w, &cid)
    return w
end

function sortby!(w::GitRevWalker, sort_mode::Symbol; rev::Bool=false)
    s = sort_mode === :none ? GitConst.SORT_NONE :
        sort_mode === :topo ? GitConst.SORT_TOPOLOGICAL :
        sort_mode === :date ? GitConst.SORT_TIME :
        throw(ArgumentError("unknown git sort flag :$s"))
    rev && (s |= GitConst.SORT_REVERSE)
    sortby!(w, s)
    return
end

function sortby!(w::GitRevWalker, sort_mode::Cint)
    ccall((:git_revwalk_sorting, libgit2), Void,
           (Ptr{Void}, Cint), w, sort_mode)
    return w
end

function hide!(w::GitRevWalker, id::Oid)
    @check ccall((:git_revwalk_hide, libgit2), Cint,
                 (Ptr{Void}, Ptr{Oid}), w, &id)
    return w
end

function reset!(w::GitRevWalker)
    ccall((:git_revwalk_reset, libgit2), Void, (Ptr{Void},), w)
    return w
end

function walk(r::GitRepo, from::Oid, sort_mode::Symbol=:date, rev::Bool=false)
    walker = GitRevWalker(r)
    sortby!(walker, sort_mode, rev=rev)
    push!(walker, from)
    return (@task for c in walker
        produce(c)
    end)
end

# walk(repo, oid) do commit
      # do something with commit
# end
function walk(f::Function, r::GitRepo, from::Oid, sort_mode::Symbol=:date, rev::Bool=false)
    walker = GitRevWalker(r)
    sortby!(walker, sort_mode, rev=rev)
    push!(walker, from)
    for c in walker
        f(c)
    end
    return
end
