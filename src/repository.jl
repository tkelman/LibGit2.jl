
type Repository
    repo::Ptr{GitRepository}
end

Base.show(io::IO, r::GitRepository) = begin
    print(io, "Repository(\n")
    for name in names(GitRepository)
        print(io, "  $(name)=$(getfield(r, symbol(name))),\n")
    end
    print(io, ")\n")
end

Repository(path::String) = begin
    repo_ptr = convert(Ptr{GitRepository}, [GitRepository()])
    @check ccall((:git_repository_open, :libgit2),
                 Cint,
                 (Ptr{Ptr{GitRepository}}, Ptr{Cchar}),
                 &repo_ptr, bytestring(path))
    Repository(repo_ptr)
end


function free(r::Repository)
    @check ccall((:git_repository_free, :libgit2),
                 Cint,
                 (Ptr{GitRepository},),
                 &r.repo)
end


function open_repo(path::String)
end


function init_repo(url::String;
                   bare::Bool=false)
end

function clone_repo(url::String; 
                    bare::Bool=false,
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


function isbare(r::Repository)
    res = ccall((:git_repository_is_bare, :libgit2), Cint,
                (Ptr{GitRepository},), r.repo)
    return res > 0 ? true : false
end

function isbare(r::GitRepository)
    res = ccall((:git_repository_is_bare, :libgit2), Cint,
                (Ptr{GitRepository},), &r)
    return res > 0 ? true : false
end


function Base.isempty(r::Repository)
    res = ccall((:git_repository_is_empty, :libgit2), Cint,
                (Ptr{GitRepository},), r.repo)
    return res > 0 ? true : false
end

function Base.isempty(r::GitRepository)
    res = ccall((:git_repository_is_empty, :libgit2), Cint,
                (Ptr{GitRepository},), &r)
    return res > 0 ? true : false
end

function workdir(r::Repository)
    res = ccall((:git_repository_workdir, :libgit2), Ptr{Cchar},
                (Ptr{GitRepository},), &r.repo)
    if res == C_NULL
        return nothing
    end
    return bytestring(res)
end

function repo_path(r::Repository)
    res = ccall((:git_repository_path, :libgit2), Ptr{Cchar},
                (Ptr{GitRepository},), r.repo)
    @show res
    if res == C_NULL
        return nothing
    end
    return bytestring(res)
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
