"""
pruebas.py - Pruebas automaticas de MotoDiag (Entregables 2 y 3).

Ejecucion:
    python -m unittest pruebas -v
"""

import os
import re
import tempfile
import unittest

# Las pruebas usan un archivo de aprendizaje temporal para no tocar el real.
# Debe fijarse antes de crear cualquier MotorInferencia (tambien el de la interfaz).
_ARCHIVO_TEMPORAL = os.path.join(tempfile.mkdtemp(), "aprendido_pruebas.pl")
os.environ["MOTODIAG_APRENDIZAJE"] = _ARCHIVO_TEMPORAL

from motor_inferencia import MotorInferencia, RUTA_BASE



class MotorExperto(MotorInferencia):
    """Motor que actua como rol "experto" (puede ensenar). El motor normal es "usuario"."""
    rol_por_defecto = "experto"


CASO_1 = ["freno_esponjoso", "palanca_freno_larga", "frenada_larga",
          ("km_mantenimiento", 9000)]


class PruebasMotor(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.motor = MotorInferencia()

    # ---------- Caso 1: inferencia completa y "Por que?" ----------
    def test_caso1_diagnostico_principal(self):
        r = self.motor.diagnosticar_explicado(CASO_1)
        d = r["diagnosticos"][0]
        self.assertEqual(d["falla"], "aire_circuito_frenos")
        self.assertEqual(d["certeza"], "alto")
        self.assertEqual(d["gravedad"], "critica")
        self.assertTrue(d["recomendacion"].startswith("NO CONDUZCA"))
        self.assertEqual(len(r["alertas"]), 3)

    def test_caso1_traza_con_los_tres_niveles(self):
        d = self.motor.diagnosticar_explicado(CASO_1)["diagnosticos"][0]
        niveles = {x["nivel"] for x in d["reglas"]}
        self.assertEqual(niveles, {1, 2, 3})
        nombres = " ".join(x["regla"] for x in d["reglas"])
        for regla in ("R3 ", "R9 ", "R11 ", "R13 ", "R16 ", "R18 "):
            self.assertIn(regla, nombres)

    def test_caso1_hechos_comprobados(self):
        d = self.motor.diagnosticar_explicado(CASO_1)["diagnosticos"][0]
        hechos = {(h["tipo"], h["texto"]) for h in d["hechos"]}
        self.assertIn(("Condición principal", "freno esponjoso"), hechos)
        self.assertIn(("Síntoma de apoyo", "frenada larga"), hechos)
        self.assertIn(("Historial", "mantenimiento vencido"), hechos)

    def test_caso1_hipotesis_descartada_por_excluyente(self):
        descartadas = self.motor.diagnosticar_explicado(CASO_1)["descartadas"]
        pastillas = [x for x in descartadas
                     if x["hipotesis"] == "Pastillas de freno desgastadas"]
        self.assertEqual(len(pastillas), 1)
        self.assertIn("excluyente", pastillas[0]["motivo"])
        self.assertIn("freno esponjoso", pastillas[0]["motivo"])

    def test_traza_solo_incluye_reglas_que_se_cumplieron(self):
        # Sin km_mantenimiento la regla R3 no debe aparecer en la traza.
        obs = ["freno_esponjoso", "palanca_freno_larga", "frenada_larga"]
        d = self.motor.diagnosticar_explicado(obs)["diagnosticos"][0]
        self.assertFalse(any(x["regla"].startswith("R3 ") for x in d["reglas"]))

    # ---------- Caso 2: datos incompletos y "Que falta?" ----------
    def test_caso2_empate_y_sugerencia(self):
        r = self.motor.recomendar_evidencia(["pierde_potencia"])
        self.assertEqual(r["estado"], "empate")
        self.assertGreaterEqual(len(r["competencia"]), 2)
        self.assertEqual(r["sugerencias"][0]["dato"], "falla_en_ralenti")
        self.assertEqual(r["sugerencias"][0]["tipo"], "sintoma")
        pesos = [s["peso"] for s in r["sugerencias"]]
        self.assertEqual(pesos, sorted(pesos, reverse=True))

    def test_caso2_el_desempate_se_resuelve_paso_a_paso(self):
        obs = ["pierde_potencia", "falla_en_ralenti"]
        r = self.motor.recomendar_evidencia(obs)
        self.assertEqual(r["estado"], "empate")  # carburador vs inyector
        self.assertEqual(r["sugerencias"][0]["dato"], "alimentacion_carburador")
        obs.append("alimentacion_carburador")
        d = self.motor.diagnosticar_explicado(obs)["diagnosticos"][0]
        self.assertEqual(d["falla"], "carburador_sucio")
        nombres = [x["hipotesis"] for x in
                   self.motor.diagnosticar_explicado(obs)["descartadas"]]
        self.assertIn("Inyector tapado", nombres)

    def test_sin_datos_no_es_mensaje_generico(self):
        r = self.motor.recomendar_evidencia([])
        self.assertEqual(r["estado"], "sin_diagnostico")
        self.assertGreater(len(r["sugerencias"]), 0)
        self.assertEqual(self.motor.diagnosticar_explicado([])["diagnosticos"], [])

    def test_evidencia_suficiente_no_pide_mas_datos(self):
        obs = ["no_enciende", "cranquea_lento", "luces_debiles", "luz_bateria",
               "click_al_arrancar", ("antiguedad_bateria", 30)]
        r = self.motor.recomendar_evidencia(obs)
        self.assertEqual(r["estado"], "suficiente")
        self.assertEqual(r["sugerencias"], [])

    # ---------- Validacion de entradas ----------
    def test_python_rechaza_atomos_mal_formados(self):
        for malo in ("No_Enciende", "x); halt(", "x y"):
            with self.assertRaises(ValueError):
                self.motor.diagnosticar_explicado([malo])

    def test_prolog_valida_variables_libres_y_mayusculas(self):
        s = self.motor._consultar_una("validar_entrada([X], E)")
        self.assertEqual(s["E"], "variables_libres")
        s = self.motor._consultar_una("validar_entrada(['No_Enciende'], E)")
        self.assertEqual(s["E"], "mayusculas")
        s = self.motor._consultar_una("validar_entrada(no_es_lista, E)")
        self.assertEqual(s["E"], "no_es_lista")
        s = self.motor._consultar_una("validar_entrada([no_enciende], E)")
        self.assertEqual(s["E"], "ok")

    def test_elementos_desconocidos_se_reportan(self):
        r = self.motor.diagnosticar_explicado(["no_enciende", "inventado"])
        self.assertEqual(r["invalidos"], ["inventado"])

    # ---------- Reglas de arquitectura ----------
    def test_la_base_no_usa_read_1(self):
        with open(RUTA_BASE, encoding="utf8") as f:
            codigo = re.sub(r"%.*", "", f.read())
        self.assertIsNone(re.search(r"\bread\s*\(", codigo))
        self.assertIsNone(re.search(r"\bread_term\s*\(", codigo))


class PruebasInterfaz(unittest.TestCase):
    def test_flujo_completo_de_la_interfaz(self):
        from streamlit.testing.v1 import AppTest
        ruta = os.path.join(os.path.dirname(os.path.abspath(__file__)), "main.py")
        at = AppTest.from_file(ruta, default_timeout=60).run()
        self.assertFalse(at.exception)
        at.checkbox(key="s_pierde_potencia").check().run()
        [b for b in at.button if b.label == "Diagnosticar"][0].click().run()
        self.assertFalse(at.exception)
        self.assertEqual([t.label for t in at.tabs],
                         ["Diagnóstico", "¿Por qué?", "¿Qué falta?", "Modo Experto"])
        botones = [b for b in at.button if b.label == "Sí, lo observo"]
        self.assertTrue(botones)
        botones[0].click().run()          # confirma el sintoma sugerido por Prolog
        self.assertTrue(at.checkbox(key="s_falla_en_ralenti").value)


# ---------------------------------------------------------------------------
# Aprendizaje: el sistema agrega fallas y sintomas nuevos y los conserva
# ---------------------------------------------------------------------------
FALLA_NUEVA = dict(
    nombre="Rodamiento de dirección dañado",
    subsistema="frenos_transmision",
    gravedad="moderada",
    requisitos=["ruido_al_girar_el_manubrio", "vibracion_excesiva"],
    apoyos=["ruido_metalico"],
    excluyentes=["luces_normales"],
    agravantes=["mantenimiento_vencido"],
    alimentacion="cualquiera",
    recomendacion="Revise y cambie los rodamientos de la dirección.",
)
ID_FALLA = "rodamiento_de_direccion_danado"


class PruebasAprendizaje(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.motor = MotorExperto()

    def setUp(self):
        self.motor.reiniciar_aprendizaje()

    def tearDown(self):
        self.motor.reiniciar_aprendizaje()

    def _ensenar_todo(self):
        r = self.motor.aprender_sintoma("Ruido al girar el manubrio", "motor")
        self.assertEqual(r["estado"], "ok")
        self.assertEqual(r["elemento"], "ruido_al_girar_el_manubrio")
        r = self.motor.aprender_falla(**FALLA_NUEVA)
        self.assertEqual(r["estado"], "ok", r["mensaje"])
        self.assertEqual(r["falla"], ID_FALLA)

    def test_sintoma_nuevo_aparece_como_pregunta_en_su_categoria(self):
        self.motor.aprender_sintoma("Ruido al girar el manubrio", "motor")
        preguntas = self.motor.preguntas_guiadas()
        self.assertEqual(len(preguntas), 46)
        titulos = [t for t, _, _ in preguntas]
        # el grupo de la categoria sigue siendo uno solo (no se parte en dos)
        grupos = [t for i, t in enumerate(titulos) if i == 0 or titulos[i - 1] != t]
        self.assertEqual(len(grupos), len(set(grupos)))
        nueva = [x for x in preguntas if x[1] == "ruido_al_girar_el_manubrio"][0]
        self.assertEqual(nueva[0], "MOTOR Y LUBRICACIÓN")
        self.assertEqual(nueva[2], "¿Ruido al girar el manubrio?")

    def test_falla_nueva_se_diagnostica_y_se_explica(self):
        self._ensenar_todo()
        obs = ["ruido_al_girar_el_manubrio", "vibracion_excesiva", ("km_mantenimiento", 9000)]
        r = self.motor.diagnosticar_explicado(obs)
        d = r["diagnosticos"][0]
        self.assertEqual(d["falla"], ID_FALLA)
        self.assertEqual(d["nombre"], "Rodamiento de dirección dañado")
        self.assertEqual(d["gravedad"], "moderada")
        self.assertTrue(d["recomendacion"].startswith("Lleve la moto al taller"))
        # tambien tiene traza: reglas y hechos comprobados
        self.assertIn("R9", " ".join(x["regla"] for x in d["reglas"]))
        tipos = {h["tipo"] for h in d["hechos"]}
        self.assertIn("Condición principal", tipos)
        self.assertIn("Historial", tipos)

    def test_falla_nueva_participa_en_que_falta(self):
        self._ensenar_todo()
        r = self.motor.recomendar_evidencia(["ruido_al_girar_el_manubrio"])
        self.assertIn("Rodamiento de dirección dañado",
                      [c["hipotesis"] for c in r["competencia"]])
        self.assertEqual(r["sugerencias"][0]["dato"], "vibracion_excesiva")

    def test_falla_nueva_tambien_puede_ser_descartada_con_motivo(self):
        self._ensenar_todo()
        obs = ["ruido_al_girar_el_manubrio", "luces_normales"]
        r = self.motor.diagnosticar_explicado(obs)
        d = [x for x in r["descartadas"] if x["hipotesis"] == "Rodamiento de dirección dañado"]
        self.assertEqual(len(d), 1)
        self.assertIn("excluyente", d[0]["motivo"])

    def test_lo_aprendido_se_guarda_y_se_recarga_desde_el_archivo(self):
        self._ensenar_todo()
        with open(_ARCHIVO_TEMPORAL, encoding="utf8") as f:
            contenido = f.read()
        self.assertIn("registrar_falla(" + ID_FALLA, contenido)
        self.assertIn("registrar_sintoma(ruido_al_girar_el_manubrio", contenido)
        # "Reiniciar el programa": se vacia la memoria y se carga de nuevo el archivo
        self.motor._consultar_una(
            "olvidar_todo_en_memoria, usar_archivo_aprendizaje('"
            + _ARCHIVO_TEMPORAL.replace("\\", "/") + "')")
        self.assertEqual([f["falla"] for f in self.motor.fallas_aprendidas()], [ID_FALLA])
        self.assertEqual(len(self.motor.sintomas_aprendidos()), 1)
        d = self.motor.diagnosticar_explicado(
            ["ruido_al_girar_el_manubrio", "vibracion_excesiva"])["diagnosticos"][0]
        self.assertEqual(d["falla"], ID_FALLA)

    def test_olvidar_devuelve_el_sistema_al_conocimiento_del_experto(self):
        self._ensenar_todo()
        self.assertEqual(self.motor.olvidar_falla(ID_FALLA)["estado"], "ok")
        self.assertEqual(self.motor.olvidar_sintoma("ruido_al_girar_el_manubrio")["estado"], "ok")
        self.assertEqual(self.motor.fallas_aprendidas(), [])
        self.assertEqual(len(self.motor.preguntas_guiadas()), 45)
        r = self.motor.diagnosticar_explicado(["ruido_al_girar_el_manubrio"])
        self.assertEqual(r["diagnosticos"], [])
        self.assertEqual(r["invalidos"], ["ruido_al_girar_el_manubrio"])

    def test_no_se_puede_olvidar_lo_del_experto(self):
        self.assertEqual(self.motor.olvidar_falla("carburador_sucio")["estado"], "no_aprendida")
        self.assertEqual(self.motor.olvidar_sintoma("no_enciende")["estado"], "no_aprendida")
        r = self.motor.diagnosticar_explicado(
            ["falla_en_ralenti", "pierde_potencia", "alimentacion_carburador"])
        self.assertEqual(r["diagnosticos"][0]["falla"], "carburador_sucio")

    def test_un_sintoma_en_uso_no_se_puede_olvidar(self):
        self._ensenar_todo()
        self.assertEqual(self.motor.olvidar_sintoma("ruido_al_girar_el_manubrio")["estado"], "en_uso")
        self.motor.olvidar_falla(ID_FALLA)
        self.assertEqual(self.motor.olvidar_sintoma("ruido_al_girar_el_manubrio")["estado"], "ok")

    def test_validaciones_de_prolog(self):
        self._ensenar_todo()

        def estado(**cambios):
            datos = dict(FALLA_NUEVA, nombre="Falla de prueba")
            datos.update(cambios)
            return self.motor.aprender_falla(**datos)["estado"]

        self.assertEqual(estado(nombre=""), "nombre_vacio")
        self.assertEqual(estado(nombre="x" * 61), "nombre_largo")
        self.assertEqual(estado(nombre="Carburador sucio"), "ya_existe")
        self.assertEqual(estado(nombre="Rodamiento de dirección dañado"), "ya_existe")
        self.assertEqual(estado(subsistema="general"), "subsistema_invalido")
        self.assertEqual(estado(gravedad="grave"), "gravedad_invalida")
        self.assertEqual(estado(alimentacion="hibrida"), "alimentacion_invalida")
        self.assertEqual(estado(requisitos=["no_enciende"]), "pocos_requisitos")
        self.assertEqual(estado(requisitos=["no_enciende", "sin_chispa", "humo_azul",
                                            "humo_negro", "luz_aceite", "fuga_aceite"]),
                         "demasiados_requisitos")
        self.assertEqual(estado(requisitos=["no_enciende", "inventado"]), "sintoma_desconocido")
        self.assertEqual(estado(requisitos=["no_enciende", "alimentacion_carburador"]),
                         "sintoma_desconocido")
        self.assertEqual(estado(requisitos=["no_enciende", "no_enciende"]), "sintomas_repetidos")
        self.assertEqual(estado(requisitos=["no_enciende", "sin_chispa"],
                                excluyentes=["no_enciende"]), "sintomas_repetidos")
        self.assertEqual(estado(agravantes=["luz_aceite"]), "agravante_invalido")
        self.assertEqual(estado(recomendacion=""), "recomendacion_vacia")
        self.assertEqual(estado(recomendacion="r" * 301), "recomendacion_larga")
        # mismas condiciones y mismo tipo de moto que la falla ya aprendida
        self.assertEqual(estado(), "falla_equivalente")
        # ninguna de las fallas invalidas se agrego
        self.assertEqual(len(self.motor.fallas_aprendidas()), 1)

    def test_validaciones_de_sintomas(self):
        self.assertEqual(self.motor.aprender_sintoma("", "motor")["estado"], "texto_vacio")
        self.assertEqual(self.motor.aprender_sintoma("¿¿??", "motor")["estado"], "texto_vacio")
        self.assertEqual(self.motor.aprender_sintoma("x" * 81, "motor")["estado"], "texto_largo")
        self.assertEqual(self.motor.aprender_sintoma("algo", "dato_moto")["estado"], "categoria_invalida")
        self.assertEqual(self.motor.aprender_sintoma("Humo negro", "motor")["estado"], "ya_existe")
        self.assertEqual(self.motor.aprender_sintoma("Humo NEGRO!!", "motor")["estado"], "ya_existe")
        self.assertEqual(self.motor.sintomas_aprendidos(), [])

    def test_tildes_comillas_y_codigo_en_los_textos_no_rompen_ni_inyectan(self):
        r = self.motor.aprender_sintoma("Se oye un 'golpe' seco\\ al frenar", "frenos_transmision")
        self.assertEqual(r["estado"], "ok")
        self.assertEqual(r["elemento"], "se_oye_un_golpe_seco_al_frenar")
        r = self.motor.aprender_falla(**dict(
            FALLA_NUEVA, nombre="x'); halt(0); foo('",
            requisitos=["no_enciende", "sin_chispa"], apoyos=[], excluyentes=[],
            recomendacion="Ñandú 'raro' \\ \n con salto"))
        self.assertEqual(r["estado"], "ok")
        # el motor sigue vivo y el archivo guardado se puede recargar
        self.assertEqual(len(self.motor.fallas_aprendidas()), 1)
        self.motor._consultar_una("usar_archivo_aprendizaje('"
                                  + _ARCHIVO_TEMPORAL.replace("\\", "/") + "')")
        self.assertEqual(len(self.motor.fallas_aprendidas()), 1)

    def test_python_rechaza_identificadores_mal_formados(self):
        with self.assertRaises(ValueError):
            self.motor.olvidar_falla("x); halt(")
        with self.assertRaises(ValueError):
            self.motor.aprender_sintoma("algo", "No Valida")

    def test_la_traza_de_una_falla_aprendida_cumple_la_regla_sin_read(self):
        with open(RUTA_BASE, encoding="utf8") as f:
            codigo = re.sub(r"%.*", "", f.read())
        self.assertIsNone(re.search(r"\bread\s*\(", codigo))
        self.assertIsNone(re.search(r"\bread_term\s*\(", codigo))


def _app_como(rol):
    """Abre la interfaz con el rol indicado (la clave se prueba aparte)."""
    from streamlit.testing.v1 import AppTest
    ruta = os.path.join(os.path.dirname(os.path.abspath(__file__)), "main.py")
    at = AppTest.from_file(ruta, default_timeout=60)
    at.session_state["rol"] = rol
    at.run()
    return at


class PruebasInterfazAprendizaje(unittest.TestCase):
    def tearDown(self):
        MotorExperto().reiniciar_aprendizaje()

    def test_el_usuario_ensena_un_sintoma_y_una_falla_desde_la_interfaz(self):
        at = _app_como("experto")
        self.assertFalse(at.exception)

        # Paso 1: sintoma nuevo
        at.text_input(key="ens_sint_txt").input("Ruido al girar el manubrio")
        at.selectbox(key="ens_sint_cat").select("motor")
        [b for b in at.button if b.label == "Agregar síntoma"][0].click().run()
        self.assertFalse(at.exception)
        self.assertEqual(at.session_state["aprendizaje_msg"][0], True)
        self.assertTrue(at.checkbox(key="s_ruido_al_girar_el_manubrio").value)

        # Paso 2: falla nueva
        at.text_input(key="ens_nombre").input("Rodamiento de dirección dañado")
        at.selectbox(key="ens_sub").select("frenos_transmision")
        at.selectbox(key="ens_grav").select("moderada")
        at.multiselect(key="ens_req").set_value(
            ["ruido_al_girar_el_manubrio", "vibracion_excesiva"])
        at.text_area(key="ens_rec").input("Revise y cambie los rodamientos.")
        [b for b in at.button if b.label == "Enseñar al sistema"][0].click().run()
        self.assertFalse(at.exception)
        self.assertEqual(at.session_state["aprendizaje_msg"][0], True,
                         at.session_state["aprendizaje_msg"])

        # La interfaz ya diagnostica con lo aprendido
        at.checkbox(key="s_vibracion_excesiva").check()
        [b for b in at.button if b.label == "Diagnosticar"][0].click().run()
        self.assertFalse(at.exception)
        textos = " ".join(m.value for m in at.markdown)
        self.assertIn("Rodamiento de dirección dañado", textos)

    def test_la_interfaz_muestra_el_error_de_prolog(self):
        at = _app_como("experto")
        # sin elegir subsistema ni gravedad: Prolog explica que falta
        at.text_input(key="ens_nombre").input("Falla sin condiciones")
        [b for b in at.button if b.label == "Enseñar al sistema"][0].click().run()
        self.assertFalse(at.exception)
        self.assertEqual(at.session_state["aprendizaje_msg"][0], False)
        self.assertIn("subsistema", at.session_state["aprendizaje_msg"][1])
        # con subsistema y gravedad pero sin condiciones principales
        at.selectbox(key="ens_sub").select("frenos_transmision")
        at.selectbox(key="ens_grav").select("leve")
        [b for b in at.button if b.label == "Enseñar al sistema"][0].click().run()
        self.assertIn("al menos 2 condiciones", at.session_state["aprendizaje_msg"][1])


# ---------------------------------------------------------------------------
# Validaciones de coherencia: una moto no puede tener datos que se contradicen
# ---------------------------------------------------------------------------
class PruebasCoherencia(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.motor = MotorExperto()

    def setUp(self):
        self.motor.reiniciar_aprendizaje()

    def tearDown(self):
        self.motor.reiniciar_aprendizaje()

    def estado(self, observados):
        return self.motor.validar_observaciones(observados)["estado"]

    def test_carburador_e_inyeccion_a_la_vez_es_contradiccion(self):
        obs = ["alimentacion_carburador", "alimentacion_inyeccion", "no_enciende"]
        r = self.motor.validar_observaciones(obs)
        self.assertEqual(r["estado"], "incoherente")
        self.assertEqual(r["problemas"][0]["tipo"], "exclusivo")
        self.assertIn("alimentación", r["problemas"][0]["mensaje"])
        # una sola opcion si es valida
        self.assertEqual(self.estado(["alimentacion_carburador", "no_enciende"]), "ok")

    def test_todos_los_grupos_excluyentes_rechazan_dos_opciones(self):
        grupos = self.motor.grupos_exclusivos()
        self.assertGreaterEqual(len(grupos), 6)
        for _, _, miembros in grupos:
            self.assertGreaterEqual(len(miembros), 2)
            self.assertEqual(self.estado(miembros[:1] + ["no_enciende"]), "ok")
            for i, a in enumerate(miembros):
                for b in miembros[i + 1:]:
                    self.assertEqual(self.estado([a, b]), "incoherente", (a, b))

    def test_combinaciones_imposibles_entre_grupos_distintos(self):
        for a, b in (("no_enciende", "se_apaga_en_marcha"),
                     ("motor_cranquea_normal", "click_al_arrancar"),
                     ("temperatura_alta", "falla_en_frio")):
            r = self.motor.validar_observaciones([a, b])
            self.assertEqual(r["estado"], "incoherente", (a, b))
            self.assertEqual(r["problemas"][0]["tipo"], "incompatible")

    def test_datos_numericos_fuera_de_rango_o_repetidos(self):
        limites = self.motor.limites_numericos()
        self.assertEqual(limites["km_mantenimiento"], (0, 100000))
        self.assertEqual(limites["antiguedad_bateria"], (0, 120))
        r = self.motor.validar_observaciones(["no_enciende", ("km_mantenimiento", 500000)])
        self.assertEqual(r["problemas"][0]["tipo"], "fuera_de_rango")
        self.assertEqual(self.estado(["no_enciende", ("antiguedad_bateria", 121)]), "incoherente")
        self.assertEqual(self.estado(["no_enciende", ("antiguedad_bateria", 120)]), "ok")
        self.assertEqual(self.estado(["no_enciende", ("km_mantenimiento", -1)]), "incoherente")
        r = self.motor.validar_observaciones(
            ["no_enciende", ("km_mantenimiento", 10), ("km_mantenimiento", 20)])
        self.assertEqual(r["problemas"][0]["tipo"], "dato_repetido")

    def test_sin_sintomas_no_alcanza_para_diagnosticar(self):
        self.assertEqual(self.estado([]), "sin_sintomas")
        self.assertEqual(self.estado(["alimentacion_carburador", ("km_mantenimiento", 9000)]),
                         "sin_sintomas")
        self.assertEqual(self.estado(["no_enciende"]), "ok")

    def test_ningun_diagnostico_se_calcula_con_datos_contradictorios(self):
        obs = ["alimentacion_carburador", "alimentacion_inyeccion", "pierde_potencia",
               "falla_en_ralenti"]
        r = self.motor.diagnosticar_explicado(obs)
        self.assertEqual(r["diagnosticos"], [])
        self.assertEqual(r["descartadas"], [])
        self.assertTrue(r["alertas"])
        self.assertIn("No pueden darse a la vez", r["alertas"][0])
        e = self.motor.recomendar_evidencia(obs)
        self.assertEqual(e["estado"], "entrada_incoherente")
        self.assertEqual(e["sugerencias"], [])
        d = self.motor.diagnosticar(obs)             # tambien el motor del Entregable 1
        self.assertEqual(d["diagnosticos"], [])
        self.assertTrue(d["alertas"])
        d = self.motor.diagnosticar_explicado(["no_enciende", ("km_mantenimiento", 900000)])
        self.assertEqual(d["diagnosticos"], [])

    def test_los_diagnosticos_validos_siguen_igual(self):
        r = self.motor.diagnosticar_explicado(CASO_1)
        self.assertEqual(r["diagnosticos"][0]["falla"], "aire_circuito_frenos")

    def test_las_sugerencias_no_proponen_datos_que_contradicen_lo_marcado(self):
        obs = ["pierde_potencia", "falla_en_ralenti", "alimentacion_carburador"]
        datos = [s["dato"] for s in self.motor.recomendar_evidencia(obs)["sugerencias"]]
        self.assertNotIn("alimentacion_inyeccion", datos)
        obs = ["motor_cranquea_normal"]
        datos = [s["dato"] for s in self.motor.recomendar_evidencia(obs)["sugerencias"]]
        for malo in ("cranquea_lento", "motor_no_cranquea", "click_al_arrancar"):
            self.assertNotIn(malo, datos)

    def test_no_se_puede_ensenar_una_falla_con_condiciones_imposibles(self):
        r = self.motor.aprender_falla(
            "Luces raras", "electrico", "leve", ["luces_normales", "sin_luces"],
            recomendacion="Revise.")
        self.assertEqual(r["estado"], "sintomas_contradictorios")
        self.assertIn("No pueden darse a la vez", r["mensaje"])
        r = self.motor.aprender_falla(
            "Otra", "motor_lubricacion", "leve", ["no_enciende", "ruido_metalico"],
            apoyos=["se_apaga_en_marcha"], recomendacion="Revise.")
        self.assertEqual(r["estado"], "sintomas_contradictorios")
        self.assertEqual(self.motor.fallas_aprendidas(), [])

    def test_no_se_puede_ensenar_una_falla_equivalente_a_otra(self):
        r = self.motor.aprender_falla(
            "Mi carburador", "combustible", "leve", ["pierde_potencia", "falla_en_ralenti"],
            alimentacion="carburador", recomendacion="Limpie.")
        self.assertEqual(r["estado"], "falla_equivalente")
        self.assertIn("Carburador sucio", r["mensaje"])
        # para otro tipo de moto (o sin restriccion) ya no es la misma falla
        r = self.motor.aprender_falla(
            "Marcha irregular", "combustible", "leve", ["pierde_potencia", "falla_en_ralenti"],
            alimentacion="cualquiera", recomendacion="Revise.")
        self.assertEqual(r["estado"], "ok", r["mensaje"])


class PruebasInterfazCoherencia(unittest.TestCase):
    def _app(self, rol="usuario"):
        at = _app_como(rol)
        self.assertFalse(at.exception)
        return at

    def _diagnosticar(self, at):
        return [b for b in at.button if b.label == "Diagnosticar"][0]

    def test_solo_se_puede_elegir_carburador_o_inyeccion(self):
        at = self._app()
        at.checkbox(key="s_alimentacion_carburador").check().run()
        at.checkbox(key="s_alimentacion_inyeccion").check().run()
        self.assertTrue(at.checkbox(key="s_alimentacion_inyeccion").value)
        self.assertFalse(at.checkbox(key="s_alimentacion_carburador").value)
        self.assertFalse(at.error)

    def test_cada_grupo_excluyente_deja_marcada_una_sola_opcion(self):
        at = self._app()
        for _, _, miembros in MotorInferencia().grupos_exclusivos():
            for elemento in miembros:
                at.checkbox(key=f"s_{elemento}").check().run()
                marcadas = [e for e in miembros if at.checkbox(key=f"s_{e}").value]
                self.assertEqual(marcadas, [elemento])

    def test_diagnosticar_se_bloquea_con_contradicciones_o_sin_sintomas(self):
        at = self._app()
        self.assertTrue(self._diagnosticar(at).disabled)         # nada marcado
        at.checkbox(key="s_no_enciende").check().run()
        self.assertFalse(self._diagnosticar(at).disabled)
        at.checkbox(key="s_se_apaga_en_marcha").check().run()    # se contradicen
        self.assertTrue(self._diagnosticar(at).disabled)
        self.assertTrue(any("no puede apagarse" in e.value for e in at.error))
        at.checkbox(key="s_se_apaga_en_marcha").uncheck().run()
        self.assertFalse(self._diagnosticar(at).disabled)

    def test_los_numeros_tienen_rango_definido_por_prolog(self):
        at = self._app()
        km = at.number_input(key="n_km_mantenimiento")
        self.assertEqual(km.max, 100000)
        self.assertEqual(km.min, 0)
        self.assertEqual(at.number_input(key="n_antiguedad_bateria").max, 120)

    def test_la_pestana_ensenar_avisa_de_condiciones_imposibles(self):
        at = self._app("experto")
        at.multiselect(key="ens_req").set_value(["luces_normales", "sin_luces"]).run()
        self.assertTrue(any("se contradicen" in e.value for e in at.error))
        boton = [b for b in at.button if b.label == "Enseñar al sistema"][0]
        self.assertTrue(boton.disabled)


# ---------------------------------------------------------------------------
# Entregable 3 (a): lenguaje natural con DCG. Prolog analiza la oracion.
# ---------------------------------------------------------------------------
class PruebasLenguajeNatural(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.motor = MotorInferencia()

    def interpretar(self, texto):
        return self.motor.interpretar(texto)

    def test_la_oracion_se_convierte_en_hechos(self):
        r = self.interpretar("la moto no enciende y las luces se ven débiles")
        self.assertEqual(r["estado"], "ok")
        self.assertEqual(set(r["hechos"]), {"no_enciende", "luces_debiles"})

    def test_muestra_que_palabras_dieron_cada_hecho(self):
        r = self.interpretar("la moto no enciende y las luces se ven débiles")
        tipos = {x["nombre"]: x["tipo"] for x in r["interpretacion"]}
        self.assertEqual(tipos, {"no_enciende": "hecho", "luces_debiles": "hecho"})
        self.assertTrue(all(x["frase"] for x in r["interpretacion"]))

    def test_mayusculas_tildes_y_puntuacion_no_cambian_el_resultado(self):
        base = set(self.interpretar("la moto no enciende y las luces se ven débiles")["hechos"])
        for texto in ("¡LA MOTO NO ENCIENDE!!!  Y LAS LUCES SE VEN DÉBILES.",
                      "la moto no enciende; las luces se ven debiles",
                      "  la   moto no   enciende,\ny las luces se ven débiles  "):
            self.assertEqual(set(self.interpretar(texto)["hechos"]), base, texto)

    def test_historial_en_la_oracion(self):
        r = self.interpretar("Hace 9.000 km que no le hago mantenimiento")
        self.assertIn(("km_mantenimiento", 9000), r["datos"])
        r = self.interpretar("nueve mil kilómetros desde el último mantenimiento")
        self.assertIn(("km_mantenimiento", 9000), r["datos"])
        r = self.interpretar("la batería tiene 3 años")
        self.assertIn(("antiguedad_bateria", 36), r["datos"])
        r = self.interpretar("la batería tiene 18 meses")
        self.assertIn(("antiguedad_bateria", 18), r["datos"])

    def test_la_negacion_descarta_el_sintoma(self):
        r = self.interpretar("No sale humo negro, pero la moto pierde potencia")
        self.assertEqual(r["ausentes"], ["humo_negro"])
        self.assertEqual(r["hechos"], ["pierde_potencia"])
        self.assertNotIn("humo_negro", r["observados"])

    def test_el_texto_alimenta_el_diagnostico_igual_que_el_formulario(self):
        r = self.interpretar("El freno se siente esponjoso, la palanca recorre mucho y "
                             "tarda más en detenerse. Hace 9.000 km que no le hago mantenimiento")
        d = self.motor.diagnosticar_explicado(r["observados"])["diagnosticos"][0]
        self.assertEqual(d["falla"], "aire_circuito_frenos")
        self.assertEqual(d["certeza"], "alto")

    def test_una_frase_fuera_del_dominio_no_se_entiende(self):
        r = self.interpretar("el servidor presenta tráfico inusual en el puerto 22 y uso alto de cpu")
        self.assertEqual(r["estado"], "no_entendido")
        self.assertEqual(r["hechos"], [])
        self.assertIn("servidor", r["desconocidas"])

    def test_palabras_desconocidas_se_informan_sin_romper_lo_demas(self):
        r = self.interpretar("la moto no enciende y huele raro")
        self.assertEqual(r["estado"], "ok")
        self.assertEqual(r["hechos"], ["no_enciende"])
        self.assertIn("huele", r["desconocidas"])

    def test_texto_vacio_o_demasiado_largo(self):
        for vacio in ("", "   ", "!!! ... ???", "\n\t"):
            self.assertEqual(self.interpretar(vacio)["estado"], "texto_vacio", repr(vacio))
        self.assertEqual(self.interpretar("moto " * 200)["estado"], "texto_largo")

    def test_el_texto_no_puede_inyectar_codigo_prolog(self):
        for texto in ("'); halt. %", "x'), shell('echo hola'), ('", "\\\\ \\' \"", "[a|b] :- - ("):
            r = self.interpretar(texto)
            self.assertIn(r["estado"], ("no_entendido", "texto_vacio"), texto)
            self.assertEqual(r["hechos"], [])
        # el motor sigue funcionando despues
        self.assertEqual(self.interpretar("la moto no enciende")["hechos"], ["no_enciende"])

    def test_texto_contradictorio_lo_detecta_la_validacion_de_prolog(self):
        r = self.interpretar("mi moto usa carburador e inyección")
        self.assertEqual(set(r["hechos"]), {"alimentacion_carburador", "alimentacion_inyeccion"})
        self.assertEqual(self.motor.validar_observaciones(r["observados"])["estado"], "incoherente")
        self.assertEqual(self.motor.diagnosticar_explicado(r["observados"])["diagnosticos"], [])

    def test_el_resultado_siempre_cumple_la_misma_forma(self):
        for texto in ("", "hola", "la moto no enciende", "125 grados"):
            r = self.interpretar(texto)
            self.assertEqual(set(r), {"estado", "hechos", "ausentes", "datos", "lecturas",
                                      "interpretacion", "desconocidas", "observados"})


# ---------------------------------------------------------------------------
# Entregable 3 (c): lecturas continuas -> nivel (scikit-learn) -> hecho (Prolog)
# ---------------------------------------------------------------------------
class PruebasLecturas(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.motor = MotorInferencia()

    def test_el_nivel_lo_decide_el_clasificador(self):
        from preprocesamiento import Discretizador
        d = Discretizador()
        self.assertEqual(d.nivel("temperatura_motor", 40), "bajo")
        self.assertEqual(d.nivel("temperatura_motor", 90), "normal")
        self.assertEqual(d.nivel("temperatura_motor", 125), "alto")
        self.assertEqual(d.nivel("voltaje_carga", 12.2), "bajo")
        self.assertEqual(d.nivel("voltaje_carga", 14.1), "normal")
        self.assertEqual(d.nivel("voltaje_carga", 15.8), "alto")

    def test_los_umbrales_aprendidos_dividen_en_tres_niveles(self):
        from preprocesamiento import Discretizador
        d = Discretizador()
        for variable in d.variables():
            cortes = d.umbrales(variable)
            self.assertEqual(len(cortes), 2, variable)
            self.assertEqual(cortes, sorted(cortes))

    def test_el_nivel_nunca_baja_cuando_sube_la_lectura(self):
        from preprocesamiento import Discretizador
        orden = {"bajo": 0, "normal": 1, "alto": 2}
        d = Discretizador()
        for variable in d.variables():
            niveles = [orden[d.nivel(variable, x)] for x in range(0, 101)]
            self.assertEqual(niveles, sorted(niveles), variable)

    def test_lectura_alta_se_vuelve_el_sintoma_que_define_prolog(self):
        r = self.motor.evaluar_lectura("temperatura_motor", 125)
        self.assertEqual((r["nivel"], r["hecho"], r["estado"]), ("alto", "temperatura_alta", "ok"))
        r = self.motor.evaluar_lectura("voltaje_carga", 12.2)
        self.assertEqual((r["nivel"], r["hecho"]), ("bajo", "bateria_se_descarga_rodando"))

    def test_lectura_normal_no_genera_sintoma(self):
        r = self.motor.evaluar_lectura("temperatura_motor", 90)
        self.assertEqual((r["nivel"], r["hecho"]), ("normal", None))

    def test_prolog_rechaza_lecturas_imposibles_o_variables_desconocidas(self):
        r = self.motor.evaluar_lectura("temperatura_motor", 500)
        self.assertEqual(r["estado"], "fuera_de_rango")
        self.assertIsNone(r["hecho"])
        self.assertEqual(self.motor.evaluar_lectura("temperatura_motor", -5)["estado"], "fuera_de_rango")
        self.assertEqual(self.motor.evaluar_lectura("presion_aceite", 3)["estado"], "variable_desconocida")
        with self.assertRaises(ValueError):
            self.motor.evaluar_lectura("temperatura_motor", "125")

    def test_la_oracion_con_medidas_produce_hechos_discretos(self):
        r = self.motor.interpretar("el motor está a 125 grados y la carga marca 12,2 voltios")
        self.assertEqual({(x["variable"], x["nivel"]) for x in r["lecturas"]},
                         {("temperatura_motor", "alto"), ("voltaje_carga", "bajo")})
        self.assertEqual(set(r["hechos"]), {"temperatura_alta", "bateria_se_descarga_rodando"})

    def test_unidades_distintas(self):
        r = self.motor.interpretar("rinde 22 km por litro, la cadena tiene 45 mm de holgura "
                                   "y frena en 18 metros")
        niveles = {x["variable"]: x["nivel"] for x in r["lecturas"]}
        self.assertEqual(niveles, {"consumo_combustible": "bajo",
                                   "holgura_cadena": "alto", "distancia_frenado": "alto"})
        self.assertEqual(set(r["hechos"]), {"consumo_alto_gasolina", "cadena_holgura_visible",
                                            "frenada_larga"})

    def test_la_lectura_discreta_alimenta_el_diagnostico(self):
        r = self.motor.interpretar("el motor está a 125 grados")
        self.assertIn("temperatura_alta", r["observados"])
        self.assertTrue(self.motor.diagnosticar(r["observados"])["diagnosticos"])

    def test_el_discretizador_funciona_sin_scikit_learn(self):
        import preprocesamiento
        original = preprocesamiento.HAY_SKLEARN
        preprocesamiento.HAY_SKLEARN = False
        try:
            d = preprocesamiento.Discretizador()
            self.assertEqual(d.nivel("temperatura_motor", 125), "alto")
            self.assertEqual(d.nivel("temperatura_motor", 90), "normal")
            self.assertEqual(d.nivel("temperatura_motor", 40), "bajo")
        finally:
            preprocesamiento.HAY_SKLEARN = original


# ---------------------------------------------------------------------------
# Entregable 3 (b): roles. Solo el experto puede modificar el conocimiento.
# ---------------------------------------------------------------------------
class PruebasRoles(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.usuario = MotorInferencia()
        cls.experto = MotorExperto()

    def setUp(self):
        self.experto.reiniciar_aprendizaje()

    def tearDown(self):
        self.experto.reiniciar_aprendizaje()

    def test_el_motor_normal_es_usuario_y_no_puede_ensenar(self):
        self.assertEqual(MotorInferencia.rol_por_defecto, "usuario")
        self.assertEqual(self.usuario.aprender_falla(**FALLA_NUEVA)["estado"], "no_autorizado")
        self.assertEqual(self.usuario.aprender_sintoma("Ruido al girar el manubrio", "motor")["estado"],
                         "no_autorizado")
        self.assertEqual(self.usuario.aprender_frase("se desmaya", "se_apaga_en_marcha")["estado"],
                         "no_autorizado")
        # nada quedo guardado
        self.assertEqual(self.experto.fallas_aprendidas(), [])
        self.assertEqual(self.experto.sintomas_aprendidos(), [])
        self.assertEqual(self.experto.frases_aprendidas(), [])
        self.assertEqual(self.experto.contenido_aprendizaje().count("registrar_"), 0)

    def test_el_usuario_tampoco_puede_olvidar_ni_reiniciar(self):
        self.assertEqual(self.experto.aprender_sintoma("Ruido al girar el manubrio", "motor")["estado"], "ok")
        self.assertEqual(self.usuario.olvidar_sintoma("ruido_al_girar_el_manubrio")["estado"], "no_autorizado")
        self.assertEqual(self.usuario.olvidar_falla("lo_que_sea")["estado"], "no_autorizado")
        with self.assertRaises(PermissionError):
            self.usuario.reiniciar_aprendizaje()
        self.assertEqual(len(self.experto.sintomas_aprendidos()), 1)

    def test_el_experto_si_puede(self):
        r = self.usuario.aprender_frase("se desmaya", "se_apaga_en_marcha", rol="experto")
        self.assertEqual(r["estado"], "ok")
        self.assertEqual(len(self.experto.frases_aprendidas()), 1)

    def test_prolog_decide_los_permisos_de_cada_rol(self):
        for accion in ("diagnosticar", "describir_en_texto"):
            self.assertEqual(self.usuario.autorizar("usuario", accion)["estado"], "ok")
            self.assertEqual(self.usuario.autorizar("experto", accion)["estado"], "ok")
        for accion in ("ensenar_falla", "ensenar_sintoma", "ensenar_frase", "olvidar"):
            self.assertEqual(self.usuario.autorizar("usuario", accion)["estado"], "no_autorizado")
            self.assertEqual(self.usuario.autorizar("experto", accion)["estado"], "ok")

    def test_un_rol_inventado_o_una_accion_desconocida_se_deniegan(self):
        self.assertEqual(self.usuario.autorizar("administrador", "diagnosticar")["estado"], "no_autorizado")
        self.assertEqual(self.usuario.autorizar("experto", "borrar_todo")["estado"], "no_autorizado")
        r = self.usuario.aprender_frase("se desmaya", "se_apaga_en_marcha", rol="administrador")
        self.assertEqual(r["estado"], "no_autorizado")

    def test_python_rechaza_roles_mal_formados(self):
        with self.assertRaises(ValueError):
            self.usuario.autorizar("experto'); halt. %", "diagnosticar")


# ---------------------------------------------------------------------------
# Entregable 3 (b): aprendizaje en caliente de vocabulario + persistencia
# ---------------------------------------------------------------------------
class PruebasVocabulario(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.motor = MotorExperto()

    def setUp(self):
        self.motor.reiniciar_aprendizaje()

    def tearDown(self):
        self.motor.reiniciar_aprendizaje()

    def test_antes_de_ensenar_la_expresion_no_se_entiende(self):
        self.assertNotIn("se_apaga_en_marcha", self.motor.interpretar("se desmaya")["hechos"])

    def test_la_expresion_ensenada_se_entiende_de_inmediato(self):
        r = self.motor.aprender_frase("se desmaya", "se_apaga_en_marcha")
        self.assertEqual(r["estado"], "ok", r["mensaje"])
        r = self.motor.interpretar("la moto se desmaya y no tiene chispa")
        self.assertIn("se_apaga_en_marcha", r["hechos"])

    def test_la_expresion_se_guarda_en_el_archivo_y_sobrevive_al_reinicio(self):
        self.motor.aprender_frase("pierde fuerza en subida", "pierde_potencia")
        contenido = self.motor.contenido_aprendizaje()
        self.assertIn("registrar_frase(", contenido)
        self.assertIn("pierde_potencia", contenido)
        # reinicio simulado: memoria vacia y carga del archivo
        self.motor._consultar_una(
            "olvidar_todo_en_memoria, usar_archivo_aprendizaje('"
            + _ARCHIVO_TEMPORAL.replace("\\", "/") + "')")
        self.assertEqual([f["elemento"] for f in self.motor.frases_aprendidas()], ["pierde_potencia"])
        self.assertIn("pierde_potencia", self.motor.interpretar("pierde fuerza en subida")["hechos"])

    def test_la_expresion_ensenada_alimenta_el_diagnostico(self):
        self.motor.aprender_frase("no prende para nada", "no_enciende")
        r = self.motor.interpretar("no prende para nada, y las luces se ven débiles")
        self.assertEqual(self.motor.diagnosticar(r["observados"])["diagnosticos"][0]["falla"],
                         "Batería descargada")

    def test_olvidar_la_expresion(self):
        self.motor.aprender_frase("se desmaya", "se_apaga_en_marcha")
        self.assertEqual(self.motor.olvidar_frase("se desmaya")["estado"], "ok")
        self.assertEqual(self.motor.frases_aprendidas(), [])
        self.assertNotIn("registrar_frase", self.motor.contenido_aprendizaje())
        self.assertEqual(self.motor.olvidar_frase("se desmaya")["estado"], "no_aprendida")

    def test_no_se_puede_olvidar_el_vocabulario_del_experto(self):
        self.assertEqual(self.motor.olvidar_frase("la moto no enciende")["estado"], "no_aprendida")
        self.assertEqual(self.motor.interpretar("la moto no enciende")["hechos"], ["no_enciende"])

    def test_validaciones_de_prolog_sobre_la_expresion(self):
        casos = [
            ("", "pierde_potencia", "texto_vacio"),
            ("     ", "pierde_potencia", "texto_vacio"),
            ("   ???  ", "pierde_potencia", "frase_sin_palabras"),
            ("la el de", "pierde_potencia", "frase_sin_palabras"),
            ("aa bb cc dd ee ff gg", "pierde_potencia", "frase_larga"),
            ("x " * 40, "pierde_potencia", "texto_largo"),
            ("se desmaya", "sintoma_que_no_existe", "elemento_desconocido"),
            ("el motor no enciende", "no_enciende", "frase_repetida"),
            ("el motor no enciende", "pierde_potencia", "frase_ambigua"),
        ]
        for texto, elemento, esperado in casos:
            r = self.motor.aprender_frase(texto, elemento)
            self.assertEqual(r["estado"], esperado, (texto, r))
            self.assertTrue(r["mensaje"])
        self.assertEqual(self.motor.frases_aprendidas(), [])

    def test_repetir_la_misma_expresion_no_la_duplica(self):
        self.assertEqual(self.motor.aprender_frase("se desmaya", "se_apaga_en_marcha")["estado"], "ok")
        self.assertEqual(self.motor.aprender_frase("se desmaya", "se_apaga_en_marcha")["estado"],
                         "frase_repetida")
        self.assertEqual(len(self.motor.frases_aprendidas()), 1)

    def test_un_sintoma_nuevo_se_puede_describir_con_sus_propias_palabras(self):
        self.motor.aprender_sintoma("Ruido al girar el manubrio", "motor")
        r = self.motor.interpretar("hay ruido al girar el manubrio")
        self.assertEqual(r["hechos"], ["ruido_al_girar_el_manubrio"])

    def test_la_expresion_ensenada_puede_empezar_con_palabras_de_relleno(self):
        self.motor.aprender_frase("se muere en subida", "pierde_potencia")
        self.assertEqual(self.motor.interpretar("la moto se muere en subida")["hechos"],
                         ["pierde_potencia"])

    def test_olvidar_un_sintoma_olvida_sus_expresiones(self):
        self.motor.aprender_sintoma("Ruido al girar el manubrio", "motor")
        self.motor.aprender_frase("suena al doblar", "ruido_al_girar_el_manubrio")
        self.assertEqual(self.motor.olvidar_sintoma("ruido_al_girar_el_manubrio")["estado"], "ok")
        self.assertEqual(self.motor.frases_aprendidas(), [])
        self.assertNotIn("suena", self.motor.contenido_aprendizaje())


# ---------------------------------------------------------------------------
# Entregable 3: interfaz (texto libre, lecturas, roles, Modo Experto)
# ---------------------------------------------------------------------------
class PruebasInterfazE3(unittest.TestCase):
    def tearDown(self):
        MotorExperto().reiniciar_aprendizaje()

    def _boton(self, at, etiqueta):
        return [b for b in at.button if b.label == etiqueta][0]

    def _app_sin_sesion(self):
        from streamlit.testing.v1 import AppTest
        ruta = os.path.join(os.path.dirname(os.path.abspath(__file__)), "main.py")
        return AppTest.from_file(ruta, default_timeout=60).run()

    def test_describir_con_palabras_marca_la_lista_y_diagnostica(self):
        at = _app_como("usuario")
        at.text_area(key="texto_libre").set_value(
            "El freno se siente esponjoso, la palanca recorre mucho y tarda más en detenerse. "
            "Hace 9.000 km que no le hago mantenimiento")
        self._boton(at, "Interpretar y diagnosticar").click().run()
        self.assertFalse(at.exception)
        for e in ("freno_esponjoso", "palanca_freno_larga", "frenada_larga"):
            self.assertTrue(at.checkbox(key=f"s_{e}").value, e)
        self.assertEqual(at.number_input(key="n_km_mantenimiento").value, 9000)
        textos = " ".join(m.value for m in at.markdown)
        self.assertIn("Aire en el circuito de frenos", textos)
        self.assertIn("Lo que entendí", textos)

    def test_interpretar_sin_diagnosticar_solo_rellena(self):
        at = _app_como("usuario")
        at.text_area(key="texto_libre").set_value("la moto no enciende")
        self._boton(at, "Interpretar").click().run()
        self.assertTrue(at.checkbox(key="s_no_enciende").value)
        self.assertFalse(at.session_state["consultado"])

    def test_texto_no_entendido_avisa_y_no_toca_lo_marcado(self):
        at = _app_como("usuario")
        at.checkbox(key="s_no_enciende").check().run()
        at.text_area(key="texto_libre").set_value(
            "el servidor presenta tráfico inusual en el puerto 22 y uso alto de cpu")
        self._boton(at, "Interpretar").click().run()
        self.assertTrue(any("No reconocí" in w.value for w in at.warning))
        self.assertTrue(at.checkbox(key="s_no_enciende").value)

    def test_texto_contradictorio_bloquea_diagnosticar(self):
        at = _app_como("usuario")
        at.text_area(key="texto_libre").set_value("mi moto usa carburador e inyección")
        self._boton(at, "Interpretar").click().run()
        self.assertTrue(at.checkbox(key="s_alimentacion_carburador").value)
        self.assertTrue(at.checkbox(key="s_alimentacion_inyeccion").value)
        self.assertTrue(at.error)
        self.assertTrue(self._boton(at, "Diagnosticar").disabled)

    def test_lectura_del_taller_se_convierte_en_sintoma(self):
        at = _app_como("usuario")
        at.number_input(key="l_temperatura_motor").set_value(125.0).run()
        self.assertFalse(at.exception)
        self.assertIn("ALTO", " ".join(c.value for c in at.caption))
        self.assertTrue(any("Elementos marcados: 1" in c.value for c in at.caption))

    def test_limpiar_borra_texto_lecturas_y_casillas(self):
        at = _app_como("usuario")
        at.text_area(key="texto_libre").set_value("la moto no enciende, motor a 125 grados")
        self._boton(at, "Interpretar").click().run()
        self.assertTrue(at.checkbox(key="s_temperatura_alta").value)
        self._boton(at, "Limpiar").click().run()
        self.assertFalse(at.checkbox(key="s_no_enciende").value)
        self.assertFalse(at.checkbox(key="s_temperatura_alta").value)
        self.assertEqual(at.text_area(key="texto_libre").value, "")

    def test_el_usuario_ve_el_modo_experto_bloqueado(self):
        at = _app_como("usuario")
        self.assertTrue(any("solo para el rol" in w.value for w in at.warning))
        etiquetas = [b.label for b in at.button]
        for prohibido in ("Enseñar al sistema", "Agregar síntoma", "Enseñar expresión"):
            self.assertNotIn(prohibido, etiquetas)
        self.assertEqual(len(at.multiselect), 0)

    def test_la_clave_correcta_da_el_rol_de_experto(self):
        at = self._app_sin_sesion()
        at.sidebar.text_input(key="clave_ingresada").set_value("clave equivocada")
        at.sidebar.button[0].click().run()
        self.assertNotIn("rol", at.session_state)
        self.assertTrue(any("incorrecta" in e.value for e in at.sidebar.error))
        at.sidebar.text_input(key="clave_ingresada").set_value("experto2026")
        at.sidebar.button[0].click().run()
        self.assertEqual(at.session_state["rol"], "experto")
        self.assertIn("Enseñar al sistema", [b.label for b in at.button])

    def test_demasiados_intentos_fallidos_bloquean_el_acceso(self):
        at = self._app_sin_sesion()
        for _ in range(5):
            at.sidebar.text_input(key="clave_ingresada").set_value("mala")
            at.sidebar.button[0].click().run()
        at.sidebar.text_input(key="clave_ingresada").set_value("experto2026")
        at.sidebar.button[0].click().run()
        self.assertNotEqual(at.session_state["rol"] if "rol" in at.session_state else "usuario", "experto")
        self.assertTrue(any("Demasiados" in e.value for e in at.sidebar.error))

    def test_el_experto_ensena_una_expresion_y_el_texto_la_usa(self):
        at = _app_como("experto")
        at.text_input(key="ens_frase_txt").input("se desmaya")
        at.selectbox(key="ens_frase_sint").select("se_apaga_en_marcha")
        self._boton(at, "Enseñar expresión").click().run()
        self.assertFalse(at.exception)
        self.assertTrue(at.session_state["aprendizaje_msg"][0], at.session_state["aprendizaje_msg"])
        at.text_area(key="texto_libre").set_value("se desmaya")
        self._boton(at, "Interpretar").click().run()
        self.assertTrue(at.checkbox(key="s_se_apaga_en_marcha").value)

    def test_el_experto_ve_el_archivo_persistente(self):
        at = _app_como("experto")
        at.text_input(key="ens_frase_txt").input("se desmaya")
        at.selectbox(key="ens_frase_sint").select("se_apaga_en_marcha")
        self._boton(at, "Enseñar expresión").click().run()
        self.assertIn("registrar_frase", " ".join(c.value for c in at.code))


if __name__ == "__main__":
    unittest.main()
