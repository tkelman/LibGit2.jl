export Repository, repo_isbare, repo_isempty, repo_workdir, repo_path,
       repo_open, repo_init, repo_index, head, tags, commits, references

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
        @check api.git_repository_free(r.ptr)
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
    res = api.git_repository_is_bare(r.ptr)
    return res > 0 ? true : false
end

function repo_isempty(r::Repository)
    res = api.git_repository_is_empty(r.ptr) 
    return res > 0 ? true : false
end

function repo_workdir(r::Repository)
    res = api.git_repository_workdir(r.ptr)
    if res == C_NULL
        return nothing
    end
    # remove trailing slash
    return bytestring(res)[1:end-1]
end

function repo_path(r::Repository)
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

function commits(r::Repository)
    return nothing
end 

function references(r::Repository)
    return nothing
end


function repo_discover(url::String)
end


function repo_config(r::Repository)
end

function repo_index(r::Repository)
    idx_ptr = Array(Ptr{Void}, 1)
    @check api.git_repository_index(idx_ptr, r.ptr)
    @check_null idx_ptr
    return Index(idx_ptr[1])
end


#function lookup_type(r::Repository, oid::Oid, t::ObjectType)
#end


function repo_lookup(r::Repository, oid::Oid)
end


function repo_lookup_commit(r::Repository, oid::Oid)
end


function repo_lookup_blob(r::Repository, oid::Oid)
end


function repo_lookup_ref(r::Repository, refname::String)
end


function repo_create_ref(r::Repository, refname::String, oid::Oid, force::Bool)
end


function repo_create_sym_ref(r::Repository, refname::String, target::String, force::Bool)
end


function repo_walk(r::Repository)
end


#function create_commit(refname::String,
#                       author::Signiture,
#                       committer::Signiture,
#                       message::String,
#                       tree::Tree,
#                       parents...)
#end


function repo_set_workdir(r::Repository, dir::String, update::Bool)
end


function repo_tree_builder(r::Repository)
end

function repo_revparse_single(r::Repository, spec::String)
end

function repo_read(r::Repository, oid::Oid)
end

function repo_write(r::Repository, gittype, data)
end
