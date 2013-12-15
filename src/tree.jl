export GitTree, git_otype, GitTreeEntry, entry_byname, entry_bypath

type GitTree <: GitObject
    ptr::Ptr{Void}

    function GitTree(ptr::Ptr{Void})
        @assert ptr != C_NULL
        t = new(ptr)
        finalizer(t, free!)
        return t
    end
end

git_otype(::Type{GitTree}) = api.OBJ_TREE

Base.count(t::GitTree) = begin
    return int(api.git_tree_entrycount(t.ptr))
end

type GitTreeEntry{T<:GitObject}
    name::String
    oid::Oid
    filemode::Cint
end

Base.filemode(te::GitTreeEntry) = begin
    convert(Cint, te.filemode)
end

let 
    function tree_entry_name(ptr::Ptr{Void})
        ptr::Ptr{Cchar} = api.git_tree_entry_name(ptr)
        if ptr == C_NULL
            error("tree entry name pointer is NULL")
        end
        return bytestring(ptr)
    end

    function tree_entry_oid(ptr::Ptr{Void})
        oid_ptr::Ptr{Uint8} = api.git_tree_entry_id(ptr)
        if oid_ptr == C_NULL
            error("tree entry oid pointer is NULL")
        end
        return Oid(oid_ptr)
    end

    function tree_entry_type(ptr::Ptr{Void})
        t = api.git_tree_entry_type(ptr)
        if t == api.OBJ_BLOB
            return GitBlob
        elseif t == api.OBJ_COMMIT
            return GitCommit
        elseif t == api.OBJ_TAG
            return GitTag
        elseif t == api.OBJ_Tree
            return GitTree
        else
            error("unknown git_type $(t)")
        end
    end

    function tree_entry_filemode(ptr::Ptr{Void})
        fm = api.git_tree_entry_filemode(ptr)
        return fm
    end

    function GitTreeEntry(ptr::Ptr{Void}, owns::Bool=false)
        @assert ptr != C_NULL
        ty   = tree_entry_type(ptr)
        name = tree_entry_name(ptr)
        oid  = tree_entry_oid(ptr)
        fm   = tree_entry_filemode(ptr)
        entry = GitTreeEntry{ty}(name, oid, fm)
        return entry
    end
end

free!(te::GitTreeEntry) = begin 
    if te.ownsptr && te.ptr != C_NULL
        @check api.git_tree_entry_free(te.ptr)
        te.ptr = C_NULL
    end
end

#TODO: entries become invalid after tree 
#is explictly free'd, copy everything instead?
function entry_byname(t::GitTree, filename::String)
    @assert t.ptr != C_NULL
    bname = bytestring(filename)
    entry_ptr = api.git_tree_entry_byname(t.ptr, bname)
    if entry_ptr == C_NULL
        error("tree entry pointer is NULL")
    end
    return GitTreeEntry(entry_ptr)
end

function entry_bypath(t::GitTree, path::String)
    @assert t.ptr != C_NULL
    bpath = bytestring(path)
    entry_ptr = Array(Ptr{Void}, 1)
    @check api.git_tree_entry_bypath(entry_ptr, t.ptr, bpath)
    @check_null entry_ptr
    te = GitTreeEntry(entry_ptr[1], true)
    # tree entries returned are owned by the user
    # and must be explictly freed.  
    # since we make a copy, free here
    @check_null entry_ptr
    @check api.git_tree_entry_free(entry_ptr[1])
    return te
end


