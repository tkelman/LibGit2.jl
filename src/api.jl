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

@libgit(git_index_free, (Ptr{Void},))

end # module api
