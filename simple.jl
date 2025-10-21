#= #Codigo original
using Agents, Random
using StaticArrays: SVector

@agent struct Car(ContinuousAgent{2,Float64})
end


function agent_step!(agent, model)
    move_agent!(agent, model, 1.0)
end
=#


#= #Activar para modificacion 1 de pregunta 1, (POSICION DEL CARRO CON IDENTIFICADOR 1)
const PRINT_CAR1_POS = true

function agent_step!(agent, model)
    move_agent!(agent, model, 1.0)
    if PRINT_CAR1_POS && agent.id == 1
        # puedes usar println o @info; dejo ambos ejemplos:
        # println("car#1 pos=($(agent.pos[1]), $(agent.pos[2]))")
        @info "car#1 position" x=agent.pos[1] y=agent.pos[2]
    end
end
=#


#= #initialize_model original
function initialize_model(extent = (25, 10))
    space2d = ContinuousSpace(extent; spacing = 0.5, periodic = true)
    rng = Random.MersenneTwister()

    model = StandardABM(Car, space2d; rng, agent_step!, scheduler = Schedulers.Randomly())

    for px in randperm(25)[1:5]
        add_agent!(SVector{2, Float64}(px, 0.0), model; vel=SVector{2, Float64}(1.0, 0.0))
    end
    model
end
=#


#= #Modificacion 1 de la Pregunta 1, funcion extra
using Printf: @printf

function run_and_print!(model, steps::Int; id::Int=1)
    ids_disponibles = [a.id for a in allagents(model)]
    if !(id in ids_disponibles)
        println("No existe un agente con id=$id. Ids disponibles: $(ids_disponibles)")
        return
    end

    @printf("%-6s %-6s %-12s\n", "tick", "id", "pos(x,y)")
    for t in 1:steps
        run!(model, 1)                    
        a = model[id]                     
        @printf("%-6d %-6d (%.2f, %.2f)\n", t, id, a.pos[1], a.pos[2])
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    m = initialize_model()
    run_and_print!(m, 20; id=1)
end
=#


#= #Modificacion 2 de la Pregunta 1, muchos carros: 
function initialize_model(extent = (25, 10); n_cars::Int=5, seed::Int=1)
    space2d = ContinuousSpace(extent; spacing = 0.5, periodic = true)
    rng = Random.MersenneTwister(seed)
    model = StandardABM(Car, space2d; rng, agent_step!, scheduler = Schedulers.Randomly())

    for px in randperm(rng, 25)[1:n_cars]
        add_agent!(SVector{2, Float64}(px, 0.0), model; vel=SVector{2, Float64}(1.0, 0.0))
    end
    model
end

if abspath(PROGRAM_FILE) == @__FILE__
    m = initialize_model(; n_cars=12)
    run!(m, 10)
end
=#


#= # Modificacion 3 de la Pregunta 1, distintas velocidades a carros
function initialize_model(extent = (25, 10); seed::Int=1)
    space2d = ContinuousSpace(extent; spacing = 0.5, periodic = true)
    rng = Random.MersenneTwister(seed)
    model = StandardABM(Car, space2d; rng, agent_step!, scheduler = Schedulers.Randomly())

    for px in randperm(rng, 25)[1:5]
        speed = rand(rng)  # ∈ [0,1)
        add_agent!(SVector{2, Float64}(px, 0.0), model; vel=SVector{2, Float64}(speed, 0.0))
    end
    model
end

if abspath(PROGRAM_FILE) == @__FILE__
    m = initialize_model()
    for t in 1:10
        run!(m, 1)
        println("t=$t  id=1  vel=$(round(m[1].vel[1];digits=2))  pos=$(m[1].pos)")
    end
end
=#




#= # Pregunta 2, ORDEN AL CAOS
using Agents, Random
using StaticArrays: SVector

@agent struct Car(ContinuousAgent{2,Float64})
    accelerating::Bool = true
end

accelerate(agent) = agent.vel[1] + 0.05
decelerate(agent) = agent.vel[1] - 0.1

function  agent_step!(agent, model)
    new_velocity = agent.accelerating ? accelerate(agent) : decelerate(agent)

    if new_velocity >= 1.0
        new_velocity = 1.0
        agent.accelerating = false
    elseif new_velocity <= 0.0
        new_velocity = 0.0
        agent.accelerating = true
    end
    
    agent.vel = (new_velocity, 0.0)
    move_agent!(agent, model, 0.4)
end

function initialize_model(extent = (25, 10))
    space2d = ContinuousSpace(extent; spacing = 0.5, periodic = true)
    rng = Random.MersenneTwister()

    model = StandardABM(Car, space2d; rng, agent_step!, scheduler = Schedulers.Randomly())

    first = true
    py = 1.0
    for px in randperm(25)[1:5]
        if first
            add_agent!(SVector{2, Float64}(px, py), model; vel=SVector{2, Float64}(1.0, 0.0))
        else
            add_agent!(SVector{2, Float64}(px, py), model; vel=SVector{2, Float64}(rand(Uniform(0.2, 0.7)), 0.0))
        end
        py += 2.0
    end
    model
end
=#




# Paso 3 — Realineando el tráfico (integrado sobre "Orden al caos")
using Agents, Random
using StaticArrays: SVector
using Distributions: Uniform

@agent struct Car(ContinuousAgent{2,Float64})
    accelerating::Bool = true
    is_blue::Bool      = false
    color::String      = "red"
end

accelerate(c::Car) = c.vel[1] + 0.05
decelerate(c::Car) = c.vel[1] - 0.10

const LANE_TOL     = 0.25   
const LOOK_AHEAD   = 2.0   
const MOVE_DT      = 0.4    

function car_ahead(a::Car, model)
    for n in nearby_agents(a, model, LOOK_AHEAD + 0.1)  
        abs(n.pos[2] - a.pos[2]) ≤ LANE_TOL || continue
        dx = n.pos[1] - a.pos[1]
        if 0.0 < dx ≤ LOOK_AHEAD
            return n
        end
    end
    return nothing
end

function agent_step!(a::Car, model)
    new_v = isnothing(car_ahead(a, model)) ? accelerate(a) : decelerate(a)
    new_v = clamp(new_v, 0.0, 1.0)                
    a.vel = SVector{2,Float64}(new_v, 0.0)
    move_agent!(a, model, MOVE_DT)
end

function initialize_model(extent = (25, 10); n_cars::Int=5, seed::Int=1)
    space2d = ContinuousSpace(extent; spacing=0.5, periodic=true)
    rng     = Random.MersenneTwister(seed)
    model   = StandardABM(Car, space2d; rng, agent_step!, scheduler=Schedulers.Randomly())

    ys = collect(1.0:2.0:extent[2]-1)
    first = true
    i = 0
    for px in randperm(rng, extent[1])[1:n_cars]
        i += 1
        py = ys[(i-1) % length(ys) + 1]
        if first
            add_agent!(SVector{2,Float64}(px, py), model;
                       vel=SVector{2,Float64}(1.0, 0.0), is_blue=true, color="blue")
            first = false
        else
            v0 = rand(rng, Uniform(0.2, 0.7))
            add_agent!(SVector{2,Float64}(px, py), model;
                       vel=SVector{2,Float64}(v0, 0.0), is_blue=false, color="red")
        end
    end
    return model
end

function blue_id(model)
    for a in allagents(model)
        a.is_blue && return a.id
    end
    best, bestv = first(agents(model)).id, -Inf
    for a in allagents(model)
        if a.vel[1] > bestv
            best, bestv = a.id, a.vel[1]
        end
    end
    return best
end

current_blue_speed(model, bid::Int) = model[bid].vel[1]
