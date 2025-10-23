#=
using Agents, Random
using StaticArrays: SVector
using Distributions: Uniform

@agent struct TrafficLight(ContinuousAgent{2,Float64})
    orientation::Symbol   
    color::Symbol         
    timer::Int            
end

@agent struct Car(ContinuousAgent{2,Float64})
    speed::Float64        
end

const DEFAULT_GREEN  = 10
const DEFAULT_YELLOW = 4
const DEFAULT_RED    = 14

const CAR_SPEED   = 0.7    
const STOP_GAP    = 1.5     
const LEFT_RESPAWN = 2.0    
const RIGHT_MARGIN = 2.0   

cycle_len(g,y,r) = g + y + r
_next_color(c) = c === :green ? :yellow : (c === :yellow ? :red : :green)


function light_step!(l::TrafficLight, model)
    pars = model.properties
    g, y, r = pars[:green], pars[:yellow], pars[:red]
    durations = (; green=g, yellow=y, red=r)

    l.timer += 1
    if (l.color === :green  && l.timer >= durations.green) ||
       (l.color === :yellow && l.timer >= durations.yellow) ||
       (l.color === :red    && l.timer >= durations.red)
        l.color = _next_color(l.color)
        l.timer = 0
    end
end


function car_step!(a::Car, model)
    pars = model.properties
    cx   = pars[:cx]
    extentx = model.space.extent[1]

    l_ew = model[pars[:light_ew_id]]
    stop_x = cx - STOP_GAP

    must_stop = (l_ew.color != :green)

    proposed = a.pos[1] + a.speed

    if must_stop
        if a.pos[1] < stop_x
            newx = min(proposed, stop_x)
        else
            newx = a.pos[1]
        end
    else
        newx = proposed
    end

    if newx > (extentx - RIGHT_MARGIN)
        newx = LEFT_RESPAWN
    end

    move_agent!(a, model, SVector{2,Float64}(newx, a.pos[2]))
end


agent_step!(l::TrafficLight, m) = light_step!(l, m)
agent_step!(c::Car,         m) = car_step!(c, m)


function initialize_cross_model(extent::Tuple{Int,Int}=(30,30);
                                seed::Int=1,
                                green::Int=DEFAULT_GREEN,
                                yellow::Int=DEFAULT_YELLOW,
                                red::Int=DEFAULT_RED,
                                add_car::Bool=true)

    @assert extent[1] == extent[2] 

    space2d = ContinuousSpace(extent; spacing = 1.0, periodic = false)
    rng     = Random.MersenneTwister(seed)

    model = StandardABM(Union{TrafficLight,Car}, space2d;
                        rng,
                        agent_step!,
                        scheduler = Schedulers.by_type((TrafficLight, Car)),
                        properties = Dict{Symbol,Any}(:green=>green, :yellow=>yellow, :red=>red))

    cx, cy = extent[1]/2, extent[2]/2

    pos_ew = SVector{2,Float64}(cx - 1.0, cy + 0.0)  
    pos_ns = SVector{2,Float64}(cx + 0.0, cy - 1.0)  

    lew = add_agent!(pos_ew, model; orientation=:EW, color=:green, timer=0)
    lns = add_agent!(pos_ns, model; orientation=:NS, color=:red,   timer=0)

    model.properties[:cx] = cx
    model.properties[:cy] = cy
    model.properties[:light_ew_id] = lew
    model.properties[:light_ns_id] = lns

    if add_car
        function rand_x_away()
            while true
                x = rand(rng, Uniform(2.0, extent[1]-2.0))
                abs(x - cx) > 3.0 && return x
            end
        end
        x0 = rand_x_away()
        y0 = cy
        add_agent!(SVector{2,Float64}(x0, y0), model; speed = CAR_SPEED)
    end

    return model
end
=#












using Agents, Random
using StaticArrays: SVector
using Distributions: Uniform

@agent struct TrafficLight(ContinuousAgent{2,Float64})
    orientation::Symbol 
    color::Symbol        
    timer::Int            
end

@agent struct Car(ContinuousAgent{2,Float64})
    speed::Float64       
end


const DEFAULT_GREEN  = 10
const DEFAULT_YELLOW = 4
const DEFAULT_RED    = 14

const CAR_SPEED   = 0.7     
const STOP_GAP    = 1.5      
const LEFT_RESPAWN = 2.0     
const RIGHT_MARGIN = 2.0     

cycle_len(g,y,r) = g + y + r
_next_color(c) = c === :green ? :yellow : (c === :yellow ? :red : :green)

function light_step!(l::TrafficLight, model)
    pars = model.properties
    g, y, r = pars[:green], pars[:yellow], pars[:red]
    durations = (; green=g, yellow=y, red=r)

    l.timer += 1
    if (l.color === :green  && l.timer >= durations.green) ||
       (l.color === :yellow && l.timer >= durations.yellow) ||
       (l.color === :red    && l.timer >= durations.red)
        l.color = _next_color(l.color)
        l.timer = 0
    end
end

function car_step!(a::Car, model)
    pars = model.properties
    cx   = pars[:cx]
    extentx = model.space.extent[1]

    l_ew = model[pars[:light_ew_id]]
    stop_x = cx - STOP_GAP

    must_stop = (l_ew.color != :green)

    proposed = a.pos[1] + a.speed

    if must_stop
        if a.pos[1] < stop_x
            newx = min(proposed, stop_x)
        else
            newx = a.pos[1]
        end
    else

        newx = proposed
    end

    if newx > (extentx - RIGHT_MARGIN)
        newx = LEFT_RESPAWN
    end

    move_agent!(a, model, SVector{2,Float64}(newx, a.pos[2]))
end

agent_step!(l::TrafficLight, m) = light_step!(l, m)
agent_step!(c::Car,         m) = car_step!(c, m)

function initialize_cross_model(extent::Tuple{Int,Int}=(30,30);
                                seed::Int=1,
                                green::Int=DEFAULT_GREEN,
                                yellow::Int=DEFAULT_YELLOW,
                                red::Int=DEFAULT_RED,
                                add_car::Bool=true)

    @assert extent[1] == extent[2]

    space2d = ContinuousSpace(extent; spacing = 1.0, periodic = false)
    rng     = Random.MersenneTwister(seed)

    model = StandardABM(Union{TrafficLight,Car}, space2d;
                        rng,
                        agent_step!,
                        scheduler = Schedulers.by_type((TrafficLight, Car)),
                        properties = Dict{Symbol,Any}(:green=>green, :yellow=>yellow, :red=>red))

    cx, cy = extent[1]/2, extent[2]/2

    pos_ew = SVector{2,Float64}(cx - 1.0, cy + 0.0)  
    pos_ns = SVector{2,Float64}(cx + 0.0, cy - 1.0)  

    lew = add_agent!(pos_ew, model; orientation=:EW, color=:green, timer=0)
    lns = add_agent!(pos_ns, model; orientation=:NS, color=:red,   timer=0)

    model.properties[:cx] = cx
    model.properties[:cy] = cy
    model.properties[:light_ew_id] = lew
    model.properties[:light_ns_id] = lns

    if add_car
        function rand_x_away()
            while true
                x = rand(rng, Uniform(2.0, extent[1]-2.0))
                abs(x - cx) > 3.0 && return x
            end
        end
        x0 = rand_x_away()
        y0 = cy 
        add_agent!(SVector{2,Float64}(x0, y0), model; speed = CAR_SPEED)
    end

    return model
end

if abspath(PROGRAM_FILE) == @__FILE__
    m = initialize_cross_model(; add_car=true)
    for t in 1:30
        run!(m, 1)
        lew = m[m.properties[:light_ew_id]]
        car = first(filter(a->a isa Car, allagents(m)); init=nothing)
        println("t=$t  light(EW)=$(lew.color)  car_x=", isnothing(car) ? "—" : round(car.pos[1]; digits=2))
    end
end
