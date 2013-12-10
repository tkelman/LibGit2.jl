#TODO: is this valid for 32 & 64 bit sytems
typealias GitAtomic Clong

type GitRefCount
    refcount::GitAtomic
    owner::Ptr{Void}

    function GitRefCount()
        new(zero(GitAtomic),
            C_NULL)
    end
end

# Function Pointer
# int (*git_vector_cmp)(const void *, const void *)
typealias GitVectorCmp Ptr{Void}

type GitVector
    _alloc_size::Csize_t
    _cmp::GitVectorCmp
    contents::Ptr{Ptr{Void}}
    length::Csize_t
    sorted::Cint

    function GitVector()
        new(zero(Csize_t),
            C_NULL, 
            C_NULL, 
            zero(Csize_t), 
            zero(Cint))
    end
end

type GitConfig
    #git_refcount rc
    rc_refcount::Clong
    rc_owner::Ptr{Void}

    #git_vector files
    files__alloc_size::Csize_t
    files__cmp::GitVectorCmp
    files_contents::Ptr{Ptr{Void}}
    files_length::Csize_t
    files_sorted::Cint

    function GitConfig()
        new(zero(Clong),
            C_NULL, 
            zero(Csize_t), 
            C_NULL,
            C_NULL,
            zero(Csize_t), 
            zero(Cint))
    end
end

#TODO: In threaded versions this it a pthread_mutex_t
typealias GitMutex Cuint

#TODO: typealias khash_t(oid) git_oidmap
typealias GitOidMap Ptr{Void}

type GitCache
    map::Ptr{GitOidMap}
    lock::GitMutex
    used_memory::Csize_t

    function GitCache()
        new(C_NULL, 
            zero(GitMutex),
            zero(Csize_t))
    end
end

type GitOdb
    #git_refcount rc
    rc_refcount::GitAtomic
    rc_owner::Ptr{Void}

    #git_vector backends
    backends__alloc_size::Csize_t
    backends__cmp::GitVectorCmp
    backends_contents::Ptr{Ptr{Void}}
    backends_length::Csize_t
    backends_sorted::Cint

    #git_cache own_cache
    own_cache_map::Ptr{GitOidMap}
    own_cache_lock::GitMutex
    own_cache_used_memory::Csize_t

    function GitOdb()
        new(zero(GitAtomic),
            C_NULL, 
            zero(Csize_t), 
            C_NULL,
            C_NULL, 
            zero(Csize_t), 
            zero(Cint), 
            C_NULL, 
            zero(GitMutex), 
            zero(Csize_t))
    end
end

type GitPool
    #git_pool_page *open; /* pages with space left */
    open::Ptr{Void}
    #git_pool_page *full; /* pages with no space left */
    full::Ptr{Void}
    #void *free_list; /* optional: list of freed blocks */
    free_list::Ptr{Void}
    #uint32_t item_size; /* size of single alloc unit in bytes */
    item_size::Uint32
    #uint32_t page_size; /* size of page in bytes */
    page_size::Uint32
    #uint32_t items;
    items::Uint32
    #unsigned has_string_alloc : 1; /* was the strdup function used */
    has_string_alloc::Cuint
    #unsigned has_multi_item_alloc : 1; /* was items ever > 1 in malloc */
    has_multi_item_alloc::Cuint
    #unsigned has_large_page_alloc : 1; /* are any pages > page_size */
    has_large_page_alloc::Cuint

    function GitPool()
        new(C_NULL,
            C_NULL,
            C_NULL,
            zero(Uint32),
            zero(Uint32),
            zero(Uint32),
            one(Cuint),
            one(Cuint),
            one(Cuint))
        end
end

type GitAttrCache
    initialized::Cint
    
    #git_pool pool
    pool_open::Ptr{Void}
    pool_full::Ptr{Void}
    pool_free_list::Ptr{Void}
    pool_item_size::Uint32
    pool_page_size::Uint32
    pool_items::Uint32
    pool_has_string_alloc::Cuint
    pool_has_multi_item_alloc::Cuint
    pool_has_large_page_alloc::Cuint
    
    #git_strmap* files
    files::Ptr{Void}
    
    #git_strmap* macros
    macros::Ptr{Void}
    
    #char* cfg_attr_file
    cfg_attr_file::Ptr{Cchar}
    
    #char* cfg_excl_file
    cfg_excl_file::Ptr{Cchar}

    function GitAttrCache()
        new(zero(Cint),
            C_NULL,
            C_NULL,
            C_NULL,
            zero(Uint32),
            zero(Uint32),
            zero(Uint32),
            zero(Cuint),
            zero(Cuint),
            zero(Cuint),
            C_NULL,
            C_NULL,
            convert(Ptr{Cchar}, ""),
            convert(Ptr{Cchar}, ""))
    end
end

typealias GitFunctionPtr Ptr{Void}

type GitRefDBBackend
    version::Cuint
    exists::GitFunctionPtr
    lookup::GitFunctionPtr
    iterator::GitFunctionPtr
    write::GitFunctionPtr
    rename::GitFunctionPtr
    del::GitFunctionPtr
    compress::GitFunctionPtr
    free::GitFunctionPtr
    reflog_read::GitFunctionPtr
    reflog_write::GitFunctionPtr
    reflog_renmae::GitFunctionPtr
    reflog_delete::GitFunctionPtr

    function GitRefDBBackend()
        new(zero(Cuint),
            C_NULL,
            C_NULL,
            C_NULL,
            C_NULL,
            C_NULL,
            C_NULL,
            C_NULL,
            C_NULL,
            C_NULL,
            C_NULL,
            C_NULL,
            C_NULL)
    end
end

type GitRefDB
    #git_refcount rc
    rc_refcount::GitAtomic
    rc_owner::Ptr{Void}
    
    #git_repo* repo
    #repo::Ptr{GitRepositry}
    repo::Ptr{Void}

    #git_refdb_backend* backend
    backend::Ptr{GitRefDBBackend}

    function GitRefDB()
        new(zero(GitAtomic),
            C_NULL,
            C_NULL,
            C_NULL,
            C_NULL)
    end
end

immutable GitFUtilsFilestamp
    #git_time_t mtime;
    mtime::Int64
    #git_off_t size;
    size::Int64
    #unsigned int ino;
    ino::Cuint
end

type GitIndex
    #git_refcount rc;
    rc_refcount::GitAtomic
    rc_owner::Ptr{Void}

    #char *index_file_path;
    index_file_path::Ptr{Cchar}

    #git_futils_filestamp stamp;
    stamp_mtime::Int64
    stamp_size::Int64
    stamp_ino::Cuint

    #git_vector entries;
    entries__alloc_size::Csize_t
    entries__cmp::GitVectorCmp
    entries_contents::Ptr{Ptr{Void}}
    entries_length::Csize_t
    entries_sorted::Cint

    #unsigned int on_disk:1;
    on_disk::Cuint
    #unsigned int ignore_case:1;
    ignore_case::Cuint
    #unsigned int distrust_filemode:1;
    distrust_filemode::Cuint
    #unsigned int no_symlinks:1;
    no_symlinks::Cuint

    #git_tree_cache *tree;
    tree::Ptr{Void}

    #git_vector names;
    names__alloc_size::Csize_t
    names__cmp::GitVectorCmp
    names_contents::Ptr{Ptr{Void}}
    names_length::Csize_t
    names_sorted::Cint

    #git_vector reuc;
    reuc__alloc_size::Csize_t
    reuc__cmp::GitVectorCmp
    reuc_contents::Ptr{Ptr{Void}}
    reuc_length::Csize_t
    reuc_sorted::Cint

    #git_vector_cmp entries_cmp_path;
    entries_cmp_path::GitVectorCmp
    #git_vector_cmp entries_search;
    entries_search::GitVectorCmp
    #git_vector_cmp entries_search_path;
    entries_search_path::GitVectorCmp
    #git_vector_cmp reuc_search;
    reuc_search::GitVectorCmp

    function GitIndex()
        new(zero(GitAtomic),
            C_NULL,

            convert(Ptr{Cchar}, ""),

            zero(Int64),
            zero(Int64),
            zero(Cuint),

            zero(Csize_t),
            C_NULL,
            C_NULL,
            zero(Csize_t),
            zero(Cint),

            one(Cuint),
            one(Cuint),
            one(Cuint),
            one(Cuint),

            C_NULL,

            zero(Csize_t),
            C_NULL,
            C_NULL,
            zero(Csize_t),
            zero(Cint),
            
            zero(Csize_t),
            C_NULL,
            C_NULL,
            zero(Csize_t),
            zero(Cint),

            C_NULL,
            C_NULL,
            C_NULL,
            C_NULL)
    end
end


type GitRepositry
    #git_odb* _odb
    _odb::Ptr{GitOdb}
    #git_refdb* _refdb
    _refdb::Ptr{GitRefDB}
    #git_config* _config
    _config::Ptr{GitConfig}
    #git_index* _index
    _index::Ptr{GitIndex}

    #git_cache objects
    objects_map::Ptr{GitOidMap}
    objects_lock::GitMutex
    objects_used_memory::Csize_t

    #git_attr_cache attr_cache
    attr_cache_initialized::Cint
    attr_cache_pool_open::Ptr{Void}
    attr_cache_pool_full::Ptr{Void}
    attr_cache_pool_free_list::Ptr{Void}
    attr_cache_pool_item_size::Uint32
    attr_cache_pool_page_size::Uint32
    attr_cache_pool_items::Uint32
    attr_cache_pool_has_string_alloc::Cuint
    attr_cache_pool_has_multi_item_alloc::Cuint
    attr_cache_pool_has_large_page_alloc::Cuint
    attr_cache_files::Ptr{Void}
    attr_cache_macros::Ptr{Void}
    attr_cache_cfg_attr_file::Ptr{Cchar}
    attr_cache_cfg_excl_file::Ptr{Cchar}

    #git_strmap * submodules
    submodules::Ptr{Void}

    #git diff_driver_registry *diff_drivers
    diff_drivers::Ptr{Void}

    path_repository::Ptr{Cchar}
    workdir::Ptr{Cchar}
    namespace::Ptr{Cchar}
    
    # unsigned is_bare:1
    is_bare::Cuint
    
    lru_counter::Cuint
    
    #GIT_CVAR_CACHE_MAX = 9 (parrot bindings)
    #git_cvar_value cvar_cache[GIT_CVAR_CACHE_MAX]
    cvar_cache1::Cint
    cvar_cache2::Cint
    cvar_cache3::Cint
    cvar_cache4::Cint
    cvar_cache5::Cint
    cvar_cache6::Cint
    cvar_cache7::Cint
    cvar_cache8::Cint

    function GitRepositry()
        new(C_NULL, 
            C_NULL, 
            C_NULL, 
            C_NULL,
            C_NULL, 
            zero(GitMutex), 
            zero(Csize_t),
            zero(Cint), 
            C_NULL, 
            C_NULL, 
            C_NULL,
            zero(Uint32), 
            zero(Uint32), 
            zero(Uint32),
            zero(Cuint), 
            zero(Cuint), 
            zero(Cuint),
            C_NULL, 
            C_NULL,
            convert(Ptr{Cchar}, ""), 
            convert(Ptr{Cchar}, ""),
            C_NULL, 
            C_NULL,
            convert(Ptr{Cchar}, ""), 
            convert(Ptr{Cchar}, ""),
            convert(Ptr{Cchar}, ""),
            one(Cuint),
            zero(Cuint),
            zero(Cint),
            zero(Cint),
            zero(Cint),
            zero(Cint),
            zero(Cint),
            zero(Cint),
            zero(Cint),
            zero(Cint))
    end
end
