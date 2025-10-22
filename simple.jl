 # Modelado de Trafico Simple Parte 2, cruce con semáforos
using Agents, Random
using StaticArrays: SVector

@agent struct TrafficLight(ContinuousAgent{2,Float64})
    orientation::Symbol   
    color::Symbol        
    timer::Int            
end

const DEFAULT_GREEN  = 10
const DEFAULT_YELLOW = 4
const DEFAULT_RED    = 14

cycle_len(g,y,r) = g + y + r
_next_color(c) = c === :green ? :yellow : (c === :yellow ? :red : :green)

function light_step!(l::TrafficLight, model)
    pars = model.properties      
    g, y, r = pars[:green], pars[:yellow], pars[:red]
    durations = Dict(:green=>g, :yellow=>y, :red=>r)

    l.timer += 1
    if l.timer >= durations[l.color]
        l.color = _next_color(l.color)
        l.timer = 0
    end
end

function initialize_cross_model(extent::Tuple{Int,Int}=(30,30);
                                seed::Int=1,
                                green::Int=DEFAULT_GREEN,
                                yellow::Int=DEFAULT_YELLOW,
                                red::Int=DEFAULT_RED)

    @assert extent[1] == extent[2] 

    space2d = ContinuousSpace(extent; spacing = 1.0, periodic = false)
    rng     = Random.MersenneTwister(seed)

    model = StandardABM(TrafficLight, space2d;
                        rng,
                        agent_step! = light_step!,
                        scheduler = Schedulers.Randomly(),
                        properties = Dict(:green=>green, :yellow=>yellow, :red=>red))

    cx, cy = extent[1]/2, extent[2]/2

    pos_ew = SVector{2,Float64}(cx - 1.0, cy + 0.0)
    pos_ns = SVector{2,Float64}(cx + 0.0, cy - 1.0)

    add_agent!(pos_ew, model; orientation=:EW, color=:green, timer=0)
    add_agent!(pos_ns, model; orientation=:NS, color=:red,   timer=0)

    return model
end

if abspath(PROGRAM_FILE) == @__FILE__
    m = initialize_cross_model()
    for t in 1:30
        run!(m, 1)
        cs = [(a.orientation, a.color, a.timer) for a in allagents(m)]
        println("t=$t  ", cs)
    end
end
