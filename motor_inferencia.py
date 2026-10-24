"""
motor_inferencia.py - Puente entre Python y SWI-Prolog para MotoDiag.

Este modulo SOLO se encarga de:
  1. cargar base_conocimiento.pl en el motor de SWI-Prolog (via PySwip),
  2. enviar la lista de observaciones como consulta,
  3. recibir las listas de resultados y devolverlas como estructuras de Python.

Toda la logica de inferencia, descarte, validacion de listas, calculo de
severidad, traza de auditoria y sugerencias de desempate reside en Prolog.

Nota tecnica: SWI-Prolog se inicializa en un unico hilo dedicado y todas las
consultas se ejecutan en ese hilo. Asi la interfaz (que puede correr cada
interaccion en un hilo distinto) nunca toca el motor desde un hilo ajeno.
"""

import atexit
import os
import re
from concurrent.futures import ThreadPoolExecutor

from pyswip import Prolog

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

    def __init__(self, ruta_base=RUTA_BASE):
        if not os.path.isfile(ruta_base):
            raise FileNotFoundError(
                f"No se encontro la base de conocimiento: {ruta_base}")
        self._prolog = None
        self._ejecutor = ThreadPoolExecutor(max_workers=1,
                                            thread_name_prefix="swi-prolog")
        # Prolog espera barras normales aun en Windows.
        self._ejecutor.submit(self._iniciar,
                              ruta_base.replace("\\", "/")).result()
        atexit.register(self._ejecutor.shutdown, wait=True)

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
    # Utilidades internas
    # ------------------------------------------------------------------
    def _iniciar(self, ruta):
        self._prolog = Prolog()
        self._prolog.consult(ruta)

    def _ejecutar(self, consulta):
        return list(self._prolog.query(consulta))

    def _consultar_una(self, consulta):
        soluciones = self._ejecutor.submit(self._ejecutar, consulta).result()
        if not soluciones:
            raise RuntimeError(f"Prolog no devolvio solucion para: {consulta}")
        return soluciones[0]

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
