
type Repository
    ptr::Ptr{Void}

    function Repository(ptr::Ptr{Void})
        if ptr == C_NULL
            throw(ArgumentError("Repository initialized with NULL pointer"))
        end
        r = new(ptr)
        finalizer(r, r -> free!(r))
        return r
    end
end

free!(r::Repository) = begin
    if r.ptr != C_NULL
        @check ccall((:git_repository_free, :libgit2), Cint,
                     (Ptr{Void},), r.ptr)
        r.ptr = C_NULL
    end
end

Repository(path::String) = begin
    bpath = bytestring(path)
    err_code = Cint[-1]
    repo_ptr = ccall((:open_repo, libwrapgit), Ptr{Void}, 
                     (Ptr{Cchar}, Ptr{Cint}),
                     bpath, err_code)
    if err_code[1] < 0
        if repo_ptr != C_NULL
            ccall((:git_repository_free, :libgit2), Cint,
                  (Ptr{Void},), repo_ptr)
        end
        throw(GitError(err_code[1]))
    end
    if repo_ptr == C_NULL
        error("repo pointer is NULL")
    end
    return Repository(repo_ptr)
end

function isbare(r::Repository)
    res = ccall((:git_repository_is_bare, :libgit2), Cint,
                (Ptr{Void},), r.ptr)
    return res > 0 ? true : false
end

function Base.isempty(r::Repository)
    res = ccall((:git_repository_is_empty, :libgit2), Cint,
                (Ptr{Void},), r.ptr)
    return res > 0 ? true : false
end

function workdir(r::Repository)
    res = ccall((:git_repository_workdir, :libgit2), Ptr{Cchar},
                (Ptr{Void},), r.ptr)
    if res == C_NULL
        return nothing
    end
    return bytestring(res)
end

function path(r::Repository)
    cpath = ccall((:git_repository_path, :libgit2), Ptr{Cchar},
                  (Ptr{Void},), r.ptr)
    if cpath == C_NULL
        return nothing
    end
    return bytestring(cpath)
end

function head_orphaned(r::Repository)
end

function head_detached(r::Repository)
end


function open_repo(path::String)
    Repository(path)
end

function init_repo(path::String; bare::Bool=false)
    bpath = bytestring(path)
    err_code = Cint[-1]
    repo_ptr = ccall((:init_repo, libwrapgit), Ptr{Void},
                     (Ptr{Cchar}, Cint, Ptr{Cint}),
                     bpath, bare ? 1 : 0, err_code)
    if err_code[1] < 0
        if repo_ptr != C_NULL
            ccall((:git_repository_free, :libgit2), Cint,
                  (Ptr{Void},), repo_ptr)
        end
        throw(GitError(err_code[1]))
    end
    if repo_ptr == C_NULL
        error("repo pointer is NULL")
    end
    return Repository(repo_ptr)
end

function clone_repo(url::String; 
                    repobare::Bool=false,
                    ignore_cert_errors::Bool=false,
                    remote_name::String="origin",
                    checkout_branch=nothing)
end

function discover_repo(url::String)
end


function config(r::Repository)
end


function index(r::Repository)
end


#function lookup_type(r::Repository, oid::Oid, t::ObjectType)
#end


function lookup(r::Repository, oid::Oid)
end


function lookup_commit(r::Repository, oid::Oid)
end


function lookup_blob(r::Repository, oid::Oid)
end


function lookup_ref(r::Repository, refname::String)
end


function create_ref(r::Repository, refname::String, oid::Oid, force::Bool)
end


function create_sym_ref(r::Repository, refname::String, target::String, force::Bool)
end


function walk(r::Repository)
end


#function create_commit(refname::String,
#                       author::Signiture,
#                       committer::Signiture,
#                       message::String,
#                       tree::Tree,
#                       parents...)
#end


#function free(o::Odb)
#end


function path(r::Repository)
end


function set_workdir(r::Repository, dir::String, update::Bool)
end


function tree_builder(r::Repository)
end

function revparse_single(r::Repository, spec::String)
end

function read(r::Repository, oid::Oid)
end

#function write(r::Repository, type, data)
#end
