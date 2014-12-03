# LibGit2.jl "clone" example - shows how to use the clone API
#
# Written by the LibGit2.jl contributors, based on the libgit2 examples.
#
# To the extent possible under law, the author(s) have dedicated all copyright
# and related and neighboring rights to this software to the public domain
# worldwide. This software is distributed without any warranty.
#
# You should have received a copy of the CC0 Public Domain Dedication along
# with this software. If not, see
# <http://creativecommons.org/publicdomain/zero/1.0/>.

using LibGit2
using ArgParse

# This example demonstrates the use of the LibGit2.jl clone APIs
# emulating the command `git clone` and printing the progress of
# the clone process and of the checkout

# from the git-clone man page:
# Clones a repository into a newly created directory, creates remote-tracking
# branches for each branch in the cloned repository (visible using git branch -r),
# and creates and checks out an initial branch that is forked from the cloned
# repository's currently active branch.

function parse_commandline()
    settings = ArgParseSettings(autofix_names=true)
    @add_arg_table settings begin
        "repo-url"
        help = "repo url"
        required = true

        "directory"
        help = ""
    end
    return parse_args(settings)
end

# Assuming n is in bytes
function pretty_size(n)
    c = log2(n) / 10
    val = n / 1024^floor(c)
    c < 1      && return @sprintf("%i B",val)
    1 <= c < 2 && return @sprintf("%.2f KiB",val)
    2 <= c < 3 && return @sprintf("%.2f MiB",val)
    3 <= c     && return @sprintf("%.2f GiB",val)
end

# fetch and checkout head with progress indication
function doclone(repo_url::AbstractString, dest_dir::AbstractString)
    if isempty(dest_dir)
        git_dir = joinpath(pwd(), basename(splitext(repo_url)[1]))
    else
        git_dir = joinpath(pwd(), basename(dest_dir))
    end

    info("cloning into $git_dir")
    mkdir(git_dir)

    total_objects = indexed_objects = received_objects = received_bytes = 0
    repo = LibGit2.repo_clone(repo_url, git_dir, Dict{Any,Any}(
        :callbacks => Dict{Any,Any}(
          :transfer_progress => (args...) -> begin
                total_objects, indexed_objects, received_objects, received_bytes = args
                perc = int(received_objects / total_objects * 100.0)
                print("\rReceiving objects: $perc% ($received_objects/$total_objects) ",
                      "$(pretty_size(received_bytes))")
            end
          )
        ))

    println(", done.")

    path = completed_steps = total_steps = payload = 0
    LibGit2.checkout_head!(repo,
        Dict{Any,Any}(
         :strategy => :safe_create,
         :progress => (args...) -> begin
            path, completed_steps, total_steps = args
            print("\rUnpacking files: $completed_steps/$total_steps")
         end
        ))

    println(", done.")
    return repo
end

function main()
    opts = parse_commandline()
    if haskey(opts, "directory") && opts["directory"] != nothing
        doclone(opts["repo_url"], opts["directory"])
    else
        doclone(opts["repo_url"], "")
    end
end

main()
