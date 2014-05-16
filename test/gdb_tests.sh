#cat script.gdb | gdb --args julia runtests.jl all
gdb -ex r --args julia runtests.jl all
