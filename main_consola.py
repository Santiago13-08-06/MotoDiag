"""
main_consola.py - Interfaz de consola de MotoDiag (Entregable 1).

Python solo muestra las preguntas que entrega Prolog, recoge las respuestas,
las envia al motor y presenta los resultados. No contiene logica de inferencia.

Uso:
    python main_consola.py            # consulta interactiva guiada
    python main_consola.py --demo     # ejecuta tres casos de ejemplo sin preguntar
"""

import sys
import textwrap

from motor_inferencia import MotorInferencia

ANCHO = 78
LINEA = "=" * ANCHO
SUBLINEA = "-" * ANCHO

# Solo presentacion: texto con tilde para el nivel de gravedad que devuelve Prolog.
ETIQUETA_GRAVEDAD = {"leve": "LEVE", "moderada": "MODERADA", "critica": "CRÍTICA"}

# Casos de ejemplo para --demo (solo datos de entrada).
CASOS_DEMO = {
    "Caso 1 - La moto no enciende y las luces se ven débiles": [
        "alimentacion_carburador", "no_enciende", "cranquea_lento",
        "luces_debiles", "luz_bateria", ("antiguedad_bateria", 30),
    ],
    "Caso 2 - Freno esponjoso con recorrido largo en la palanca": [
        "alimentacion_inyeccion", "freno_esponjoso", "palanca_freno_larga",
        "frenada_larga", ("km_mantenimiento", 9000),
    ],
    "Caso 3 - Síntomas sin relación con ninguna falla conocida": [
        "alimentacion_carburador", "falla_en_frio",
    ],
}


def escribir(texto="", sangria=0):
    """Imprime texto ajustado al ancho de la consola."""
    prefijo = " " * sangria
    print(textwrap.fill(texto, width=ANCHO, initial_indent=prefijo,
                        subsequent_indent=prefijo) if texto else "")


def preguntar_si_no(texto):
    """Pregunta de si/no. Enter se toma como 'no'. Devuelve True, False o None (salir)."""
    while True:
        respuesta = input(f"  {texto} (s/n): ").strip().lower()
        if respuesta in ("s", "si", "sí"):
            return True
        if respuesta in ("n", "no", ""):
            return False
        if respuesta in ("salir", "q"):
            return None
        print("    Responda 's' o 'n' (o 'salir' para terminar).")


def preguntar_numero(texto):
    """Pregunta numerica opcional. Enter la omite."""
    while True:
        respuesta = input(f"  {texto} (Enter si no sabe): ").strip()
        if respuesta == "":
            return None
        try:
            valor = int(respuesta)
            if valor >= 0:
                return valor
        except ValueError:
            pass
        print("    Escriba un número entero positivo o presione Enter.")


def recoger_observaciones(motor):
    """Hace las preguntas guiadas que entrega Prolog y arma la lista de entrada."""
    observados = []
    grupo_actual = None
    for titulo, elemento, texto in motor.preguntas_guiadas():
        if titulo != grupo_actual:
            grupo_actual = titulo
            print(f"\n[{titulo}]")
        respuesta = preguntar_si_no(texto)
        if respuesta is None:
            return None
        if respuesta:
            observados.append(elemento)

    print("\n[HISTORIAL]")
    for dato, texto in motor.preguntas_numericas():
        valor = preguntar_numero(texto)
        if valor is not None:
            observados.append((dato, valor))
    return observados


def mostrar_diagnostico(d, titulo):
    print(SUBLINEA)
    print(titulo)
    print(SUBLINEA)
    print(f"  Falla probable : {d['falla']}")
    print(f"  Subsistema     : {d['subsistema']}")
    print(f"  Certeza        : {d['certeza'].upper()} ({d['puntaje']}/100)")
    gravedad = ETIQUETA_GRAVEDAD.get(d["gravedad"], d["gravedad"].upper())
    print(f"  Gravedad       : {gravedad} (prioridad {d['prioridad']}/100)")
    print("  Recomendación  :")
    escribir(d["recomendacion"], sangria=4)
    print("  Explicación    :")
    for linea in d["explicacion"]:
        escribir("- " + str(linea), sangria=4)


def mostrar_resultado(resultado):
    print("\n" + LINEA)
    print("RESULTADO DEL DIAGNÓSTICO".center(ANCHO))
    print(LINEA)

    if resultado["invalidos"]:
        escribir("Elementos no reconocidos (ignorados): "
                 + ", ".join(resultado["invalidos"]))
        print()

    if resultado["alertas"]:
        print("!! ALERTAS DE SEGURIDAD !!")
        for alerta in resultado["alertas"]:
            escribir("* " + alerta, sangria=2)
        print()

    diagnosticos = resultado["diagnosticos"]
    mostrar_diagnostico(diagnosticos[0], "DIAGNÓSTICO PRINCIPAL")
    for i, alterno in enumerate(diagnosticos[1:], start=1):
        print()
        mostrar_diagnostico(alterno, f"ALTERNATIVA {i}")

    print(LINEA)
    escribir("Este sistema orienta la decisión del usuario; no reemplaza una "
             "revisión presencial en un taller.")


def modo_demo(motor):
    for nombre, observados in CASOS_DEMO.items():
        print("\n" + "#" * ANCHO)
        print(nombre)
        print("#" * ANCHO)
        legibles = [o if isinstance(o, str) else f"{o[0]}={o[1]}" for o in observados]
        escribir("Entrada enviada a Prolog: " + ", ".join(legibles))
        mostrar_resultado(motor.diagnosticar(observados))


def modo_interactivo(motor):
    print(LINEA)
    print("MotoDiag - Sistema experto de diagnóstico de motocicletas".center(ANCHO))
    print(LINEA)
    escribir("Responda con 's' (sí) o 'n' (no). Escriba 'salir' para terminar.")

    while True:
        observados = recoger_observaciones(motor)
        if observados is None:
            break
        mostrar_resultado(motor.diagnosticar(observados))
        otra = input("\n¿Desea realizar otra consulta? (s/n): ").strip().lower()
        if otra not in ("s", "si", "sí"):
            break
    print("\nGracias por usar MotoDiag.")


def main():
    try:
        motor = MotorInferencia()
    except Exception as error:  # SWI-Prolog no instalado o archivo ausente
        print(f"No se pudo iniciar el motor de Prolog: {error}")
        sys.exit(1)

    if "--demo" in sys.argv[1:]:
        modo_demo(motor)
    else:
        modo_interactivo(motor)


if __name__ == "__main__":
    main()
