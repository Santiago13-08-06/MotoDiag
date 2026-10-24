# MotoDiag — Sistema experto auditable para diagnóstico de motocicletas

Sistema experto para diagnosticar fallas mecánicas y eléctricas en motocicletas
monocilíndricas de 4 tiempos (100 a 400 cc).

* **Prolog (SWI-Prolog)** contiene todo el conocimiento y toda la lógica: inferencia,
  descarte, severidad, traza de auditoría y sugerencias de desempate.
* **Python** solo dibuja la interfaz, captura las entradas y presenta los resultados
  que devuelve Prolog.

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
pip install pyswip streamlit
```

## Ejecución

Interfaz web (Entregable 2):

```bash
streamlit run main.py
```

Se abre en el navegador (por defecto en <http://localhost:8501>).

Consola (Entregable 1, se conserva):

```bash
python main_consola.py          # consulta guiada
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

## Estructura del proyecto

| Archivo | Contenido |
|---|---|
| `base_conocimiento.pl` | Hechos, reglas (niveles 1 a 3), módulo de explicabilidad y módulo de recomendación |
| `motor_inferencia.py` | Puente PySwip: carga el `.pl`, envía listas de observaciones, devuelve resultados |
| `main.py` | Interfaz web con Streamlit (Entregable 2) |
| `main_consola.py` | Interfaz de consola (Entregable 1) |
| `pruebas.py` | Pruebas automáticas |
| `diccionario_predicados.md` | Diccionario de los nuevos predicados |

## Arquitectura híbrida

* **Capa imperativa (Python):** interfaz, captura y limpieza de entradas, presentación
  visual. Solo verifica que cada elemento enviado tenga forma de átomo en minúscula.
* **Capa simbólica (Prolog):** toda la inferencia y la construcción de la traza. La
  base no usa `read/1`: recibe la lista de observaciones como argumento, así el hilo de
  la interfaz nunca se bloquea. Además valida la entrada con `ground/1` y verificando
  átomos en minúscula (`validar_entrada/2`).
* SWI-Prolog corre en un único hilo dedicado dentro de `motor_inferencia.py`, de modo
  que la interfaz puede atender cada interacción desde hilos distintos sin problemas.

## Pruebas

```bash
python -m unittest pruebas -v
```

Cubren los dos casos de demostración, la traza, la validación de entradas y el flujo
de la interfaz.

## Notas

* Al cerrar el programa puede aparecer el aviso `Failed to stop Prolog threads`. Es
  inofensivo.
* MotoDiag orienta la decisión del usuario; no reemplaza una revisión presencial en un
  taller.
