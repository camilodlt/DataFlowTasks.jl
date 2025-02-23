__precompile__()

"""
    module DataFlowTask

Create `Task`s which can keep track of how data flows through it.
"""
module DataFlowTasks

dir = pkgdir(DataFlowTasks)
@static if VERSION > v"1.8"
    const PROJECT_ROOT::Ref{String} = Ref{String}(dir)
else
    const PROJECT_ROOT = Ref{String}(dir)
end

using OrderedCollections
using Compat
import Pkg
import TOML
import Scratch
using Printf

export @dspawn, @dasync

"""
    _get_dataflowtasks_root()

Returns the current `PROJECT_ROOT` value.

Does not assume the ref has been set.
"""
function _get_dataflowtasks_root()
    global PROJECT_ROOT
    return PROJECT_ROOT[]
end

"""
    @enum AccessMode READ WRITE READWRITE

Describe how a `DataFlowTask` access its `data`.
"""
@enum AccessMode::UInt8 begin
    READ
    WRITE
    READWRITE
end

const R  = READ
const W  = WRITE
const RW = READWRITE

const Maybe{T} = Union{T,Nothing}

include("utils.jl")
include("logger.jl")
include("dataflowtask.jl")
include("dag.jl")
include("taskgraph.jl")
include("arrayinterface.jl")

"""
    __init__()

"""
function __init__()
    # default scheduler
    capacity = 50
    tg = TaskGraph(capacity)
    set_active_taskgraph!(tg)
    # no logger by default
    return _setloginfo!(nothing)
end

const WEAKDEPS_PROJ = let
    deps = TOML.parse(read(joinpath(@__DIR__, "..", "ext", "Project.toml"), String))["deps"]
    filter!(deps) do (pkg, _)
        return pkg != String(nameof(@__MODULE__))
    end
    compat = Dict{String,Any}()
    for (pkg, bound) in
        TOML.parse(read(joinpath(@__DIR__, "..", "Project.toml"), String))["compat"]
        pkg ∈ keys(deps) || continue
        compat[pkg] = bound
    end
    Dict("deps" => deps, "compat" => compat)
end

"""
    DataFlowTasks.stack_weakdeps_env!(; verbose = false, update = false)

Push to the load stack an environment providing the weak dependencies of
DataFlowTasks. During the development stage, this allows benefiting from the
profiling / debugging features of DataFlowTasks without having to install
`GraphViz` or `Makie` in the project environment.

This can take quite some time if packages have to be installed or precompiled.
Run in `verbose` mode to see what happens.

Additionally, set `update=true` if you want to update the `weakdeps`
environment.

!!! warning

    This feature is experimental and might break in the future.

## Examples:
```example
DataFlowTasks.stack_weakdeps_env!()
using GraphViz
```
"""
function stack_weakdeps_env!(; verbose = false, update = false)
    weakdeps_env = Scratch.@get_scratch!("weakdeps-$(VERSION.major).$(VERSION.minor)")
    open(joinpath(weakdeps_env, "Project.toml"), "w") do f
        return TOML.print(f, WEAKDEPS_PROJ)
    end

    cpp = Pkg.project().path
    io = verbose ? stderr : devnull

    try
        Pkg.activate(weakdeps_env; io)
        update && Pkg.update(; io)
        Pkg.resolve(; io)
        Pkg.instantiate(; io)
        Pkg.status()
    finally
        Pkg.activate(cpp; io)
    end

    push!(LOAD_PATH, weakdeps_env)
    return nothing
end

"""
    DataFlowTasks.savedag(filepath, graph)

Save `graph` as an SVG image at `filepath`. This requires `GraphViz` to be
available.
"""
function savedag end

end # module
