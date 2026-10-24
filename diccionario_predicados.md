# Diccionario de predicados — Entregable 2

Documentación técnica de los predicados nuevos de `base_conocimiento.pl` para el
**Módulo de Explicabilidad ("¿Por qué?")** y el **Módulo de Recomendación
("¿Qué falta?")**. Los predicados del Entregable 1 (R1 a R23) se mantienen sin cambios.

**Convención de argumentos** (notación estándar de Prolog):

| Símbolo | Significado |
|---|---|
| `+` | Argumento de entrada: debe llegar instanciado |
| `-` | Argumento de salida: llega libre y el predicado lo instancia |
| `?` | Puede usarse como entrada o como salida |

**Determinismo:** `det` produce una única solución; `semidet` produce una solución o
falla; `nondet` puede producir varias soluciones por backtracking.

**Observaciones (`Obs`):** lista de átomos y de términos numéricos, por ejemplo
`[no_enciende, luces_debiles, km_mantenimiento(9000)]`. Los predicados de este
diccionario que reciben `Obs` esperan la lista ya validada (`observados_validos/3`);
solo los predicados principales (`diagnosticar_explicado/5` y `recomendar_evidencia/5`)
reciben la lista cruda y la validan por dentro.

---

## 1. Validación de la entrada

### `validar_entrada/2` (R24) — det
`validar_entrada(+Entrada, -Estado)`

| Argumento | Descripción |
|---|---|
| `+Entrada` | Término recibido desde Python |
| `-Estado` | `ok`, `no_es_lista`, `variables_libres` o `mayusculas` |

Verifica que la entrada sea una lista (`is_list/1`), sin variables libres (`ground/1`)
y con átomos en minúscula (`downcase_atom/2`). Cláusulas excluyentes con corte y valor
por defecto `ok`.

```prolog
?- validar_entrada([X], E).                  % E = variables_libres
?- validar_entrada(['No_Enciende'], E).      % E = mayusculas
?- validar_entrada([no_enciende], E).        % E = ok
```

---

## 2. Módulo de explicabilidad ("¿Por qué?")

### `fallas_candidatas_ordenadas/2` (R25) — det
`fallas_candidatas_ordenadas(+Obs, -Fallas)`

Lista de fallas candidatas (átomos) ordenadas de mayor a menor probabilidad; el empate
se resuelve por gravedad. Usa `setof/3` con `^`, sin duplicados. `Fallas = []` si no hay
candidatas.

### `motivo_severidad/3` (R26) — det
`motivo_severidad(+Falla, +Obs, -Texto)`

Texto que explica por qué la severidad tiene el nivel calculado: gravedad habitual,
escalada por síntoma de riesgo (moderada a crítica) o escalada por agravante (leve a
moderada). Espeja las cláusulas de `severidad/3`.

### `regla_disparada/3` (R27) — nondet
`regla_disparada(+Falla, +Obs, -Regla)` con `Regla = regla(Nivel, Id, Texto)`

| Campo | Descripción |
|---|---|
| `Nivel` | 1 (validación), 2 (inferencia) o 3 (conclusión) |
| `Id` | Identificador de la regla, por ejemplo `'R9 requisitos_cumplidos/4'` |
| `Texto` | Resultado de la regla con los valores reales de este caso |

Cada cláusula reevalúa una regla real del sistema: si el cuerpo de la regla falla para
esa falla, no se genera la entrada. Por eso la traza es exacta y no una descripción fija.
Reglas cubiertas: R3, R4, R5, R6, R9 a R18.

### `reglas_disparadas/3` — det
`reglas_disparadas(+Falla, +Obs, -Lista)`

Recolecta con `findall/3` todas las soluciones de `regla_disparada/3`.
`Lista = [[Nivel, Id, Texto], ...]` en orden de nivel.

### `hecho_comprobado/4` (R28) — nondet
`hecho_comprobado(+Falla, +Obs, -Tipo, -Texto)`

Hechos de entrada que Prolog unificó y validó positivamente para la falla. `Tipo` es
`'Condición principal'`, `'Síntoma de apoyo'`, `'Historial'` o `'Dato de la moto'`
(textos definidos en `tipo_hecho/2`).

### `hechos_verdaderos/3` — det
`hechos_verdaderos(+Falla, +Obs, -Lista)`

`Lista = [[Tipo, Texto], ...]`, recolectada con `findall/3`.

### `sintoma_de_falla/2` (R29) — semidet
`sintoma_de_falla(+Falla, +Sintoma)`

Verdadero si el síntoma es condición principal o de apoyo de la falla.

### `sintomas_compartidos/3` (R29) — det
`sintomas_compartidos(+Falla, +Obs, -Compartidos)`

Síntomas observados que pertenecen a la falla (principales o de apoyo), sin duplicados.

### `motivo_descarte/3` (R30) — det
`motivo_descarte(+Falla, +Obs, -Motivo)`

Motivo por el que una falla no es candidata. Tres cláusulas excluyentes con corte:

1. presencia de condición excluyente (negación por fallo `\+`);
2. incompatibilidad con el tipo de alimentación de la moto;
3. por defecto, evidencia crítica insuficiente (indica cuántas condiciones se cumplen y
   cuáles faltan).

### `hipotesis_descartadas/2` (R31) — det
`hipotesis_descartadas(+Obs, -Lista)`

`Lista = [[NombreFalla, SintomasCompartidos, Motivo], ...]`. Incluye las fallas que
comparten al menos un síntoma con el caso pero no son candidatas (`\+ falla_candidata/2`
con la falla ya instanciada). Ordenada por cantidad de síntomas compartidos.

```prolog
?- hipotesis_descartadas([freno_esponjoso, palanca_freno_larga, frenada_larga], L).
% L = [['Pastillas de freno desgastadas', 'frenada larga',
%       'Presencia de condición excluyente (\\+): freno esponjoso.']]
```

### `item_resultado/3` (R32) — det
`item_resultado(+Falla, +Obs, -Item)`

`Item = [Falla, Nombre, Subsistema, Certeza, Puntaje, Gravedad, Prioridad,
Recomendacion, ReglasDisparadas, HechosVerdaderos]`. Reúne el diagnóstico y su traza.

### `diagnosticar_explicado/5` (R33) — det — predicado principal
`diagnosticar_explicado(+Observados, -Resultados, -Descartadas, -Invalidos, -Alertas)`

| Argumento | Descripción |
|---|---|
| `+Observados` | Lista cruda enviada desde Python |
| `-Resultados` | Hasta 3 ítems de `item_resultado/3` (principal y dos alternativas) |
| `-Descartadas` | Salida de `hipotesis_descartadas/2` |
| `-Invalidos` | Elementos no reconocidos (o el estado de `validar_entrada/2` si no es `ok`) |
| `-Alertas` | Mensajes de seguridad inmediatos (`alertas_seguridad/2`) |

Si `validar_entrada/2` no devuelve `ok`, responde con listas vacías y el motivo en
`Invalidos`.

---

## 3. Módulo de recomendación ("¿Qué falta?")

### `hipotesis_activas/2` (R34) — det
`hipotesis_activas(+Obs, -Activas)`

`Activas = [Puntaje-Falla, ...]`, de mayor a menor puntaje. Hipótesis parcialmente
activas: compatibles con la alimentación, sin condición excluyente y con al menos una
condición principal cumplida.

### `hipotesis_para_sugerir/2` (R35) — det
`hipotesis_para_sugerir(+Obs, -Hipotesis)`

Devuelve las hipótesis activas; si no hay ninguna, todas las fallas compatibles con
puntaje 0 (corte y valor por defecto). Así el sistema nunca responde solo "diagnóstico
desconocido": siempre propone por dónde empezar.

### `estado_evidencia/2` (R36) — det
`estado_evidencia(+Obs, -Estado)`

| Estado | Condición |
|---|---|
| `sin_diagnostico` | No hay fallas candidatas |
| `empate` | Las dos mejores candidatas difieren 10 puntos o menos |
| `certeza_no_alta` | Hay una principal, pero su certeza no es alta |
| `suficiente` | Valor por defecto: certeza alta y sin empate |

### `contribucion/5` (R37) — nondet
`contribucion(+Dato, +Puntaje-Falla, -Peso, -NombreFalla, -Efecto)`

Aporte de un dato aún no ingresado a una hipótesis. `Efecto` es `confirma` o `descarta`.
Peso base: 3 si es condición principal pendiente, 1 si es síntoma de apoyo, 2 si
descartaría la falla (excluyente), 3 y 2 para el tipo de alimentación que confirma o
descarta fallas restringidas, y 1 para un dato numérico que activa un agravante. El peso
se multiplica por `Puntaje // 10 + 1` para favorecer a las hipótesis más fuertes.

### `resumen_contribuciones/5` (R38) — semidet
`resumen_contribuciones(+Dato, +Hipotesis, -Peso, -Confirma, -Descarta)`

Suma los pesos de `contribucion/5` y lista las fallas que el dato reforzaría y las que
descartaría. Falla si el dato no afecta a ninguna hipótesis.

### `sugerencias_desempate/2` (R39) — det
`sugerencias_desempate(+Obs, -Sugerencias)`

`Sugerencias = [[Tipo, Dato, Pregunta, Peso, Confirma, Descarta], ...]`, hasta 4,
ordenadas por peso descendente (a igual peso, por el orden de las preguntas). `Tipo` es
`sintoma` o `dato_numerico`. Solo propone datos que aún no están en `Obs`.

```prolog
?- sugerencias_desempate([pierde_potencia], S).
% primera: [sintoma, falla_en_ralenti, '¿La falla aparece en ralentí ...?', 24,
%           ['Carburador sucio', 'Inyector tapado'], []]
```

### `hipotesis_en_competencia/2` (R40) — det
`hipotesis_en_competencia(+Obs, -Competencia)`

`Competencia = [[Nombre, Puntaje, Certeza], ...]`, hasta 4 hipótesis activas.

### `recomendar_evidencia/5` (R41) — det — predicado principal
`recomendar_evidencia(+Observados, -Estado, -Mensaje, -EnCompetencia, -Sugerencias)`

| Argumento | Descripción |
|---|---|
| `+Observados` | Lista cruda enviada desde Python |
| `-Estado` | Estado de `estado_evidencia/2`, o `entrada_invalida` |
| `-Mensaje` | Texto de `mensaje_evidencia/2` para ese estado |
| `-EnCompetencia` | Salida de `hipotesis_en_competencia/2` |
| `-Sugerencias` | Salida de `sugerencias_desempate/2` (vacía si la evidencia es suficiente) |

---

## 4. Hechos nuevos

| Predicado | Contenido |
|---|---|
| `mensaje_evidencia/2` | `mensaje_evidencia(Estado, Texto)`: mensaje de cada estado de la evidencia (5 hechos) |
| `dato_para_condicion/2` | `dato_para_condicion(DatoNumerico, Condicion)`: enlaza `km_mantenimiento` con `mantenimiento_vencido` y `antiguedad_bateria` con `bateria_vieja` |
| `tipo_hecho/2` | `tipo_hecho(Clave, Texto)`: clasificación de los hechos comprobados (4 hechos) |
| `nombre_gravedad/2` | `nombre_gravedad(Nivel, Texto)`: texto con tilde de leve, moderada y crítica |

---

## 5. Predicados del Entregable 1 que se reutilizan

| Predicado | Uso en el Entregable 2 |
|---|---|
| `observados_validos/3` (R2) | Valida la entrada antes de inferir |
| `alimentacion_moto/2` (R5), `compatible_alimentacion/2` (R6) | Compatibilidad de las hipótesis con la moto |
| `condicion_activa/2` (R7), `agravantes_presentes/3` (R12) | Hechos de historial y agravantes |
| `alertas_seguridad/2` (R8) | Alertas inmediatas |
| `requisitos_cumplidos/4` (R9), `apoyos_presentes/3` (R10), `hay_excluyente/2` (R11) | Base de la traza y de los descartes |
| `falla_candidata/2` (R13), `puntaje/3` (R14), `nivel_certeza/2` (R15) | Candidatura y certeza |
| `severidad/3` (R16), `prioridad/3` (R17), `recomendacion_final/3` (R18) | Gravedad y recomendación |
| `construir_diagnostico/4` (R20) | Ordenamiento y datos del diagnóstico |
| `etiqueta/2`, `legible/2`, `primeros/3`, `valores_de_pares/2`, `elementos_faltantes/3` | Utilidades de listas y textos |
