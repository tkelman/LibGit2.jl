export GitRevWalker, hide!, reset!, walk

abstract GitSortType
type SortDate <: GitSortType end 

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
    @check ccall((:git_revwalk_new, api.libgit2), Cint,
                  (Ptr{Ptr{Void}}, Ptr{Void}), wptr, r) 
    return GitRevWalker(r, wptr[1])
end

free!(w::GitRevWalker) = begin
    if w.ptr != C_NULL
        ccall((:git_revwalk_free, api.libgit2), Void, (Ptr{Void},), w.ptr)
        w.ptr = C_NULL
    end
end

Base.convert(::Type{Ptr{Void}}, w::GitRevWalker) = w.ptr

Base.start(w::GitRevWalker) = begin
    cid = Oid()
    err = ccall((:git_revwalk_next, api.libgit2), Cint,
                (Ptr{Oid}, Ptr{Void}), &cid, w)
    if err == api.ITEROVER
        return (nothing, true)
    elseif err != api.GIT_OK
        throw(LibGitError(err))
    end
    return (lookup_commit(w.repo, cid), false)
end

Base.done(w::GitRevWalker, state) = state[2]::Bool

Base.next(w::GitRevWalker, state) = begin
    cid = Oid()
    err = ccall((:git_revwalk_next, api.libgit2), Cint,
                (Ptr{Oid}, Ptr{Void}), &cid, w)
    if err == api.ITEROVER
        return (state[1], (nothing, true))
    elseif err != api.GIT_OK
        throw(LibGitError(err))
    end
    return (state[1], (lookup_commit(w.repo, cid), false))
end

Base.push!(w::GitRevWalker, cid::Oid) = begin
    @check ccall((:git_revwalk_push, api.libgit2), Cint,
                 (Ptr{Void}, Ptr{Oid}), w, &cid)
    return w 
end

function _symbol_to_gitsort(s::Symbol)
    s == :none && return api.SORT_NONE
    s == :topo && return api.SORT_TOPOLOGICAL
    s == :date && return api.SORT_TIME
    error("unknown git sort flag :$s")
end

#TODO: this does not mimic Base's sortby! functionality so it should be renamed
Base.sortby!(w::GitRevWalker, sort_mode::Symbol; rev::Bool=false) = begin
    s = _symbol_to_gitsort(sort_mode)
    rev && (s |= api.SORT_REVERSE)
    sortby!(w, s)
    return 
end

Base.sortby!(w::GitRevWalker, sort_mode::Cint) = begin
    ccall((:git_revwalk_sorting, api.libgit2), Void,
           (Ptr{Void}, Cint), w, sort_mode)
    return w 
end

function hide!(w::GitRevWalker, cid::Oid)
    @check ccall((:git_revwalk_hide, api.libgit2), Cint,
                 (Ptr{Void}, Ptr{Oid}), w, &cid)
    return w 
end

function reset!(w::GitRevWalker)
    ccall((:git_revwalk_reset, api.libgit2), Void, (Ptr{Void},), w)
    return w 
end

function walk(r::GitRepo, from::Oid, sorting=SortDate)
    walker = GitRevWalker(r)
    sortby!(walker, api.SORT_TIME)
    push!(walker, from)
    return (@task for c in walker
        produce(c)
    end)
end

# walk(repo, oid) do commit
      # do something with commit
# end
function walk(f::Function, r::GitRepo, from::Oid, sorting=SortDate)
    walker = GitRevWalker(r)
    sortby!(walker, api.SORT_TIME)
    push!(walker, from) 
    for c in walker
        f(c)
    end
    return 
end
