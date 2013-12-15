export Repository, repo_isbare, repo_isempty, repo_workdir, repo_path,
       repo_open, repo_init, repo_index, head, tags, commits, references,
       repo_lookup, repo_lookup_tree, repo_lookup_commit, commit,
       repo_revparse_single, create_ref, create_sym_ref, lookup_ref,
       repo_odb, iter_refs, repo_config

type Repository
    ptr::Ptr{Void}

    function Repository(ptr::Ptr{Void})
        if ptr == C_NULL
            throw(ArgumentError("Repository initialized with NULL pointer"))
        end
        r = new(ptr)
        finalizer(r, free!)
        return r
    end
end

free!(r::Repository) = begin
    if r.ptr != C_NULL
        api.git_repository_free(r.ptr)
        r.ptr = C_NULL
    end
end

Repository(path::String) = begin
    bpath = bytestring(path)
    repo_ptr = Array(Ptr{Void}, 1)
    err_code = api.git_repository_open(repo_ptr, bpath)
    if err_code < 0
        if repo_ptr[1] != C_NULL
            api.git_repository_free(repo_ptr[1])
        end
        throw(GitError(err_code))
    end
    @check_null repo_ptr
    return Repository(repo_ptr[1])
end

function repo_isbare(r::Repository)
    @assert r.ptr != C_NULL
    res = api.git_repository_is_bare(r.ptr)
    return res > 0 ? true : false
end

function repo_isempty(r::Repository)
    @assert r.ptr != C_NULL
    res = api.git_repository_is_empty(r.ptr) 
    return res > 0 ? true : false
end

function repo_workdir(r::Repository)
    @assert r.ptr != C_NULL
    res = api.git_repository_workdir(r.ptr)
    if res == C_NULL
        return nothing
    end
    # remove trailing slash
    return bytestring(res)[1:end-1]
end

function repo_path(r::Repository)
    @assert r.ptr != C_NULL
    cpath = api.git_repository_path(r.ptr)
    if cpath == C_NULL
        return nothing
    end
    # remove trailing slash
    return bytestring(cpath)[1:end-1]
end

function repo_head_orphaned(r::Repository)
end

function repo_head_detached(r::Repository)
end

function repo_open(path::String)
    Repository(path)
end

function repo_init(path::String; bare::Bool=false)
    bpath = bytestring(path)
    repo_ptr = Array(Ptr{Void}, 1)
    err_code = api.git_repository_init(repo_ptr, bpath, bare? 1 : 0)
    if err_code < 0
        if repo_ptr[1] != C_NULL
            api.git_repository_free(repo_ptr[1])
        end
        throw(GitError(err_code))
    end
    @check_null repo_ptr
    return Repository(repo_ptr[1])
end


function repo_clone(url::String; 
                    repobare::Bool=false,
                    ignore_cert_errors::Bool=false,
                    remote_name::String="origin",
                    checkout_branch=nothing)
end

function head(r::Repository)
    return nothing
end

function commits(r::Repository)
    return nothing 
end

function tags(r::Repository)
    return nothing
end

function references(r::Repository)
    return nothing
end


function repo_discover(url::String)
end


function repo_config(r::Repository)
    @assert r.ptr != C_NULL
    config_ptr = Array(Ptr{Void}, 1)
    @check api.git_repository_config(config_ptr, r.ptr)
    @check_null config_ptr
    return GitConfig(config_ptr[1])
end

function repo_odb(r::Repository)
    @assert r.ptr != C_NULL
    odb_ptr = Array(Ptr{Void}, 1)
    @check api.git_repository_odb(odb_ptr, r.ptr)
    @check_null odb_ptr
    return Odb(odb_ptr[1])
end

function repo_index(r::Repository)
    @assert r.ptr != C_NULL
    idx_ptr = Array(Ptr{Void}, 1)
    @check api.git_repository_index(idx_ptr, r.ptr)
    @check_null idx_ptr
    return Index(idx_ptr[1])
end

function repo_lookup{T<:GitObject}(::Type{T}, r::Repository, id::Oid)
    @assert r.ptr != C_NULL
    obj_ptr = Array(Ptr{Void}, 1)
    @check api.git_object_lookup(obj_ptr, r.ptr, id.oid, git_otype(T))
    @check_null obj_ptr
    return T(obj_ptr[1])
end

function repo_lookup(r::Repository, id::Oid)
    @assert r.ptr != C_NULL
    obj_ptr = Array(Ptr{Void}, 1)
    @check api.git_object_lookup(obj_ptr, r.ptr, id.oid, api.OBJ_ANY)
    @check_null obj_ptr
    return gitobj_from_ptr(obj_ptr[1]) 
end

repo_lookup_tree(r::Repository, id::Oid) = repo_lookup(GitTree, r, id)
repo_lookup_blob(r::Repository, id::Oid) = repo_lookup(GitBlob, r, id)
repo_lookup_commit(r::Repository, id::Oid) = repo_lookup(GitCommit, r, id)

function lookup_ref(r::Repository, refname::String)
    @assert r.ptr != C_NULL
    bname = bytestring(refname)
    ref_ptr = Array(Ptr{Void}, 1)
    @check api.git_reference_lookup(ref_ptr, r.ptr, bname)
    @check_null ref_ptr
    return GitReference(ref_ptr[1])
end


function create_ref(r::Repository, refname::String,
                    id::Oid, force::Bool=false)
    @assert r.ptr != C_NULL
    bname = bytestring(refname)
    ref_ptr = Array(Ptr{Void}, 1)
    @check api.git_reference_create(ref_ptr, r.ptr, bname,
                                    id.oid, force? 1 : 0)
    @check_null ref_ptr
    return GitReference(ref_ptr[1])
end


function create_sym_ref(r::Repository, refname::String,
                        target::String, force::Bool=false)
    @assert r.ptr != C_NUL
    bname = bytestring(refname)
    ref_ptr = Array(Ptr{Void}, 1)
    @check api.git_reference_symbolic_create(ref_ptr, r.ptr, bname,
                                             id.oid, force? 1 : 0)
    @check_null ref_ptr
    return GitReference(ref_ptr[1])
end


function repo_walk(r::Repository)
end


function commit(r::Repository,
                refname::String,
                author::Signature,
                committer::Signature,
                msg::String,
                tree::GitTree,
                parents::GitCommit...)
    @assert r.ptr != C_NULL
    @assert tree.ptr != C_NULL
    commit_oid  = Oid()
    bref = bytestring(refname)
    bmsg = bytestring(msg)
    nparents = convert(Cint, length(parents))
    cparents = Array(Ptr{Void}, nparents)
    if nparents > zero(Cint)
        for (i, commit) in enumerate(parents)
            @assert commit.ptr != C_NULL
            cparents[i] = commit.ptr

        end
    end
    #TODO: encoding?
    err_code = ccall((:git_commit_create, api.libgit2), Cint,
                     (Ptr{Uint8}, Ptr{Void}, Ptr{Cchar}, 
                      Ptr{api.Signature}, Ptr{api.Signature}, 
                      Ptr{Cchar}, Ptr{Cchar}, Ptr{Void},
                      Cint, Ptr{Ptr{Void}}),
                      commit_oid.oid, r.ptr, bref,
                      &author, &committer,
                      C_NULL, bmsg, tree.ptr, 
                      nparents, nparents > 0 ? cparents : C_NULL)
    if err_code < 0
        throw(GitError(err_code))
    end
    return commit_oid
end

function repo_set_workdir(r::Repository, dir::String, update::Bool)
end


function repo_tree_builder(r::Repository)
end


function repo_revparse_single(r::Repository, spec::String)
    @assert r.ptr != C_NULL
    bspec = bytestring(spec)
    obj_ptr = Array(Ptr{Void}, 1)
    @check api.git_revparse_single(obj_ptr, r.ptr, bspec)
    @check_null obj_ptr
    return gitobj_from_ptr(obj_ptr[1])
end

#-------- Reference Iterator --------
type ReferenceIterator
    ptr::Ptr{Void}
    repo::Repository

    function ReferenceIterator(ptr::Ptr{Void}, r::Repository)
        @assert ptr != C_NULL
        ri = new(ptr, r)
        finalizer(ri, free!)
        return ri
    end
end

free!(r::ReferenceIterator) = begin
    if r.ptr != C_NULL
        api.git_reference_iterator_free(r.ptr)
        r.ptr = C_NULL
    end
end

function iter_refs(r::Repository; glob=nothing)
    @assert r.ptr != C_NULL
    iter_ptr = Array(Ptr{Void}, 1)
    if glob == nothing
        @check api.git_reference_iterator_new(iter_ptr, r.ptr)
    else
        bglob = bytestring(glob)
        @check api.git_reference_iterator_glob_new(iter_ptr, r.ptr, bglob)
    end
    @check_null iter_ptr
    return ReferenceIterator(iter_ptr[1], r)
end

Base.start(r::ReferenceIterator) = begin
    @assert r != C_NULL
    ref_ptr = Array(Ptr{Void}, 1)
    ret = api.git_reference_next(ref_ptr, r.ptr)
    if ret == api.ITEROVER
        return nothing
    end
    @check_null ref_ptr
    return GitReference(ref_ptr[1])
end

Base.done(r::ReferenceIterator, state) = begin
    state == nothing
end

Base.next(r::ReferenceIterator, state) = begin
    @assert r.ptr != C_NULL
    ref_ptr = Array(Ptr{Void}, 1)
    ret = api.git_reference_next(ref_ptr, r.ptr)
    if ret == api.ITEROVER
        return (state, nothing)
    end
    @check_null ref_ptr
    return (state, GitReference(ref_ptr[1]))
end
