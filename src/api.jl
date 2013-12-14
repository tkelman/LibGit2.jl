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

# ----- libgit constants -----
const OID_RAWSZ = 20
const OID_HEXSZ = 40

const OBJ_ANY    = cint(-2)
const OBJ_BAD    = cint(-1)
const OBJ_COMMIT = cint(1)
const OBJ_TREE   = cint(2)
const OBJ_BLOB   = cint(3)
const OBJ_TAG    = cint(4)

const REF_OID = cint(1)    
const REF_SYMBOLIC = cint(0)

const FILEMODE_NEW             = cint(00000)
const FILEMODE_TREE            = cint(16384)
const FILEMODE_BLOB            = cint(33188)
const FILEMODE_BLOB_EXECUTABLE = cint(33261)
const FILEMODE_LINK            = cint(40960)
const FILEMODE_COMMIT          = cint(57344)

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

# ----- libgit threads -----
@libgit(git_threads_init, Cint, ())
@libgit(git_threads_shutdown, Cint, ())

# ----- libgit repo ------
@libgit(git_repository_open, Cint, (Ptr{Ptr{Void}}, Ptr{Cchar}))
@libgit(git_repository_init, Cint, (Ptr{Ptr{Void}}, Ptr{Cchar}, Cint))
@libgit(git_repository_free, Cint, (Ptr{Void},))
@libgit(git_repository_index, Cint, (Ptr{Ptr{Void}}, Ptr{Void}))
@libgit(git_repository_is_bare, Cint, (Ptr{Void},))
@libgit(git_repository_is_empty, Cint, (Ptr{Void},))
@libgit(git_repository_workdir, Ptr{Cchar}, (Ptr{Void},))
@libgit(git_repository_path, Ptr{Cchar}, (Ptr{Void},))

@libgit(git_revparse_single, Cint, (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Cchar}))

# ----- libgit index ------
@libgit(git_index_free, Cint, (Ptr{Void},))
@libgit(git_index_add_bypath, Cint, (Ptr{Void}, Ptr{Cchar}))
@libgit(git_index_write_tree, Cint, (Ptr{Uint8}, Ptr{Void}))

# ----- libgit object ------
@libgit(git_object_id, Ptr{Uint8}, (Ptr{Void},))
@libgit(git_object_free, Cint, (Ptr{Void},))
@libgit(git_object_id, Ptr{Uint8}, (Ptr{Void},))
@libgit(git_oid_fmt, Cint, (Ptr{Cchar}, Ptr{Uint8}))
@libgit(git_object_lookup, Cint, (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}, Cint))
@libgit(git_object_type, Cint, (Ptr{Void},))

# ----- libgit signature ------
type Signature
    name::Ptr{Cchar}
    email::Ptr{Cchar}
    time::Int64
    time_offset::Cint
end

@libgit(git_signature_new, Cint, (Ptr{Ptr{Signature}}, Ptr{Cchar}, Ptr{Cchar}, Int64, Cint))
@libgit(git_signature_now, Cint, (Ptr{Ptr{Signature}}, Ptr{Cchar}, Ptr{Cchar}))

# ----- libgit commit ------
@libgit(git_commit_message, Ptr{Cchar}, (Ptr{Void},))
@libgit(git_commit_message_raw, Ptr{Cchar}, (Ptr{Void},))
@libgit(git_commit_tree, Cint, (Ptr{Ptr{Void}}, Ptr{Void}))
@libgit(git_commit_tree_id, Ptr{Uint8}, (Ptr{Void},))
@libgit(git_commit_committer, Ptr{Signature}, (Ptr{Void},))
@libgit(git_commit_author, Ptr{Signature}, (Ptr{Void},))
@libgit(git_commit_parent, Cint, (Ptr{Ptr{Void}}, Ptr{Void}, Cuint))
@libgit(git_commit_parent_id, Ptr{Void}, (Ptr{Void}, Cuint))
@libgit(git_commit_lookup_prefix, Cint,
        (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Void}, Csize_t))
@libgit(git_commit_create, Cint,
        (Ptr{Uint8}, Ptr{Void}, Ptr{Cchar}, Ptr{Signature},
         Ptr{Signature}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Void},
         Cint, Ptr{Ptr{Void}}))
                               
# ------ libgit blob ------
@libgit(git_blob_rawsize, Int64, (Ptr{Void},))
@libgit(git_blob_owner, Ptr{Void}, (Ptr{Void},))
@libgit(git_blob_rawcontent, Ptr{Void}, (Ptr{Void},))
@libgit(git_blob_is_binary, Cint, (Ptr{Void},))

# ------ libgit tree ------
@libgit(git_tree_entry_bypath, Cint, (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Cchar})) 
@libgit(git_tree_entry_byname, Ptr{Void}, (Ptr{Void}, Ptr{Cchar}))
@libgit(git_tree_entry_free, Cint, (Ptr{Void},))
@libgit(git_tree_entry_name, Ptr{Cchar}, (Ptr{Void},))
@libgit(git_tree_entry_id, Ptr{Uint8}, (Ptr{Void},))
@libgit(git_tree_entry_type, Cint, (Ptr{Void},))
@libgit(git_tree_entry_filemode, Cint, (Ptr{Void},))
@libgit(git_tree_entrycount, Csize_t, (Ptr{Void},))
end # module api
