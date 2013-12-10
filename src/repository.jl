type Repository
    repo::GitRepositry
end

Repository(path::String) = begin
    repo = GitRepositry()
    @check ccall((:git_repository_open, :libgit2),
                 Cint,
                 (Ptr{GitRepositry}, Ptr{Cchar}),
                 &repo, bytestring(path))
    Repository(repo)
end


function free(r::Repository)
    @check ccall((:git_repository_free, :libgit2),
                 Cint,
                 (Ptr{GitRepositry},),
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
end


function isempty(r::Repository)
end


function workdir(r::Repository)
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

