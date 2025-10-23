# Modelado de Tráfico Simple - P2: Semáforos

Este repositorio contiene la segunda parte (P2) del ejercicio de modelado de tráfico simple. El objetivo principal de esta etapa es extender el código de la simulación base para introducir agentes "Semáforo" (Traffic Light) y simular su comportamiento sincronizado en una intersección.

## Etapa 1: Configuración de Semáforos

En esta primera fase del proyecto, el objetivo fue construir el entorno de la intersección y la lógica de los semáforos.

### Características Implementadas

1.  **Nuevo Agente: Semáforo**
    * Se ha definido un nuevo tipo de agente en el modelo para representar los semáforos.
    * Estos agentes son estáticos (no se mueven).

2.  **Entorno de Simulación**
    * Se modificó el tamaño del espacio de simulación (la "grid") para que sea un **cuadro (NxN)**.
    * El **front-end** se ha actualizado para dibujar las calles que forman el cruce, permitiendo visualizar la intersección.

3.  **Lógica y Sincronización de Semáforos**
    * Se implementó la lógica de transición de colores siguiendo la secuencia estándar de México: **Verde -> Amarillo -> Rojo -> Verde**.
    * Se modificó la función `agent_step!` para controlar el comportamiento de los semáforos.
    * Los dos semáforos de la intersección están **sincronizados** (mientras uno permite el paso, el otro lo restringe).
    * La temporización actual es (a modo de ejemplo):
        * **Verde:** 10 pasos de simulación.
        * **Amarillo:** 4 pasos de simulación.
        * **Rojo:** 14 pasos de simulación (10+4).

### Referencia Conceptual

El comportamiento de la intersección se basa conceptualmente en la simulación de NetLogo disponible en: [Traffic Intersection (NetLogo)](https://tinyurl.com/237faa9a).

---

## Etapa 2: Integración de Agente "Auto"

En esta segunda fase, se introduce un agente `Car` a la simulación, capaz de reaccionar al estado de los semáforos.

### Características Implementadas

1.  **Agente `Car` y Lógica de Movimiento:**
    * Se define un nuevo tipo de agente: `@agent struct Car(...)`.
    * Se añade una **única instancia** de auto a la simulación, circulando por la vía horizontal (`:EW`).
    * Se implementa la función `car_step!` que define su comportamiento:
        * El auto avanza a una velocidad constante (`CAR_SPEED`).
        * Verifica el estado del semáforo horizontal.
        * Se detiene antes del cruce (`STOP_GAP`) si el semáforo está en `:red` o `:yellow`.
        * Avanza si el semáforo está en `:green`.
        * El auto "reaparece" al inicio de la calle (`LEFT_RESPAWN`) tras llegar al final del mapa.

2.  **Manejo de Múltiples Agentes y Sincronización (Scheduler):**
    * El modelo `StandardABM` se actualizó para manejar múltiples tipos de agentes usando `Union{TrafficLight, Car}`.
    * Se implementó un nuevo planificador (scheduler): `Schedulers.by_type((TrafficLight, Car))`.
    * Este scheduler es fundamental, ya que garantiza que **todos los semáforos se activen primero**, y solo después se activen todos los autos. Esto previene que un auto "se pase un alto" por un cambio de estado inoportuno (condición de carrera).

3.  **Despacho Múltiple (Multiple Dispatch):**
    * La función `agent_step!` principal ahora utiliza el **despacho múltiple** de Julia, dirigiendo a cada agente a su función de lógica específica (`light_step!` para semáforos, `car_step!` para autos).

4.  **Actualización del Frontend:**
    * Se modificó `webapi.jl` para serializar (`serialize_cars`) y enviar la información del auto al navegador.
    * El código JavaScript en el HTML se actualizó para incluir la función `drawCar`, que dibuja el agente auto (como un cuadrado azul) en el canvas.
