export GitIndex, GitIndexEntry, add_bypath!, write_tree!, write!, reload!, clear!,
       remove!, removedir!, add!, read_tree!, add_all!, update_all!,
       remove_all!, has_conflicts

type GitIndex
    ptr::Ptr{Void}

    function GitIndex(ptr::Ptr{Void})
        @assert ptr != C_NULL
        idx = new(ptr)
        finalizer(idx, free!)
        return idx
    end
end

free!(idx::GitIndex) = begin
    if idx.ptr != C_NULL
        ccall((:git_index_free, libgit2), Void, (Ptr{Void},), idx.ptr)
        idx.ptr = C_NULL
    end
end

Base.convert(::Type{Ptr{Void}}, idx::GitIndex) = idx.ptr

GitIndex(path::String) = begin
    idxptr = Ptr{Void}[0]
    @check ccall((:git_index_open, libgit2), Cint, 
                 (Ptr{Ptr{Void}}, Ptr{Uint8}), idxptr, path)
    return GitIndex(idxptr[1])
end

GitIndex(r::GitRepo) = begin
    idxptr = Ptr{Void}[0]
    @check ccall((:git_repository_index, libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}), idxptr, r)
    return GitIndex(idxptr[1])
end

function has_conflicts(idx::GitIndex)
    return bool(ccall((:git_index_has_conflicts, libgit2), Cint, (Ptr{Void},), idx))
end

function clear!(idx::GitIndex)
    ccall((:git_index_clear, libgit2), Void, (Ptr{Void},), idx)
    return idx
end

function reload!(idx::GitIndex)
    @check ccall((:git_index_read, libgit2), Cint, (Ptr{Void}, Cint), idx, zero(Cint)) 
    return idx
end

function write!(idx::GitIndex)
    @check ccall((:git_index_write, libgit2), Cint, (Ptr{Void},), idx) 
    return idx
end 

function remove!(idx::GitIndex, path::String, stage::Integer=0)
    @check ccall((:git_index_remove, libgit2), Cint, (Ptr{Void}, Ptr{Uint8}, Cint),
                 idx, path, stage)
    return idx
end

function removedir!(idx::GitIndex, path::String, stage::Integer=0)
    @check ccall((:git_index_remove_directory, libgit2), Cint, (Ptr{Void}, Ptr{Uint8}, Cint),
                  idx, path, stage)
    return idx
end

Base.length(idx::GitIndex) = int(ccall((:git_index_entrycount, libgit2), Cint, 
                                       (Ptr{Void},), idx))

function write_tree!(idx::GitIndex)
    id_ptr = [Oid()]
    @check ccall((:git_index_write_tree, libgit2), Cint, 
                 (Ptr{Oid}, Ptr{Void}), id_ptr, idx)
    return id_ptr[1]
end

type GitIndexEntry
    path::ByteString
    id::Oid
    ctime::Float64
    mtime::Float64
    file_size::Int
    dev::Int
    ino::Int
    mode::Int
    uid::Int
    gid::Int
    valid::Bool
    stage::Int
end

immutable IndexTimeStruct
    seconds::GitTimeT
    nanoseconds::Cuint
end

IndexTimeStruct() = IndexTimeStruct(0, 0)

immutable IndexEntryStruct
    ctime::IndexTimeStruct
    mtime::IndexTimeStruct
    dev::Cuint
    ino::Cuint
    mode::Cuint
    uid::Cuint
    gid::Cuint
    file_size::GitOffT
    id::Oid
    flags::Cushort
    flags_extended::Cushort
    path::Ptr{Uint8}
end

IndexEntryStruct() = IndexEntryStruct(IndexTimeStruct(), 
                                      IndexTimeStruct(), 
                                      zero(Cuint), 
                                      zero(Cuint), 
                                      zero(Cuint), 
                                      zero(Cuint), 
                                      zero(Cuint), 
                                      zero(GitOffT),  
                                      Oid(), 
                                      zero(Cushort),  
                                      zero(Cushort),  
                                      zero(Ptr{Uint8})) 
Oid(entry::GitIndexEntry) = entry.id

IndexEntryStruct(entry::GitIndexEntry) = begin
    flags = uint16(0x0)
    flags &= ~GitConst.IDXENTRY_STAGEMASK
    flags |= (uint16(entry.stage) << GitConst.IDXENTRY_STAGESHIFT) & GitConst.IDXENTRY_STAGEMASK
    flags &= ~GitConst.IDXENTRY_VALID
    entry.valid && (flags |= GitConst.IDXENTRY_VALID)
    #TODO: rounding
    ctime = IndexTimeStruct(ifloor(entry.ctime), ifloor(entry.ctime - floor(entry.ctime) * 1e3))
    mtime = IndexTimeStruct(ifloor(entry.mtime), ifloor(entry.mtime - floor(entry.mtime) * 1e3))
    return IndexEntryStruct(ctime,
                            ctime,
                            entry.dev,
                            entry.ino,
                            entry.mode,
                            entry.uid,
                            entry.gid,
                            entry.file_size,
                            entry.id,
                            flags,
                            0,
                            convert(Ptr{Uint8}, entry.path))
end

function GitIndexEntry(ptr::Ptr{IndexEntryStruct})
    @assert ptr != C_NULL
    entry = unsafe_load(ptr)
    path  = bytestring(entry.path)
    ctime = entry.ctime.seconds + (entry.ctime.nanoseconds / 1e3)
    mtime = entry.mtime.seconds + (entry.mtime.nanoseconds / 1e3)
    dev   = int(entry.dev)
    ino   = int(entry.ino)
    mode  = int(entry.mode)
    uid   = int(entry.uid)
    gid   = int(entry.gid)
    valid = bool(entry.flags & GitConst.IDXENTRY_VALID)
    stage = int((entry.flags & GitConst.IDXENTRY_STAGEMASK) >> GitConst.IDXENTRY_STAGESHIFT)
    file_size = int(entry.file_size)
    id = entry.id
    return GitIndexEntry(path, id, ctime, mtime, file_size,
                      dev, ino, mode, uid, gid, valid, stage)
end

Base.add!(idx::GitIndex, entry::GitIndexEntry) = begin
    estruct = IndexEntryStruct(entry)
    @check ccall((:git_index_add, libgit2), Cint,
                 (Ptr{Void}, Ptr{IndexEntryStruct}),
                 idx, &estruct)
    return idx
end

Base.add!(idx::GitIndex, path::String) = begin
    @check ccall((:git_index_add_bypath, libgit2), Cint,
                 (Ptr{Void}, Ptr{Uint8}), idx, path)
    return idx
end

Base.getindex(idx::GitIndex, i::Integer) = begin
    i <= 0 && throw(BoundsError())
    entryptr = ccall((:git_index_get_byindex, libgit2), Ptr{IndexEntryStruct},
                     (Ptr{Void}, Csize_t), idx, i-1)
    entryptr == C_NULL && return nothing
    return GitIndexEntry(entryptr)
end

Base.getindex(idx::GitIndex, path::String, stage::Integer=0) = begin
    entryptr = ccall((:git_index_get_bypath, libgit2), Ptr{IndexEntryStruct},
                      (Ptr{Void}, Ptr{Uint8}, Cint), idx, path, stage) 
    entryptr == C_NULL && return nothing
    return GitIndexEntry(entryptr)
end

Base.(:(==))(e1::GitIndexEntry, e2::GitIndexEntry) = begin
    return e1.path  == e2.path &&
           e1.id == e2.id &&
           e1.ctime == e2.ctime && 
           e1.mtime == e2.mtime &&
           e1.file_size == e2.file_size &&
           e1.dev  == e2.dev && 
           e1.ino  == e2.ino &&
           e1.mode == e2.mode &&
           e1.uid  == e2.uid &&
           e1.gid  == e2.gid &&
           e1.valid == e2.valid && 
           e1.stage == e2.stage
end
Base.isequal(e1::GitIndexEntry, e2::GitIndexEntry) = e1 == e2

Base.start(idx::GitIndex) = begin
    if length(idx) == 0
        return (0, nothing)
    end
    return (1, idx[1])
end

Base.done(idx::GitIndex, state) = begin
    i = state[1]
    return i == 0 || i > length(idx)
end

Base.next(idx::GitIndex, state) = begin
    i = state[1] + 1
    return (state[2], (i, idx[i]))
end

function read_tree!(idx::GitIndex, tree::GitTree)
    @check ccall((:git_index_read_tree, libgit2), Cint,
                 (Ptr{Void}, Ptr{Void}), idx, tree)
    return idx
end

function add_all!(idx::GitIndex, pathspec::String;
                 force::Bool=false,
                 disable_pathsepc_match::Bool=false,
                 check_pathspec::Bool=false)
    return add_all!(idx, [pathspec], 
                    force=force, 
                    disable_pathsepc_match=disable_pathsepc_match,
                    check_pathspec=check_pathspec)
end

function add_all!{T<:String}(idx::GitIndex, pathspecs::Vector{T};
                             force::Bool=false,
                             disable_pathsepc_match::Bool=false,
                             check_pathspec::Bool=false)
    flags = GitConst.INDEX_ADD_DEFAULT
    if force
        flags |= GitConst.INDEX_ADD_FORCE
    end
    if disable_pathsepc_match
        flags |= GitConst.INDEX_ADD_DISABLE_PATHSPEC_MATCH
    end
    if check_pathspec
        flags |= GitConst.INDEX_ADD_CHECK_PATHSPEC
    end
    sa_ptr = [StrArrayStruct(pathspecs)]
    ex_ptr = Cint[0]
    @check ccall((:git_index_add_all, libgit2), Cint,
                 (Ptr{Void}, Ptr{StrArrayStruct}, Cuint, Ptr{Void}, Ptr{Cint}),
                 idx, sa_ptr, flags, C_NULL, ex_ptr)
    ccall((:git_strarray_free, libgit2), Void, (Ptr{StrArrayStruct},), sa_ptr)
    if ex_ptr[1] != GitErrorConst.GIT_OK
        throw(LibGitError(ex_ptr[1]))
    end
    return idx
end

function update_all!{T<:String}(idx::GitIndex, pathspecs::Vector{T})
    sa_ptr = [StrArrayStruct(pathspecs)]
    ex_ptr = Cint[0]
    @check ccall((:git_index_update_all, libgit2), Cint,
                 (Ptr{Void}, Ptr{StrArrayStruct}, Ptr{Void}, Ptr{Cint}),
                 idx, sa_ptr, C_NULL, ex_ptr)
    ccall((:git_strarray_free, libgit2), Void, (Ptr{StrArrayStruct},), sa_ptr)
    if ex_ptr[1] != GitErrorConst.GIT_OK
        throw(LibGitError(ex_ptr[1]))
    end
    return idx
end
update_all!(idx::GitIndex, pathspec::String) = update_all!(idx, [pathspec])
update_all!(idx::GitIndex) = update_all!(idx, [""])

function remove_all!{T<:String}(idx::GitIndex, pathspecs::Vector{T})
    sa_ptr = [StrArrayStruct(pathspecs)]
    ex_ptr = Cint[0]
    @check ccall((:git_index_remove_all, libgit2), Cint,
                 (Ptr{Void}, Ptr{StrArrayStruct}, Ptr{Void}, Ptr{Cint}),
                 idx, sa_ptr, C_NULL, ex_ptr)
    ccall((:git_strarray_free, libgit2), Void, (Ptr{StrArrayStruct},), sa_ptr)
    if ex_ptr[1] != GitErrorConst.GIT_OK
        throw(LibGitError(ex_ptr[1]))
    end
    return idx
end
remove_all!(idx::GitIndex, pathspec::String) = remove_all!(idx, [pathspec])
