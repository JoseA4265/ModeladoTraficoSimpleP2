# Modelado de Tráfico Simple - P2: Semáforos

Este repositorio contiene la segunda parte (P2) del ejercicio de modelado de tráfico simple. El objetivo principal de esta etapa es extender el código de la simulación base para introducir agentes "Semáforo" (Traffic Light) y simular su comportamiento sincronizado en una intersección.


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

4.  **Agentes de Auto (Pausados)**
    * Siguiendo la estrategia de la etapa 1, las partes del código responsables de crear e insertar agentes "Auto" están actualmente comentadas para centrar el desarrollo en los semáforos.

### Referencia Conceptual

El comportamiento de la intersección se basa conceptualmente en la simulación de NetLogo disponible en: [Traffic Intersection (NetLogo)](https://tinyurl.com/237faa9a).

