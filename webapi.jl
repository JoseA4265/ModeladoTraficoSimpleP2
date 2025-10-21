#= #Codigo original
include("simple.jl")
using Genie, Genie.Renderer.Json, Genie.Requests, HTTP
using UUIDs

instances = Dict()

route("/simulations", method = POST) do
    payload = jsonpayload()
    
    #= #Activar seccion para modificacion de 2 del paso 1
    n_cars = get(payload, "n_cars", 12)  # default 12 si no lo mandan
    seed   = get(payload, "seed", 1)
    =#
    

    model = initialize_model()
    
    #= #Activar para modificacion 2 del paso 1
    model = initialize_model(; n_cars = n_cars, seed = seed)
    =#
    
    
    id = string(uuid1())
    instances[id] = model

    cars = []
    for car in allagents(model)
        push!(cars, car)
    end

    #=  #Activar para modificacion 2 del paso 1
    cars = [car for car in allagents(model)]
    =#
    
    
    json(Dict("Location" => "/simulations/$id", "cars" => cars))
end

route("/simulations/:id") do
    println(payload(:id))
    model = instances[payload(:id)]
    run!(model, 1)
    cars = []
    for car in allagents(model)
        push!(cars, car)
    end
    
    json(Dict("cars" => cars))
end

#= #Activar para modificacion 2 del paso 1
route("/simulations/:id") do
    model = instances[payload(:id)]
    run!(model, 1)
    cars = [car for car in allagents(model)]
    json(Dict("cars" => cars))
end
=#


Genie.config.run_as_server = true
Genie.config.cors_headers["Access-Control-Allow-Origin"] = "*"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS" 
Genie.config.cors_allowed_origins = ["*"]

up()
=#




#Pregunta 3, Realineando el trafico
include("simple.jl")

using Genie, Genie.Renderer.Json, Genie.Requests, HTTP
using UUIDs
using Statistics

Genie.config.server_host = "127.0.0.1"
Genie.config.server_port = 8000

const instances      = Dict{String, Any}()             
const blue_ids       = Dict{String, Int}()            
const history_blue   = Dict{String, Vector{Float64}}() 
const history_min    = Dict{String, Vector{Float64}}()  
const history_max    = Dict{String, Vector{Float64}}()  

function serialize_cars(model)
    cars = Vector{Dict{String,Any}}()
    for a in allagents(model)
        push!(cars, Dict(
            "id"      => a.id,
            "pos"     => (Float64(a.pos[1]), Float64(a.pos[2])),
            "vel"     => (Float64(a.vel[1]), Float64(a.vel[2])),
            "is_blue" => a.is_blue,
            "color"   => a.color,
        ))
    end
    return cars
end
extent_tuple(model) = try Tuple(model.space.extent) catch; (25,10) end

route("/simulations", method = POST) do
    payload = jsonpayload()
    n_cars = get(payload, "n_cars", 5)
    seed   = get(payload, "seed",   1)

    model = initialize_model(; n_cars=n_cars, seed=seed)
    id = string(uuid1())
    instances[id] = model

    bid = blue_id(model)
    blue_ids[id]     = bid
    history_blue[id] = Float64[]
    history_min[id]  = Float64[]
    history_max[id]  = Float64[]

    push!(history_blue[id], current_blue_speed(model, bid))
    vs = [a.vel[1] for a in allagents(model)]
    push!(history_min[id], minimum(vs))
    push!(history_max[id], maximum(vs))

    json(Dict(
        "id"            => id,
        "extent"        => extent_tuple(model),
        "cars"          => serialize_cars(model),
        "speed_history" => Dict("blue"=>history_blue[id], "min"=>history_min[id], "max"=>history_max[id])
    ))
end

route("/simulations/:id") do
    id    = payload(:id)
    model = instances[id]
    run!(model, 1)

    bid = blue_ids[id]
    push!(history_blue[id], current_blue_speed(model, bid))
    vs = [a.vel[1] for a in allagents(model)]
    push!(history_min[id], minimum(vs))
    push!(history_max[id], maximum(vs))

    json(Dict(
        "cars"          => serialize_cars(model),
        "extent"        => extent_tuple(model),
        "speed_history" => Dict("blue"=>history_blue[id], "min"=>history_min[id], "max"=>history_max[id]),
        "tick"          => length(history_blue[id])-1
    ))
end

function ui_html()
    raw"""
<!doctype html>
<html>
<head>
<meta charset="utf-8" />
<title>Traffic ABM</title>
<meta name="viewport" content="width=device-width, initial-scale=1" />
<style>
 body{font-family:system-ui,Segoe UI,Roboto,sans-serif;margin:16px}
 .toolbar{display:flex;gap:12px;margin-bottom:12px}
 button{padding:8px 14px;border:1px solid #ccc;border-radius:10px;background:#f8f8f8;cursor:pointer}
 button.primary{background:#0ea5e9;color:#fff;border-color:#0ea5e9}
 .row{display:flex;flex-wrap:wrap;gap:16px}
 #stage{border:1px solid #ddd;border-radius:12px}
 .panel{border:1px solid #ddd;border-radius:12px;padding:12px;box-shadow:0 2px 10px rgba(0,0,0,.06)}
 .legend{display:flex;gap:18px;margin-top:6px;font-size:14px}
 .dot{display:inline-block;width:12px;height:12px;border-radius:50%;margin-right:6px;vertical-align:middle}
 .red{background:#ef4444}.blue{background:#3b82f6}.green{background:#22c55e}
 #status{min-height:1.2em;color:#b91c1c;margin-bottom:8px}
</style>
</head>
<body>
  <div id="status"></div>
  <div class="toolbar">
    <button id="btnSetup">Setup</button>
    <button id="btnStart" class="primary">Start</button>
    <button id="btnStop">Stop</button>
    <div style="margin-left:auto">sim: <code id="simId">—</code> · tick: <b id="tick">0</b></div>
  </div>

  <div class="row">
    <canvas id="stage" width="940" height="280" class="panel"></canvas>
    <div class="panel" style="flex:1;min-width:420px">
      <h3 style="margin:6px 0 12px">Car speeds</h3>
      <canvas id="chart" height="220"></canvas>
      <div class="legend">
        <span><span class="dot red"></span> red car (blue-agent)</span>
        <span><span class="dot blue"></span> min speed</span>
        <span><span class="dot green"></span> max speed</span>
      </div>
    </div>
  </div>

<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
<script>
let simId=null, timer=null, extent=[25,10];
const roadY=200, roadH=55, statusEl=document.getElementById('status');

const c=document.getElementById('stage'), ctx=c.getContext('2d');
function clear(){ctx.clearRect(0,0,c.width,c.height)}
function road(){ctx.fillStyle='#b3b3b3';ctx.fillRect(10,roadY,c.width-20,roadH)}
function drawCar(x,y,color){
  const sx=10 + x*(c.width-20)/extent[0];
  const sy=roadY + roadH/2 - (y-5)*5;
  ctx.fillStyle=color; ctx.fillRect(sx-10,sy-7,20,14);
  ctx.fillStyle='#111';
  ctx.fillRect(sx-12,sy-10,6,4); ctx.fillRect(sx+6,sy-10,6,4);
  ctx.fillRect(sx-12,sy+6,6,4);  ctx.fillRect(sx+6,sy+6,6,4);
}
function render(cars){ clear(); road(); for(const a of cars){ drawCar(a.pos[0], a.pos[1], a.is_blue?'blue':(a.color||'red')); } }

const chart = new Chart(document.getElementById('chart').getContext('2d'),{
  type:'line',
  data:{ labels:[], datasets:[
    {label:'red car (blue-agent)', data:[], borderColor:'#ef4444', tension:0, borderWidth:2, pointRadius:0},
    {label:'min speed',            data:[], borderColor:'#3b82f6', tension:0, borderWidth:1.5, pointRadius:0},
    {label:'max speed',            data:[], borderColor:'#22c55e', tension:0, borderWidth:1.5, pointRadius:0},
  ]},
  options:{ responsive:true, animation:false,
    scales:{ y:{min:0,max:1.1, title:{display:true,text:'speed'}}, x:{title:{display:true,text:'time'}} },
    plugins:{ legend:{position:'bottom'} }
  }
});

function updateChart(sh){
  chart.data.labels = sh.blue.map((_,i)=>i);
  chart.data.datasets[0].data = sh.blue; // rojo = azul (blue-agent)
  chart.data.datasets[1].data = sh.min;
  chart.data.datasets[2].data = sh.max;
  chart.update();
}

async function setup(){
  statusEl.textContent='';
  const res = await fetch('/simulations', {method:'POST', headers:{'Content-Type':'application/json'}, body:'{}'});
  const js  = await res.json();
  simId = js.id; extent = js.extent;
  document.getElementById('simId').textContent=simId;
  document.getElementById('tick').textContent=0;
  updateChart(js.speed_history);
  render(js.cars);
}

async function step(){
  if(!simId) return;
  const res = await fetch(`/simulations/${simId}`);
  const js  = await res.json();
  extent = js.extent || extent;
  updateChart(js.speed_history);
  document.getElementById('tick').textContent = js.tick;
  render(js.cars);
}

document.getElementById('btnSetup').addEventListener('click', setup);
document.getElementById('btnStart').addEventListener('click', async()=>{
  if(!simId) await setup();         
  if(timer) clearInterval(timer);
  await step();                       
  timer=setInterval(step,150);      
});
document.getElementById('btnStop').addEventListener('click', ()=>{ if(timer) clearInterval(timer); });

window.addEventListener('load', async()=>{ await setup(); document.getElementById('btnStart').click(); });
</script>
</body>
</html>
"""
end

route("/")  do; ui_html(); end
route("/ui") do; ui_html(); end

Genie.config.run_as_server = true
Genie.config.cors_headers["Access-Control-Allow-Origin"]  = "*"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS"
Genie.config.cors_allowed_origins = ["*"]

up()
