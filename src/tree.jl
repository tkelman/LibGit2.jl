
type Tree
end

immutable Oid
end

immutable ObjectType
end

immutable CTreeEntry
end

type TreeEntry
    name::String
    id::Oid
    type::ObjectType
    filemode::Int
end


TreeEntry(entry::CTreeEntry) = begin
end


function entry_by_name(t::Tree, filename::String)
end

function entry_by_path(t::Tree, path::String)
end

function entry_by_index(t::Tree, index::Uint64)
end

function entry_count(t::Tree)
end

function walk(t::Tree)
end

typealias CTreeBuilder Void

type TreeBuilder
    ptr::Ptr{CTreeBuilder}
    repo::Repository
end

function free(t::TreeBuilder)
end

function insert(t::TreeBuilder, filename::String, 
                id::Oid, filemode::Int)
end

function write(t::TreeBuilder)
end

