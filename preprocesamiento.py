"""
preprocesamiento.py - Entregable 3 (opcional hibrido): de numeros a hechos discretos.

Las medidas continuas del taller (temperatura del motor, voltaje de carga,
holgura de la cadena...) no sirven directamente al motor de inferencia, que
razona con hechos simbolicos. Este modulo las convierte en un NIVEL discreto
("bajo", "normal" o "alto") usando un clasificador ligero de scikit-learn:
un arbol de decision de profundidad 2 entrenado con pocas lecturas de
referencia etiquetadas por el experto. El arbol aprende los umbrales.

Despues Prolog decide que hecho simbolico significa cada nivel
(lectura_nivel/3 en gramatica_dcg.pl): por ejemplo, temperatura_motor "alto"
equivale al sintoma temperatura_alta. Python no decide ningun diagnostico.

scikit-learn es opcional: si no esta instalado, se calculan los mismos umbrales
(el punto medio entre clases vecinas) con un metodo simple, asi el proyecto
funciona igual.
"""

try:                                  # clasificador ligero (opcional)
    from sklearn.tree import DecisionTreeClassifier
    HAY_SKLEARN = True
except ImportError:                   # pragma: no cover - depende del entorno
    DecisionTreeClassifier = None
    HAY_SKLEARN = False

# Lecturas de referencia etiquetadas por el experto: (valor, nivel).
REFERENCIAS = {
    # temperatura del motor en operacion, en grados Celsius
    "temperatura_motor": [(30, "bajo"), (50, "bajo"), (65, "bajo"),
                          (80, "normal"), (90, "normal"), (100, "normal"), (105, "normal"),
                          (115, "alto"), (125, "alto"), (140, "alto")],
    # voltaje en la bateria con el motor encendido (carga del regulador), en voltios
    "voltaje_carga": [(9, "bajo"), (11, "bajo"), (12, "bajo"), (12.8, "bajo"),
                      (13.4, "normal"), (13.8, "normal"), (14.2, "normal"), (14.6, "normal"),
                      (15.2, "alto"), (15.8, "alto"), (16.5, "alto")],
    # holgura de la cadena de transmision, en milimetros
    "holgura_cadena": [(5, "bajo"), (10, "bajo"), (12, "bajo"),
                       (20, "normal"), (25, "normal"), (30, "normal"), (35, "normal"),
                       (45, "alto"), (55, "alto"), (70, "alto")],
    # distancia de frenado desde 40 km/h, en metros
    "distancia_frenado": [(3, "bajo"), (5, "bajo"), (6, "bajo"),
                          (9, "normal"), (11, "normal"), (12, "normal"), (13, "normal"),
                          (17, "alto"), (20, "alto"), (25, "alto")],
    # rendimiento de combustible, en kilometros por litro (bajo = gasta mucho)
    "consumo_combustible": [(8, "bajo"), (12, "bajo"), (18, "bajo"), (22, "bajo"),
                            (30, "normal"), (35, "normal"), (40, "normal"), (45, "normal"),
                            (55, "alto"), (65, "alto")],
}

_ORDEN = {"bajo": 0, "normal": 1, "alto": 2}


def _umbrales_simples(tabla):
    """Punto medio entre el ultimo valor de una clase y el primero de la siguiente."""
    ordenada = sorted(tabla)
    return [(a[0] + b[0]) / 2 for a, b in zip(ordenada, ordenada[1:]) if a[1] != b[1]]


class Discretizador:
    """Convierte una lectura continua en un nivel (bajo / normal / alto)."""

    def __init__(self, referencias=None):
        self._referencias = dict(referencias or REFERENCIAS)
        self._modelos = {}
        self._umbrales = {}
        for variable, tabla in self._referencias.items():
            self._entrenar(variable, tabla)

    @property
    def usa_sklearn(self):
        return HAY_SKLEARN

    def _entrenar(self, variable, tabla):
        if HAY_SKLEARN:
            x = [[valor] for valor, _ in tabla]
            y = [nivel for _, nivel in tabla]
            modelo = DecisionTreeClassifier(max_depth=2, random_state=0).fit(x, y)
            self._modelos[variable] = modelo
            arbol = modelo.tree_
            self._umbrales[variable] = sorted(
                round(float(t), 2) for t, hijo in zip(arbol.threshold, arbol.children_left)
                if hijo != -1)
        else:                          # pragma: no cover
            self._umbrales[variable] = _umbrales_simples(tabla)

    def variables(self):
        return list(self._referencias)

    def umbrales(self, variable):
        """Cortes que aprendio el clasificador para esa variable."""
        return list(self._umbrales[variable])

    def nivel(self, variable, valor):
        """Nivel de la lectura: "bajo", "normal" o "alto"."""
        if variable not in self._referencias:
            raise KeyError(f"Variable sin referencias: {variable}")
        if HAY_SKLEARN:
            return str(self._modelos[variable].predict([[float(valor)]])[0])
        cortes = self._umbrales[variable]            # pragma: no cover
        niveles = sorted({n for _, n in self._referencias[variable]}, key=_ORDEN.get)
        posicion = sum(1 for corte in cortes if valor > corte)
        return niveles[min(posicion, len(niveles) - 1)]
