using BinDeps

@BinDeps.setup

libgit2 = library_dependency("libgit2")
version = "0.21.0-rc2"
provides(Sources,
         URI("https://github.com/libgit2/libgit2/archive/v$version.tar.gz"),
         libgit2,
         unpacked_dir="libgit2-$version")

# Windows binaries built in MSYS2 via:
# /d/code/CMake-2.8/bin/cmake .. -DCMAKE_INSTALL_PREFIX=$PWD/usr -G"MSYS Makefiles"
# /d/code/CMake-2.8/bin/cmake --build . --target install
provides(Binaries, URI("http://sourceforge.net/projects/juliadeps-win/files/libgit2-v$version.7z"),
         libgit2, os = :Windows)

prefix = joinpath(BinDeps.depsdir(libgit2),"usr")
srcdir = joinpath(BinDeps.depsdir(libgit2),"src","libgit2-$version") 

provides(SimpleBuild,
    (@build_steps begin
        GetSources(libgit2)
        @build_steps begin
            ChangeDirectory(srcdir)
            `cmake . -DCMAKE_INSTALL_PREFIX=$prefix`
            `make install`
        end
    end), libgit2, os = :Unix)

@BinDeps.install [:libgit2 => :libgit2]
