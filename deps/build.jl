const pathkey = "JULIA_LIBCEED_LIB"

if isfile("deps.jl")
   rm("deps.jl")
end

if haskey(ENV, pathkey)
   ceedpath = escape_string(ENV[pathkey])
   open("deps.jl", write=true) do f
      println(f, "const libceed = \"$ceedpath\"")
   end
else
   error("""
   JULIA_LIBCEED_LIB environment variable not set.

   To build libCEED.jl, set the JULIA_LIBCEED_LIB environment variable
   to the absolute path of the libCEED dynamic library.
   """)
end
