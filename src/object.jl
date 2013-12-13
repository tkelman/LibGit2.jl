abstract GitObject

immutable Blob <:GitObject
end

function oid(o::GitObject)
end

function hex(o::GitObject)
end

function raw(o::GitObject)
end

# Git Blob...
immutable Blob <:GitObject
end

function data(b::Blob)
    return raw(b)
end

function Base.sizeof(b::Blob)
end

function isbinary(b::Blob)
end

function Blob()
end

#hash
#hashfile

immutable Tree <: GitObject
end

# supports getindex interface
# supports hash (in) interface

function Base.length(t::Tree)
end

# supports iterable interface

# diff_to_tree
# diff_to_workdir
# diff_to_index

immutable TreeEntry <: GitObject
end

function name(t::TreeEntry)
end

function oid(t::TreeEntry)
end

function hex(t::TreeEntry)
end

function filemode(t::TreeEntry)
end

# builder objects for trees

immutable Commit <: GitObject
    author
    committer
    message
    message_encoding
    raw_message
    tree
    parents
    commit_time
    commit_time_offset
end

immutable Signiture <: GitObject
    name
    email
    time
    time_offset
end

function create_commit(r::Repository, author, committer..)
end

immutable Tag <: GitObject
    name
    target
    tagger
    message
    obj
end

function create_tag(r::Repository, name, oid, 
                    type, tagger, msg)
    end

