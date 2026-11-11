# MotoDiag — Sistema experto auditable para diagnóstico de motocicletas

Sistema experto para diagnosticar fallas mecánicas y eléctricas en motocicletas
monocilíndricas de 4 tiempos (100 a 400 cc).

* **Prolog (SWI-Prolog)** contiene todo el conocimiento y toda la lógica: inferencia,
  descarte, severidad, traza de auditoría y sugerencias de desempate.
* **Python** dibuja la interfaz, captura las entradas y presenta los resultados que
  devuelve Prolog. Además convierte medidas numéricas en niveles con scikit-learn.

Proyecto de Sistemas Expertos — Ingeniería de Software — Fundación Escuela
Tecnológica de Neiva (FET).

## Qué hace

1. **Diagnóstico:** diagnóstico principal y hasta dos alternativas, con nivel de
   certeza (alto, medio, bajo), gravedad (leve, moderada, crítica), prioridad
   numérica y recomendación.
2. **¿Por qué?** (módulo de explicabilidad): muestra la traza exacta de Prolog:
   reglas disparadas (por nivel), hechos comprobados como verdaderos e hipótesis
   alternativas descartadas con su motivo.
3. **¿Qué falta?** (módulo de recomendación): cuando la evidencia no basta o hay
   empate, Prolog indica qué hipótesis compiten y qué síntoma o dato adicional
   tiene mayor peso para confirmar o desempatar.
4. **Modo Experto** (aprendizaje, solo rol Experto): si la moto presenta una falla que el sistema no conoce,
   el experto puede agregarla (con sus síntomas, gravedad y recomendación) y también
   puede agregar síntomas nuevos. Prolog valida lo que recibe, lo suma a su base de
   conocimiento con `assertz/1` y lo guarda en `conocimiento_aprendido.pl`, de modo que
   no se pierde al cerrar el programa. Las fallas nuevas se diagnostican, se explican
   ("¿Por qué?") y participan en "¿Qué falta?" igual que las del experto.
5. **Lenguaje natural (Entregable 3):** el usuario escribe la falla con sus palabras
   ("la moto no enciende y las luces se ven débiles, hace 9000 km que no le hago
   mantenimiento") y una gramática DCG de Prolog extrae los síntomas, los datos del
   historial, los síntomas negados y las medidas numéricas. Muestra "Lo que entendí"
   y rellena el formulario.
6. **Lecturas del taller:** temperatura, voltaje, holgura de cadena, distancia de frenado y
   rendimiento. Un clasificador de scikit-learn las convierte en nivel (bajo, normal, alto)
   y Prolog decide qué síntoma significa cada nivel.
7. **Roles:** *usuario* diagnostica; *experto* (clave) además enseña fallas, síntomas y
   vocabulario. Los permisos los decide Prolog (`autorizar/4`).
8. **Validaciones de coherencia:** una moto no puede tener datos que se contradicen.
   Prolog define qué combinaciones son imposibles y la interfaz las impide o las
   señala; con datos contradictorios no se calcula ningún diagnóstico (ver abajo).

## Requisitos

| Componente | Versión probada |
|---|---|
| SWI-Prolog | 9.0.4 (cualquier 9.x) — debe estar instalado y `swipl` en el PATH |
| Python | 3.10 o superior |
| PySwip | 0.3.3 |
| Streamlit | 1.66 (se necesita una versión reciente que admita `width="stretch"`) |

## Instalación

1. Instale SWI-Prolog desde <https://www.swi-prolog.org/Download.html>
   (en Windows, marque la opción de agregarlo al PATH).
2. Instale las dependencias de Python:

```bash
pip install pyswip streamlit scikit-learn
```

`scikit-learn` es opcional: sin él, el programa calcula los mismos umbrales con un método
simple y funciona igual.

## Ejecución

Interfaz web (Entregable 2):

```bash
streamlit run main.py
```

Se abre en el navegador (por defecto en <http://localhost:8501>).

**Rol Experto:** en el panel lateral escriba la clave y presione *Entrar como experto*.
La clave por defecto es `experto2026`; para cambiarla defina la variable de entorno
`MOTODIAG_CLAVE_EXPERTO` antes de ejecutar. Tras 5 intentos fallidos el acceso se bloquea
hasta recargar la página.

Consola (Entregable 1, se conserva):

```bash
python main_consola.py          # consulta guiada (tampoco acepta respuestas contradictorias)
python main_consola.py --demo   # tres casos de ejemplo
```

## Cómo usar la interfaz

1. En **Describa la falla**, abra cada grupo y marque lo que observa. Lo que no sepa,
   déjelo sin marcar. En **HISTORIAL** puede indicar kilómetros desde el último
   mantenimiento y meses de la batería.
2. Presione **Diagnosticar**.
3. Revise las pestañas **Diagnóstico**, **¿Por qué?** y **¿Qué falta?**.
4. En **¿Qué falta?**, el botón **Sí, lo observo** marca el síntoma sugerido y
   recalcula el diagnóstico de inmediato.

### Validaciones de coherencia

Prolog (`base_conocimiento.pl`, sección 19, reglas R51 a R54) revisa en cada cambio que lo
marcado tenga sentido. La interfaz solo muestra lo que Prolog decide:

| Validación | Ejemplo | Qué hace la interfaz |
|---|---|---|
| **Grupos de una sola opción** | carburador *o* inyección; el motor gira normal, lento *o* no gira; sin chispa *o* chispa débil; humo negro, blanco *o* azul; luces normales, débiles *o* apagadas; falla en frío *o* en caliente | Al marcar una opción se desmarca la otra del grupo y aparece un aviso |
| **Combinaciones imposibles** | "no enciende" y "se apaga mientras anda"; "gira con fuerza normal" y "clic seco al arrancar"; "temperatura alta" y "falla en frío" | Muestra el error en rojo y bloquea **Diagnosticar** |
| **Rangos del historial** | kilómetros entre 0 y 100000; batería entre 0 y 120 meses | El campo numérico no admite valores fuera del rango, y Prolog también los rechaza |
| **Un dato por campo** | dos valores distintos de kilómetros | Prolog lo rechaza |
| **Al menos un síntoma** | solo "carburador" y kilómetros no bastan | **Diagnosticar** queda desactivado |
| **Sugerencias coherentes** | si ya marcó "carburador", **¿Qué falta?** no propone "inyección" | Prolog excluye de las sugerencias lo que contradiría lo marcado |

Aunque alguien llame al motor sin pasar por la interfaz, `diagnosticar/4`,
`diagnosticar_explicado/5` y `recomendar_evidencia/5` no calculan nada con datos
contradictorios: devuelven los motivos (estado `entrada_incoherente`).

También se validan las fallas que se enseñan: si las condiciones principales y de apoyo se
contradicen (por ejemplo *luces normales* y *luces apagadas*), la falla nunca podría
diagnosticarse, así que se rechaza. Tampoco se acepta una falla con las mismas condiciones
principales y el mismo tipo de moto que otra ya existente.

### Caso de demostración 1 — inferencia completa y "¿Por qué?"

Marque en FRENOS Y TRANSMISIÓN: *freno esponjoso*, *recorrido largo de la palanca* y
*tarda más en detenerse*; en HISTORIAL escriba 9000 km. Resultado: **Aire en el
circuito de frenos**, certeza alta, gravedad crítica ("NO CONDUZCA la moto"). En
**¿Por qué?** aparecen las reglas disparadas, los hechos comprobados y la hipótesis
descartada *Pastillas de freno desgastadas* por la condición excluyente (`\+`)
*freno esponjoso*.

### Caso de demostración 2 — datos incompletos y "¿Qué falta?"

Marque solo *pierde potencia*. Resultado: empate entre varias hipótesis. En **¿Qué
falta?** se sugiere primero *falla en ralentí*; al confirmarla, el empate se reduce a
Carburador sucio frente a Inyector tapado, y Prolog sugiere el tipo de alimentación;
al marcar *carburador*, el diagnóstico es **Carburador sucio** y el inyector queda
descartado.

### Caso de demostración 3 — el sistema aprende una falla nueva

1. Entre como experto y abra la pestaña **Modo Experto**. En *Paso 1* agregue el síntoma *ruido al girar el
   manubrio* (categoría Motor y lubricación): aparece como pregunta en la lista de la
   izquierda y queda marcado.
2. En *Paso 2* escriba el nombre **Rodamiento de dirección dañado**, elija subsistema
   *Frenos y transmisión* y gravedad *moderada*. En *Condiciones principales* elija
   *ruido al girar el manubrio* y *vibración excesiva*; como apoyo, *ruido metálico*;
   escriba una recomendación y presione **Enseñar al sistema**.
3. Marque *vibración excesiva* y presione **Diagnosticar**: el diagnóstico principal es la
   falla recién aprendida, con su traza en **¿Por qué?**.
4. Cierre y vuelva a abrir el programa: la falla sigue ahí (se cargó de
   `conocimiento_aprendido.pl`). Para quitarla, use el botón **Olvidar** de la misma pestaña (solo el experto).

Qué valida Prolog antes de aprender: nombre no vacío y no repetido; subsistema, gravedad
y tipo de moto válidos; entre 2 y 5 condiciones principales; todos los síntomas deben existir
en el catálogo; un síntoma no puede repetirse ni ser a la vez condición y excluyente;
recomendación no vacía; las condiciones principales y de apoyo no pueden contradecirse ni
repetir otra falla existente. Si algo falla, el mensaje de Prolog dice qué corregir y no se
guarda nada. Solo se puede olvidar lo aprendido: el conocimiento del experto no se modifica.

## Entregable 3 — lenguaje natural, Modo Experto y modelo híbrido

### Describir la falla con palabras

1. En **Con sus propias palabras** escriba la descripción y presione **Interpretar** (solo
   rellena la lista) o **Interpretar y diagnosticar**.
2. **Lo que entendí** muestra qué palabras dieron cada hecho. Abajo, *Hechos que recibió el
   motor de inferencia* muestra la lista exacta que Prolog usó.
3. Si el texto no tiene ningún síntoma reconocible (por ejemplo una frase sobre un servidor),
   el sistema lo dice y no toca lo que ya estaba marcado.

Lo que la gramática (`gramatica_dcg.pl`) sabe interpretar:

| En la oración | Resultado |
|---|---|
| "la moto no enciende", "las luces se ven débiles" | síntomas presentes |
| "no sale humo negro" | síntoma **descartado** |
| "hace 9.000 km que no le hago mantenimiento", "nueve mil kilómetros desde el último mantenimiento" | historial: 9000 km |
| "la batería tiene 3 años" | historial: 36 meses |
| "el motor está a 125 grados", "carga 12,2 voltios", "la cadena tiene 45 mm", "22 km por litro" | lecturas numéricas |
| mayúsculas, tildes, puntuación, "y", "pero", comas | no cambian el resultado |

Si el texto es contradictorio ("carburador e inyección"), se marcan ambos y las validaciones de
coherencia bloquean **Diagnosticar**.

### Modo Experto

Solo con el rol Experto la pestaña permite: **Paso 1** agregar un síntoma, **Paso 2** agregar una
falla con sus reglas (condiciones principales, apoyo, excluyentes, agravantes) y **Paso 3** enseñar
una expresión del lenguaje natural ("se desmaya" = pierde potencia). Prolog valida, lo agrega con
`assertz/1` y lo **escribe en `conocimiento_aprendido.pl`**, que la interfaz muestra en un panel.
Al reiniciar, Prolog lo carga de nuevo. Un usuario sin rol de experto no puede modificar nada:
el permiso lo verifica Prolog, no solo la interfaz.

### Caso de demostración 4 — frase del usuario → diagnóstico

Escriba: *El freno se siente esponjoso, la palanca recorre mucho y tarda más en detenerse. Hace
9.000 km que no le hago mantenimiento* y presione **Interpretar y diagnosticar**: el resultado es
**Aire en el circuito de frenos**, igual que marcando las casillas.

### Caso de demostración 5 — el experto amplía el vocabulario

1. Como usuario escriba "la moto se desmaya": no reconoce nada.
2. Entre como experto, abra **Modo Experto → Paso 3**, escriba *se desmaya* y elija *pierde potencia*.
3. Vuelva a interpretar la misma frase: ahora marca *pierde potencia*. Cierre el programa y ábralo
   de nuevo: sigue funcionando (está en `conocimiento_aprendido.pl`).

### Modelo híbrido (scikit-learn)

`preprocesamiento.py` entrena, por cada variable, un `DecisionTreeClassifier(max_depth=2)` con
lecturas de referencia etiquetadas por el experto. El árbol aprende los umbrales (por ejemplo, la
temperatura del motor: bajo hasta 72,5 °C, normal hasta 110 °C, alto desde ahí). Python solo entrega
el nivel; **Prolog** valida el rango (`validar_lectura/4`) y decide el síntoma (`hecho_de_lectura/3`).

## Estructura del proyecto

| Archivo | Contenido |
|---|---|
| `base_conocimiento.pl` | Hechos, reglas (niveles 1 a 3), módulo de explicabilidad y módulo de recomendación |
| `motor_inferencia.py` | Puente PySwip: carga el `.pl`, envía listas de observaciones, devuelve resultados |
| `gramatica_dcg.pl` | Entregable 3: gramática DCG, léxico, vocabulario aprendido, lecturas |
| `preprocesamiento.py` | Entregable 3: clasificador scikit-learn que convierte lecturas en niveles |
| `main.py` | Interfaz web con Streamlit (Entregables 2 y 3) |
| `main_consola.py` | Interfaz de consola (Entregable 1) |
| `pruebas.py` | Pruebas automáticas |
| `conocimiento_aprendido.pl` | Lo que el usuario ha enseñado. Lo genera Prolog solo (no existe hasta que se enseña algo); no lo edite a mano |
| `diccionario_predicados.md` | Diccionario de los nuevos predicados |

## Arquitectura híbrida

* **Capa imperativa (Python):** interfaz, captura y limpieza de entradas, presentación
  visual. Solo verifica que cada elemento enviado tenga forma de átomo en minúscula.
* **Capa simbólica (Prolog):** toda la inferencia y la construcción de la traza. La
  base no usa `read/1`: recibe la lista de observaciones como argumento, así el hilo de
  la interfaz nunca se bloquea. Además valida la entrada con `ground/1` y verificando
  átomos en minúscula (`validar_entrada/2`).
* **Aprendizaje:** Python solo envía lo que el usuario escribió (los textos libres se
  entrecomillan y escapan para que no puedan alterar la consulta). Prolog normaliza el
  nombre a un identificador, valida, registra con `assertz/1` y guarda el archivo. Los
  predicados del catálogo (`falla_subsistema/2`, `requisitos_falla/2`, etc.) se declaran
  `dynamic` para poder crecer.
* SWI-Prolog corre en un único hilo dedicado dentro de `motor_inferencia.py`, de modo
  que la interfaz puede atender cada interacción desde hilos distintos sin problemas.

## Pruebas

```bash
python -m unittest pruebas -v
```

Son 94 pruebas. Cubren los dos casos de demostración, la traza, la validación de entradas,
el flujo de la interfaz, el aprendizaje (fallas y síntomas nuevos, validaciones, guardado y
recarga desde el archivo, olvidar) y las validaciones de coherencia (grupos de una sola
opción, combinaciones imposibles, rangos, bloqueo del diagnóstico y comportamiento de la
interfaz), y las del Entregable 3: gramática (frases, negación, números, texto vacío o
inyectado, texto fuera del dominio), lecturas y umbrales, roles, vocabulario aprendido con
persistencia y la interfaz (texto libre, bloqueo del Modo Experto, clave). Las pruebas usan un archivo de aprendizaje
temporal, así que no tocan `conocimiento_aprendido.pl`.

## Notas

* `conocimiento_aprendido.pl` se crea junto a `base_conocimiento.pl`. Si no quiere
  compartir lo aprendido, agréguelo al `.gitignore`; si quiere compartirlo (por ejemplo,
  entre los dos integrantes), súbalo al repositorio. Para empezar de cero, borre el archivo.
* Para usar otro archivo de aprendizaje, defina la variable de entorno
  `MOTODIAG_APRENDIZAJE` con su ruta antes de ejecutar.
* Al cerrar el programa puede aparecer el aviso `Failed to stop Prolog threads`. Es
  inofensivo.
* MotoDiag orienta la decisión del usuario; no reemplaza una revisión presencial en un
  taller.
