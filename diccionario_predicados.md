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

---

## 6. Aprendizaje: el sistema agrega fallas y síntomas nuevos (extensión)

Los predicados del catálogo se declaran `dynamic` para poder crecer en tiempo de ejecución:
`falla_subsistema/2`, `nombre_falla/2`, `requisitos_falla/2`, `sintoma_apoyo/2`, `excluyente/2`,
`agravante_de/2`, `restriccion_alimentacion/2`, `gravedad_base/2`, `recomendacion_base/2`,
`categoria_sintoma/2`, `nombre_elemento/2` y `pregunta_sintoma/3`. Lo aprendido se agrega a esos
mismos predicados con `assertz/1`, así que participa en la inferencia igual que el conocimiento
del experto, y se guarda en `conocimiento_aprendido.pl` (un archivo de directivas que se
consulta al arrancar).

**Estados que devuelven los predicados de aprendizaje** (cada uno tiene su mensaje en
`mensaje_aprendizaje/2`): `ok`, `nombre_vacio`, `nombre_largo`, `ya_existe`, `subsistema_invalido`,
`gravedad_invalida`, `alimentacion_invalida`, `lista_invalida`, `pocos_requisitos`,
`demasiados_requisitos`, `sintoma_desconocido`, `sintomas_repetidos`, `sintomas_contradictorios`, `falla_equivalente`, `agravante_invalido`,
`recomendacion_vacia`, `recomendacion_larga`, `texto_vacio`, `texto_largo`, `categoria_invalida`,
`no_aprendida`, `en_uso`.

### Predicados principales (los invoca la interfaz)

#### `aprender_falla/12` (R48) — det
`aprender_falla(+Nombre, +Subsistema, +Gravedad, +Requisitos, +Apoyos, +Excluyentes, +Agravantes, +Alimentacion, +Recomendacion, -Estado, -Mensaje, -Falla)`

| Argumento | Descripción |
|---|---|
| `+Nombre` | Nombre legible de la falla (máx. 60 caracteres) |
| `+Subsistema` | Uno de los subsistemas del catálogo (no `general`) |
| `+Gravedad` | `leve`, `moderada` o `critica` |
| `+Requisitos` | De 2 a 5 síntomas que definen la falla (condiciones principales) |
| `+Apoyos`, `+Excluyentes` | Listas de síntomas (pueden ser vacías); no pueden repetirse entre sí |
| `+Agravantes` | Subconjunto de `[mantenimiento_vencido, bateria_vieja]` |
| `+Alimentacion` | `cualquiera`, `carburador` o `inyeccion` |
| `+Recomendacion` | Texto de la recomendación (máx. 300 caracteres) |
| `-Estado`, `-Mensaje` | Resultado de la validación y su mensaje |
| `-Falla` | Identificador generado a partir del nombre |

Valida con `validar_falla/13`; si todo está bien registra con `registrar_falla/10` y guarda con
`guardar_aprendizaje/0`. Si algo falla no cambia nada.

```prolog
?- aprender_falla('Rodamiento de dirección dañado', frenos_transmision, moderada,
                  [ruido_al_girar_el_manubrio, vibracion_excesiva], [ruido_metalico], [],
                  [mantenimiento_vencido], cualquiera,
                  'Revise y cambie los rodamientos.', E, M, F).
% E = ok, F = rodamiento_de_direccion_danado
```

#### `aprender_sintoma/5` (R45) — det
`aprender_sintoma(+Texto, +Categoria, -Estado, -Mensaje, -Elemento)`

Agrega un síntoma nuevo al catálogo: genera el identificador, el nombre y la pregunta
(`¿Texto?`) y le da el siguiente número de orden. Rechaza texto vacío o largo (máx. 80),
categoría inválida y nombres que ya existen.

#### `olvidar_falla/3` (R49) y `olvidar_sintoma/3` (R50) — det
`olvidar_falla(+Falla, -Estado, -Mensaje)` / `olvidar_sintoma(+Elemento, -Estado, -Mensaje)`

Solo olvidan lo aprendido (`no_aprendida` si es del experto). Un síntoma que todavía usa alguna
falla devuelve `en_uso`.

### Validación y registro

| Predicado / aridad | Argumentos | Descripción funcional |
|---|---|---|
| `validar_falla/13` (R46) | `+Nombre, +Subsistema, +Gravedad, +Req, +Apo, +Exc, +Agr, +Alim, +Rec, -Estado, -Falla, -NombreLimpio, -RecLimpia` | Reglas excluyentes con corte: cada una detecta un problema; la última es el caso `ok` |
| `validar_sintoma_nuevo/6` (R43) | `+Texto, +Categoria, -Estado, -Elemento, -Nombre, -Pregunta` | Validación de un síntoma nuevo, con el mismo esquema |
| `registrar_falla/10` (R47) | `+Falla, +Sub, +Nombre, +Req, +Apo, +Exc, +Gravedad, +Rec, +Alim, +Agr` | Agrega la falla con `assertz/1`. Idempotente; también lo usa la carga del archivo |
| `registrar_sintoma/4` (R44) | `+Elemento, +Categoria, +Nombre, +Pregunta` | Agrega el síntoma con `assertz/1`. Idempotente |
| `texto_a_atomo/2` (R42) | `+Texto, -Atomo` | Texto libre a identificador: minúsculas, sin tildes, guiones bajos (máx. 40). Falla si no queda nada útil |
| `normalizar_caracter/2`, `colapsar_guiones/2`, `recortar_guiones/2` | `+Entrada, -Salida` | Procesamiento recursivo de listas de caracteres usado por `texto_a_atomo/2` |
| `texto_util/2`, `capitalizar/2`, `sin_signos/2` | `+Texto, -Resultado` | Limpieza de textos (espacios, mayúscula inicial, signos de interrogación) |
| `sintoma_conocido/1` | `+Elemento` | Verdadero si el síntoma está en el catálogo y no es un dato de la moto |
| `sintoma_en_uso/1` | `+Elemento` | Verdadero si alguna falla lo usa como condición, apoyo o excluyente |
| `quitar_falla/1`, `quitar_sintoma/1` | `+Id` | Retiran de la memoria los hechos con `retractall/1` |

### Persistencia

| Predicado / aridad | Argumentos | Descripción funcional |
|---|---|---|
| `guardar_aprendizaje/0` | — | Escribe `conocimiento_aprendido.pl` (primero en un temporal, para no dejarlo a medias) |
| `cargar_aprendizaje/0` | — | Consulta el archivo si existe; sus directivas llaman a `registrar_sintoma/4` y `registrar_falla/10` |
| `usar_archivo_aprendizaje/1` | `+Ruta` | Cambia el archivo y lo carga (lo usan las pruebas) |
| `reiniciar_aprendizaje/0` | — | Vuelve al conocimiento original del experto y vacía el archivo |
| `olvidar_todo_en_memoria/0` | — | Retira de la memoria todo lo aprendido sin tocar el archivo |

### Consultas para la interfaz

| Predicado / aridad | Argumentos | Descripción funcional |
|---|---|---|
| `catalogo_sintomas/1` | `-Lista` | `[[Elemento, TituloCategoria, Nombre], ...]` para elegir condiciones |
| `catalogo_subsistemas/1`, `catalogo_categorias/1`, `catalogo_gravedades/1` | `-Lista` | Opciones de los desplegables |
| `listar_fallas_aprendidas/1` | `-Lista` | `[[Id, Nombre, Subsistema, Gravedad, Requisitos, Apoyos, Excluyentes, Alimentacion, Recomendacion], ...]` |
| `listar_sintomas_aprendidos/1` | `-Lista` | `[[Elemento, TituloCategoria, Nombre], ...]` |
| `preguntas_guiadas/1` (modificado) | `-Lista` | Ahora agrupa por categoría, así que un síntoma aprendido queda junto a los de su categoría |
| `orden_categoria/2` | `+Categoria, -Rango` | Menor número de pregunta de la categoría (para ordenar los grupos) |

### Hechos nuevos

| Predicado | Contenido |
|---|---|
| `mensaje_aprendizaje/2` | `mensaje_aprendizaje(Estado, Texto)`: mensaje de cada estado (22 hechos) |
| `sin_tilde/2` | Correspondencia letra con tilde a letra sin tilde (21 hechos) |
| `limite_texto/2`, `limite_requisitos/2` | Longitudes máximas de los textos y mínimo y máximo de condiciones principales |
| `agravante_permitido/1`, `alimentacion_permitida/1` | Valores aceptados para agravantes y tipo de moto |
| `sintoma_aprendido/4`, `falla_aprendida/10` | Memoria de lo que el usuario enseñó (dinámicos): de aquí se escribe el archivo |
| `ruta_aprendizaje/1` | Ruta del archivo de aprendizaje (dinámico; por defecto junto a la base) |

---

## 7. Validaciones de coherencia de la entrada (extensión)

Una moto real no puede presentar a la vez datos que se contradicen (carburador e inyección,
luces normales y apagadas...). Estos predicados, en la sección 19 de `base_conocimiento.pl`,
detectan esas contradicciones. La interfaz solo los consulta y muestra el resultado.

### Predicados principales

#### `validar_observaciones/3` (R54) — det
`validar_observaciones(+Obs, -Estado, -Problemas)`

| Argumento | Descripción |
|---|---|
| `+Obs` | Lista de observaciones tal como la envía la interfaz |
| `-Estado` | `ok`, `entrada_invalida`, `incoherente` o `sin_sintomas` |
| `-Problemas` | `[[Tipo, Mensaje], ...]` con cada problema encontrado (vacía si `ok`) |

La interfaz la llama en cada cambio: si el estado no es `ok`, muestra los mensajes y desactiva
**Diagnosticar**. Cláusulas excluyentes con corte y valor por defecto `ok`.

```prolog
?- validar_observaciones([alimentacion_carburador, alimentacion_inyeccion], E, P).
% E = incoherente
?- validar_observaciones([alimentacion_carburador], E, P).
% E = sin_sintomas
```

#### `validar_coherencia/2` (R52) — det
`validar_coherencia(+Obs, -Problemas)`

Reúne con `findall/3` todos los problemas de `problema/3` y quita repetidos (`list_to_set/2`).
Lista vacía: la entrada no se contradice. La usan `diagnosticar/4`, `diagnosticar_explicado/5`,
`recomendar_evidencia/5` y `validar_falla/13`.

### Reglas y consultas

| Predicado / aridad | Argumentos | Descripción funcional |
|---|---|---|
| `problema/3` (R51) | `+Obs, -Tipo, -Mensaje` | nondet. Un problema por cláusula: `exclusivo` (dos opciones de un mismo grupo), `incompatible` (par imposible), `fuera_de_rango` y `dato_repetido` (datos numéricos) |
| `genera_conflicto/2` (R53) | `+Sintoma, +Obs` | Verdadero si agregar el síntoma a `Obs` crearía una contradicción. `sugerencias_desempate/2` lo usa para no proponer datos que contradigan lo marcado |
| `mensajes_de_problemas/2` | `+Problemas, -Mensajes` | Solo los textos (recursión sobre lista) |
| `hay_sintoma/1` | `+Obs` | Verdadero si hay al menos un síntoma (los datos de la moto y el historial no bastan) |
| `grupos_exclusivos/1` | `-Lista` | `[[Id, Descripcion, Miembros], ...]`: la interfaz lo usa para dejar marcada una sola opción por grupo |
| `limites_numericos/1` | `-Lista` | `[[Dato, Minimo, Maximo], ...]`: rangos de los campos numéricos |
| `falla_con_mismos_requisitos/3` | `+Req, +Alim, -Falla` | Una falla del catálogo exige exactamente esas condiciones y el mismo tipo de moto (se rechaza al enseñar) |
| `mensaje_de_aprendizaje/5` | `+Estado, +Req, +Apo, +Falla, -Mensaje` | Agrega el detalle (cuál contradicción, cuál falla ya existe) a los dos estados nuevos de aprendizaje |
| `elemento_valido/1` (R1, modificado) | `+Elemento` | Los datos numéricos ahora deben estar dentro de `limite_dato/3` |
| `diagnosticar/4`, `diagnosticar_explicado/5`, `recomendar_evidencia/5` (modificados) | — | Con datos contradictorios no diagnostican: devuelven los motivos (`Alertas`, o estado `entrada_incoherente`) |

### Hechos nuevos

| Predicado | Contenido |
|---|---|
| `grupo_exclusivo/3` | `grupo_exclusivo(Id, Descripcion, Miembros)`: como máximo uno de los miembros puede ser cierto. Seis grupos: alimentación, giro del motor, chispa, color del humo, intensidad de las luces, temperatura de la falla |
| `incompatible/3` | `incompatible(A, B, Motivo)`: par de síntomas de grupos distintos que no pueden darse juntos (siete pares) |
| `limite_dato/3` | `limite_dato(Dato, Minimo, Maximo)`: 0 a 100000 km y 0 a 120 meses |
| `nombre_dato/2` | Texto de cada dato numérico para los mensajes |
| `mensaje_evidencia/2` | Nuevo estado `entrada_incoherente` |
| `mensaje_aprendizaje/2` | Nuevos estados `sintomas_contradictorios` y `falla_equivalente` |

Como el conocimiento está en hechos, agregar un grupo o un par imposible es agregar una línea;
las reglas no cambian.

## 8. Entregable 3: lenguaje natural (DCG), roles y lecturas

Archivo nuevo `gramatica_dcg.pl` (lo carga `base_conocimiento.pl`). Reglas R55 a R70.
Python solo envía el texto y muestra lo que Prolog entiende; la gramática, el vocabulario,
los permisos y la validación están en Prolog.

### Análisis de la oración (DCG)

| Predicado / aridad | Argumentos | Descripción funcional |
|---|---|---|
| `interpretar_texto/8` (R64) | `+Texto, -Estado, -Hechos, -Datos, -Ausentes, -Lecturas, -Interpretacion, -Desconocidas` | Predicado principal. `Estado`: `ok`, `texto_vacio`, `texto_largo` o `no_entendido`. `Interpretacion` = `[[Frase, Tipo, Nombre, Valor], ...]` indica qué palabras dieron cada hecho |
| `tokenizar/2` | `+Texto, -Tokens` | Minúsculas, sin tildes (`sin_tilde/2`), separa letras de dígitos, "9.000" pasa a 9000, "12,2" a 12.2; la puntuación es el token `sep` |
| `oracion//1` (R55) | `-Items` | Una oración es una o más cláusulas separadas por conectores (y, pero, además, coma...) |
| `clausulas//1`, `clausula//1` (R56–R57) | `-Items` | Recursión sobre las cláusulas; cada una produce un ítem |
| `sintagma//1` (R58) | `-Item` | Alternativas en orden: `lectura`, `dato_historial`, `sintoma`, `sintoma_negado`, relleno omitido, palabra desconocida |
| `sintoma//1` (R59) | `-hecho(E, Frase)` | Frase del léxico; gana la coincidencia más larga (`findall/3` + `keysort/2`). Puede saltar hasta 3 palabras de relleno |
| `sintoma_negado//1` (R60) | `-ausente(E, Frase)` | "no" + frase: el usuario descarta ese síntoma |
| `cantidad//1` (R61) | `-N` | Dígitos, "9 mil", "nueve mil", palabras numéricas |
| `lectura//1` (R62) | `-lectura(Variable, Valor, Frase)` | Medida con unidad ("125 grados", "12,2 voltios", "45 mm", "22 km por litro") |
| `dato_historial//1` (R63) | `-dato(Dato, Valor, Frase)` | Kilómetros desde el mantenimiento (cualquier orden) y edad de la batería (meses o años) |
| `estado_texto/2`, `separar_items/7` | — | Validación del texto y reparto de los ítems en listas |

### Vocabulario que enseña el experto

| Predicado / aridad | Argumentos | Descripción funcional |
|---|---|---|
| `aprender_frase/4` (R68) | `+Texto, +Elemento, -Estado, -Mensaje` | Valida, registra con `assertz/1` y guarda el archivo. Estados: `ok`, `texto_vacio`, `texto_largo`, `frase_sin_palabras`, `frase_larga`, `elemento_desconocido`, `frase_repetida`, `frase_ambigua` |
| `validar_frase/4` (R66) | `+Texto, +Elemento, -Estado, -Palabras` | Todas las comprobaciones, en orden |
| `registrar_frase/2` (R67) | `+Palabras, +Elemento` | `assertz(frase_aprendida/2)`; idempotente; también lo usa la carga del archivo |
| `olvidar_frase/3` | `+Texto, -Estado, -Mensaje` | Solo expresiones enseñadas (`ok` o `no_aprendida`) |
| `listar_frases_aprendidas/1` | `-Lista` | `[[Texto, Elemento, Nombre], ...]` |
| `registrar_frase_de_nombre/2` | `+Elemento, +Nombre` | Un síntoma nuevo queda describible con su propio nombre |

### Roles y lecturas

| Predicado / aridad | Argumentos | Descripción funcional |
|---|---|---|
| `permiso/2` | `+Rol, +Accion` | Hechos: el usuario diagnostica y describe en texto; el experto además enseña falla, síntoma y frase, y olvida |
| `autorizar/4` (R71) | `+Rol, +Accion, -Estado, -Mensaje` | `ok` o `no_autorizado`. Todo rol o acción desconocidos se deniega. Lo consultan `aprender_*` y `olvidar_*` de Python antes de modificar nada |
| `variable_lectura/5` | `Variable, Unidad, Min, Max, Descripcion` | Lecturas del taller y sus rangos |
| `validar_lectura/4` (R69) | `+Variable, +Valor, -Estado, -Mensaje` | `ok`, `fuera_de_rango`, `variable_desconocida` o `lectura_invalida` |
| `lectura_nivel/3` / `hecho_de_lectura/3` (R70) | `Variable, Nivel, Elemento` | Qué síntoma significa un nivel (alto, bajo). El nivel lo da scikit-learn en `preprocesamiento.py` |
| `variables_lectura/1` | `-Lista` | Para armar el formulario de lecturas |

### Hechos nuevos

| Predicado | Contenido |
|---|---|
| `frase/2` | Léxico del experto: unas 190 expresiones y el síntoma que significan |
| `frase_aprendida/2` (dinámico) | Expresiones enseñadas; se escriben en `conocimiento_aprendido.pl` como `:- registrar_frase([...], Sintoma).` |
| `relleno/1`, `conector/1`, `negacion/1`, `unidad/2`, `palabra_numero/2` | Palabras que la gramática omite, separa, niega o convierte |
