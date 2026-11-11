"""
main.py - Interfaz web de MotoDiag (Entregable 2), hecha con Streamlit.

Arquitectura hibrida:
  * Capa imperativa (este archivo, Python): dibuja la interfaz, captura y
    limpia las entradas del usuario y presenta visualmente los resultados.
  * Capa simbolica (base_conocimiento.pl, Prolog): toda la logica de
    inferencia, encadenamiento, traza de auditoria y recomendaciones.

Este archivo NO decide nada: cada diagnostico, cada regla disparada, cada
hipotesis descartada y cada sugerencia vienen calculados por Prolog.

Entregable 3:
  * Lenguaje natural: el usuario describe la falla con sus palabras; una DCG de
    Prolog analiza la oracion y extrae los hechos (la casilla de verificacion ya
    no es la unica forma de entrada).
  * Lecturas del taller: las medidas continuas (temperatura, voltaje...) las
    convierte en niveles un clasificador de scikit-learn; Prolog decide que
    hecho significa cada nivel.
  * Modo Experto: solo el rol "experto" puede ensenar fallas, sintomas y
    vocabulario. Prolog valida, hace assertz/1 y guarda en conocimiento_aprendido.pl.
    La autenticacion (clave) es de Python; los permisos los decide Prolog.

Ejecucion:
    pip install pyswip streamlit scikit-learn
    streamlit run main.py
"""

import hmac
import os

import streamlit as st

from motor_inferencia import MotorInferencia

st.set_page_config(page_title="MotoDiag", page_icon="🏍️", layout="wide",
                   initial_sidebar_state="expanded")

# Clave del rol experto. Cambiela con la variable de entorno MOTODIAG_CLAVE_EXPERTO.
CLAVE_EXPERTO = os.environ.get("MOTODIAG_CLAVE_EXPERTO", "experto2026")
MAX_INTENTOS = 5

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
    "entrada_incoherente": "Datos contradictorios",
}
ETIQUETA_TIPO = {"hecho": "Síntoma presente", "ausente": "Síntoma descartado",
                 "dato": "Dato del historial", "lectura": "Lectura numérica"}
ETIQUETA_DATO = {"km_mantenimiento": "Km desde el último mantenimiento",
                 "antiguedad_bateria": "Meses de la batería"}
ETIQUETA_NIVEL_LECTURA = {"bajo": "BAJO", "normal": "NORMAL", "alto": "ALTO"}
AVISO_TEXTO = {
    "texto_vacio": "Escriba una descripción de la falla.",
    "texto_largo": "La descripción es demasiado larga (máximo 600 caracteres).",
    "no_entendido": "No reconocí ningún síntoma en esa descripción. Pruebe con otras "
                    "palabras (por ejemplo: «la moto no enciende y las luces están "
                    "débiles») o márquelos en la lista.",
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
    return (motor, motor.preguntas_numericas(), motor.grupos_exclusivos(),
            motor.limites_numericos(), motor.variables_lectura())


motor, NUMERICAS, GRUPOS, LIMITES, LECTURAS = cargar_motor()
# Reglas de coherencia que entrega Prolog: de cada grupo solo se elige una opcion.
GRUPO_DE = {e: (g, d, m) for g, d, m in GRUPOS for e in m}
# Estas listas pueden crecer cuando el usuario ensena algo nuevo: se piden
# a Prolog en cada ejecucion de la pagina.
PREGUNTAS = motor.preguntas_guiadas()
CATALOGO = motor.catalogo()
APRENDIDAS = motor.fallas_aprendidas()
ID_APRENDIDAS = {f["falla"] for f in APRENDIDAS}
NOMBRE_SINTOMA = {x["elemento"]: x["nombre"] for x in CATALOGO["sintomas"]}
ETIQUETA_AGRAVANTE = {"mantenimiento_vencido": "Mantenimiento vencido",
                      "bateria_vieja": "Batería antigua"}
ETIQUETA_ALIMENTACION = {"cualquiera": "Cualquier moto", "carburador": "Solo con carburador",
                         "inyeccion": "Solo con inyección"}


# ---------------------------------------------------------------------------
# Estado y captura de entradas (capa imperativa)
# ---------------------------------------------------------------------------
def clave_sintoma(elemento):
    return f"s_{elemento}"


def clave_numero(dato):
    return f"n_{dato}"


def hacer_exclusivo(elemento):
    """Si el elemento quedo marcado, desmarca los de su grupo (Prolog define el grupo).

    Devuelve True si tuvo que desmarcar alguno.
    """
    ss = st.session_state
    if not ss.get(clave_sintoma(elemento)) or elemento not in GRUPO_DE:
        return False
    _, descripcion, miembros = GRUPO_DE[elemento]
    desmarcados = [o for o in miembros
                   if o != elemento and ss.get(clave_sintoma(o))]
    for otro in desmarcados:
        ss[clave_sintoma(otro)] = False
    if desmarcados:
        st.toast(f"Solo puede elegirse una opción sobre {descripcion}: "
                 "se cambió su elección.", icon="🔁")
    return bool(desmarcados)


def al_marcar(elemento):
    """Callback de cada casilla: aplica la exclusividad de su grupo."""
    hacer_exclusivo(elemento)


def marcar(elemento):
    """Callback del boton 'Si, lo observo' de las sugerencias de Prolog."""
    st.session_state[clave_sintoma(elemento)] = True
    hacer_exclusivo(elemento)
    st.session_state["consultado"] = True


def diagnosticar():
    st.session_state["consultado"] = True


def clave_lectura(variable):
    return f"l_{variable}"


def vaciar_formulario():
    """Deja en blanco casillas, historial y lecturas (no toca el texto escrito)."""
    for _, elemento, _ in PREGUNTAS:
        st.session_state[clave_sintoma(elemento)] = False
    for dato, _ in NUMERICAS:
        st.session_state[clave_numero(dato)] = None
    for v in LECTURAS:
        st.session_state[clave_lectura(v["variable"])] = None


def limpiar():
    vaciar_formulario()
    for clave in ("texto_libre", "interp"):
        st.session_state.pop(clave, None)
    st.session_state["consultado"] = False


def lecturas_del_formulario():
    """Evalua las lecturas numericas escritas a mano: [{variable, valor, nivel, hecho...}]."""
    resultado = []
    for v in LECTURAS:
        valor = st.session_state.get(clave_lectura(v["variable"]))
        if valor is not None:
            resultado.append(motor.evaluar_lectura(v["variable"], float(valor)))
    return resultado


def recoger_observaciones():
    """Arma la lista que se envia a Prolog: casillas + historial + hechos de las lecturas."""
    observados = [elemento for _, elemento, _ in PREGUNTAS
                  if st.session_state.get(clave_sintoma(elemento), False)]
    for lectura in lecturas_del_formulario():
        if lectura["hecho"] and lectura["hecho"] not in observados:
            observados.append(lectura["hecho"])
    for dato, _ in NUMERICAS:
        valor = st.session_state.get(clave_numero(dato))
        if valor is not None:
            observados.append((dato, int(valor)))
    return observados


# ---------------------------------------------------------------------------
# Entregable 3: descripcion en lenguaje natural (la DCG la analiza Prolog)
# ---------------------------------------------------------------------------
def interpretar_descripcion(y_diagnosticar=False):
    """Envia el texto a Prolog y rellena el formulario con los hechos que extrajo."""
    ss = st.session_state
    r = motor.interpretar(ss.get("texto_libre", ""))
    r["avisos"] = []
    ss["interp"] = r
    if r["estado"] != "ok":
        return                              # no se toca lo que ya estaba marcado
    vaciar_formulario()                     # el texto reemplaza lo marcado antes
    for hecho in r["hechos"]:
        ss[clave_sintoma(hecho)] = True
    for dato, valor in r["datos"]:
        minimo, maximo = LIMITES.get(dato, (0, None))
        if valor < minimo or (maximo is not None and valor > maximo):
            r["avisos"].append(f"{ETIQUETA_DATO.get(dato, dato)}: {valor} está fuera "
                               f"del rango permitido ({minimo} a {maximo}); no se usó.")
        else:
            ss[clave_numero(dato)] = int(valor)
    for lectura in r["lecturas"]:
        if lectura["estado"] != "ok":
            r["avisos"].append(lectura["mensaje"])
    ss["consultado"] = bool(y_diagnosticar)


# ---------------------------------------------------------------------------
# Roles: la clave la verifica Python; que puede hacer cada rol lo decide Prolog
# ---------------------------------------------------------------------------
def rol_actual():
    return st.session_state.get("rol", "usuario")


def iniciar_sesion_experto():
    ss = st.session_state
    if ss.get("intentos", 0) >= MAX_INTENTOS:
        ss["login_msg"] = "Demasiados intentos fallidos. Cierre y vuelva a abrir la página."
        return
    if hmac.compare_digest(str(ss.get("clave_ingresada", "")).encode(),
                           CLAVE_EXPERTO.encode()):
        ss["rol"] = "experto"
        ss["intentos"] = 0
        ss["login_msg"] = ""
    else:
        ss["intentos"] = ss.get("intentos", 0) + 1
        ss["login_msg"] = "Clave incorrecta."
    ss["clave_ingresada"] = ""


def cerrar_sesion():
    st.session_state["rol"] = "usuario"
    st.session_state["login_msg"] = ""


# ---------------------------------------------------------------------------
# Aprendizaje: callbacks que envian a Prolog lo que el usuario ensena
# ---------------------------------------------------------------------------
def avisar(resultado):
    """Guarda el resultado de Prolog para mostrarlo y lo anuncia con un aviso."""
    ok = resultado["estado"] == "ok"
    st.session_state["aprendizaje_msg"] = (ok, resultado["mensaje"])
    st.toast(resultado["mensaje"], icon="✅" if ok else "⚠️")


def ensenar_sintoma():
    ss = st.session_state
    resultado = motor.aprender_sintoma(ss.get("ens_sint_txt", ""),
                                       ss.get("ens_sint_cat") or "sin_elegir",
                                       rol=rol_actual())
    avisar(resultado)
    if resultado["estado"] == "ok":
        ss[clave_sintoma(resultado["elemento"])] = True     # queda marcado como observado
        ss["ens_sint_txt"] = ""


def copiar_marcados():
    """Precarga las condiciones principales con los sintomas que el usuario marco."""
    ss = st.session_state
    ss["ens_req"] = [e for _, e, _ in PREGUNTAS
                     if ss.get(clave_sintoma(e)) and e in NOMBRE_SINTOMA][:5]


def ensenar_falla():
    ss = st.session_state
    resultado = motor.aprender_falla(
        ss.get("ens_nombre", ""),
        ss.get("ens_sub") or "sin_elegir",     # Prolog responde "elija un subsistema"
        ss.get("ens_grav") or "sin_elegir",
        ss.get("ens_req", []), ss.get("ens_apo", []), ss.get("ens_exc", []),
        ss.get("ens_agr", []), ss.get("ens_ali", "cualquiera"),
        ss.get("ens_rec", ""), rol=rol_actual())
    avisar(resultado)
    if resultado["estado"] == "ok":
        for clave in ("ens_req", "ens_apo", "ens_exc", "ens_agr"):
            ss[clave] = []
        ss["ens_nombre"] = ""
        ss["ens_rec"] = ""
        ss["consultado"] = True


def ensenar_frase():
    ss = st.session_state
    resultado = motor.aprender_frase(ss.get("ens_frase_txt", ""),
                                     ss.get("ens_frase_sint") or "sin_elegir",
                                     rol=rol_actual())
    avisar(resultado)
    if resultado["estado"] == "ok":
        ss["ens_frase_txt"] = ""


def olvidar_frase(texto):
    avisar(motor.olvidar_frase(texto, rol=rol_actual()))


def olvidar_falla(falla):
    avisar(motor.olvidar_falla(falla, rol=rol_actual()))


def olvidar_sintoma(elemento):
    resultado = motor.olvidar_sintoma(elemento, rol=rol_actual())
    avisar(resultado)
    if resultado["estado"] == "ok":
        for clave in ("ens_req", "ens_apo", "ens_exc"):
            st.session_state[clave] = [e for e in st.session_state.get(clave, []) if e != elemento]
        st.session_state.pop(clave_sintoma(elemento), None)


# ---------------------------------------------------------------------------
# Encabezado
# ---------------------------------------------------------------------------
st.title("🏍️ MotoDiag")
st.caption("Sistema experto auditable (\"caja blanca\") para el diagnóstico de fallas "
           "en motocicletas de 100 a 400 cc. Prolog razona; Python solo muestra.")

with st.sidebar:
    st.header("Acceso")
    if rol_actual() == "experto":
        st.success("Rol actual: **Experto**")
        st.caption("Puede enseñar fallas, síntomas y vocabulario en la pestaña "
                   "**Modo Experto**.")
        st.button("Cerrar sesión de experto", on_click=cerrar_sesion, width="stretch")
    else:
        st.info("Rol actual: **Usuario**")
        st.caption("El usuario diagnostica. Solo el experto puede modificar el "
                   "conocimiento del sistema.")
        with st.form("login_experto", border=False):
            st.text_input("Clave de experto", type="password", key="clave_ingresada")
            st.form_submit_button("Entrar como experto", on_click=iniciar_sesion_experto)
        if st.session_state.get("login_msg"):
            st.error(st.session_state["login_msg"])

col_entrada, col_salida = st.columns([5, 7], gap="large")

# ---------------------------------------------------------------------------
# Columna izquierda: preguntas entregadas por Prolog
# ---------------------------------------------------------------------------
with col_entrada:
    st.subheader("1. Describa la falla")
    with st.container(border=True):
        st.markdown("**Con sus propias palabras**")
        st.text_area("Escriba qué le pasa a la moto", key="texto_libre", max_chars=600,
                     height=110, label_visibility="collapsed",
                     placeholder="Ejemplo: la moto no enciende y las luces se ven débiles, "
                                 "hace 9000 km que no le hago mantenimiento")
        b1, b2 = st.columns(2)
        b1.button("Interpretar", width="stretch", on_click=interpretar_descripcion)
        b2.button("Interpretar y diagnosticar", type="primary", width="stretch",
                  on_click=interpretar_descripcion, args=(True,))
        st.caption("Prolog analiza la oración con una gramática (DCG), extrae los síntomas "
                   "y marca la lista de abajo. Reemplaza lo marcado antes.")

        interp = st.session_state.get("interp")
        if interp:
            if interp["estado"] != "ok":
                st.warning(AVISO_TEXTO.get(interp["estado"], interp["estado"]))
            else:
                st.markdown("**Lo que entendí**")
                filas = []
                for x in interp["interpretacion"]:
                    if x["tipo"] == "hecho" or x["tipo"] == "ausente":
                        significado = NOMBRE_SINTOMA.get(x["nombre"], x["nombre"])
                    elif x["tipo"] == "dato":
                        significado = f"{ETIQUETA_DATO.get(x['nombre'], x['nombre'])} = {x['valor']}"
                    else:
                        significado = f"{x['nombre']} = {x['valor']}"
                    filas.append((f"«{x['frase']}»", ETIQUETA_TIPO.get(x["tipo"], x["tipo"]),
                                  significado))
                tabla_md(["Usted escribió", "Tipo", "Prolog entendió"], filas)
                for lectura in interp["lecturas"]:
                    if lectura["estado"] == "ok":
                        efecto = (f"genera el síntoma «{NOMBRE_SINTOMA.get(lectura['hecho'], lectura['hecho'])}»"
                                  if lectura["hecho"] else "es normal: no genera síntoma")
                        st.caption(f"📈 {lectura['descripcion']}: {lectura['valor']:g} "
                                   f"{lectura['unidad']} → nivel "
                                   f"{ETIQUETA_NIVEL_LECTURA.get(lectura['nivel'], lectura['nivel'])} "
                                   f"→ {efecto}.")
                if interp["ausentes"]:
                    st.caption("Descartó: " + ", ".join(NOMBRE_SINTOMA.get(a, a)
                                                        for a in interp["ausentes"]) + ".")
                if interp["desconocidas"]:
                    st.caption("No entendí estas palabras (se ignoraron): "
                               + ", ".join(interp["desconocidas"]) + ".")
                for aviso in interp["avisos"]:
                    st.warning(aviso)
                with st.expander("Hechos que recibió el motor de inferencia"):
                    st.code("[" + ", ".join(
                        h if isinstance(h, str) else f"{h[0]}({h[1]})"
                        for h in interp["observados"]) + "]", language="prolog")

    st.write("O marque lo que observa en la moto. Puede dejar sin marcar lo que no sabe: "
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
            avisados = set()
            for elemento, texto in items:
                grupo = GRUPO_DE.get(elemento)
                ayuda = None
                if grupo:
                    ayuda = f"Solo una opción sobre {grupo[1]}."
                    if grupo[0] not in avisados:       # un aviso por grupo
                        avisados.add(grupo[0])
                        st.caption(f"☝️ Elija solo una opción sobre {grupo[1]}.")
                st.checkbox(texto, key=clave_sintoma(elemento), help=ayuda,
                            on_change=al_marcar, args=(elemento,))

    with st.expander("HISTORIAL"):
        for dato, texto in NUMERICAS:
            minimo, maximo = LIMITES.get(dato, (0, None))
            st.number_input(texto, min_value=minimo, max_value=maximo, step=1,
                            value=None, placeholder=f"Entre {minimo} y {maximo}",
                            key=clave_numero(dato))

    with st.expander("LECTURAS DEL TALLER (medidas con instrumento)"):
        st.caption("Si midió algo, escríbalo: un clasificador de scikit-learn lo convierte "
                   "en un nivel (bajo, normal o alto) y Prolog decide qué síntoma significa.")
        for v in LECTURAS:
            st.number_input(f"{v['descripcion']} ({v['unidad']})",
                            min_value=float(v["minimo"]), max_value=float(v["maximo"]),
                            step=0.1, value=None, key=clave_lectura(v["variable"]),
                            placeholder=f"Entre {v['minimo']} y {v['maximo']}")
        for lectura in lecturas_del_formulario():
            if lectura["hecho"]:
                st.caption(f"📈 {lectura['descripcion']}: nivel "
                           f"{ETIQUETA_NIVEL_LECTURA[lectura['nivel']]} → síntoma "
                           f"«{NOMBRE_SINTOMA.get(lectura['hecho'], lectura['hecho'])}»")
            else:
                st.caption(f"📈 {lectura['descripcion']}: nivel "
                           f"{ETIQUETA_NIVEL_LECTURA[lectura['nivel']]} → sin síntoma")

    observados_actuales = recoger_observaciones()
    # Prolog revisa en cada cambio que lo marcado no se contradiga.
    validacion = motor.validar_observaciones(observados_actuales)
    for problema in validacion["problemas"]:
        if problema["tipo"] != "sin_sintomas":
            st.error(f"⛔ {problema['mensaje']}")
    st.caption(f"Elementos marcados: {len(observados_actuales)}")
    if validacion["estado"] == "sin_sintomas":
        st.caption("Marque al menos un síntoma para poder diagnosticar.")

    c1, c2 = st.columns(2)
    c1.button("Diagnosticar", type="primary", width="stretch",
              on_click=diagnosticar, disabled=validacion["estado"] != "ok")
    c2.button("Limpiar", width="stretch", on_click=limpiar)

# ---------------------------------------------------------------------------
# Columna derecha: resultados calculados por Prolog
# ---------------------------------------------------------------------------
def aviso_ensenar():
    st.info("¿Ya sabe cuál es la falla de su moto y el sistema no la conoce? "
            "Un experto puede enseñársela en la pestaña **Modo Experto**: la guarda y la usa en los próximos diagnósticos.")


with col_salida:
    st.subheader("2. Resultado")
    pidio = st.session_state.get("consultado", False)
    # Con datos contradictorios Prolog no diagnostica: primero hay que corregirlos.
    if pidio and validacion["estado"] == "incoherente":
        st.error("No se puede diagnosticar: hay datos que se contradicen. "
                 "Corríjalos en la lista de la izquierda.")
    consultado = pidio and validacion["estado"] == "ok"
    explicado = recomendacion = None
    if consultado:
        observados = recoger_observaciones()
        explicado = motor.diagnosticar_explicado(observados)
        recomendacion = motor.recomendar_evidencia(observados)
        for alerta in explicado["alertas"]:
            st.error(f"⚠️ {alerta}")
        if explicado["invalidos"]:
            st.warning("Elementos no reconocidos (ignorados): "
                       + ", ".join(explicado["invalidos"]))
    diagnosticos = explicado["diagnosticos"] if consultado else []

    tab_dx, tab_por_que, tab_falta, tab_experto = st.tabs(
        ["Diagnóstico", "¿Por qué?", "¿Qué falta?", "Modo Experto"])

    # ---------------- Diagnostico ----------------
    with tab_dx:
        if not consultado:
            st.info("Marque los síntomas y presione **Diagnosticar**.")
        else:
            if not diagnosticos:
                st.warning("Sin diagnóstico concluyente con los datos ingresados. "
                           "Revise la pestaña **¿Qué falta?**.")
                aviso_ensenar()
            for i, d in enumerate(diagnosticos):
                titulo = "Diagnóstico principal" if i == 0 else f"Alternativa {i}"
                with st.container(border=True):
                    st.markdown(f"**{titulo}**")
                    st.markdown(f"### {d['nombre']}")
                    st.caption(f"Subsistema: {d['subsistema']}")
                    if d["falla"] in ID_APRENDIDAS:
                        st.caption("🧠 Falla aprendida: se la enseñó un usuario al sistema.")
                    m1, m2, m3 = st.columns(3)
                    m1.metric("Certeza", f"{d['certeza'].upper()} ({d['puntaje']})")
                    m2.metric("Gravedad", ETIQUETA_GRAVEDAD.get(d["gravedad"], d["gravedad"]))
                    m3.metric("Prioridad", f"{d['prioridad']}/100")
                    MENSAJE_GRAVEDAD.get(d["gravedad"], st.info)(d["recomendacion"])

    # ---------------- ¿Por que? ----------------
    with tab_por_que:
        if not consultado:
            st.info("Presione **Diagnosticar** para ver la traza de auditoría.")
        else:
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
        if not consultado:
            st.info("Presione **Diagnosticar** para ver qué dato falta.")
        else:
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
            if estado in ("sin_diagnostico", "empate", "certeza_no_alta"):
                aviso_ensenar()

    # ---------------- Modo Experto (aprendizaje en caliente) ----------------
    with tab_experto:
        es_experto = rol_actual() == "experto"
        st.markdown("#### Modo Experto")
        if not es_experto:
            st.warning("🔒 Esta sección es solo para el rol **Experto**. Inicie sesión en el "
                       "panel de la izquierda para enseñar fallas, síntomas y vocabulario. "
                       "Como usuario puede ver abajo lo que el sistema ha aprendido.")
        else:
            st.write("Aquí el experto agrega conocimiento nuevo (un síntoma, una falla con sus "
                     "reglas o una expresión del lenguaje natural). Prolog lo valida, lo suma "
                     "a su base con `assertz/1` y lo escribe en el archivo "
                     "`conocimiento_aprendido.pl`: al reiniciar, el sistema lo sigue sabiendo. "
                     "El conocimiento original del experto no se puede modificar.")

        mensaje = st.session_state.get("aprendizaje_msg")
        if mensaje:
            (st.success if mensaje[0] else st.error)(mensaje[1])

        if es_experto:
            # ---- Paso 1: sintoma nuevo (opcional) ----
            with st.expander("Paso 1 (opcional): agregar un síntoma que no está en la lista"):
                st.text_input("Describa el síntoma", key="ens_sint_txt", max_chars=80,
                              placeholder="Ejemplo: ruido al girar el manubrio")
                st.selectbox("Categoría", [c[0] for c in CATALOGO["categorias"]],
                             format_func=lambda c: dict(CATALOGO["categorias"])[c],
                             key="ens_sint_cat", index=None, placeholder="Elija una")
                st.button("Agregar síntoma", on_click=ensenar_sintoma)
                st.caption("El síntoma nuevo aparece como pregunta en la lista de la izquierda "
                           "y queda marcado como observado.")

            # ---- Paso 2: falla nueva ----
            st.markdown("##### Paso 2: describa la falla")
            st.text_input("Nombre de la falla", key="ens_nombre", max_chars=60,
                          placeholder="Ejemplo: Rodamiento de dirección dañado")
            c1, c2, c3 = st.columns(3)
            c1.selectbox("Subsistema", [x[0] for x in CATALOGO["subsistemas"]],
                         format_func=lambda x: dict(CATALOGO["subsistemas"])[x], key="ens_sub",
                         index=None, placeholder="Elija uno")
            c2.selectbox("Gravedad", [x[0] for x in CATALOGO["gravedades"]],
                         format_func=lambda x: dict(CATALOGO["gravedades"])[x],
                         key="ens_grav", index=None, placeholder="Elija una")
            c3.selectbox("Aplica a", list(ETIQUETA_ALIMENTACION),
                         format_func=ETIQUETA_ALIMENTACION.get, key="ens_ali")

            opciones = list(NOMBRE_SINTOMA)
            st.multiselect("Condiciones principales (de 2 a 5): los síntomas que definen la falla",
                           opciones, format_func=NOMBRE_SINTOMA.get, key="ens_req", max_selections=5)
            st.button("Copiar los síntomas que marqué", on_click=copiar_marcados)
            st.multiselect("Síntomas de apoyo (opcional): refuerzan el diagnóstico",
                           opciones, format_func=NOMBRE_SINTOMA.get, key="ens_apo")
            st.multiselect("Síntomas excluyentes (opcional): si aparecen, la falla se descarta",
                           opciones, format_func=NOMBRE_SINTOMA.get, key="ens_exc")
            st.multiselect("Agravantes del historial (opcional)", list(ETIQUETA_AGRAVANTE),
                           format_func=ETIQUETA_AGRAVANTE.get, key="ens_agr")
            st.text_area("Recomendación para el usuario", key="ens_rec", max_chars=300,
                         placeholder="Ejemplo: Revise y cambie los rodamientos de la dirección.")

            # Prolog avisa al instante si las condiciones y los apoyos se contradicen
            # (una falla que exija cosas imposibles nunca podria diagnosticarse).
            definicion = list(dict.fromkeys(st.session_state.get("ens_req", [])
                                            + st.session_state.get("ens_apo", [])))
            contradicciones = motor.validar_observaciones(definicion)["problemas"] if definicion else []
            contradicciones = [p for p in contradicciones if p["tipo"] != "sin_sintomas"]
            for problema in contradicciones:
                st.error(f"⛔ Condiciones o apoyos que se contradicen. {problema['mensaje']}")
            st.button("Enseñar al sistema", type="primary", on_click=ensenar_falla,
                      disabled=bool(contradicciones))

            # ---- Paso 3: vocabulario del lenguaje natural ----
            st.markdown("##### Paso 3: enséñele una expresión al lenguaje natural")
            st.caption("Para que la gramática entienda frases nuevas, por ejemplo "
                       "«se ahoga al acelerar» = se apaga mientras anda.")
            st.text_input("Expresión (de 1 a 6 palabras)", key="ens_frase_txt", max_chars=60,
                          placeholder="Ejemplo: se ahoga al acelerar")
            st.selectbox("Significa este síntoma", opciones, format_func=NOMBRE_SINTOMA.get,
                         key="ens_frase_sint", index=None, placeholder="Elija un síntoma")
            st.button("Enseñar expresión", on_click=ensenar_frase)

        # ---- Lo aprendido (lectura para todos; borrar solo el experto) ----
        st.markdown("#### Lo que el sistema ha aprendido")
        sintomas_nuevos = motor.sintomas_aprendidos()
        frases_nuevas = motor.frases_aprendidas()
        if not APRENDIDAS and not sintomas_nuevos and not frases_nuevas:
            st.caption("Todavía no se ha agregado nada: el sistema solo usa el conocimiento del experto.")
        if APRENDIDAS:
            tabla_md(["Falla", "Subsistema", "Gravedad", "Condiciones principales",
                      "Apoyo", "Excluyentes", "Aplica a"],
                     [(f["nombre"], f["subsistema"], f["gravedad"], ", ".join(f["requisitos"]),
                       ", ".join(f["apoyos"]) or "—", ", ".join(f["excluyentes"]) or "—",
                       ETIQUETA_ALIMENTACION.get(f["alimentacion"], f["alimentacion"]))
                      for f in APRENDIDAS])
            if es_experto:
                for f in APRENDIDAS:
                    st.button(f"Olvidar «{f['nombre']}»", key=f"olv_f_{f['falla']}",
                              on_click=olvidar_falla, args=(f["falla"],))
        if sintomas_nuevos:
            st.markdown("**Síntomas agregados**")
            for x in sintomas_nuevos:
                if es_experto:
                    st.button(f"Olvidar el síntoma «{x['nombre']}»", key=f"olv_s_{x['elemento']}",
                              on_click=olvidar_sintoma, args=(x["elemento"],))
                else:
                    st.write(f"- {x['nombre']}")
        if frases_nuevas:
            st.markdown("**Expresiones agregadas al lenguaje natural**")
            for x in frases_nuevas:
                if es_experto:
                    st.button(f"Olvidar «{x['texto']}» (= {x['nombre']})",
                              key=f"olv_p_{x['texto']}", on_click=olvidar_frase, args=(x["texto"],))
                else:
                    st.write(f"- «{x['texto']}» = {x['nombre']}")
        if es_experto:
            with st.expander("Archivo conocimiento_aprendido.pl (lo que Prolog escribió)"):
                contenido = motor.contenido_aprendizaje()
                if contenido:
                    st.code(contenido, language="prolog")
                else:
                    st.caption("El archivo todavía no existe: se crea al enseñar algo.")

st.divider()
st.caption("MotoDiag orienta la decisión del usuario; no reemplaza una revisión "
           "presencial en un taller.")
