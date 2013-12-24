module api

const libgit2 = "libgit2"

macro libgit(func, ret_type, arg_types)
  local args_in = Symbol[symbol("arg$i::$T")
                         for (i, T) in enumerate(arg_types.args)]
  quote
      function $(esc(func))($(args_in...))
          err = ccall(($(string(func)), libgit2),
                       $ret_type,
                       $arg_types,
                       $(args_in...))
          return err
      end
   end
end

cint(i) = convert(Cint, i)
cuint(i) = convert(Cuint, i)

# ----- libgit constants -----
const OID_RAWSZ = 20
const OID_HEXSZ = 40

const GIT_OK     = cint(0)
const ERROR      = cint(-01)  
const ENOTFOUND  = cint(-03)  
const EEXISTS    = cint(-04) 
const EAMBIGUOUS = cint(-05) 
const EBUFS      = cint(-06) 
const EUSER      = cint(-07) 
const EBAREREPO       = cint(-08) 
const EUNBORNBRANCH   = cint(-09) 
const EUNMERGED       = cint(-10) 
const ENONFASTFORWARD = cint(-11) 
const EINVALIDSPEC    = cint(-12) 
const EMERGECONFLICT  = cint(-13) 
const ELOCKED         = cint(-14) 
const PASSTHROUGH     = cint(-30) 
const ITEROVER        = cint(-31)

const OBJ_ANY    = cint(-2)
const OBJ_BAD    = cint(-1)
const OBJ_COMMIT = cint(1)
const OBJ_TREE   = cint(2)
const OBJ_BLOB   = cint(3)
const OBJ_TAG    = cint(4)

const SORT_NONE = cint(0)
const SORT_TOPOLOGICAL = cint(1) << cint(0)
const SORT_TIME = cint(1) << cint(1)
const SORT_REVERSE = cint(1) << cint(2)

const REF_INVALID = cint(0)
const REF_OID = cint(1)    
const REF_SYMBOLIC = cint(2)
const REF_LISTALL = REF_OID | REF_SYMBOLIC

const BRANCH_LOCAL = cint(1)
const BRANCH_REMOTE = cint(2)

const FILEMODE_NEW             = cint(00000)
const FILEMODE_TREE            = cint(16384)
const FILEMODE_BLOB            = cint(33188)
const FILEMODE_BLOB_EXECUTABLE = cint(33261)
const FILEMODE_LINK            = cint(40960)
const FILEMODE_COMMIT          = cint(57344)

const CHECKOUT_NONE                    = cint(0)
const CHECKOUT_SAFE                    = cuint(1) << cint(0)
const CHECKOUT_SAFE_CREATE             = cuint(1) << cint(1)
const CHECKOUT_FORCE                   = cuint(1) << cint(2)
const CHECKOUT_ALLOW_CONFLICTS         = cuint(1) << cint(4)
const CHECKOUT_REMOVE_UNTRACKED        = cuint(1) << cint(5)
const CHECKOUT_REMOVE_IGNORED          = cuint(1) << cint(6)
const CHECKOUT_UPDATE_ONLY             = cuint(1) << cint(7)
const CHECKOUT_DONT_UPDATE_INDEX       = cuint(1) << cint(8)
const CHECKOUT_NO_REFRESH              = cuint(1) << cint(9)
const CHECKOUT_SKIP_UNMERGED           = cuint(1) << cint(10)
const CHECKOUT_USE_OURS                = cuint(1) << cint(11)
const CHECKOUT_USE_THEIRS              = cuint(1) << cint(12)
const CHECKOUT_DISABLE_PATHSPEC_MATCH  = cuint(1) << cint(13)
const CHECKOUT_SKIP_LOCKED_DIRECTORIES = cuint(1) << cint(18)
const CHECKOUT_DONT_OVERWRITE_IGNORED  = cuint(1) << cint(19)

const SUBMODULE_UPDATE_RESET    = cint(-1)
const SUBMODULE_UPDATE_CHECKOUT = cint(1)
const SUBMODULE_UPDATE_REBASE   = cint(2)
const SUBMODULE_UPDATE_MERGE    = cint(3)
const SUBMODULE_UPDATE_NONE     = cint(4)
const SUBMODULE_UPDATE_DEFAULT  = cint(0)

const SUBMODULE_IGNORE_RESET     = cint(-1)
const SUBMODULE_IGNORE_NONE      = cint(1)  
const SUBMODULE_IGNORE_UNTRACKED = cint(2)  
const SUBMODULE_IGNORE_DIRTY     = cint(3)  
const SUBMODULE_IGNORE_ALL       = cint(4) 
const SUBMODULE_IGNORE_DEFAULT   = cint(0)

const TREEWALK_PRE  = cint(0)
const TREEWALK_POST = cint(1)

const GIT_PATH_MAX = cint(4096)

type GitStrArray
   strings::Ptr{Ptr{Cchar}}
   count::Csize_t

   function GitStrArray()
       sa = new(C_NULL, 0)
       finalizer(sa, free!)
       return sa
   end
end

free!(sa::GitStrArray) = begin
    if sa.strings != C_NULL && sa.count > 0
        for i in 1:sa.count
            cptr = unsafe_load(sa.strings, i)
            @assert cptr != C_NULL
            c_free(cptr)
        end
        sa.strings = C_NULL
        sa.count  = 0
    end
end

# ----- libgit threads -----
@libgit(git_threads_init, Cint, ())
@libgit(git_threads_shutdown, Cint, ())

# ----- libgit repo ------
@libgit(git_repository_discover, Cint, 
        (Ptr{Cchar}, Csize_t, Ptr{Cchar}, Cint, Ptr{Void}))  
@libgit(git_repository_open, Cint, (Ptr{Ptr{Void}}, Ptr{Cchar}))
@libgit(git_repository_init, Cint, (Ptr{Ptr{Void}}, Ptr{Cchar}, Cint))
@libgit(git_repository_free, Cint, (Ptr{Void},))
@libgit(git_repository_index, Cint, (Ptr{Ptr{Void}}, Ptr{Void}))
@libgit(git_repository_workdir, Ptr{Cchar}, (Ptr{Void},))
@libgit(git_repository_path, Ptr{Cchar}, (Ptr{Void},))
@libgit(git_repository_odb, Cint, (Ptr{Ptr{Void}}, Ptr{Void}))
@libgit(git_revparse_single, Cint, (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Cchar}))
@libgit(git_repository_config, Cint, (Ptr{Ptr{Void}}, Ptr{Void}))
@libgit(git_repository_head, Cint, (Ptr{Ptr{Void}}, Ptr{Void}))
@libgit(git_repository_set_head, Cint, (Ptr{Void}, Ptr{Cchar}))
@libgit(git_repository_set_namespace, Cint, (Ptr{Void}, Ptr{Cchar}))
@libgit(git_repository_get_namespace, Ptr{Cchar}, (Ptr{Void},))

@libgit(git_repository_is_empty, Cint, (Ptr{Void},))
@libgit(git_repository_is_shallow, Cint, (Ptr{Void},))
@libgit(git_repository_is_bare, Cint, (Ptr{Void},))

# ----- libgit index ------
@libgit(git_index_free, Cint, (Ptr{Void},))
@libgit(git_index_add_bypath, Cint, (Ptr{Void}, Ptr{Cchar}))
@libgit(git_index_write_tree, Cint, (Ptr{Uint8}, Ptr{Void}))

# ----- libgit object ------
@libgit(git_object_id, Ptr{Uint8}, (Ptr{Void},))
@libgit(git_object_free, Cint, (Ptr{Void},))
@libgit(git_object_id, Ptr{Uint8}, (Ptr{Void},))
@libgit(git_object_lookup, Cint, (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}, Cint))
@libgit(git_object_type, Cint, (Ptr{Void},))
@libgit(git_object_owner, Ptr{Void}, (Ptr{Void},))

@libgit(git_oid_cmp, Cint, (Ptr{Uint8}, Ptr{Uint8}))
@libgit(git_oid_fmt, Cint, (Ptr{Cchar}, Ptr{Uint8}))

# ----- libgit note ------
@libgit(git_note_read, Cint, (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Cchar}, Ptr{Uint8}))
@libgit(git_note_message, Ptr{Cchar}, (Ptr{Void},))
@libgit(git_note_oid, Ptr{Uint8}, (Ptr{Void},))
@libgit(git_note_free, Void, (Ptr{Void},))
@libgit(git_note_default_ref, Cint, (Ptr{Ptr{Cchar}}, Ptr{Void},))
@libgit(git_note_foreach, Cint, (Ptr{Void}, Ptr{Cchar}, Ptr{Void}, Ptr{Void}))

# ----- libgit graph ------
@libgit(git_graph_ahead_behind, Cint, 
        (Ptr{Csize_t}, Ptr{Csize_t}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}))

# ----- libgit merge ------
@libgit(git_merge_base_many, Cint,
        (Ptr{Uint8}, Ptr{Void}, Csize_t, Ptr{Void}))

# ----- libgit signature ------
type GitSignature
    name::Ptr{Cchar}
    email::Ptr{Cchar}
    time::Int64
    time_offset::Cint
end

free!(s::GitSignature) = begin
    if s.name != C_NULL
        c_free(s.name)
    end
    s.name = C_NULL
    if s.email != C_NULL
        c_free(s.email)
    end
    s.email = C_NULL
end

@libgit(git_signature_default, Cint,
        (Ptr{Ptr{GitSignature}}, Ptr{Void}))
@libgit(git_signature_new, Cint, 
        (Ptr{Ptr{GitSignature}}, Ptr{Cchar}, Ptr{Cchar}, Int64, Cint))
@libgit(git_signature_now, Cint, 
        (Ptr{Ptr{GitSignature}}, Ptr{Cchar}, Ptr{Cchar}))

# ----- libgit commit ------
@libgit(git_commit_message, Ptr{Cchar}, (Ptr{Void},))
@libgit(git_commit_message_raw, Ptr{Cchar}, (Ptr{Void},))
@libgit(git_commit_tree, Cint, (Ptr{Ptr{Void}}, Ptr{Void}))
@libgit(git_commit_tree_id, Ptr{Uint8}, (Ptr{Void},))
@libgit(git_commit_committer, Ptr{GitSignature}, (Ptr{Void},))
@libgit(git_commit_author, Ptr{GitSignature}, (Ptr{Void},))
@libgit(git_commit_parent, Cint, (Ptr{Ptr{Void}}, Ptr{Void}, Cuint))
@libgit(git_commit_parentcount, Csize_t, (Ptr{Void},))
@libgit(git_commit_parent_id, Ptr{Void}, (Ptr{Void}, Cuint))
@libgit(git_commit_lookup, Cint, (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}))
@libgit(git_commit_lookup_prefix, Cint,
        (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Void}, Csize_t))
@libgit(git_commit_create, Cint,
        (Ptr{Uint8}, Ptr{Void}, Ptr{Cchar}, Ptr{GitSignature},
         Ptr{GitSignature}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Void},
         Cint, Ptr{Ptr{Void}}))
                                        
# ----- libgit tag ------
@libgit(git_tag_name, Ptr{Cchar}, (Ptr{Void},))
@libgit(git_tag_message, Ptr{Cchar}, (Ptr{Void},))
@libgit(git_tag_target_id, Ptr{Uint8}, (Ptr{Void},))
@libgit(git_tag_target, Cint, (Ptr{Ptr{Void}}, Ptr{Void}))
@libgit(git_tag_tagger, Ptr{GitSignature}, (Ptr{Void},))
@libgit(git_tag_delete, Cint, (Ptr{Void}, Ptr{Cchar}))
@libgit(git_tag_create_lightweight, Cint, 
        (Ptr{Uint8}, Ptr{Void}, Ptr{Cchar}, Ptr{Void}, Cint))

# ------ libgit blob ------
@libgit(git_blob_rawsize, Int64, (Ptr{Void},))
@libgit(git_blob_owner, Ptr{Void}, (Ptr{Void},))
@libgit(git_blob_rawcontent, Ptr{Uint8}, (Ptr{Void},))
@libgit(git_blob_is_binary, Cint, (Ptr{Void},))
@libgit(git_blob_create_frombuffer, Cint, 
        (Ptr{Uint8}, Ptr{Void}, Ptr{Uint8}, Csize_t))
@libgit(git_blob_create_fromworkdir, Cint,
        (Ptr{Uint8}, Ptr{Void}, Ptr{Cchar}))

# ------ libgit tree ------
@libgit(git_tree_entry_bypath, Cint, (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Cchar})) 
@libgit(git_tree_entry_byname, Ptr{Void}, (Ptr{Void}, Ptr{Cchar}))
@libgit(git_tree_entry_byindex, Ptr{Void}, (Ptr{Void}, Csize_t))
@libgit(git_tree_entry_byoid, Ptr{Void}, (Ptr{Void}, Ptr{Uint8}))
@libgit(git_tree_entry_free, Void, (Ptr{Void},))
@libgit(git_tree_entry_name, Ptr{Cchar}, (Ptr{Void},))
@libgit(git_tree_entry_id, Ptr{Uint8}, (Ptr{Void},))
@libgit(git_tree_entry_type, Cint, (Ptr{Void},))
@libgit(git_tree_entry_filemode, Cint, (Ptr{Void},))
@libgit(git_tree_entrycount, Csize_t, (Ptr{Void},))
@libgit(git_tree_walk, Cint, (Ptr{Void}, Cint, Ptr{Void}, Ptr{Void}))

@libgit(git_treebuilder_create, Cint, (Ptr{Ptr{Void}}, Ptr{Void}))
@libgit(git_treebuilder_free, Void, (Ptr{Void},))
@libgit(git_treebuilder_write, Cint, (Ptr{Uint8}, Ptr{Void}, Ptr{Void}))
@libgit(git_treebuilder_insert, Cint,
        (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Cchar}, Ptr{Void}, Cint)) 
                                        
# ------ libgit walker ------
@libgit(git_revwalk_new, Cint, (Ptr{Ptr{Void}}, Ptr{Void}))
@libgit(git_revwalk_next, Cint, (Ptr{Uint8}, Ptr{Void}))
@libgit(git_revwalk_free, Void, (Ptr{Void},))
@libgit(git_revwalk_repository, Ptr{Void}, (Ptr{Void},))
@libgit(git_revwalk_push, Cint, (Ptr{Void}, Ptr{Uint8}))
@libgit(git_revwalk_hide, Cint, (Ptr{Void}, Ptr{Uint8}))
@libgit(git_revwalk_sorting, Void, (Ptr{Void}, Cint))
@libgit(git_revwalk_reset, Void, (Ptr{Void},))

# ------ libgit remote ------
@libgit(git_remote_free, Void, (Ptr{Void},))
@libgit(git_remote_list, Cint, (Ptr{GitStrArray}, Ptr{Void}))

# ------ libgit odb ------
@libgit(git_odb_exists, Cint, (Ptr{Void}, Ptr{Uint8}))
@libgit(git_odb_free, Void, (Ptr{Void},))
@libgit(git_odb_foreach, Cint, (Ptr{Void}, Ptr{Void}, Ptr{Cint})) 
@libgit(git_odb_add_disk_alternate, Cint, (Ptr{Void}, Ptr{Cchar}))
@libgit(git_odb_hash, Cint, (Ptr{Uint8}, Ptr{Cchar}, Csize_t, Cint))

@libgit(git_odb_write, Cint, 
        (Ptr{Uint8}, Ptr{Void}, Ptr{Uint8}, Csize_t))
@libgit(git_odb_read, Cint,
        (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}))
@libgit(git_odb_read_header, Cint,
        (Ptr{Csize_t}, Ptr{Cint}, Ptr{Void}, Ptr{Uint8}))
@libgit(git_odb_open_rstream, Cint,
        (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}))
@libgit(git_odb_open_wstream, Cint,
        (Ptr{Ptr{Void}}, Ptr{Void}, Csize_t, Cint))
@libgit(git_odb_stream_read, Cint,
        (Ptr{Void}, Ptr{Uint8}, Csize_t))
@libgit(git_odb_stream_write, Cint,
        (Ptr{Void}, Ptr{Cchar}, Csize_t)) 
@libgit(git_odb_stream_finalize_write, Cint,
        (Ptr{Uint8}, Ptr{Void}))
@libgit(git_odb_stream_free, Void, (Ptr{Void},))
@libgit(git_odb_object_free, Void, (Ptr{Void},))
@libgit(git_odb_object_id, Ptr{Uint8}, (Ptr{Void},))
@libgit(git_odb_object_data, Ptr{Void}, (Ptr{Void},))
@libgit(git_odb_object_size, Csize_t, (Ptr{Void},))
@libgit(git_odb_object_type, Cint, (Ptr{Void},))

# ------ libgit reference  ------
@libgit(git_reference_is_valid_name, Cint, (Ptr{Cchar},))
@libgit(git_reference_create, Cint, 
        (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Cchar}, Ptr{Uint8}, Cint))
@libgit(git_reference_free, Void, (Ptr{Void},))
@libgit(git_reference_peel, Cint, (Ptr{Ptr{Void}}, Ptr{Void}, Cint))
@libgit(git_reference_symbolic_create, Cint,
        (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Cchar}, Ptr{Uint8}, Cint))
@libgit(git_reference_lookup, Cint, 
        (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Cchar}))
@libgit(git_reference_symbolic_target, Ptr{Cchar}, (Ptr{Void},)) 
@libgit(git_reference_set_target, Cint, 
        (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}))
@libgit(git_reference_resolve, Cint, (Ptr{Ptr{Void}}, Ptr{Void}))
@libgit(git_reference_rename, Cint, 
        (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Cchar}, Cint))
@libgit(git_reference_target, Ptr{Uint8}, (Ptr{Void},))
@libgit(git_reference_delete, Cint, (Ptr{Void},))
@libgit(git_reference_name, Ptr{Cchar}, (Ptr{Void},))
@libgit(git_reference_type, Cint, (Ptr{Void},))
@libgit(git_reference_iterator_new, Cint, (Ptr{Ptr{Void}}, Ptr{Void}))
@libgit(git_reference_iterator_glob_new, Cint, 
        (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Cchar}))
@libgit(git_reference_next_name, Cint, (Ptr{Ptr{Void}}, Ptr{Void}))
@libgit(git_reference_next, Cint, (Ptr{Ptr{Void}}, Ptr{Void}))
@libgit(git_reference_iterator_free, Cint, (Ptr{Void},))
@libgit(git_reference_has_log, Cint, (Ptr{Void},))
@libgit(git_reference_owner, Ptr{Void}, (Ptr{Void},))

@libgit(git_reflog_write, Cint, (Ptr{Void},))
@libgit(git_reflog_read, Cint, (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Cchar}))
@libgit(git_reflog_append, Cint, (Ptr{Void}, Ptr{Void}, Ptr{GitSignature}, Ptr{Cchar}))
@libgit(git_reflog_entrycount, Cint, (Ptr{Void},))
@libgit(git_reflog_entry_byindex, Ptr{Void}, (Ptr{Void}, Csize_t))
@libgit(git_reflog_free, Void, (Ptr{Void},))
@libgit(git_reflog_entry_id_old, Ptr{Uint8}, (Ptr{Void},))
@libgit(git_reflog_entry_id_new, Ptr{Uint8}, (Ptr{Void},))
@libgit(git_reflog_entry_committer, Ptr{GitSignature}, (Ptr{Void},))
@libgit(git_reflog_entry_message, Ptr{Cchar}, (Ptr{Void},))

# ------ libgit checkout  ------
#TODO:...
type GitCheckoutOpts
    version::Cuint
    checkout_strategy::Cuint
    disable_filters::Cint
    dir_mode::Cint
    file_mode::Cint
    file_open_flags::Cint
    notify_flags::Cuint 
    notify_cb::Ptr{Void}
    notify_payload::Ptr{Void}
    progress_cb::Ptr{Void}
    progress_payload::Ptr{Void}
    paths_strings::Ptr{Ptr{Void}}
    paths_count::Csize_t
    baseline::Ptr{Void}
    target_directory::Ptr{Cchar}
    our_label::Ptr{Cchar}
    their_label::Ptr{Cchar}

    function GitCheckoutOpts()
        return new(cuint(0),
                   cuint(0),
                   cint(0),
                   cint(0),
                   cint(0),
                   cint(0),
                   cuint(0),
                   C_NULL,
                   C_NULL,
                   C_NULL,
                   C_NULL,
                   C_NULL,
                   convert(Csize_t, 0),
                   C_NULL,
                   C_NULL,
                   C_NULL,
                   C_NULL)
    end
end

@libgit(git_checkout_opts_init, Ptr{Void}, ())
@libgit(git_checkout_head, Cint, (Ptr{Void}, Ptr{Void})) 
@libgit(git_checkout_index, Cint, (Ptr{Void}, Ptr{Void}, Ptr{Void}))

# ------ libgit config  ------
type GitConfigEntry
    name::Ptr{Cchar}
    value::Ptr{Cchar}
    level::Cint
end

@libgit(git_config_open_default, Cint, (Ptr{Ptr{Void}},))
@libgit(git_config_open_ondisk,  Cint, (Ptr{Ptr{Void}}, Ptr{Cchar}))
@libgit(git_config_set_string, Cint, (Ptr{Void}, Ptr{Cchar}, Ptr{Cchar}))
@libgit(git_config_get_string, Cint, (Ptr{Ptr{Cchar}}, Ptr{Void}, Ptr{Cchar}))
@libgit(git_config_set_int64,  Cint, (Ptr{Void}, Ptr{Cchar}, Int64))
@libgit(git_config_get_int64,  Cint, (Ptr{Int64}, Ptr{Void}, Ptr{Cchar}))
@libgit(git_config_set_int32,  Cint, (Ptr{Void}, Ptr{Cchar}, Int32))
@libgit(git_config_get_int32,  Cint, (Ptr{Int32}, Ptr{Void}, Ptr{Cchar}))
@libgit(git_config_set_bool,   Cint, (Ptr{Void}, Ptr{Cchar}, Cint))
@libgit(git_config_get_bool,   Cint, (Ptr{Cint}, Ptr{Void}l, Ptr{Cchar}))
@libgit(git_config_delete_entry, Cint, (Ptr{Void}, Ptr{Cchar}))
@libgit(git_config_free, Void, (Ptr{Void},)) 
@libgit(git_config_foreach, Cint, (Ptr{Void}, Ptr{Void}, Ptr{Void})) 

end # module api
