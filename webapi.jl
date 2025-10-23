include("simple.jl")

using Genie, Genie.Renderer.Html, Genie.Renderer.Json, Genie.Requests
using UUIDs

Genie.config.server_host = "127.0.0.1"
Genie.config.server_port = 8000
Genie.config.run_as_server = true

Genie.config.cors_headers["Access-Control-Allow-Origin"]  = "*"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS"
Genie.config.cors_allowed_origins = ["*"]

const INSTANCES = Dict{String, Any}()

function serialize_lights(model)
    out = Vector{Dict{String,Any}}()
    for a in allagents(model)
        if a isa TrafficLight
            push!(out, Dict(
                "id"          => a.id,
                "pos"         => (Float64(a.pos[1]), Float64(a.pos[2])),
                "orientation" => String(a.orientation),
                "color"       => String(a.color),
                "timer"       => a.timer
            ))
        end
    end
    return out
end

function serialize_cars(model)
    out = Vector{Dict{String,Any}}()
    for a in allagents(model)
        if a isa Car
            push!(out, Dict(
                "id"    => a.id,
                "pos"   => (Float64(a.pos[1]), Float64(a.pos[2])),
                "speed" => a.speed
            ))
        end
    end
    return out
end

extent_tuple(model) = try Tuple(model.space.extent) catch; (30,30) end

route("/simulations", method=POST) do
    p = jsonpayload()
    green  = get(p, "green",  DEFAULT_GREEN)
    yellow = get(p, "yellow", DEFAULT_YELLOW)
    red    = get(p, "red",    DEFAULT_RED)
    seed   = get(p, "seed",   1)

    model = initialize_cross_model(; green, yellow, red, seed, add_car=true)
    id = string(uuid1())
    INSTANCES[id] = model

    json(Dict(
        "id"     => id,
        "extent" => extent_tuple(model),
        "lights" => serialize_lights(model),
        "cars"   => serialize_cars(model)
    ))
end

route("/simulations/:id") do
    id = payload(:id)
    model = INSTANCES[id]
    run!(model, 1)
    json(Dict(
        "extent" => extent_tuple(model),
        "lights" => serialize_lights(model),
        "cars"   => serialize_cars(model)
    ))
end

function ui_html()
    raw"""
<!doctype html>
<html>
<head>
<meta charset="utf-8" />
<title>Cruce con Semáforos (ABM)</title>
<meta name="viewport" content="width=device-width, initial-scale=1" />
<style>
  body{font-family:system-ui,Segoe UI,Roboto,Arial,sans-serif;margin:16px}
  .toolbar{display:flex;gap:12px;margin-bottom:12px}
  button{padding:8px 14px;border:1px solid #ccc;border-radius:10px;background:#f8f8f8;cursor:pointer}
  button.primary{background:#0ea5e9;color:#fff;border-color:#0ea5e9}
  #stage{border:1px solid #ddd;border-radius:12px}
  .legend{margin-top:8px;display:flex;gap:14px}
  .dot{display:inline-block;width:12px;height:12px;border-radius:3px;margin-right:6px;vertical-align:middle}
  .g{background:#22c55e}.y{background:#eab308}.r{background:#ef4444}
</style>
</head>
<body>
  <div class="toolbar">
    <button id="btnSetup">Setup</button>
    <button id="btnStart" class="primary">Start</button>
    <button id="btnStop">Stop</button>
    <div style="margin-left:auto">sim: <code id="simId">—</code></div>
  </div>

  <canvas id="stage" width="520" height="520"></canvas>
  <div class="legend">
    <span><span class="dot g"></span>verde</span>
    <span><span class="dot y"></span>amarillo</span>
    <span><span class="dot r"></span>rojo</span>
  </div>

<script>
let simId=null, timer=null, extent=[30,30];
const c=document.getElementById('stage'), ctx=c.getContext('2d');

function toScreen([x,y]){
  const pad = 20;
  const sx = pad + (x-1) * (c.width - 2*pad) / (extent[0]-1);
  const sy = pad + (y-1) * (c.height - 2*pad) / (extent[1]-1);
  return [sx, sy];
}

function drawMap(){
  ctx.fillStyle='#3a7d2f';
  ctx.fillRect(0,0,c.width,c.height);

  const roadW = c.width*0.28;  
  const cen   = c.width/2;
  ctx.fillStyle='#111';
  ctx.fillRect(0, cen-roadW/2, c.width, roadW);
  ctx.fillRect(cen-roadW/2, 0, roadW, c.height);
}

function drawLight(l){
  const col = l.color === 'green' ? '#22c55e' : (l.color === 'yellow' ? '#eab308' : '#ef4444');
  const [sx,sy] = toScreen(l.pos);
  const s=16;
  ctx.fillStyle=col;
  ctx.fillRect(sx-s/2, sy-s/2, s, s);
  ctx.strokeStyle='#111'; ctx.lineWidth=1; ctx.strokeRect(sx-s/2, sy-s/2, s, s);
}

function drawCar(car){
  const [sx,sy] = toScreen(car.pos);
  const s=12; 
  ctx.fillStyle='#0ea5e9';
  ctx.fillRect(sx-s/2, sy-s/2, s, s);
}

function render(data){
  drawMap();
  for(const L of data.lights){ drawLight(L); }
  for(const C of data.cars){ drawCar(C); }
}

async function setup(){
  const res = await fetch('/simulations', {method:'POST', headers:{'Content-Type':'application/json'}, body:'{}'});
  const js  = await res.json();
  simId = js.id; extent = js.extent;
  document.getElementById('simId').textContent = simId;
  render({lights: js.lights, cars: js.cars});
}

async function step(){
  if(!simId) return;
  const res = await fetch(`/simulations/${simId}`);
  const js  = await res.json();
  extent = js.extent || extent;
  render({lights: js.lights, cars: js.cars});
}

document.getElementById('btnSetup').addEventListener('click', async()=>{ if(timer){clearInterval(timer); timer=null;} await setup(); });
document.getElementById('btnStart').addEventListener('click', async()=>{
  if(!simId) await setup();
  if(timer) clearInterval(timer);
  await step();
  timer=setInterval(step, 200);  
});
document.getElementById('btnStop').addEventListener('click', ()=>{ if(timer) clearInterval(timer); timer=null; });

window.addEventListener('load', setup);
</script>
</body>
</html>
"""
end

route("/") do; ui_html(); end
route("/ui") do; ui_html(); end

up()