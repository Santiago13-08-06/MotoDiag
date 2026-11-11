"""
motor_inferencia.py - Puente entre Python y SWI-Prolog para MotoDiag.

Este modulo SOLO se encarga de:
  1. cargar base_conocimiento.pl en el motor de SWI-Prolog (via PySwip),
  2. enviar la lista de observaciones como consulta,
  3. recibir las listas de resultados y devolverlas como estructuras de Python.

Toda la logica de inferencia, descarte, validacion de listas, calculo de
severidad, traza de auditoria, sugerencias de desempate, analisis del lenguaje
natural (DCG), permisos por rol y aprendizaje reside en Prolog. La unica tarea
numerica que hace Python es convertir lecturas continuas en niveles discretos
(preprocesamiento.py, scikit-learn); Prolog decide que hecho significa cada nivel.

Nota tecnica: SWI-Prolog se inicializa en un unico hilo dedicado y todas las
consultas se ejecutan en ese hilo. Asi la interfaz (que puede correr cada
interaccion en un hilo distinto) nunca toca el motor desde un hilo ajeno.
"""

import atexit
import os
import re
from concurrent.futures import ThreadPoolExecutor

from pyswip import Prolog

from preprocesamiento import Discretizador

RUTA_BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         "base_conocimiento.pl")

# Un elemento de entrada es un atomo de Prolog (minusculas y guion bajo).
_ATOMO = re.compile(r"^[a-z][a-z0-9_]*$")

_CAMPOS_DIAGNOSTICO = (
    "falla", "subsistema", "certeza", "puntaje", "gravedad",
    "prioridad", "recomendacion", "explicacion",
)
_CAMPOS_EXPLICADO = (
    "falla", "nombre", "subsistema", "certeza", "puntaje", "gravedad",
    "prioridad", "recomendacion", "reglas", "hechos",
)


class MotorInferencia:
    """Envuelve una sesion de SWI-Prolog con la base de conocimiento cargada."""

    # Rol con el que se llama al motor cuando no se indica otro. Es "usuario":
    # sin rol de experto no se puede ensenar nada (denegar por defecto).
    rol_por_defecto = "usuario"

    def __init__(self, ruta_base=RUTA_BASE, ruta_aprendizaje=None):
        """
        ruta_base: archivo .pl con la base de conocimiento.
        ruta_aprendizaje: archivo donde Prolog guarda lo que el usuario ensena.
            Por defecto es conocimiento_aprendido.pl junto a la base (o el que
            indique la variable de entorno MOTODIAG_APRENDIZAJE); las pruebas
            usan otro archivo para no tocar el real.
        """
        if not os.path.isfile(ruta_base):
            raise FileNotFoundError(
                f"No se encontro la base de conocimiento: {ruta_base}")
        self._prolog = None
        self._discretizador = None
        self._ejecutor = ThreadPoolExecutor(max_workers=1,
                                            thread_name_prefix="swi-prolog")
        # Prolog espera barras normales aun en Windows.
        self._ejecutor.submit(self._iniciar,
                              ruta_base.replace("\\", "/")).result()
        atexit.register(self._ejecutor.shutdown, wait=True)
        if ruta_aprendizaje is None:
            ruta_aprendizaje = os.environ.get("MOTODIAG_APRENDIZAJE")
        if ruta_aprendizaje is not None:
            self._consultar_una(
                "usar_archivo_aprendizaje("
                + self._texto(str(ruta_aprendizaje).replace("\\", "/")) + ")")

    # ------------------------------------------------------------------
    # Consultas auxiliares: Prolog entrega las preguntas
    # ------------------------------------------------------------------
    def preguntas_guiadas(self):
        """Devuelve [(titulo_grupo, elemento, texto_pregunta), ...] en orden."""
        solucion = self._consultar_una("preguntas_guiadas(L)")
        return [tuple(fila) for fila in solucion["L"]]

    def preguntas_numericas(self):
        """Devuelve [(dato, texto_pregunta), ...]."""
        solucion = self._consultar_una("preguntas_numericas(L)")
        return [tuple(fila) for fila in solucion["L"]]

    # ------------------------------------------------------------------
    # Entregable 1: diagnostico con explicacion en texto
    # ------------------------------------------------------------------
    def diagnosticar(self, observados):
        """
        Envia la lista de observaciones a Prolog y devuelve el resultado.

        observados: lista de str (atomos, p. ej. "no_enciende") o de tuplas
                    (dato, numero), p. ej. ("km_mantenimiento", 8000).
        """
        lista_prolog = self._a_lista_prolog(observados)
        solucion = self._consultar_una(
            f"diagnosticar({lista_prolog}, R, I, A)")
        diagnosticos = [dict(zip(_CAMPOS_DIAGNOSTICO, fila))
                        for fila in solucion["R"]]
        return {
            "diagnosticos": diagnosticos,
            "invalidos": [str(x) for x in solucion["I"]],
            "alertas": [str(x) for x in solucion["A"]],
        }

    # ------------------------------------------------------------------
    # Entregable 2: modulo de explicabilidad ("¿Por que?")
    # ------------------------------------------------------------------
    def diagnosticar_explicado(self, observados):
        """
        Diagnostico con la traza de inferencia devuelta por Prolog:
        reglas disparadas, hechos comprobados e hipotesis descartadas.
        """
        lista_prolog = self._a_lista_prolog(observados)
        s = self._consultar_una(
            f"diagnosticar_explicado({lista_prolog}, R, D, I, A)")
        diagnosticos = []
        for fila in s["R"]:
            d = dict(zip(_CAMPOS_EXPLICADO, fila))
            d["reglas"] = [{"nivel": n, "regla": r, "texto": t}
                           for n, r, t in d["reglas"]]
            d["hechos"] = [{"tipo": t, "texto": x} for t, x in d["hechos"]]
            diagnosticos.append(d)
        return {
            "diagnosticos": diagnosticos,
            "descartadas": [{"hipotesis": h, "compartidos": c, "motivo": m}
                            for h, c, m in s["D"]],
            "invalidos": [str(x) for x in s["I"]],
            "alertas": [str(x) for x in s["A"]],
        }

    # ------------------------------------------------------------------
    # Entregable 2: modulo de recomendacion ("¿Que falta?")
    # ------------------------------------------------------------------
    def recomendar_evidencia(self, observados):
        """
        Pregunta a Prolog si la evidencia alcanza y, si no, que dato adicional
        tiene mayor peso para confirmar o desempatar el diagnostico.
        """
        lista_prolog = self._a_lista_prolog(observados)
        s = self._consultar_una(
            f"recomendar_evidencia({lista_prolog}, E, M, C, S)")
        return {
            "estado": str(s["E"]),
            "mensaje": str(s["M"]),
            "competencia": [{"hipotesis": n, "puntaje": p, "certeza": c}
                            for n, p, c in s["C"]],
            "sugerencias": [{"tipo": t, "dato": d, "pregunta": q, "peso": w,
                             "confirma": list(cf), "descarta": list(ds)}
                            for t, d, q, w, cf, ds in s["S"]],
        }

    # ------------------------------------------------------------------
    # Entregable 2 (extension): validaciones de coherencia. Prolog decide
    # que combinaciones son imposibles; Python solo las pide y las muestra.
    # ------------------------------------------------------------------
    def validar_observaciones(self, observados):
        """
        Pregunta a Prolog si lo marcado tiene sentido.
        Devuelve {"estado": ok | incoherente | sin_sintomas | entrada_invalida,
                  "problemas": [{"tipo", "mensaje"}, ...]}.
        """
        s = self._consultar_una(
            f"validar_observaciones({self._a_lista_prolog(observados)}, E, P)")
        return {"estado": str(s["E"]),
                "problemas": [{"tipo": str(t), "mensaje": str(m)} for t, m in s["P"]]}

    def grupos_exclusivos(self):
        """[(id, descripcion, [elementos]), ...]: de cada grupo solo puede elegirse uno."""
        s = self._consultar_una("grupos_exclusivos(G)")
        return [(i, d, list(m)) for i, d, m in s["G"]]

    def limites_numericos(self):
        """{dato: (minimo, maximo)} de los datos numericos del historial."""
        s = self._consultar_una("limites_numericos(L)")
        return {d: (mn, mx) for d, mn, mx in s["L"]}

    # ------------------------------------------------------------------
    # Entregable 2 (extension): aprendizaje. El sistema agrega fallas y
    # sintomas nuevos a su base y los guarda en conocimiento_aprendido.pl.
    # Python solo envia lo que el usuario escribio; Prolog valida, registra
    # con assertz/1 y guarda. Los mensajes de error tambien vienen de Prolog.
    # ------------------------------------------------------------------
    def catalogo(self):
        """Listas para armar el formulario: sintomas, subsistemas, categorias, gravedades."""
        s = self._consultar_una(
            "catalogo_sintomas(S), catalogo_subsistemas(B), "
            "catalogo_categorias(C), catalogo_gravedades(G)")
        return {
            "sintomas": [{"elemento": e, "categoria": c, "nombre": n}
                         for e, c, n in s["S"]],
            "subsistemas": [tuple(x) for x in s["B"]],
            "categorias": [tuple(x) for x in s["C"]],
            "gravedades": [tuple(x) for x in s["G"]],
        }

    def aprender_falla(self, nombre, subsistema, gravedad, requisitos,
                       apoyos=(), excluyentes=(), agravantes=(),
                       alimentacion="cualquiera", recomendacion="", rol=None):
        """
        Ensena una falla nueva. Devuelve {"estado", "mensaje", "falla"}.
        estado es "ok", "no_autorizado" (Prolog nego el permiso al rol) o el
        codigo del problema que detecto Prolog.
        """
        negado = self._negar_si_no_autorizado(rol, "ensenar_falla", {"falla": ""})
        if negado:
            return negado
        consulta = (
            "aprender_falla({n}, {sub}, {gra}, {req}, {apo}, {exc}, {agr}, "
            "{ali}, {rec}, E, M, F)").format(
                n=self._texto(nombre), sub=self._atomo(subsistema),
                gra=self._atomo(gravedad), req=self._atomos(requisitos),
                apo=self._atomos(apoyos), exc=self._atomos(excluyentes),
                agr=self._atomos(agravantes), ali=self._atomo(alimentacion),
                rec=self._texto(recomendacion))
        s = self._consultar_una(consulta)
        return {"estado": str(s["E"]), "mensaje": str(s["M"]), "falla": str(s["F"])}

    def aprender_sintoma(self, texto, categoria, rol=None):
        """Ensena un sintoma nuevo. Devuelve {"estado", "mensaje", "elemento"}."""
        negado = self._negar_si_no_autorizado(rol, "ensenar_sintoma", {"elemento": ""})
        if negado:
            return negado
        s = self._consultar_una(
            "aprender_sintoma({t}, {c}, E, M, X)".format(
                t=self._texto(texto), c=self._atomo(categoria)))
        return {"estado": str(s["E"]), "mensaje": str(s["M"]), "elemento": str(s["X"])}

    def fallas_aprendidas(self):
        """Fallas que el usuario ensenio (las del experto no aparecen aqui)."""
        s = self._consultar_una("listar_fallas_aprendidas(L)")
        return [{"falla": f, "nombre": n, "subsistema": sub, "gravedad": g,
                 "requisitos": list(r), "apoyos": list(a), "excluyentes": list(x),
                 "alimentacion": al, "recomendacion": rec}
                for f, n, sub, g, r, a, x, al, rec in s["L"]]

    def sintomas_aprendidos(self):
        s = self._consultar_una("listar_sintomas_aprendidos(L)")
        return [{"elemento": e, "categoria": c, "nombre": n} for e, c, n in s["L"]]

    def olvidar_falla(self, falla, rol=None):
        negado = self._negar_si_no_autorizado(rol, "olvidar")
        if negado:
            return negado
        s = self._consultar_una(
            "olvidar_falla({f}, E, M)".format(f=self._atomo(falla)))
        return {"estado": str(s["E"]), "mensaje": str(s["M"])}

    def olvidar_sintoma(self, elemento, rol=None):
        negado = self._negar_si_no_autorizado(rol, "olvidar")
        if negado:
            return negado
        s = self._consultar_una(
            "olvidar_sintoma({e}, E, M)".format(e=self._atomo(elemento)))
        return {"estado": str(s["E"]), "mensaje": str(s["M"])}

    def reiniciar_aprendizaje(self, rol=None):
        """Vuelve al conocimiento original del experto (borra lo aprendido)."""
        if self._negar_si_no_autorizado(rol, "olvidar"):
            raise PermissionError("Solo el rol experto puede reiniciar el aprendizaje.")
        self._consultar_una("reiniciar_aprendizaje")

    # ------------------------------------------------------------------
    # Entregable 3: roles. Prolog decide quien puede hacer que (permiso/2).
    # ------------------------------------------------------------------
    def autorizar(self, rol, accion):
        """Pregunta a Prolog si el rol puede hacer la accion. {"estado", "mensaje"}."""
        s = self._consultar_una(
            "autorizar({r}, {a}, E, M)".format(r=self._atomo(rol), a=self._atomo(accion)))
        return {"estado": str(s["E"]), "mensaje": str(s["M"])}

    def _negar_si_no_autorizado(self, rol, accion, extra=None):
        """None si el rol puede; si no, el resultado de denegacion (nada se modifica)."""
        resultado = self.autorizar(rol or self.rol_por_defecto, accion)
        if resultado["estado"] == "ok":
            return None
        resultado.update(extra or {})
        return resultado

    # ------------------------------------------------------------------
    # Entregable 3: lenguaje natural. Una DCG de Prolog analiza la oracion y
    # extrae los hechos; Python solo transporta el texto y discretiza las
    # lecturas numericas (scikit-learn) antes de devolverlas a Prolog.
    # ------------------------------------------------------------------
    def interpretar(self, texto):
        """
        Interpreta una descripcion escrita en espanol.

        Devuelve un diccionario con:
          estado: ok | texto_vacio | texto_largo | no_entendido
          hechos: sintomas que presenta la moto (incluye los que salen de lecturas)
          ausentes: sintomas que el usuario dice que NO tiene
          datos: [(dato, valor)] del historial (km_mantenimiento, antiguedad_bateria)
          lecturas: [{variable, descripcion, valor, unidad, nivel, hecho, estado, mensaje}]
          interpretacion: [{frase, tipo, nombre, valor}] palabras -> hecho (para mostrar)
          desconocidas: palabras que no se pudieron interpretar
          observados: lista lista para diagnosticar() (hechos + datos)
        """
        s = self._consultar_una(
            "interpretar_texto({t}, E, H, D, A, L, I, X)".format(t=self._texto(texto)))
        hechos = [str(h) for h in s["H"]]
        lecturas = []
        for variable, valor in s["L"]:
            lectura = self.evaluar_lectura(str(variable), valor)
            lecturas.append(lectura)
            if lectura["hecho"] and lectura["hecho"] not in hechos:
                hechos.append(lectura["hecho"])
        datos = [(str(d), v) for d, v in s["D"]]
        return {
            "estado": str(s["E"]),
            "hechos": hechos,
            "ausentes": [str(a) for a in s["A"]],
            "datos": datos,
            "lecturas": lecturas,
            "interpretacion": [{"frase": str(f), "tipo": str(t), "nombre": str(n),
                                "valor": v if isinstance(v, (int, float)) else str(v)}
                               for f, t, n, v in s["I"]],
            "desconocidas": [str(x) for x in s["X"]],
            "observados": hechos + datos,
        }

    def variables_lectura(self):
        """[{variable, unidad, minimo, maximo, descripcion}] de las lecturas del taller."""
        s = self._consultar_una("variables_lectura(L)")
        return [{"variable": str(v), "unidad": str(u), "minimo": mn, "maximo": mx,
                 "descripcion": str(d)} for v, u, mn, mx, d in s["L"]]

    def evaluar_lectura(self, variable, valor):
        """
        Convierte una medida continua en un hecho simbolico:
          1) Prolog valida la variable y el rango (validar_lectura/4),
          2) el clasificador de scikit-learn da el nivel (bajo/normal/alto),
          3) Prolog traduce ese nivel a un sintoma (hecho_de_lectura/3).
        """
        v = self._atomo(variable)
        if isinstance(valor, bool) or not isinstance(valor, (int, float)):
            raise ValueError(f"Lectura no numerica: {valor!r}")
        s = self._consultar_una(f"validar_lectura({v}, {valor}, E, M), "
                                f"variables_lectura(V)")
        unidad = descripcion = ""
        for var, uni, _mn, _mx, desc in s["V"]:
            if str(var) == variable:
                unidad, descripcion = str(uni), str(desc)
        resultado = {"variable": variable, "descripcion": descripcion, "valor": valor,
                     "unidad": unidad, "nivel": None, "hecho": None,
                     "estado": str(s["E"]), "mensaje": str(s["M"])}
        if resultado["estado"] != "ok":
            return resultado
        if self._discretizador is None:
            self._discretizador = Discretizador()
        nivel = self._discretizador.nivel(variable, valor)
        resultado["nivel"] = nivel
        hecho = self._ejecutar_sync(f"hecho_de_lectura({v}, {nivel}, X)")
        resultado["hecho"] = str(hecho[0]["X"]) if hecho else None
        return resultado

    def umbrales_lectura(self, variable):
        """Cortes que aprendio el clasificador para una variable (para explicarlos)."""
        if self._discretizador is None:
            self._discretizador = Discretizador()
        return self._discretizador.umbrales(variable)

    @property
    def usa_sklearn(self):
        if self._discretizador is None:
            self._discretizador = Discretizador()
        return self._discretizador.usa_sklearn

    # ------------------------------------------------------------------
    # Entregable 3: vocabulario. El experto ensena frases nuevas para que la
    # gramatica las reconozca. Prolog valida, hace assertz/1 y guarda.
    # ------------------------------------------------------------------
    def aprender_frase(self, texto, elemento, rol=None):
        """Ensena que una expresion significa un sintoma. {"estado", "mensaje"}."""
        negado = self._negar_si_no_autorizado(rol, "ensenar_frase")
        if negado:
            return negado
        s = self._consultar_una("aprender_frase({t}, {e}, E, M)".format(
            t=self._texto(texto), e=self._atomo(elemento)))
        return {"estado": str(s["E"]), "mensaje": str(s["M"])}

    def olvidar_frase(self, texto, rol=None):
        negado = self._negar_si_no_autorizado(rol, "olvidar")
        if negado:
            return negado
        s = self._consultar_una(f"olvidar_frase({self._texto(texto)}, E, M)")
        return {"estado": str(s["E"]), "mensaje": str(s["M"])}

    def frases_aprendidas(self):
        """[{texto, elemento, nombre}] de las expresiones que se ensenaron."""
        s = self._consultar_una("listar_frases_aprendidas(L)")
        return [{"texto": str(t), "elemento": str(e), "nombre": str(n)}
                for t, e, n in s["L"]]

    def archivo_aprendizaje(self):
        """Ruta del archivo .pl donde Prolog guarda lo aprendido."""
        s = self._consultar_una("ruta_aprendizaje(R)")
        return str(s["R"])

    def contenido_aprendizaje(self):
        """Texto del archivo de aprendizaje ('' si todavia no existe)."""
        ruta = self.archivo_aprendizaje()
        if not os.path.isfile(ruta):
            return ""
        with open(ruta, encoding="utf-8") as f:
            return f.read()

    # ------------------------------------------------------------------
    # Utilidades internas
    # ------------------------------------------------------------------
    def _iniciar(self, ruta):
        self._prolog = Prolog()
        self._prolog.consult(ruta)

    def _ejecutar(self, consulta):
        return list(self._prolog.query(consulta))

    def _ejecutar_sync(self, consulta):
        return self._ejecutor.submit(self._ejecutar, consulta).result()

    def _consultar_una(self, consulta):
        soluciones = self._ejecutor.submit(self._ejecutar, consulta).result()
        if not soluciones:
            raise RuntimeError(f"Prolog no devolvio solucion para: {consulta}")
        return soluciones[0]

    @staticmethod
    def _texto(valor):
        """Texto libre escrito por el usuario, como atomo entre comillas simples.

        Se escapan la barra invertida y la comilla simple, y los caracteres de
        control pasan a espacios, para que el texto nunca pueda salirse del
        atomo y alterar la consulta. Prolog valida despues el contenido.
        """
        limpio = "".join(c if c.isprintable() else " " for c in str(valor))[:1000]
        return "'" + limpio.replace("\\", "\\\\").replace("'", "\\'") + "'"

    @staticmethod
    def _atomo(valor):
        """Identificador (subsistema, categoria, elemento...) con forma de atomo."""
        if not isinstance(valor, str) or not _ATOMO.match(valor):
            raise ValueError(f"Identificador no valido: {valor!r}")
        return valor

    @classmethod
    def _atomos(cls, valores):
        return "[" + ",".join(cls._atomo(v) for v in valores) + "]"

    @staticmethod
    def _a_lista_prolog(observados):
        """Convierte la entrada de Python en el texto de una lista de Prolog.

        Solo comprueba la FORMA (atomos en minuscula y numeros) para armar una
        consulta bien formada; la validacion de contenido la hace Prolog.
        """
        elementos = []
        for item in observados:
            if isinstance(item, str):
                if not _ATOMO.match(item):
                    raise ValueError(f"Elemento no valido: {item!r}")
                elementos.append(item)
            else:
                dato, valor = item
                if not _ATOMO.match(dato) or isinstance(valor, bool) \
                        or not isinstance(valor, (int, float)):
                    raise ValueError(f"Dato numerico no valido: {item!r}")
                elementos.append(f"{dato}({valor})")
        return "[" + ",".join(elementos) + "]"
