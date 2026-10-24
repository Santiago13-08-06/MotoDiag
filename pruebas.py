"""
pruebas.py - Pruebas automaticas de MotoDiag (Entregable 2).

Ejecucion:
    python -m unittest pruebas -v
"""

import os
import re
import unittest

from motor_inferencia import MotorInferencia, RUTA_BASE

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
        at.checkbox(key="s_pierde_potencia").check()
        at.button[0].click().run()
        self.assertFalse(at.exception)
        self.assertEqual([t.label for t in at.tabs],
                         ["Diagnóstico", "¿Por qué?", "¿Qué falta?"])
        botones = [b for b in at.button if b.label == "Sí, lo observo"]
        self.assertTrue(botones)
        botones[0].click().run()          # confirma el sintoma sugerido por Prolog
        self.assertTrue(at.checkbox(key="s_falla_en_ralenti").value)


if __name__ == "__main__":
    unittest.main()
