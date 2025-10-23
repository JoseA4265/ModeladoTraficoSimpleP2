using Agents, Random
using StaticArrays: SVector
using Distributions: Uniform
using Statistics: mean

@agent struct TrafficLight(ContinuousAgent{2,Float64})
    orientation::Symbol   
    color::Symbol         
    timer::Int            
end

@agent struct Car(ContinuousAgent{2,Float64})
    orientation::Symbol   
    speed::Float64        
    max_speed::Float64    
end

const DEFAULT_GREEN  = 14
const DEFAULT_YELLOW = 4
const DEFAULT_RED    = 18

const ACCELERATION    = 0.04  
const BRAKE_DECEL     = 0.1   
const MAX_SPEED_BASE  = 0.8   
const MAX_SPEED_VAR   = 0.2   
const SAFE_DISTANCE   = 3.0   
const STOP_GAP        = 2.0   
const STREET_MARGIN   = 2.0   

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
    cx, cy = pars[:cx], pars[:cy]
    (extent_x, extent_y) = model.space.extent

    obstacle_dist = Inf
    
    if a.orientation === :EW
        light = model[pars[:light_ew_id]]
        stop_line = cx - STOP_GAP
        if (light.color != :green) && (a.pos[1] < stop_line)
            obstacle_dist = min(obstacle_dist, stop_line - a.pos[1])
        end
        
        for other in allagents(model)
            if other isa Car && other.id != a.id && other.orientation === :EW && other.pos[1] > a.pos[1]
                dist = other.pos[1] - a.pos[1]
                obstacle_dist = min(obstacle_dist, dist)
            end
        end

    else # :NS
        light = model[pars[:light_ns_id]]
        stop_line = cy - STOP_GAP
        if (light.color != :green) && (a.pos[2] < stop_line)
            obstacle_dist = min(obstacle_dist, stop_line - a.pos[2])
        end

        for other in allagents(model)
            if other isa Car && other.id != a.id && other.orientation === :NS && other.pos[2] > a.pos[2]
                dist = other.pos[2] - a.pos[2]
                obstacle_dist = min(obstacle_dist, dist)
            end
        end
    end

    target_speed = (obstacle_dist < SAFE_DISTANCE) ? 0.0 : a.max_speed

    if a.speed > target_speed
        a.speed = max(target_speed, a.speed - BRAKE_DECEL)
    elseif a.speed < target_speed
        a.speed = min(target_speed, a.speed + ACCELERATION)
    end

    if a.orientation === :EW
        new_x = a.pos[1] + a.speed
        if new_x > (extent_x - STREET_MARGIN)
            new_x = STREET_MARGIN
        end
        move_agent!(a, model, SVector{2,Float64}(new_x, a.pos[2]))
        
    else # :NS
        new_y = a.pos[2] + a.speed
        if new_y > (extent_y - STREET_MARGIN)
            new_y = STREET_MARGIN
        end
        move_agent!(a, model, SVector{2,Float64}(a.pos[1], new_y))
    end
end

agent_step!(l::TrafficLight, m) = light_step!(l, m)
agent_step!(c::Car,         m) = car_step!(c, m)

function initialize_cross_model(extent::Tuple{Int,Int}=(30,30);
                                seed::Int=1,
                                green::Int=DEFAULT_GREEN,
                                yellow::Int=DEFAULT_YELLOW,
                                red::Int=DEFAULT_RED,
                                num_cars_per_street::Int=3) 

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

    function rand_pos_away(orient::Symbol)
        while true
            if orient === :EW
                x = rand(rng, Uniform(STREET_MARGIN, extent[1] - STREET_MARGIN))
                abs(x - cx) > SAFE_DISTANCE + 1.0 && return x
            else
                y = rand(rng, Uniform(STREET_MARGIN, extent[2] - STREET_MARGIN))
                abs(y - cy) > SAFE_DISTANCE + 1.0 && return y
            end
        end
    end

    for _ in 1:num_cars_per_street
        x0 = rand_pos_away(:EW)
        y0 = cy
        speed0 = rand(rng, Uniform(0.0, MAX_SPEED_BASE))
        max_s  = MAX_SPEED_BASE + rand(rng, Uniform(-MAX_SPEED_VAR, MAX_SPEED_VAR))
        add_agent!(SVector{2,Float64}(x0, y0), model; orientation=:EW, speed=speed0, max_speed=max_s)
    end
    
    for _ in 1:num_cars_per_street
        x0 = cx
        y0 = rand_pos_away(:NS)
        speed0 = rand(rng, Uniform(0.0, MAX_SPEED_BASE))
        max_s  = MAX_SPEED_BASE + rand(rng, Uniform(-MAX_SPEED_VAR, MAX_SPEED_VAR))
        add_agent!(SVector{2,Float64}(x0, y0), model; orientation=:NS, speed=speed0, max_speed=max_s)
    end

    return model
end

function get_avg_speed(model)
    cars = [a for a in allagents(model) if a isa Car]
    if isempty(cars)
        return 0.0
    end
    return mean(c.speed for c in cars)
end
