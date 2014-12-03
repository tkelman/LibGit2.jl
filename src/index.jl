export GitIndex, GitIndexEntry, add_bypath!, write_tree!, write!, reload!, clear!,
       remove!, removedir!, read_tree!, add_all!, update_all!,
       remove_all!, has_conflicts, add!, is_fully_merged, conflicts

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

GitIndex(path::AbstractString) = begin
    idxptr = Ptr{Void}[0]
    @check ccall((:git_index_open, libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{UInt8}), idxptr, path)
    return GitIndex(idxptr[1])
end

GitIndex(r::GitRepo) = begin
    idxptr = Ptr{Void}[0]
    @check ccall((:git_repository_index, libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}), idxptr, r)
    return GitIndex(idxptr[1])
end

has_conflicts(idx::GitIndex) =
    bool(ccall((:git_index_has_conflicts, libgit2), Cint, (Ptr{Void},), idx))

has_conflicts(idx::GitRepo) = has_conflicts(GitIndex(repo))

is_fully_merged(idx::GitIndex) = !has_conflicts(idx)
is_fully_merged(repo::GitRepo) = is_fully_merged(GitIndex(repo))

function clear!(idx::GitIndex)
    ccall((:git_index_clear, libgit2), Void, (Ptr{Void},), idx)
    return idx
end
clear!(repo::GitRepo) = clear!(GitIndex(repo))

function reload!(idx::GitIndex)
    @check ccall((:git_index_read, libgit2), Cint, (Ptr{Void}, Cint), idx, Cint(0))
    return idx
end
reload!(repo::GitRepo) = reload!(GitIndex(repo))

function write!(idx::GitIndex)
    @check ccall((:git_index_write, libgit2), Cint, (Ptr{Void},), idx)
    return idx
end
write!(repo::GitRepo) = write!(GitIndex(repo))

function remove!(idx::GitIndex, path::AbstractString, stage::Integer=0)
    @check ccall((:git_index_remove, libgit2), Cint, (Ptr{Void}, Ptr{UInt8}, Cint),
                 idx, path, stage)
    return idx
end

function removedir!(idx::GitIndex, path::AbstractString, stage::Integer=0)
    @check ccall((:git_index_remove_directory, libgit2), Cint, (Ptr{Void}, Ptr{UInt8}, Cint),
                  idx, path, stage)
    return idx
end

Base.length(idx::GitIndex) =
    int(ccall((:git_index_entrycount, libgit2), Cint, (Ptr{Void},), idx))

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
IndexTimeStruct()  = IndexTimeStruct(0, 0)
IndexTimeStruct(s) = IndexTimeStruct(s, 0)

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
    path::Ptr{UInt8}
end

IndexEntryStruct() = IndexEntryStruct(IndexTimeStruct(),
                                      IndexTimeStruct(),
                                      Cuint(0),
                                      Cuint(0),
                                      Cuint(0),
                                      Cuint(0),
                                      Cuint(0),
                                      GitOffT(0),
                                      Oid(),
                                      Cushort(0),
                                      Cushort(0),
                                      Ptr{UInt8}(0))
Oid(entry::GitIndexEntry) = entry.id

IndexEntryStruct(entry::GitIndexEntry) = begin
    flags = 0x0000
    flags &= ~GitConst.IDXENTRY_STAGEMASK
    flags |= (uint16(entry.stage) << GitConst.IDXENTRY_STAGESHIFT) & GitConst.IDXENTRY_STAGEMASK
    flags &= ~GitConst.IDXENTRY_VALID
    entry.valid && (flags |= GitConst.IDXENTRY_VALID)
    ctime = IndexTimeStruct(floor(GitTimeT, entry.ctime),
                            floor(Cuint, (entry.ctime - floor(entry.ctime)) * 1000))
    mtime = IndexTimeStruct(floor(GitTimeT, entry.mtime),
                            floor(Cuint, (entry.mtime - floor(entry.mtime)) * 1000))
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
                            convert(Ptr{UInt8}, entry.path))
end

function GitIndexEntry(ptr::Ptr{IndexEntryStruct})
    @assert ptr != C_NULL
    entry = unsafe_load(ptr)
    path  = bytestring(entry.path)
    ctime = entry.ctime.seconds + (entry.ctime.nanoseconds / 1000)
    mtime = entry.mtime.seconds + (entry.mtime.nanoseconds / 1000)
    dev   = int(entry.dev)
    ino   = int(entry.ino)
    mode  = int(entry.mode)
    uid   = int(entry.uid)
    gid   = int(entry.gid)
    valid = bool(entry.flags & GitConst.IDXENTRY_VALID)
    stage = int((entry.flags & GitConst.IDXENTRY_STAGEMASK) >> GitConst.IDXENTRY_STAGESHIFT)
    file_size = int(entry.file_size)
    id = Oid(hex(entry.id))
    return GitIndexEntry(path, id, ctime, mtime, file_size,
                         dev, ino, mode, uid, gid, valid, stage)
end

Base.push!(idx::GitIndex, entry::GitIndexEntry) = begin
    estruct = IndexEntryStruct(entry)
    @check ccall((:git_index_add, libgit2), Cint,
                 (Ptr{Void}, Ptr{IndexEntryStruct}), idx, &estruct)
    return idx
end

Base.push!(idx::GitIndex, path::AbstractString) = begin
    @check ccall((:git_index_add_bypath, libgit2), Cint,
                 (Ptr{Void}, Ptr{UInt8}), idx, path)
    return idx
end

Base.getindex(idx::GitIndex, i::Integer) = begin
    i <= 0 && throw(BoundsError())
    entryptr = ccall((:git_index_get_byindex, libgit2), Ptr{IndexEntryStruct},
                     (Ptr{Void}, Csize_t), idx, i-1)
    entryptr == C_NULL && return nothing
    return GitIndexEntry(entryptr)
end

Base.getindex(idx::GitIndex, path::AbstractString, stage::Integer=0) = begin
    entryptr = ccall((:git_index_get_bypath, libgit2), Ptr{IndexEntryStruct},
                      (Ptr{Void}, Ptr{UInt8}, Cint), idx, path, stage)
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

function add_all!(idx::GitIndex, pathspec::AbstractString;
                 force::Bool=false,
                 disable_pathsepc_match::Bool=false,
                 check_pathspec::Bool=false)
    return add_all!(idx, [pathspec],
                    force=force,
                    disable_pathsepc_match=disable_pathsepc_match,
                    check_pathspec=check_pathspec)
end

function add_all!{T<:AbstractString}(idx::GitIndex, pathspecs::Vector{T};
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

function update_all!{T<:AbstractString}(idx::GitIndex, pathspecs::Vector{T})
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
update_all!(idx::GitIndex, pathspec::AbstractString) = update_all!(idx, [pathspec])
update_all!(idx::GitIndex) = update_all!(idx, [""])

function remove_all!{T<:AbstractString}(idx::GitIndex, pathspecs::Vector{T})
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
remove_all!(idx::GitIndex, pathspec::AbstractString) = remove_all!(idx, [pathspec])

conflicts(r::GitRepo, idx::GitIndex) = begin
    ancestor, ours, theirs = nothing, nothing, nothing
    current_path = nothing
    res = []
    for entry in idx
        if entry.stage == 0 # staged
            continue
        end
        if current_path != nothing && entry.path != current_path
            push!(res, (ancestor, ours, theirs))
            ancestor, ours, theirs = nothing, nothing, nothing
        end
        current_path = entry.path
        if entry.stage == 1 # ancestor
            ancestor = entry
        elseif  entry.stage == 2 # ours
            ours = entry
        elseif entry.stage == 3 # theirs
            theirs = entry
        else
            error("entry $entry has unexpected stage level $(entry.stage)")
        end
    end
    if current_path != nothing
        push!(res, (ancestor, ours, theirs))
    end
    return res
end
