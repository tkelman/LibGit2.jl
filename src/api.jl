module api

const libgit2 = "libgit2"

macro libgit(func, arg_types)
  local args_in = Symbol[symbol("arg$i::$T")
                         for (i, T) in enumerate(arg_types.args)]
  quote
      function $(esc(func))($(args_in...))
          err = ccall(($(string(func)), libgit2),
                       Cint,
                       $arg_types,
                       $(args_in...))
          return err
      end
   end
end

# ----- libgit repo ------
@libgit(git_repository_index, (Ptr{Ptr{Void}}, Ptr{Void}))

# ----- libgit index ------
@libgit(git_index_free, (Ptr{Void},))

# ----- libgit signiture ------
type Signature
    name::Ptr{Cchar}
    email::Ptr{Cchar}
    time::Int64
    time_offset::Cint
end

@libgit(git_signature_new, (Ptr{Ptr{Signature}}, Ptr{Cchar}, Ptr{Cchar}, Int64, Cint))
@libgit(git_signature_now, (Ptr{Ptr{Signature}}, Ptr{Cchar}, Ptr{Cchar}))

end # module api
