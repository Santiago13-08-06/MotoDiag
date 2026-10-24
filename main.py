"""
main.py - Interfaz web de MotoDiag (Entregable 2), hecha con Streamlit.

Arquitectura hibrida:
  * Capa imperativa (este archivo, Python): dibuja la interfaz, captura y
    limpia las entradas del usuario y presenta visualmente los resultados.
  * Capa simbolica (base_conocimiento.pl, Prolog): toda la logica de
    inferencia, encadenamiento, traza de auditoria y recomendaciones.

Este archivo NO decide nada: cada diagnostico, cada regla disparada, cada
hipotesis descartada y cada sugerencia vienen calculados por Prolog.

Ejecucion:
    pip install pyswip streamlit
    streamlit run main.py
"""

import streamlit as st

from motor_inferencia import MotorInferencia

st.set_page_config(page_title="MotoDiag", page_icon="🏍️", layout="wide")

# ---------------------------------------------------------------------------
# Solo presentacion (textos y colores de la interfaz)
# ---------------------------------------------------------------------------
ETIQUETA_GRAVEDAD = {"leve": "LEVE", "moderada": "MODERADA", "critica": "CRÍTICA"}
MENSAJE_GRAVEDAD = {"leve": st.success, "moderada": st.warning, "critica": st.error}
ETIQUETA_NIVEL = {1: "Nivel 1 · Validación", 2: "Nivel 2 · Inferencia",
                  3: "Nivel 3 · Conclusión"}
ETIQUETA_ESTADO = {
    "sin_diagnostico": "Sin diagnóstico",
    "empate": "Empate entre hipótesis",
    "certeza_no_alta": "Certeza aún no alta",
    "suficiente": "Evidencia suficiente",
    "entrada_invalida": "Entrada no válida",
}


def tabla_md(encabezados, filas):
    """Tabla en markdown: el texto largo se ajusta al ancho (solo presentacion)."""
    def celda(x):
        texto = str(x).replace("|", "/").replace("\n", " ")
        # Dentro de un bloque `codigo` la barra invertida ya es literal.
        return texto if texto.startswith("`") else texto.replace("\\", "\\\\")
    lineas = ["| " + " | ".join(encabezados) + " |",
              "|" + "|".join(["---"] * len(encabezados)) + "|"]
    lineas += ["| " + " | ".join(celda(c) for c in fila) + " |" for fila in filas]
    st.markdown("\n".join(lineas))


@st.cache_resource(show_spinner="Cargando la base de conocimiento en Prolog...")
def cargar_motor():
    """Una sola sesion de SWI-Prolog compartida por la aplicacion."""
    motor = MotorInferencia()
    return motor, motor.preguntas_guiadas(), motor.preguntas_numericas()


motor, PREGUNTAS, NUMERICAS = cargar_motor()


# ---------------------------------------------------------------------------
# Estado y captura de entradas (capa imperativa)
# ---------------------------------------------------------------------------
def clave_sintoma(elemento):
    return f"s_{elemento}"


def clave_numero(dato):
    return f"n_{dato}"


def marcar(elemento):
    """Callback del boton 'Si, lo observo' de las sugerencias de Prolog."""
    st.session_state[clave_sintoma(elemento)] = True
    st.session_state["consultado"] = True


def diagnosticar():
    st.session_state["consultado"] = True


def limpiar():
    for _, elemento, _ in PREGUNTAS:
        st.session_state[clave_sintoma(elemento)] = False
    for dato, _ in NUMERICAS:
        st.session_state[clave_numero(dato)] = None
    st.session_state["consultado"] = False


def recoger_observaciones():
    """Arma la lista que se envia a Prolog con lo que marco el usuario."""
    observados = [elemento for _, elemento, _ in PREGUNTAS
                  if st.session_state.get(clave_sintoma(elemento), False)]
    for dato, _ in NUMERICAS:
        valor = st.session_state.get(clave_numero(dato))
        if valor is not None:
            observados.append((dato, int(valor)))
    return observados


# ---------------------------------------------------------------------------
# Encabezado
# ---------------------------------------------------------------------------
st.title("🏍️ MotoDiag")
st.caption("Sistema experto auditable (\"caja blanca\") para el diagnóstico de fallas "
           "en motocicletas de 100 a 400 cc. Prolog razona; Python solo muestra.")

col_entrada, col_salida = st.columns([5, 7], gap="large")

# ---------------------------------------------------------------------------
# Columna izquierda: preguntas entregadas por Prolog
# ---------------------------------------------------------------------------
with col_entrada:
    st.subheader("1. Describa la falla")
    st.write("Marque lo que observa en la moto. Puede dejar sin marcar lo que no sabe: "
             "el sistema le dirá qué falta.")

    grupos = []
    for titulo, elemento, texto in PREGUNTAS:
        if not grupos or grupos[-1][0] != titulo:
            grupos.append((titulo, []))
        grupos[-1][1].append((elemento, texto))

    # El rotulo de cada grupo es fijo: si cambiara al marcar, Streamlit lo
    # trataria como otro expander y lo cerraria en cada clic.
    for titulo, items in grupos:
        with st.expander(titulo, expanded=(titulo == grupos[0][0])):
            for elemento, texto in items:
                st.checkbox(texto, key=clave_sintoma(elemento))

    with st.expander("HISTORIAL"):
        for dato, texto in NUMERICAS:
            st.number_input(texto, min_value=0, step=1, value=None,
                            placeholder="Sin dato", key=clave_numero(dato))

    total_marcados = len(recoger_observaciones())
    st.caption(f"Elementos marcados: {total_marcados}")

    c1, c2 = st.columns(2)
    c1.button("Diagnosticar", type="primary", width="stretch",
              on_click=diagnosticar)
    c2.button("Limpiar", width="stretch", on_click=limpiar)

# ---------------------------------------------------------------------------
# Columna derecha: resultados calculados por Prolog
# ---------------------------------------------------------------------------
with col_salida:
    st.subheader("2. Resultado")
    if not st.session_state.get("consultado", False):
        st.info("Marque los síntomas y presione **Diagnosticar**.")
    else:
        observados = recoger_observaciones()
        explicado = motor.diagnosticar_explicado(observados)
        recomendacion = motor.recomendar_evidencia(observados)
        diagnosticos = explicado["diagnosticos"]

        for alerta in explicado["alertas"]:
            st.error(f"⚠️ {alerta}")
        if explicado["invalidos"]:
            st.warning("Elementos no reconocidos (ignorados): "
                       + ", ".join(explicado["invalidos"]))

        tab_dx, tab_por_que, tab_falta = st.tabs(
            ["Diagnóstico", "¿Por qué?", "¿Qué falta?"])

        # ---------------- Diagnostico ----------------
        with tab_dx:
            if not diagnosticos:
                st.warning("Sin diagnóstico concluyente con los datos ingresados. "
                           "Revise la pestaña **¿Qué falta?**.")
            for i, d in enumerate(diagnosticos):
                titulo = "Diagnóstico principal" if i == 0 else f"Alternativa {i}"
                with st.container(border=True):
                    st.markdown(f"**{titulo}**")
                    st.markdown(f"### {d['nombre']}")
                    st.caption(f"Subsistema: {d['subsistema']}")
                    m1, m2, m3 = st.columns(3)
                    m1.metric("Certeza", f"{d['certeza'].upper()} ({d['puntaje']})")
                    m2.metric("Gravedad", ETIQUETA_GRAVEDAD.get(d["gravedad"], d["gravedad"]))
                    m3.metric("Prioridad", f"{d['prioridad']}/100")
                    MENSAJE_GRAVEDAD.get(d["gravedad"], st.info)(d["recomendacion"])

        # ---------------- ¿Por que? ----------------
        with tab_por_que:
            if not diagnosticos:
                st.info("No hay diagnóstico que auditar todavía.")
            else:
                nombres = [d["nombre"] for d in diagnosticos]
                elegido = st.selectbox("Diagnóstico a auditar", nombres)
                d = diagnosticos[nombres.index(elegido)]

                st.markdown("#### Reglas disparadas")
                st.caption("Traza devuelta por Prolog: cada fila es una regla que se "
                           "evaluó con éxito para este diagnóstico.")
                tabla_md(["Nivel", "Regla", "Resultado"],
                         [(ETIQUETA_NIVEL.get(r["nivel"], r["nivel"]), f"`{r['regla']}`", r["texto"])
                          for r in d["reglas"]])

                st.markdown("#### Hechos comprobados como verdaderos")
                tabla_md(["Tipo", "Hecho"], [(h["tipo"], h["texto"]) for h in d["hechos"]])

            st.markdown("#### Hipótesis alternativas descartadas")
            if explicado["descartadas"]:
                st.caption("Fallas que comparten síntomas con el caso pero Prolog descartó.")
                tabla_md(["Hipótesis", "Síntomas compartidos", "Motivo del descarte"],
                         [(x["hipotesis"], x["compartidos"], x["motivo"])
                          for x in explicado["descartadas"]])
            else:
                st.write("Ninguna hipótesis comparte síntomas con el caso y fue descartada.")

        # ---------------- ¿Que falta? ----------------
        with tab_falta:
            estado = recomendacion["estado"]
            funcion = st.success if estado == "suficiente" else st.warning
            funcion(f"**{ETIQUETA_ESTADO.get(estado, estado)}.** {recomendacion['mensaje']}")

            if recomendacion["competencia"]:
                st.markdown("#### Hipótesis en competencia")
                tabla_md(["Hipótesis", "Puntaje", "Certeza"],
                         [(c["hipotesis"], c["puntaje"], c["certeza"])
                          for c in recomendacion["competencia"]])

            if recomendacion["sugerencias"]:
                st.markdown("#### Qué verificar a continuación")
                st.caption("Ordenado por peso: Prolog calcula cuánto ayuda cada dato a "
                           "confirmar o descartar las hipótesis activas.")
                for s in recomendacion["sugerencias"]:
                    with st.container(border=True):
                        st.markdown(f"**{s['pregunta']}**  \n_Peso: {s['peso']}_")
                        if s["confirma"]:
                            st.write("Reforzaría: " + ", ".join(s["confirma"]))
                        if s["descarta"]:
                            st.write("Descartaría: " + ", ".join(s["descarta"]))
                        if s["tipo"] == "sintoma":
                            st.button("Sí, lo observo", key=f"sug_{s['dato']}",
                                      on_click=marcar, args=(s["dato"],))
                        else:
                            st.caption("Ingréselo en la sección HISTORIAL de la izquierda.")

st.divider()
st.caption("MotoDiag orienta la decisión del usuario; no reemplaza una revisión "
           "presencial en un taller.")
