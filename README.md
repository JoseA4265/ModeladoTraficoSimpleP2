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
    * El **front-end** (contenido en `webapi.jl`) se ha actualizado para dibujar las calles que forman el cruce, permitiendo visualizar la intersección.

3.  **Lógica y Sincronización de Semáforos**
    * Se implementó la lógica de transición de colores siguiendo la secuencia estándar de México: **Verde -> Amarillo -> Rojo -> Verde**.
    * Se modificó la función `agent_step!` para controlar el comportamiento de los semáforos.
    * Los dos semáforos de la intersección están **sincronizados** (mientras uno permite el paso, el otro lo restringe).

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

2.  **Manejo de Múltiples Agentes y Sincronización (Scheduler):**
    * El modelo `StandardABM` se actualizó para manejar múltiples tipos de agentes usando `Union{TrafficLight, Car}`.
    * Se implementó un nuevo planificador (scheduler): `Schedulers.by_type((TrafficLight, Car))`.
    * Este scheduler es fundamental, ya que garantiza que **todos los semáforos se activen primero**, y solo después se activen todos los autos. Esto previene que un auto "se pase un alto" por un cambio de estado inoportuno.

3.  **Despacho Múltiple (Multiple Dispatch):**
    * La función `agent_step!` principal ahora utiliza el **despacho múltiple** de Julia, dirigiendo a cada agente a su función de lógica específica (`light_step!` para semáforos, `car_step!` para autos).

4.  **Actualización del Frontend:**
    * Se modificó `webapi.jl` para serializar (`serialize_cars`) y enviar la información del auto al navegador.
    * El código JavaScript en el HTML se actualizó para incluir la función `drawCar`, que dibuja el agente auto (como un cuadrado azul) en el canvas.

---

## Etapa 3: Simulación Completa y Física de Vehículos

En esta etapa final, la simulación se completa con múltiples autos en ambas calles, física de movimiento (aceleración/frenado) y lógica para evitar colisiones.

### Características Implementadas

1.  **Múltiples Autos en Ambas Calles:**
    * La simulación ahora permite configurar el número de autos por calle (3, 5, 7, etc.) desde un `<input>` en la interfaz de usuario.
    * Se pueblan autos tanto en la calle horizontal (`:EW`) como en la vertical (`:NS`).

2.  **Física y Lógica de Decisión (Cerebro del Auto):**
    * La `struct Car` se actualizó para incluir `orientation`, `speed` (variable) y `max_speed` (aleatoria).
    * La función `car_step!` fue reescrita para implementar una lógica de decisión compleja:
        * **Aceleración/Frenado:** Los autos ya no tienen velocidad constante. Aceleran (`ACCELERATION`) hasta su `max_speed` si el camino está libre, y frenan (`BRAKE_DECEL`) si detectan un obstáculo.
        * **Evitar Colisiones:** Cada auto "mira" hacia adelante en su carril. Si detecta otro auto a una distancia menor que `SAFE_DISTANCE`, frenará para evitar un choque.
        * **Respeto a Semáforos:** La lógica de detenerse en el cruce (`STOP_GAP`) se mantiene.
    * El `target_speed` de un auto se decide por el obstáculo más cercano (sea un auto o un semáforo en rojo).

3.  **Inicialización Aleatoria:**
    * Al presionar "Setup", los autos se crean en posiciones aleatorias (lejos del cruce) y con velocidades iniciales aleatorias, dándoles también una `max_speed` variable para mayor realismo.

4.  **Mejoras de UI y Monitoreo:**
    * **Íconos Rotados:** La función `drawCar` en JavaScript fue actualizada para dibujar un **rectángulo rotado**, mostrando visualmente la orientación (`:EW` o `:NS`) del vehículo.
    * **Monitor de Velocidad:** Se añadió un reporte de "Velocidad Promedio" en la UI. Este obtiene sus datos de una nueva ruta de API (`/simulations/:id/stats`) que calcula la velocidad media de todos los agentes `Car` en el *backend* en cada paso de la simulación.
