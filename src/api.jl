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

# ----- libgit repo ------
@libgit(git_repository_open, Cint, (Ptr{Ptr{Void}}, Ptr{Cchar}))
@libgit(git_repository_init, Cint, (Ptr{Ptr{Void}}, Ptr{Cchar}, Cint))
@libgit(git_repository_free, Cint, (Ptr{Void},))
@libgit(git_repository_index, Cint, (Ptr{Ptr{Void}}, Ptr{Void}))
@libgit(git_repository_is_bare, Cint, (Ptr{Void},))
@libgit(git_repository_is_empty, Cint, (Ptr{Void},))
@libgit(git_repository_workdir, Ptr{Cchar}, (Ptr{Void},))
@libgit(git_repository_path, Ptr{Cchar}, (Ptr{Void},))

# ----- libgit index ------
@libgit(git_index_free, Cint, (Ptr{Void},))

# ----- libgit signiture ------
type Signature
    name::Ptr{Cchar}
    email::Ptr{Cchar}
    time::Int64
    time_offset::Cint
end

@libgit(git_signature_new, Cint, (Ptr{Ptr{Signature}}, Ptr{Cchar}, Ptr{Cchar}, Int64, Cint))
@libgit(git_signature_now, Cint, (Ptr{Ptr{Signature}}, Ptr{Cchar}, Ptr{Cchar}))

end # module api
