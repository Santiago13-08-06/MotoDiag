% =====================================================================
%  MotoDiag - Base de conocimiento (SWI-Prolog)
%  Sistema experto para el diagnostico de fallas mecanicas y electricas
%  en motocicletas monocilindricas de 4 tiempos (100 a 400 cc).
%
%  Fundacion Escuela Tecnologica de Neiva - FET
%  Ingenieria de Software - Sistemas Expertos
%
%  Uso desde consola de Prolog:
%     ?- [base_conocimiento].
%     ?- diagnosticar([no_enciende, cranquea_lento, luces_debiles,
%                      luz_bateria, alimentacion_carburador,
%                      antiguedad_bateria(30)], D, Inv, Alertas).
%
%  Toda la logica (validacion, descarte, listas, severidad) vive aqui.
%  Python solo envia la lista de observaciones y muestra los resultados.
% =====================================================================

:- encoding(utf8).

% ---------------------------------------------------------------------
%  Predicados dinamicos (Entregable 2, extension de aprendizaje).
%  El conocimiento del catalogo puede crecer en tiempo de ejecucion con
%  assertz/1: las fallas y sintomas nuevos que ensene el usuario se
%  agregan a estos mismos predicados y participan en la inferencia
%  exactamente igual que los del experto.
% ---------------------------------------------------------------------
:- dynamic falla_subsistema/2, nombre_falla/2, requisitos_falla/2,
           sintoma_apoyo/2, excluyente/2, agravante_de/2,
           restriccion_alimentacion/2, gravedad_base/2, recomendacion_base/2.
:- dynamic categoria_sintoma/2, nombre_elemento/2, pregunta_sintoma/3.
:- dynamic sintoma_aprendido/4, falla_aprendida/10, ruta_aprendizaje/1.
:- dynamic frase_aprendida/2.     % vocabulario de lenguaje natural (gramatica_dcg.pl)

% =====================================================================
%  SECCION 1. HECHOS - CATALOGO DE FALLAS
% =====================================================================

% falla_subsistema(Falla, Subsistema)
falla_subsistema(bateria_descargada,        arranque_encendido).
falla_subsistema(bujia_defectuosa,          arranque_encendido).
falla_subsistema(motor_arranque_defectuoso, arranque_encendido).
falla_subsistema(cdi_bobina_danados,        arranque_encendido).
falla_subsistema(filtro_obstruido,          combustible).
falla_subsistema(carburador_sucio,          combustible).
falla_subsistema(inyector_tapado,           combustible).
falla_subsistema(bomba_gasolina_defectuosa, combustible).
falla_subsistema(sobrecalentamiento,        motor_lubricacion).
falla_subsistema(bajo_nivel_aceite,         motor_lubricacion).
falla_subsistema(perdida_compresion,        motor_lubricacion).
falla_subsistema(consumo_excesivo_aceite,   motor_lubricacion).
falla_subsistema(pastillas_desgastadas,     frenos_transmision).
falla_subsistema(aire_circuito_frenos,      frenos_transmision).
falla_subsistema(cadena_floja,              frenos_transmision).
falla_subsistema(embrague_patinando,        frenos_transmision).
falla_subsistema(fusible_quemado,           electrico).
falla_subsistema(regulador_danado,          electrico).
falla_subsistema(circuito_luces_danado,     electrico).

% nombre_falla(Falla, NombreLegible)
nombre_falla(bateria_descargada,        'Batería descargada').
nombre_falla(bujia_defectuosa,          'Bujía defectuosa').
nombre_falla(motor_arranque_defectuoso, 'Motor de arranque defectuoso').
nombre_falla(cdi_bobina_danados,        'CDI o bobina dañados').
nombre_falla(filtro_obstruido,          'Filtro de combustible obstruido').
nombre_falla(carburador_sucio,          'Carburador sucio').
nombre_falla(inyector_tapado,           'Inyector tapado').
nombre_falla(bomba_gasolina_defectuosa, 'Bomba de gasolina defectuosa').
nombre_falla(sobrecalentamiento,        'Sobrecalentamiento del motor').
nombre_falla(bajo_nivel_aceite,         'Bajo nivel de aceite').
nombre_falla(perdida_compresion,        'Pérdida de compresión').
nombre_falla(consumo_excesivo_aceite,   'Consumo excesivo de aceite').
nombre_falla(pastillas_desgastadas,     'Pastillas de freno desgastadas').
nombre_falla(aire_circuito_frenos,      'Aire en el circuito de frenos').
nombre_falla(cadena_floja,              'Cadena floja o estirada').
nombre_falla(embrague_patinando,        'Embrague patinando').
nombre_falla(fusible_quemado,           'Fusible quemado').
nombre_falla(regulador_danado,          'Regulador o rectificador dañado').
nombre_falla(circuito_luces_danado,     'Circuito de luces dañado').

% nombre_subsistema(Subsistema, NombreLegible)
nombre_subsistema(arranque_encendido, 'Arranque y encendido').
nombre_subsistema(combustible,        'Alimentación de combustible').
nombre_subsistema(motor_lubricacion,  'Motor y lubricación').
nombre_subsistema(frenos_transmision, 'Frenos y transmisión').
nombre_subsistema(electrico,          'Sistema eléctrico').
nombre_subsistema(general,            'General').

% =====================================================================
%  SECCION 2. HECHOS - SINTOMAS, CONDICIONES Y DATOS DE LA MOTO
% =====================================================================

% categoria_sintoma(Elemento, Categoria)
categoria_sintoma(no_enciende,               encendido).
categoria_sintoma(motor_no_cranquea,         encendido).
categoria_sintoma(motor_cranquea_normal,     encendido).
categoria_sintoma(cranquea_lento,            encendido).
categoria_sintoma(click_al_arrancar,         encendido).
categoria_sintoma(sin_chispa,                encendido).
categoria_sintoma(chispa_debil,              encendido).
categoria_sintoma(arranque_dificil,          encendido).
categoria_sintoma(pierde_potencia,           combustible).
categoria_sintoma(se_apaga_en_marcha,        combustible).
categoria_sintoma(olor_gasolina,             combustible).
categoria_sintoma(consumo_alto_gasolina,     combustible).
categoria_sintoma(humo_negro,                combustible).
categoria_sintoma(temperatura_alta,          motor).
categoria_sintoma(ruido_metalico,            motor).
categoria_sintoma(vibracion_excesiva,        motor).
categoria_sintoma(humo_blanco,               motor).
categoria_sintoma(humo_azul,                 motor).
categoria_sintoma(aceite_bajo_varilla,       motor).
categoria_sintoma(fuga_aceite,               motor).
categoria_sintoma(luz_aceite,                motor).
categoria_sintoma(freno_esponjoso,           frenos_transmision).
categoria_sintoma(palanca_freno_larga,       frenos_transmision).
categoria_sintoma(freno_chirria,             frenos_transmision).
categoria_sintoma(frenada_larga,             frenos_transmision).
categoria_sintoma(cadena_holgura_visible,    frenos_transmision).
categoria_sintoma(cadena_ruido,              frenos_transmision).
categoria_sintoma(tirones_al_acelerar,       frenos_transmision).
categoria_sintoma(rpm_sube_sin_avance,       frenos_transmision).
categoria_sintoma(olor_quemado,              frenos_transmision).
categoria_sintoma(luces_debiles,             electrico).
categoria_sintoma(luces_normales,            electrico).
categoria_sintoma(sin_luces,                 electrico).
categoria_sintoma(luz_bateria,               electrico).
categoria_sintoma(fusible_visible_quemado,   electrico).
categoria_sintoma(falla_electrica_repentina, electrico).
categoria_sintoma(bateria_se_descarga_rodando, electrico).
categoria_sintoma(foco_quemado_frecuente,    electrico).
categoria_sintoma(falla_en_frio,             condicion).
categoria_sintoma(falla_en_caliente,         condicion).
categoria_sintoma(falla_en_aceleracion,      condicion).
categoria_sintoma(falla_en_ralenti,          condicion).
categoria_sintoma(despues_de_lluvia,         condicion).
categoria_sintoma(alimentacion_carburador,   dato_moto).
categoria_sintoma(alimentacion_inyeccion,    dato_moto).

% nombre_elemento(Elemento, TextoLegible): texto con tildes para las explicaciones
nombre_elemento(no_enciende,                 'no enciende').
nombre_elemento(motor_no_cranquea,           'el motor no gira').
nombre_elemento(motor_cranquea_normal,       'el motor gira con fuerza normal').
nombre_elemento(cranquea_lento,              'el motor gira lento').
nombre_elemento(click_al_arrancar,           'clic seco al arrancar').
nombre_elemento(sin_chispa,                  'sin chispa en la bujía').
nombre_elemento(chispa_debil,                'chispa débil').
nombre_elemento(arranque_dificil,            'arranque difícil').
nombre_elemento(pierde_potencia,             'pérdida de potencia').
nombre_elemento(se_apaga_en_marcha,          'se apaga en marcha').
nombre_elemento(olor_gasolina,               'olor a gasolina').
nombre_elemento(consumo_alto_gasolina,       'alto consumo de gasolina').
nombre_elemento(humo_negro,                  'humo negro').
nombre_elemento(temperatura_alta,            'temperatura alta').
nombre_elemento(ruido_metalico,              'ruido metálico').
nombre_elemento(vibracion_excesiva,          'vibración excesiva').
nombre_elemento(humo_blanco,                 'humo blanco').
nombre_elemento(humo_azul,                   'humo azul').
nombre_elemento(aceite_bajo_varilla,         'aceite por debajo del mínimo').
nombre_elemento(fuga_aceite,                 'fuga de aceite').
nombre_elemento(luz_aceite,                  'luz de aceite encendida').
nombre_elemento(freno_esponjoso,             'freno esponjoso').
nombre_elemento(palanca_freno_larga,         'recorrido largo del freno').
nombre_elemento(freno_chirria,               'freno que chirría').
nombre_elemento(frenada_larga,               'frenada larga').
nombre_elemento(cadena_holgura_visible,      'cadena con holgura visible').
nombre_elemento(cadena_ruido,                'ruido en la cadena').
nombre_elemento(tirones_al_acelerar,         'tirones al acelerar').
nombre_elemento(rpm_sube_sin_avance,         'las revoluciones suben sin avance').
nombre_elemento(olor_quemado,                'olor a quemado').
nombre_elemento(luces_debiles,               'luces débiles').
nombre_elemento(luces_normales,              'luces con intensidad normal').
nombre_elemento(sin_luces,                   'luces apagadas').
nombre_elemento(luz_bateria,                 'luz de batería encendida').
nombre_elemento(fusible_visible_quemado,     'fusible quemado a la vista').
nombre_elemento(falla_electrica_repentina,   'falla eléctrica repentina').
nombre_elemento(bateria_se_descarga_rodando, 'la batería se descarga en marcha').
nombre_elemento(foco_quemado_frecuente,      'focos que se queman con frecuencia').
nombre_elemento(falla_en_frio,               'falla en frío').
nombre_elemento(falla_en_caliente,           'falla en caliente').
nombre_elemento(falla_en_aceleracion,        'falla al acelerar').
nombre_elemento(falla_en_ralenti,            'falla en ralentí').
nombre_elemento(despues_de_lluvia,           'falla después de lluvia o lavado').
nombre_elemento(alimentacion_carburador,     'alimentación por carburador').
nombre_elemento(alimentacion_inyeccion,      'alimentación por inyección').
nombre_elemento(bateria_vieja,               'batería antigua').
nombre_elemento(mantenimiento_vencido,       'mantenimiento vencido').

% titulo_categoria(Categoria, TituloParaPreguntas)
titulo_categoria(dato_moto,          'DATOS DE LA MOTO').
titulo_categoria(encendido,          'ARRANQUE Y ENCENDIDO').
titulo_categoria(combustible,        'COMBUSTIBLE Y POTENCIA').
titulo_categoria(motor,              'MOTOR Y LUBRICACIÓN').
titulo_categoria(frenos_transmision, 'FRENOS Y TRANSMISIÓN').
titulo_categoria(electrico,          'SISTEMA ELÉCTRICO').
titulo_categoria(condicion,          'CONDICIONES EN QUE OCURRE LA FALLA').

% pregunta_sintoma(Orden, Elemento, TextoDeLaPregunta)
pregunta_sintoma( 1, alimentacion_carburador,     '¿Su moto usa carburador?').
pregunta_sintoma( 2, alimentacion_inyeccion,      '¿Su moto usa inyección electrónica?').
pregunta_sintoma( 3, no_enciende,                 '¿La moto no enciende?').
pregunta_sintoma( 4, motor_cranquea_normal,       '¿Al dar arranque el motor gira con fuerza normal?').
pregunta_sintoma( 5, cranquea_lento,              '¿Al dar arranque el motor gira muy lento?').
pregunta_sintoma( 6, motor_no_cranquea,           '¿Al dar arranque el motor no gira en absoluto?').
pregunta_sintoma( 7, click_al_arrancar,           '¿Se escucha un "clic" seco al presionar el arranque?').
pregunta_sintoma( 8, sin_chispa,                  '¿Al revisar la bujía no hay chispa?').
pregunta_sintoma( 9, chispa_debil,                '¿La chispa de la bujía es débil o amarillenta?').
pregunta_sintoma(10, arranque_dificil,            '¿Cuesta mucho arrancar la moto?').
pregunta_sintoma(11, pierde_potencia,             '¿La moto pierde potencia o no acelera bien?').
pregunta_sintoma(12, se_apaga_en_marcha,          '¿La moto se apaga mientras anda?').
pregunta_sintoma(13, olor_gasolina,               '¿Se percibe olor fuerte a gasolina?').
pregunta_sintoma(14, consumo_alto_gasolina,       '¿Notó que consume más gasolina de lo normal?').
pregunta_sintoma(15, humo_negro,                  '¿Sale humo negro por el escape?').
pregunta_sintoma(16, temperatura_alta,            '¿Se enciende el indicador de temperatura alta o el motor se siente muy caliente?').
pregunta_sintoma(17, ruido_metalico,              '¿Hay ruido metálico en el motor?').
pregunta_sintoma(18, vibracion_excesiva,          '¿Hay vibración excesiva?').
pregunta_sintoma(19, humo_blanco,                 '¿Sale humo blanco por el escape?').
pregunta_sintoma(20, humo_azul,                   '¿Sale humo azulado por el escape?').
pregunta_sintoma(21, luz_aceite,                  '¿Se enciende la luz de aceite en el tablero?').
pregunta_sintoma(22, aceite_bajo_varilla,         '¿El nivel de aceite está por debajo del mínimo en la varilla o visor?').
pregunta_sintoma(23, fuga_aceite,                 '¿Se ven goteos o manchas de aceite bajo la moto?').
pregunta_sintoma(24, freno_esponjoso,             '¿El freno se siente esponjoso o blando?').
pregunta_sintoma(25, palanca_freno_larga,         '¿La palanca o el pedal de freno recorre demasiado antes de frenar?').
pregunta_sintoma(26, freno_chirria,               '¿El freno chirría o rechina al frenar?').
pregunta_sintoma(27, frenada_larga,               '¿La moto tarda más de lo normal en detenerse?').
pregunta_sintoma(28, cadena_holgura_visible,      '¿La cadena se ve floja o con mucha holgura?').
pregunta_sintoma(29, cadena_ruido,                '¿La cadena hace ruido o golpetea?').
pregunta_sintoma(30, tirones_al_acelerar,         '¿Siente tirones al acelerar?').
pregunta_sintoma(31, rpm_sube_sin_avance,         '¿Las revoluciones suben pero la moto casi no avanza?').
pregunta_sintoma(32, olor_quemado,                '¿Se percibe olor a quemado (embrague o frenos)?').
pregunta_sintoma(33, luces_debiles,               '¿Las luces se ven débiles o amarillentas?').
pregunta_sintoma(34, luces_normales,              '¿Las luces funcionan con intensidad normal?').
pregunta_sintoma(35, sin_luces,                   '¿Las luces no encienden?').
pregunta_sintoma(36, luz_bateria,                 '¿Se enciende la luz de batería en el tablero?').
pregunta_sintoma(37, fusible_visible_quemado,     '¿Se ve algún fusible quemado en la caja de fusibles?').
pregunta_sintoma(38, falla_electrica_repentina,   '¿Los componentes eléctricos fallaron de forma repentina?').
pregunta_sintoma(39, bateria_se_descarga_rodando, '¿La batería se descarga aunque la moto está en marcha?').
pregunta_sintoma(40, foco_quemado_frecuente,      '¿Se queman bombillos o focos con frecuencia?').
pregunta_sintoma(41, falla_en_frio,               '¿La falla ocurre con el motor frío?').
pregunta_sintoma(42, falla_en_caliente,           '¿La falla ocurre con el motor caliente?').
pregunta_sintoma(43, falla_en_aceleracion,        '¿La falla aparece al acelerar?').
pregunta_sintoma(44, falla_en_ralenti,            '¿La falla aparece en ralentí (motor en baja)?').
pregunta_sintoma(45, despues_de_lluvia,           '¿La falla apareció después de lluvia o lavado?').

% pregunta_numerica(Dato, TextoDeLaPregunta)
pregunta_numerica(km_mantenimiento,
    '¿Cuántos kilómetros han pasado desde el último mantenimiento?').
pregunta_numerica(antiguedad_bateria,
    '¿Cuántos meses tiene la batería instalada?').

% umbral(Dato, Valor)
umbral(km_mantenimiento,  6000).
umbral(antiguedad_bateria,  24).

% =====================================================================
%  SECCION 3. HECHOS - CONOCIMIENTO DEL EXPERTO SOBRE CADA FALLA
% =====================================================================

% requisitos_falla(Falla, ListaDeCondicionesPrincipales)
requisitos_falla(bateria_descargada,        [cranquea_lento, luces_debiles]).
requisitos_falla(bujia_defectuosa,          [no_enciende, motor_cranquea_normal]).
requisitos_falla(motor_arranque_defectuoso, [no_enciende, click_al_arrancar]).
requisitos_falla(cdi_bobina_danados,        [no_enciende, motor_cranquea_normal, sin_chispa]).
requisitos_falla(filtro_obstruido,          [pierde_potencia, falla_en_aceleracion]).
requisitos_falla(carburador_sucio,          [falla_en_ralenti, pierde_potencia]).
requisitos_falla(inyector_tapado,           [falla_en_ralenti, pierde_potencia]).
requisitos_falla(bomba_gasolina_defectuosa, [se_apaga_en_marcha, falla_en_caliente]).
requisitos_falla(sobrecalentamiento,        [temperatura_alta, falla_en_caliente]).
requisitos_falla(bajo_nivel_aceite,         [luz_aceite, aceite_bajo_varilla]).
requisitos_falla(perdida_compresion,        [pierde_potencia, arranque_dificil]).
requisitos_falla(consumo_excesivo_aceite,   [humo_azul, aceite_bajo_varilla]).
requisitos_falla(pastillas_desgastadas,     [freno_chirria, frenada_larga]).
requisitos_falla(aire_circuito_frenos,      [freno_esponjoso, palanca_freno_larga]).
requisitos_falla(cadena_floja,              [cadena_holgura_visible, cadena_ruido]).
requisitos_falla(embrague_patinando,        [rpm_sube_sin_avance, pierde_potencia]).
requisitos_falla(fusible_quemado,           [fusible_visible_quemado, falla_electrica_repentina]).
requisitos_falla(regulador_danado,          [luz_bateria, bateria_se_descarga_rodando]).
requisitos_falla(circuito_luces_danado,     [sin_luces, falla_electrica_repentina]).

% sintoma_apoyo(Falla, Sintoma): refuerzan el diagnostico pero no son obligatorios
sintoma_apoyo(bateria_descargada,        luz_bateria).
sintoma_apoyo(bateria_descargada,        click_al_arrancar).
sintoma_apoyo(bateria_descargada,        no_enciende).
sintoma_apoyo(bujia_defectuosa,          chispa_debil).
sintoma_apoyo(bujia_defectuosa,          olor_gasolina).
sintoma_apoyo(bujia_defectuosa,          falla_en_aceleracion).
sintoma_apoyo(bujia_defectuosa,          arranque_dificil).
sintoma_apoyo(motor_arranque_defectuoso, motor_no_cranquea).
sintoma_apoyo(cdi_bobina_danados,        se_apaga_en_marcha).
sintoma_apoyo(cdi_bobina_danados,        falla_en_caliente).
sintoma_apoyo(cdi_bobina_danados,        despues_de_lluvia).
sintoma_apoyo(filtro_obstruido,          se_apaga_en_marcha).
sintoma_apoyo(filtro_obstruido,          arranque_dificil).
sintoma_apoyo(carburador_sucio,          humo_negro).
sintoma_apoyo(carburador_sucio,          consumo_alto_gasolina).
sintoma_apoyo(carburador_sucio,          olor_gasolina).
sintoma_apoyo(inyector_tapado,           consumo_alto_gasolina).
sintoma_apoyo(inyector_tapado,           falla_en_aceleracion).
sintoma_apoyo(inyector_tapado,           vibracion_excesiva).
sintoma_apoyo(bomba_gasolina_defectuosa, no_enciende).
sintoma_apoyo(bomba_gasolina_defectuosa, pierde_potencia).
sintoma_apoyo(sobrecalentamiento,        pierde_potencia).
sintoma_apoyo(sobrecalentamiento,        ruido_metalico).
sintoma_apoyo(sobrecalentamiento,        vibracion_excesiva).
sintoma_apoyo(bajo_nivel_aceite,         ruido_metalico).
sintoma_apoyo(bajo_nivel_aceite,         fuga_aceite).
sintoma_apoyo(bajo_nivel_aceite,         humo_azul).
sintoma_apoyo(bajo_nivel_aceite,         temperatura_alta).
sintoma_apoyo(perdida_compresion,        humo_azul).
sintoma_apoyo(perdida_compresion,        humo_blanco).
sintoma_apoyo(perdida_compresion,        ruido_metalico).
sintoma_apoyo(perdida_compresion,        vibracion_excesiva).
sintoma_apoyo(consumo_excesivo_aceite,   pierde_potencia).
sintoma_apoyo(consumo_excesivo_aceite,   vibracion_excesiva).
sintoma_apoyo(pastillas_desgastadas,     ruido_metalico).
sintoma_apoyo(pastillas_desgastadas,     vibracion_excesiva).
sintoma_apoyo(aire_circuito_frenos,      frenada_larga).
sintoma_apoyo(cadena_floja,              tirones_al_acelerar).
sintoma_apoyo(cadena_floja,              vibracion_excesiva).
sintoma_apoyo(embrague_patinando,        olor_quemado).
sintoma_apoyo(embrague_patinando,        falla_en_aceleracion).
sintoma_apoyo(fusible_quemado,           sin_luces).
sintoma_apoyo(fusible_quemado,           no_enciende).
sintoma_apoyo(regulador_danado,          luces_debiles).
sintoma_apoyo(regulador_danado,          foco_quemado_frecuente).
sintoma_apoyo(circuito_luces_danado,     despues_de_lluvia).
sintoma_apoyo(circuito_luces_danado,     foco_quemado_frecuente).

% excluyente(Falla, Sintoma): si el sintoma esta presente, la falla se descarta
excluyente(bateria_descargada,        luces_normales).
excluyente(bujia_defectuosa,          cranquea_lento).
excluyente(bujia_defectuosa,          sin_chispa).
excluyente(motor_arranque_defectuoso, luces_debiles).
excluyente(motor_arranque_defectuoso, motor_cranquea_normal).
excluyente(cdi_bobina_danados,        cranquea_lento).
excluyente(filtro_obstruido,          humo_negro).
excluyente(perdida_compresion,        cranquea_lento).
excluyente(consumo_excesivo_aceite,   fuga_aceite).
excluyente(pastillas_desgastadas,     freno_esponjoso).
excluyente(fusible_quemado,           luz_bateria).
excluyente(regulador_danado,          fusible_visible_quemado).
excluyente(circuito_luces_danado,     luces_debiles).
excluyente(circuito_luces_danado,     luces_normales).

% agravante_de(Falla, Condicion): condiciones del historial que aumentan la probabilidad
agravante_de(bateria_descargada,      bateria_vieja).
agravante_de(regulador_danado,        bateria_vieja).
agravante_de(bujia_defectuosa,        mantenimiento_vencido).
agravante_de(filtro_obstruido,        mantenimiento_vencido).
agravante_de(carburador_sucio,        mantenimiento_vencido).
agravante_de(inyector_tapado,         mantenimiento_vencido).
agravante_de(sobrecalentamiento,      mantenimiento_vencido).
agravante_de(bajo_nivel_aceite,       mantenimiento_vencido).
agravante_de(consumo_excesivo_aceite, mantenimiento_vencido).
agravante_de(pastillas_desgastadas,   mantenimiento_vencido).
agravante_de(aire_circuito_frenos,    mantenimiento_vencido).
agravante_de(cadena_floja,            mantenimiento_vencido).
agravante_de(embrague_patinando,      mantenimiento_vencido).

% restriccion_alimentacion(Falla, TipoDeAlimentacionQueLaHacePosible)
restriccion_alimentacion(carburador_sucio,          carburador).
restriccion_alimentacion(inyector_tapado,           inyeccion).
restriccion_alimentacion(bomba_gasolina_defectuosa, inyeccion).

% =====================================================================
%  SECCION 4. HECHOS - GRAVEDAD, RIESGOS Y RECOMENDACIONES
% =====================================================================

% gravedad_base(Falla, Nivel)   Nivel: leve | moderada | critica
gravedad_base(bateria_descargada,        leve).
gravedad_base(bujia_defectuosa,          leve).
gravedad_base(motor_arranque_defectuoso, moderada).
gravedad_base(cdi_bobina_danados,        moderada).
gravedad_base(filtro_obstruido,          leve).
gravedad_base(carburador_sucio,          leve).
gravedad_base(inyector_tapado,           moderada).
gravedad_base(bomba_gasolina_defectuosa, moderada).
gravedad_base(sobrecalentamiento,        critica).
gravedad_base(bajo_nivel_aceite,         critica).
gravedad_base(perdida_compresion,        moderada).
gravedad_base(consumo_excesivo_aceite,   moderada).
gravedad_base(pastillas_desgastadas,     moderada).
gravedad_base(aire_circuito_frenos,      critica).
gravedad_base(cadena_floja,              moderada).
gravedad_base(embrague_patinando,        moderada).
gravedad_base(fusible_quemado,           leve).
gravedad_base(regulador_danado,          moderada).
gravedad_base(circuito_luces_danado,     moderada).

% peso_gravedad(Nivel, PesoNumerico)
peso_gravedad(leve,     1).
peso_gravedad(moderada, 2).
peso_gravedad(critica,  3).

% nombre_gravedad(Nivel, TextoLegible)
nombre_gravedad(leve,     'leve').
nombre_gravedad(moderada, 'moderada').
nombre_gravedad(critica,  'crítica').

% riesgo_seguridad(Sintoma, SubsistemaQueAfecta)
riesgo_seguridad(freno_esponjoso,     frenos_transmision).
riesgo_seguridad(palanca_freno_larga, frenos_transmision).
riesgo_seguridad(frenada_larga,       frenos_transmision).
riesgo_seguridad(temperatura_alta,    motor_lubricacion).
riesgo_seguridad(luz_aceite,          motor_lubricacion).

% mensaje_riesgo(Sintoma, Mensaje)
mensaje_riesgo(freno_esponjoso,     'Freno esponjoso: el sistema de frenos puede fallar. No conduzca hasta revisarlo.').
mensaje_riesgo(palanca_freno_larga, 'Recorrido excesivo del freno: hay riesgo de perder capacidad de frenado.').
mensaje_riesgo(frenada_larga,       'Distancia de frenado mayor a la normal: revise los frenos antes de circular.').
mensaje_riesgo(temperatura_alta,    'Temperatura alta: apague el motor, puede fundirse si sigue en marcha.').
mensaje_riesgo(luz_aceite,          'Luz de aceite encendida: detenga el motor, la lubricación puede ser insuficiente.').

% recomendacion_base(Falla, AccionSugerida)
recomendacion_base(bateria_descargada,        'Cargue o reemplace la batería y revise el sistema de carga.').
recomendacion_base(bujia_defectuosa,          'Retire la bujía, límpiela o cámbiela y verifique la calibración.').
recomendacion_base(motor_arranque_defectuoso, 'Revise las conexiones del motor de arranque y el relé; si persiste, repárelo o cámbielo.').
recomendacion_base(cdi_bobina_danados,        'Pida que midan la bobina y la unidad CDI; es probable que deba cambiar alguna.').
recomendacion_base(filtro_obstruido,          'Reemplace el filtro de combustible y verifique el flujo de gasolina.').
recomendacion_base(carburador_sucio,          'Desarme, limpie y calibre el carburador (chicleres y aguja).').
recomendacion_base(inyector_tapado,           'Realice limpieza de inyectores y revise la calidad del combustible.').
recomendacion_base(bomba_gasolina_defectuosa, 'Verifique la presión de la bomba; puede requerir reemplazo.').
recomendacion_base(sobrecalentamiento,        'Deje enfriar el motor, revise aceite y ventilación (o refrigerante) antes de volver a encenderlo.').
recomendacion_base(bajo_nivel_aceite,         'Complete el aceite al nivel correcto, busque fugas y haga el cambio de aceite.').
recomendacion_base(perdida_compresion,        'Solicite una prueba de compresión; puede requerir revisión de anillos, válvulas o empaque.').
recomendacion_base(consumo_excesivo_aceite,   'Solicite revisión de anillos y retenedores de válvulas en el taller.').
recomendacion_base(pastillas_desgastadas,     'Reemplace las pastillas y revise el estado del disco.').
recomendacion_base(aire_circuito_frenos,      'Purgue el circuito de frenos y revise mangueras, retenes y nivel de líquido.').
recomendacion_base(cadena_floja,              'Ajuste la tensión de la cadena, lubríquela y revise el kit de arrastre.').
recomendacion_base(embrague_patinando,        'Revise el ajuste del cable y los discos del embrague; puede necesitar reemplazo.').
recomendacion_base(fusible_quemado,           'Cambie el fusible por uno del mismo amperaje y busque la causa del cortocircuito.').
recomendacion_base(regulador_danado,          'Mida el voltaje de carga; si es anormal, reemplace el regulador o rectificador.').
recomendacion_base(circuito_luces_danado,     'Revise conectores, bombillos y cableado de las luces.').

% =====================================================================
%  SECCION 5. REGLAS DE NIVEL 1 - VALIDACION PRELIMINAR
%  (clasifican datos de entrada y verifican condiciones elementales)
% =====================================================================

% R1. Un elemento de entrada es valido si esta en el catalogo o es un dato numerico conocido.
elemento_valido(Elemento) :-
    atom(Elemento),
    categoria_sintoma(Elemento, _),
    !.
elemento_valido(Dato) :-
    compound(Dato),
    Dato =.. [Nombre, Valor],
    limite_dato(Nombre, Minimo, Maximo),
    number(Valor),
    Valor >= Minimo,
    Valor =< Maximo.

% R2. Separa la lista de entrada en elementos validos e invalidos (recursion sobre lista).
observados_validos([], [], []).
observados_validos([E|Resto], [E|Validos], Invalidos) :-
    elemento_valido(E),
    !,
    observados_validos(Resto, Validos, Invalidos).
observados_validos([E|Resto], Validos, [E|Invalidos]) :-
    observados_validos(Resto, Validos, Invalidos).

% R3. El mantenimiento esta vencido si los km superan el umbral definido.
mantenimiento_vencido(Obs) :-
    memberchk(km_mantenimiento(Km), Obs),
    umbral(km_mantenimiento, Umbral),
    Km > Umbral.

% R4. La bateria es vieja si su antiguedad (meses) alcanza el umbral.
bateria_vieja(Obs) :-
    memberchk(antiguedad_bateria(Meses), Obs),
    umbral(antiguedad_bateria, Umbral),
    Meses >= Umbral.

% R5. Tipo de alimentacion de la moto (reglas excluyentes con corte y valor por defecto).
alimentacion_moto(Obs, carburador) :-
    memberchk(alimentacion_carburador, Obs),
    !.
alimentacion_moto(Obs, inyeccion) :-
    memberchk(alimentacion_inyeccion, Obs),
    !.
alimentacion_moto(_, desconocida).

% R6. Una falla es compatible si no tiene restriccion o si coincide con la alimentacion.
compatible_alimentacion(Falla, Obs) :-
    restriccion_alimentacion(Falla, Tipo),
    !,
    alimentacion_moto(Obs, Real),
    (   Real == desconocida
    ->  true
    ;   Real == Tipo
    ).
compatible_alimentacion(_, _).

% R7. Una condicion del historial esta activa (casos especiales con corte, caso general al final).
condicion_activa(mantenimiento_vencido, Obs) :-
    !,
    mantenimiento_vencido(Obs).
condicion_activa(bateria_vieja, Obs) :-
    !,
    bateria_vieja(Obs).
condicion_activa(Condicion, Obs) :-
    memberchk(Condicion, Obs).

% R8. Alertas de seguridad inmediatas segun lo observado.
alertas_seguridad(Obs, Alertas) :-
    findall(Mensaje,
            (   riesgo_seguridad(Sintoma, _),
                memberchk(Sintoma, Obs),
                mensaje_riesgo(Sintoma, Mensaje)
            ),
            Lista),
    sort(Lista, Alertas).

% =====================================================================
%  SECCION 6. PROCESAMIENTO DE LISTAS (utilidades de apoyo)
% =====================================================================

% subconjunto_lista(+Requisitos, +Observados): todos los requisitos estan observados.
subconjunto_lista([], _).
subconjunto_lista([R|Resto], Obs) :-
    memberchk(R, Obs),
    subconjunto_lista(Resto, Obs).

% contar_presentes(+Requisitos, +Observados, -Cantidad): cuantos requisitos se cumplen.
contar_presentes([], _, 0).
contar_presentes([R|Resto], Obs, Cantidad) :-
    contar_presentes(Resto, Obs, CantResto),
    (   memberchk(R, Obs)
    ->  Cantidad is CantResto + 1
    ;   Cantidad = CantResto
    ).

% elementos_faltantes(+Requisitos, +Observados, -Faltantes): filtra los que no se cumplen.
elementos_faltantes([], _, []).
elementos_faltantes([R|Resto], Obs, Faltantes) :-
    memberchk(R, Obs),
    !,
    elementos_faltantes(Resto, Obs, Faltantes).
elementos_faltantes([R|Resto], Obs, [R|Faltantes]) :-
    elementos_faltantes(Resto, Obs, Faltantes).

% primeros(+N, +Lista, -Prefijo): toma como maximo N elementos del inicio.
primeros(0, _, []) :- !.
primeros(_, [], []) :- !.
primeros(N, [X|Resto], [X|Prefijo]) :-
    N1 is N - 1,
    primeros(N1, Resto, Prefijo).

% etiqueta(+Elemento, -Frase): texto legible; si no hay nombre definido, usa el atomo
%                              cambiando los guiones bajos por espacios (valor por defecto).
etiqueta(Elemento, Frase) :-
    nombre_elemento(Elemento, Frase),
    !.
etiqueta(Elemento, Frase) :-
    atomic_list_concat(Partes, '_', Elemento),
    atomic_list_concat(Partes, ' ', Frase).

% legible(+Lista, -Texto): convierte una lista de elementos en texto separado por comas.
legible([], 'ninguno') :- !.
legible(Lista, Texto) :-
    findall(Frase,
            (   member(Elemento, Lista),
                etiqueta(Elemento, Frase)
            ),
            Frases),
    atomic_list_concat(Frases, ', ', Texto).

% =====================================================================
%  SECCION 7. REGLAS DE NIVEL 2 - INFERENCIA INTERMEDIA
%  (combinan reglas de nivel 1 con hechos para deducir estados intermedios)
% =====================================================================

% R9. Cuantas condiciones principales de la falla se cumplen.
requisitos_cumplidos(Falla, Obs, Cumplidos, Total) :-
    requisitos_falla(Falla, Requisitos),
    contar_presentes(Requisitos, Obs, Cumplidos),
    length(Requisitos, Total).

% R10. Sintomas de apoyo que estan presentes.
apoyos_presentes(Falla, Obs, Apoyos) :-
    findall(S,
            (   sintoma_apoyo(Falla, S),
                memberchk(S, Obs)
            ),
            Lista),
    sort(Lista, Apoyos).

% R11. Existe al menos un sintoma excluyente presente.
hay_excluyente(Falla, Obs) :-
    excluyente(Falla, Sintoma),
    memberchk(Sintoma, Obs).

% R12. Agravantes del historial que aplican a la falla.
agravantes_presentes(Falla, Obs, Agravantes) :-
    findall(C,
            (   agravante_de(Falla, C),
                condicion_activa(C, Obs)
            ),
            Lista),
    sort(Lista, Agravantes).

% R13. Una falla es candidata si es compatible, cumple al menos la mitad de sus
%      condiciones principales y no hay un sintoma que la excluya.
falla_candidata(Falla, Obs) :-
    falla_subsistema(Falla, _),
    compatible_alimentacion(Falla, Obs),
    requisitos_cumplidos(Falla, Obs, Cumplidos, Total),
    Cumplidos > 0,
    Cumplidos * 2 >= Total,
    \+ hay_excluyente(Falla, Obs).

% R14. Puntaje (0-100): 70 puntos por requisitos, hasta 20 por apoyos y 10 por agravantes.
puntaje(Falla, Obs, Puntaje) :-
    requisitos_cumplidos(Falla, Obs, Cumplidos, Total),
    apoyos_presentes(Falla, Obs, Apoyos),
    length(Apoyos, NApoyos),
    agravantes_presentes(Falla, Obs, Agravantes),
    length(Agravantes, NAgravantes),
    Base is (Cumplidos * 70) // Total,
    BonoApoyo is min(NApoyos * 10, 20),
    BonoAgravante is min(NAgravantes * 5, 10),
    Puntaje is min(Base + BonoApoyo + BonoAgravante, 100).

% R15. Nivel de certeza segun el puntaje (reglas excluyentes con corte y valor por defecto).
nivel_certeza(Puntaje, alto) :-
    Puntaje >= 85,
    !.
nivel_certeza(Puntaje, medio) :-
    Puntaje >= 60,
    !.
nivel_certeza(_, bajo).

% =====================================================================
%  SECCION 8. REGLAS DE NIVEL 3 - CONCLUSION FINAL
%  (integran las reglas intermedias para el diagnostico y la recomendacion)
% =====================================================================

% R16. Severidad efectiva: puede escalar segun los sintomas de riesgo o el historial.
severidad(Falla, _, critica) :-
    gravedad_base(Falla, critica),
    !.
severidad(Falla, Obs, critica) :-
    gravedad_base(Falla, moderada),
    falla_subsistema(Falla, Subsistema),
    riesgo_seguridad(Sintoma, Subsistema),
    memberchk(Sintoma, Obs),
    !.
severidad(Falla, Obs, moderada) :-
    gravedad_base(Falla, leve),
    agravantes_presentes(Falla, Obs, [_|_]),
    !.
severidad(Falla, _, Nivel) :-
    gravedad_base(Falla, Nivel).

% R17. Prioridad numerica (0-100): sube con la gravedad y con la certeza.
prioridad(Falla, Obs, Prioridad) :-
    severidad(Falla, Obs, Nivel),
    peso_gravedad(Nivel, Peso),
    puntaje(Falla, Obs, Puntaje),
    Prioridad is Peso * 30 + Puntaje // 10.

% R18. Recomendacion final segun la severidad (excluyentes, con valor por defecto).
recomendacion_final(Falla, critica, Texto) :-
    !,
    recomendacion_base(Falla, Base),
    format(atom(Texto), 'NO CONDUZCA la moto. ~w', [Base]).
recomendacion_final(Falla, moderada, Texto) :-
    !,
    recomendacion_base(Falla, Base),
    format(atom(Texto), 'Lleve la moto al taller pronto. ~w', [Base]).
recomendacion_final(Falla, _, Texto) :-
    recomendacion_base(Falla, Base),
    format(atom(Texto), 'Puede revisarlo usted mismo. ~w', [Base]).

% R19. Explicacion del razonamiento: lista de lineas legibles.
explicacion(Falla, Obs, Lineas) :-
    requisitos_falla(Falla, Requisitos),
    requisitos_cumplidos(Falla, Obs, Cumplidos, Total),
    elementos_faltantes(Requisitos, Obs, Faltantes),
    findall(R, (member(R, Requisitos), memberchk(R, Obs)), Presentes),
    apoyos_presentes(Falla, Obs, Apoyos),
    agravantes_presentes(Falla, Obs, Agravantes),
    findall(X, excluyente(Falla, X), Excluyentes),
    gravedad_base(Falla, Base),
    severidad(Falla, Obs, Nivel),
    legible(Presentes, TPresentes),
    legible(Apoyos, TApoyos),
    legible(Agravantes, TAgravantes),
    legible(Excluyentes, TExcluyentes),
    format(atom(L1),
           'Condiciones principales cumplidas: ~w de ~w (~w).',
           [Cumplidos, Total, TPresentes]),
    format(atom(L2), 'Síntomas de apoyo presentes: ~w.', [TApoyos]),
    format(atom(L3), 'Agravantes del historial: ~w.', [TAgravantes]),
    (   Excluyentes == []
    ->  L4 = 'Esta falla no tiene condiciones excluyentes definidas.'
    ;   format(atom(L4),
               'Se verificó que no estuviera presente ningún excluyente (~w).',
               [TExcluyentes])
    ),
    (   subconjunto_lista(Requisitos, Obs)
    ->  L5 = 'La regla se cumple completa: todas las condiciones principales están presentes.'
    ;   legible(Faltantes, TFaltantes),
        format(atom(L5), 'Regla parcial. Para confirmar, verifique: ~w.', [TFaltantes])
    ),
    nombre_gravedad(Nivel, TNivel),
    nombre_gravedad(Base, TBase),
    (   Nivel == Base
    ->  format(atom(L6), 'Gravedad ~w (la gravedad habitual de esta falla).', [TNivel])
    ;   format(atom(L6), 'Gravedad ~w (escalada desde ~w por los síntomas o el historial).',
               [TNivel, TBase])
    ),
    Lineas = [L1, L2, L3, L4, L5, L6].

% R20. Construye el diagnostico completo de una falla candidata, con su clave de orden.
%      Diagnostico = [Nombre, Subsistema, Certeza, Puntaje, Severidad, Prioridad,
%                     Recomendacion, Explicacion]
construir_diagnostico(Falla, Obs, Clave,
                      [Nombre, Subsistema, Certeza, Puntaje, Severidad,
                       Prioridad, Recomendacion, Explicacion]) :-
    nombre_falla(Falla, Nombre),
    falla_subsistema(Falla, Sub),
    nombre_subsistema(Sub, Subsistema),
    puntaje(Falla, Obs, Puntaje),
    nivel_certeza(Puntaje, Certeza),
    severidad(Falla, Obs, Severidad),
    prioridad(Falla, Obs, Prioridad),
    recomendacion_final(Falla, Severidad, Recomendacion),
    explicacion(Falla, Obs, Explicacion),
    peso_gravedad(Severidad, Peso),
    Clave is Puntaje * 10 + Peso.

% R21. Recolecta TODOS los diagnosticos posibles en una unica lista sin duplicados,
%      ordenada de mayor a menor probabilidad (y gravedad como desempate).
todos_los_diagnosticos(Obs, Diagnosticos) :-
    (   setof(Clave-Diag,
              F^( falla_candidata(F, Obs),
                  construir_diagnostico(F, Obs, Clave, Diag) ),
              Ascendente)
    ->  reverse(Ascendente, Descendente),
        valores_de_pares(Descendente, Diagnosticos)
    ;   Diagnosticos = []
    ).

valores_de_pares([], []).
valores_de_pares([_-V|Resto], [V|Valores]) :-
    valores_de_pares(Resto, Valores).

% Valor por defecto (hecho): diagnostico cuando ninguna falla alcanza el umbral.
diagnostico_por_defecto(['Sin diagnóstico concluyente', 'General', bajo, 0, moderada, 60,
                         'Los síntomas no coinciden con ninguna falla de la base de conocimiento. Lleve la moto al taller para una revisión presencial.',
                         ['No se cumplió al menos la mitad de las condiciones principales de ninguna regla.',
                          'Revise que haya respondido todas las preguntas con precisión.']]).

% R22. Seleccion del resultado: principal + hasta dos alternativas, o el valor por defecto.
seleccionar_resultado([], [Defecto]) :-
    !,
    diagnostico_por_defecto(Defecto).
seleccionar_resultado(Todos, Resultado) :-
    primeros(3, Todos, Resultado).

% R23. PREDICADO PRINCIPAL DE CONSULTA (el unico que Python invoca para diagnosticar).
%      diagnosticar(+Observados, -Resultados, -Invalidos, -Alertas)
%      Si la entrada se contradice (R51), no diagnostica: devuelve los motivos como alertas.
diagnosticar(Observados, Resultados, Invalidos, Alertas) :-
    validar_coherencia(Observados, Problemas),
    (   Problemas == []
    ->  observados_validos(Observados, Validos, Invalidos),
        todos_los_diagnosticos(Validos, Todos),
        seleccionar_resultado(Todos, Resultados),
        alertas_seguridad(Validos, Alertas)
    ;   Resultados = [],
        Invalidos = [],
        mensajes_de_problemas(Problemas, Alertas)
    ).

% =====================================================================
%  SECCION 9. CONSULTAS AUXILIARES PARA LA INTERFAZ
%  (Prolog entrega las preguntas; Python solo las muestra)
% =====================================================================

% preguntas_guiadas(-Lista): [[TituloGrupo, Elemento, Texto], ...] en orden de aplicacion.
%   Las preguntas se agrupan por categoria (la categoria que aparece primero va primero),
%   de modo que un sintoma aprendido queda junto a los de su misma categoria.
preguntas_guiadas(Lista) :-
    findall(Clave-[Titulo, Elemento, Texto],
            (   pregunta_sintoma(Orden, Elemento, Texto),
                categoria_sintoma(Elemento, Categoria),
                titulo_categoria(Categoria, Titulo),
                orden_categoria(Categoria, Rango),
                Clave = k(Rango, Orden)
            ),
            Pares),
    keysort(Pares, Ordenados),
    valores_de_pares(Ordenados, Lista).

% orden_categoria(+Categoria, -Rango): menor numero de pregunta de la categoria.
orden_categoria(Categoria, Rango) :-
    findall(O, (pregunta_sintoma(O, E, _), categoria_sintoma(E, Categoria)), Ordenes),
    min_list(Ordenes, Rango).

% preguntas_numericas(-Lista): [[Dato, Texto], ...]
preguntas_numericas(Lista) :-
    findall([Dato, Texto], pregunta_numerica(Dato, Texto), Lista).

% =====================================================================
%  ENTREGABLE 2 - MODULOS DE EXPLICABILIDAD ("¿POR QUE?") Y
%  RECOMENDACION ("¿QUE FALTA?")
%
%  Estos predicados NO leen del teclado (no se usa read/1): reciben la
%  lista de observaciones como argumento y devuelven listas de resultados,
%  de modo que la interfaz de Python nunca bloquea el hilo de ejecucion.
% =====================================================================

% =====================================================================
%  SECCION 10. HECHOS - TEXTOS Y ENLACES DEL MODULO DE RECOMENDACION
% =====================================================================

% mensaje_evidencia(EstadoDeLaEvidencia, Mensaje)
mensaje_evidencia(sin_diagnostico,
    'Los datos ingresados no alcanzan para emitir un diagnóstico. Responda las preguntas sugeridas para empezar a descartar hipótesis.').
mensaje_evidencia(empate,
    'Hay un empate entre varias hipótesis posibles. Confirmar alguno de los datos sugeridos permite desempatar.').
mensaje_evidencia(certeza_no_alta,
    'Existe una hipótesis principal, pero la evidencia aún no basta para una certeza alta. Los datos sugeridos ayudan a confirmarla.').
mensaje_evidencia(suficiente,
    'La evidencia ingresada es suficiente para un dictamen con certeza alta.').
mensaje_evidencia(entrada_invalida,
    'La entrada no es válida: debe ser una lista sin variables libres y con átomos en minúscula.').
mensaje_evidencia(entrada_incoherente,
    'Hay datos que se contradicen entre sí (por ejemplo, carburador e inyección a la vez). Corríjalos para obtener un dictamen.').

% dato_para_condicion(DatoNumerico, CondicionDelHistorialQueDeterminaAgravante)
dato_para_condicion(km_mantenimiento,  mantenimiento_vencido).
dato_para_condicion(antiguedad_bateria, bateria_vieja).

% tipo_hecho(Clave, TextoLegible): clasificacion de los hechos comprobados
tipo_hecho(principal, 'Condición principal').
tipo_hecho(apoyo,     'Síntoma de apoyo').
tipo_hecho(historial, 'Historial').
tipo_hecho(moto,      'Dato de la moto').

% =====================================================================
%  SECCION 11. REGLAS - VALIDACION SEGURA DE LA ENTRADA
% =====================================================================

% R24. Valida la entrada completa antes de usarla (capa simbolica defensiva).
%      Estado: ok | no_es_lista | variables_libres | mayusculas
validar_entrada(Entrada, no_es_lista) :-
    \+ is_list(Entrada),
    !.
validar_entrada(Entrada, variables_libres) :-
    \+ ground(Entrada),
    !.
validar_entrada(Entrada, mayusculas) :-
    member(Elemento, Entrada),
    atom(Elemento),
    downcase_atom(Elemento, Minuscula),
    Elemento \== Minuscula,
    !.
validar_entrada(_, ok).

% =====================================================================
%  SECCION 12. REGLAS - MODULO DE EXPLICABILIDAD ("¿POR QUE?")
% =====================================================================

% R25. Fallas candidatas ordenadas de mayor a menor probabilidad (setof sin duplicados).
fallas_candidatas_ordenadas(Obs, Fallas) :-
    (   setof(Clave-F,
              D^( falla_candidata(F, Obs),
                  construir_diagnostico(F, Obs, Clave, D) ),
              Ascendente)
    ->  reverse(Ascendente, Descendente),
        valores_de_pares(Descendente, Fallas)
    ;   Fallas = []
    ).

% R26. Motivo por el cual la severidad tiene el nivel calculado (espeja a R16).
motivo_severidad(Falla, _, 'gravedad habitual de la falla (crítica)') :-
    gravedad_base(Falla, critica),
    !.
motivo_severidad(Falla, Obs, Texto) :-
    gravedad_base(Falla, moderada),
    falla_subsistema(Falla, Subsistema),
    riesgo_seguridad(Sintoma, Subsistema),
    memberchk(Sintoma, Obs),
    !,
    etiqueta(Sintoma, Etiqueta),
    format(atom(Texto),
           'escalada de moderada a crítica por el síntoma de riesgo "~w"',
           [Etiqueta]).
motivo_severidad(Falla, Obs, Texto) :-
    gravedad_base(Falla, leve),
    agravantes_presentes(Falla, Obs, [Agravante|_]),
    !,
    etiqueta(Agravante, Etiqueta),
    format(atom(Texto),
           'escalada de leve a moderada por el agravante "~w"',
           [Etiqueta]).
motivo_severidad(Falla, _, Texto) :-
    gravedad_base(Falla, Nivel),
    nombre_gravedad(Nivel, TNivel),
    format(atom(Texto), 'gravedad habitual de la falla (~w)', [TNivel]).

% R27. Reglas disparadas: una entrada por cada regla cuyo cuerpo tuvo exito
%      para esta falla. Cada clausula de regla_disparada/3 reevalua la regla real,
%      por eso la lista es la traza exacta (no una descripcion fija).
%      regla(Nivel, Identificador, Texto)
regla_disparada(_, Obs, regla(1, 'R5 alimentacion_moto/2', Texto)) :-
    alimentacion_moto(Obs, Tipo),
    format(atom(Texto), 'La alimentación de la moto se interpreta como "~w".', [Tipo]).
regla_disparada(Falla, Obs, regla(1, 'R6 compatible_alimentacion/2', Texto)) :-
    compatible_alimentacion(Falla, Obs),
    (   restriccion_alimentacion(Falla, Tipo)
    ->  format(atom(Texto),
               'La falla solo es posible con alimentación por ~w y es compatible con la moto.',
               [Tipo])
    ;   Texto = 'La falla no tiene restricción de alimentación: es compatible.'
    ).
regla_disparada(Falla, Obs, regla(1, 'R3 mantenimiento_vencido/1', Texto)) :-
    agravante_de(Falla, mantenimiento_vencido),
    mantenimiento_vencido(Obs),
    memberchk(km_mantenimiento(Km), Obs),
    umbral(km_mantenimiento, Umbral),
    format(atom(Texto),
           'Han pasado ~w km desde el último mantenimiento (umbral: ~w km).',
           [Km, Umbral]).
regla_disparada(Falla, Obs, regla(1, 'R4 bateria_vieja/1', Texto)) :-
    agravante_de(Falla, bateria_vieja),
    bateria_vieja(Obs),
    memberchk(antiguedad_bateria(Meses), Obs),
    umbral(antiguedad_bateria, Umbral),
    format(atom(Texto),
           'La batería tiene ~w meses (umbral: ~w meses).',
           [Meses, Umbral]).
regla_disparada(Falla, Obs, regla(2, 'R9 requisitos_cumplidos/4', Texto)) :-
    requisitos_cumplidos(Falla, Obs, Cumplidos, Total),
    format(atom(Texto),
           'Se cumplen ~w de ~w condiciones principales de la falla.',
           [Cumplidos, Total]).
regla_disparada(Falla, Obs, regla(2, 'R10 apoyos_presentes/3', Texto)) :-
    apoyos_presentes(Falla, Obs, [Apoyo|Resto]),
    legible([Apoyo|Resto], TApoyos),
    format(atom(Texto), 'Síntomas de apoyo presentes: ~w.', [TApoyos]).
regla_disparada(Falla, Obs, regla(2, 'R11 hay_excluyente/2 (negación por fallo \\+)', Texto)) :-
    \+ hay_excluyente(Falla, Obs),
    findall(X, excluyente(Falla, X), Excluyentes),
    (   Excluyentes == []
    ->  Texto = 'La falla no tiene condiciones excluyentes definidas.'
    ;   legible(Excluyentes, TExcluyentes),
        format(atom(Texto),
               'Ninguna condición excluyente está presente (se verificó: ~w).',
               [TExcluyentes])
    ).
regla_disparada(Falla, Obs, regla(2, 'R12 agravantes_presentes/3', Texto)) :-
    agravantes_presentes(Falla, Obs, [Agravante|Resto]),
    legible([Agravante|Resto], TAgravantes),
    format(atom(Texto), 'Agravantes del historial activos: ~w.', [TAgravantes]).
regla_disparada(Falla, Obs, regla(2, 'R13 falla_candidata/2', Texto)) :-
    falla_candidata(Falla, Obs),
    Texto = 'La falla supera el umbral de candidatura (al menos la mitad de sus condiciones principales).'.
regla_disparada(Falla, Obs, regla(2, 'R14 puntaje/3', Texto)) :-
    puntaje(Falla, Obs, Puntaje),
    format(atom(Texto), 'Puntaje calculado: ~w de 100.', [Puntaje]).
regla_disparada(Falla, Obs, regla(2, 'R15 nivel_certeza/2', Texto)) :-
    puntaje(Falla, Obs, Puntaje),
    nivel_certeza(Puntaje, Certeza),
    format(atom(Texto), 'Nivel de certeza asignado: ~w.', [Certeza]).
regla_disparada(Falla, Obs, regla(3, 'R16 severidad/3', Texto)) :-
    severidad(Falla, Obs, Nivel),
    nombre_gravedad(Nivel, TNivel),
    motivo_severidad(Falla, Obs, Motivo),
    format(atom(Texto), 'Severidad ~w: ~w.', [TNivel, Motivo]).
regla_disparada(Falla, Obs, regla(3, 'R17 prioridad/3', Texto)) :-
    prioridad(Falla, Obs, Prioridad),
    format(atom(Texto), 'Prioridad numérica: ~w de 100.', [Prioridad]).
regla_disparada(Falla, Obs, regla(3, 'R18 recomendacion_final/3', Texto)) :-
    severidad(Falla, Obs, Nivel),
    recomendacion_final(Falla, Nivel, _),
    nombre_gravedad(Nivel, TNivel),
    format(atom(Texto),
           'Se emite la recomendación correspondiente a la gravedad ~w.',
           [TNivel]).

% reglas_disparadas(+Falla, +Obs, -Lista): Lista = [[Nivel, Id, Texto], ...]
reglas_disparadas(Falla, Obs, Lista) :-
    findall([Nivel, Id, Texto],
            regla_disparada(Falla, Obs, regla(Nivel, Id, Texto)),
            Lista).

% R28. Hechos comprobados como verdaderos para esta falla (evidencia unificada).
hecho_comprobado(Falla, Obs, Tipo, Texto) :-
    requisitos_falla(Falla, Requisitos),
    member(R, Requisitos),
    memberchk(R, Obs),
    tipo_hecho(principal, Tipo),
    etiqueta(R, Texto).
hecho_comprobado(Falla, Obs, Tipo, Texto) :-
    sintoma_apoyo(Falla, S),
    memberchk(S, Obs),
    tipo_hecho(apoyo, Tipo),
    etiqueta(S, Texto).
hecho_comprobado(Falla, Obs, Tipo, Texto) :-
    agravante_de(Falla, Condicion),
    condicion_activa(Condicion, Obs),
    tipo_hecho(historial, Tipo),
    etiqueta(Condicion, Texto).
hecho_comprobado(Falla, Obs, Tipo, Texto) :-
    restriccion_alimentacion(Falla, Alimentacion),
    alimentacion_moto(Obs, Alimentacion),
    tipo_hecho(moto, Tipo),
    format(atom(Texto), 'alimentación por ~w', [Alimentacion]).

% hechos_verdaderos(+Falla, +Obs, -Lista): Lista = [[TipoDeHecho, Texto], ...]
hechos_verdaderos(Falla, Obs, Lista) :-
    findall([Tipo, Texto], hecho_comprobado(Falla, Obs, Tipo, Texto), Lista).

% R29. Sintomas (principales o de apoyo) que la falla comparte con lo observado.
sintoma_de_falla(Falla, Sintoma) :-
    requisitos_falla(Falla, Requisitos),
    memberchk(Sintoma, Requisitos),
    !.
sintoma_de_falla(Falla, Sintoma) :-
    sintoma_apoyo(Falla, Sintoma).

sintomas_compartidos(Falla, Obs, Compartidos) :-
    findall(S,
            (   member(S, Obs),
                atom(S),
                sintoma_de_falla(Falla, S)
            ),
            Lista),
    sort(Lista, Compartidos).

% R30. Motivo del descarte (reglas excluyentes con corte y valor por defecto).
motivo_descarte(Falla, Obs, Motivo) :-
    findall(S, (excluyente(Falla, S), memberchk(S, Obs)), [X|Xs]),
    !,
    legible([X|Xs], TExcluyentes),
    format(atom(Motivo),
           'Presencia de condición excluyente (\\+): ~w.',
           [TExcluyentes]).
motivo_descarte(Falla, Obs, Motivo) :-
    \+ compatible_alimentacion(Falla, Obs),
    restriccion_alimentacion(Falla, Tipo),
    !,
    format(atom(Motivo),
           'Incompatible con el tipo de alimentación de la moto (solo aplica con ~w).',
           [Tipo]).
motivo_descarte(Falla, Obs, Motivo) :-
    requisitos_cumplidos(Falla, Obs, Cumplidos, Total),
    requisitos_falla(Falla, Requisitos),
    elementos_faltantes(Requisitos, Obs, Faltantes),
    legible(Faltantes, TFaltantes),
    format(atom(Motivo),
           'Evidencia crítica insuficiente: se cumplen ~w de ~w condiciones principales; falta: ~w.',
           [Cumplidos, Total, TFaltantes]).

% R31. Hipotesis alternativas descartadas: fallas que comparten sintomas con el caso
%      pero NO son candidatas (se usa negacion por fallo con Falla ya instanciada).
%      Lista = [[NombreFalla, SintomasCompartidos, Motivo], ...] (mas sintomas primero)
hipotesis_descartadas(Obs, Lista) :-
    findall(Clave-[Nombre, TCompartidos, Motivo],
            (   falla_subsistema(F, _),
                sintomas_compartidos(F, Obs, [C|Cs]),
                \+ falla_candidata(F, Obs),
                nombre_falla(F, Nombre),
                legible([C|Cs], TCompartidos),
                motivo_descarte(F, Obs, Motivo),
                length([C|Cs], N),
                Clave is -N
            ),
            Pares),
    keysort(Pares, Ordenados),
    valores_de_pares(Ordenados, Lista).

% R32. Item de resultado con traza completa (para la interfaz).
%      [Falla, Nombre, Subsistema, Certeza, Puntaje, Gravedad, Prioridad,
%       Recomendacion, ReglasDisparadas, HechosVerdaderos]
item_resultado(Falla, Obs,
               [Falla, Nombre, Subsistema, Certeza, Puntaje, Gravedad, Prioridad,
                Recomendacion, Reglas, Hechos]) :-
    construir_diagnostico(Falla, Obs, _,
                          [Nombre, Subsistema, Certeza, Puntaje, Gravedad,
                           Prioridad, Recomendacion, _]),
    reglas_disparadas(Falla, Obs, Reglas),
    hechos_verdaderos(Falla, Obs, Hechos).

% R33. PREDICADO PRINCIPAL DEL ENTREGABLE 2 (invocado por la interfaz).
%      diagnosticar_explicado(+Observados, -Resultados, -Descartadas, -Invalidos, -Alertas)
diagnosticar_explicado(Observados, Resultados, Descartadas, Invalidos, Alertas) :-
    validar_entrada(Observados, Estado),
    (   Estado == ok,
        validar_coherencia(Observados, [])
    ->  observados_validos(Observados, Validos, Invalidos),
        fallas_candidatas_ordenadas(Validos, Fallas),
        primeros(3, Fallas, Principales),
        findall(Item,
                (   member(F, Principales),
                    item_resultado(F, Validos, Item)
                ),
                Resultados),
        hipotesis_descartadas(Validos, Descartadas),
        alertas_seguridad(Validos, Alertas)
    ;   Estado == ok
    ->  % entrada con datos que se contradicen (R51): no se diagnostica
        validar_coherencia(Observados, Problemas),
        mensajes_de_problemas(Problemas, Alertas),
        Resultados = [],
        Descartadas = [],
        Invalidos = [incoherente]
    ;   Resultados = [],
        Descartadas = [],
        Alertas = [],
        Invalidos = [Estado]
    ).

% =====================================================================
%  SECCION 13. REGLAS - MODULO DE RECOMENDACION ("¿QUE FALTA?")
% =====================================================================

% R34. Hipotesis parcialmente activas: compatibles, sin excluyente y con al menos
%      una condicion principal cumplida. Devuelve pares Puntaje-Falla (mayor primero).
hipotesis_activas(Obs, Activas) :-
    findall(P-F,
            (   falla_subsistema(F, _),
                compatible_alimentacion(F, Obs),
                \+ hay_excluyente(F, Obs),
                requisitos_cumplidos(F, Obs, Cumplidos, _),
                Cumplidos > 0,
                puntaje(F, Obs, P)
            ),
            Pares),
    msort(Pares, Ascendente),
    reverse(Ascendente, Activas).

% R35. Si no hay hipotesis activas se consideran todas las compatibles (puntaje 0).
hipotesis_para_sugerir(Obs, Hipotesis) :-
    hipotesis_activas(Obs, Hipotesis),
    Hipotesis = [_|_],
    !.
hipotesis_para_sugerir(Obs, Hipotesis) :-
    findall(0-F,
            (   falla_subsistema(F, _),
                compatible_alimentacion(F, Obs)
            ),
            Hipotesis).

% R36. Estado de la evidencia (reglas excluyentes con corte y valor por defecto).
%      Estado: sin_diagnostico | empate | certeza_no_alta | suficiente
estado_evidencia(Obs, sin_diagnostico) :-
    fallas_candidatas_ordenadas(Obs, []),
    !.
estado_evidencia(Obs, empate) :-
    fallas_candidatas_ordenadas(Obs, [A, B|_]),
    puntaje(A, Obs, PA),
    puntaje(B, Obs, PB),
    PA - PB =< 10,
    !.
estado_evidencia(Obs, certeza_no_alta) :-
    fallas_candidatas_ordenadas(Obs, [A|_]),
    puntaje(A, Obs, P),
    nivel_certeza(P, Nivel),
    Nivel \== alto,
    !.
estado_evidencia(_, suficiente).

% R37. Contribucion de un dato aun no ingresado a cada hipotesis. El peso se
%      multiplica por (puntaje/10 + 1) para favorecer a las hipotesis mas fuertes.
%      contribucion(+Dato, +Puntaje-Falla, -Peso, -NombreFalla, -Efecto)
%      Efecto: confirma (refuerza la falla) | descarta (la excluiria)
contribucion(Dato, P-F, Peso, Nombre, confirma) :-
    Multiplicador is P // 10 + 1,
    nombre_falla(F, Nombre),
    (   requisitos_falla(F, Requisitos),
        memberchk(Dato, Requisitos)
    ->  Peso is 3 * Multiplicador
    ;   sintoma_apoyo(F, Dato)
    ->  Peso is Multiplicador
    ).
contribucion(Dato, P-F, Peso, Nombre, descarta) :-
    excluyente(F, Dato),
    Multiplicador is P // 10 + 1,
    nombre_falla(F, Nombre),
    Peso is 2 * Multiplicador.
contribucion(Dato, P-F, Peso, Nombre, confirma) :-
    atom_concat(alimentacion_, Tipo, Dato),
    restriccion_alimentacion(F, Tipo),
    Multiplicador is P // 10 + 1,
    nombre_falla(F, Nombre),
    Peso is 3 * Multiplicador.
contribucion(Dato, P-F, Peso, Nombre, descarta) :-
    atom_concat(alimentacion_, Tipo, Dato),
    restriccion_alimentacion(F, Otro),
    Otro \== Tipo,
    Multiplicador is P // 10 + 1,
    nombre_falla(F, Nombre),
    Peso is 2 * Multiplicador.
contribucion(Dato, P-F, Peso, Nombre, confirma) :-
    dato_para_condicion(Dato, Condicion),
    agravante_de(F, Condicion),
    Multiplicador is P // 10 + 1,
    nombre_falla(F, Nombre),
    Peso is Multiplicador.

% R38. Resume las contribuciones de un dato: peso total y fallas que confirma o descarta.
resumen_contribuciones(Dato, Hipotesis, Peso, Confirma, Descarta) :-
    findall(c(P, N, E),
            (   member(H, Hipotesis),
                contribucion(Dato, H, P, N, E)
            ),
            Contribuciones),
    Contribuciones = [_|_],
    findall(P, member(c(P, _, _), Contribuciones), Pesos),
    sum_list(Pesos, Peso),
    findall(N, member(c(_, N, confirma), Contribuciones), C0),
    findall(N, member(c(_, N, descarta), Contribuciones), D0),
    sort(C0, Confirma),
    sort(D0, Descarta).

% R39. Consulta de desempate: datos aun no ingresados, ordenados por peso.
%      Sugerencias = [[Tipo, Dato, Pregunta, Peso, Confirma, Descarta], ...]
%      Tipo: sintoma | dato_numerico
sugerencias_desempate(Obs, Sugerencias) :-
    hipotesis_para_sugerir(Obs, Hipotesis),
    findall(k(NegPeso, Orden)-[sintoma, S, Pregunta, Peso, Confirma, Descarta],
            (   pregunta_sintoma(Orden, S, Pregunta),
                \+ memberchk(S, Obs),
                \+ genera_conflicto(S, Obs),
                resumen_contribuciones(S, Hipotesis, Peso, Confirma, Descarta),
                NegPeso is -Peso
            ),
            Sintomas),
    findall(k(NegPeso, 1000)-[dato_numerico, Dato, Pregunta, Peso, Confirma, []],
            (   pregunta_numerica(Dato, Pregunta),
                \+ ( member(E, Obs), functor(E, Dato, 1) ),
                resumen_contribuciones(Dato, Hipotesis, Peso, Confirma, _),
                NegPeso is -Peso
            ),
            Numericos),
    append(Sintomas, Numericos, Todos),
    keysort(Todos, Ordenados),
    valores_de_pares(Ordenados, Lista),
    primeros(4, Lista, Sugerencias).

% R40. Hipotesis en competencia: [[Nombre, Puntaje, Certeza], ...] (hasta 4).
hipotesis_en_competencia(Obs, Competencia) :-
    hipotesis_activas(Obs, Activas),
    findall([Nombre, P, Certeza],
            (   member(P-F, Activas),
                nombre_falla(F, Nombre),
                nivel_certeza(P, Certeza)
            ),
            Lista),
    primeros(4, Lista, Competencia).

% R41. PREDICADO PRINCIPAL DE RECOMENDACION (invocado por la interfaz).
%      recomendar_evidencia(+Observados, -Estado, -Mensaje, -EnCompetencia, -Sugerencias)
recomendar_evidencia(Observados, Estado, Mensaje, Competencia, Sugerencias) :-
    validar_entrada(Observados, Validez),
    (   Validez == ok,
        \+ validar_coherencia(Observados, [_|_])
    ->  observados_validos(Observados, Validos, _),
        estado_evidencia(Validos, Estado),
        hipotesis_en_competencia(Validos, Competencia),
        (   Estado == suficiente
        ->  Sugerencias = []
        ;   sugerencias_desempate(Validos, Sugerencias)
        )
    ;   (   Validez == ok
        ->  Estado = entrada_incoherente
        ;   Estado = entrada_invalida
        ),
        Competencia = [],
        Sugerencias = []
    ),
    mensaje_evidencia(Estado, Mensaje).

% =====================================================================
%  ENTREGABLE 2 (EXTENSION) - APRENDIZAJE: EL SISTEMA AGREGA FALLAS Y
%  SINTOMAS NUEVOS A SU BASE DE CONOCIMIENTO
%
%  Cuando la moto presenta una falla que el sistema no conoce, el usuario
%  puede ensenarsela: Prolog valida los datos, los agrega con assertz/1 a
%  los mismos predicados del catalogo (ya declarados dinamicos al inicio)
%  y los guarda en el archivo conocimiento_aprendido.pl. Ese archivo se
%  carga cada vez que arranca el sistema, de modo que lo aprendido no se
%  pierde. Las fallas del experto (R1 a R41) no se pueden modificar ni
%  borrar: solo se puede olvidar lo que el usuario ensenio.
% =====================================================================

% =====================================================================
%  SECCION 12. HECHOS - TEXTOS Y LIMITES DEL APRENDIZAJE
% =====================================================================

% mensaje_aprendizaje(Estado, Mensaje)
mensaje_aprendizaje(ok,
    'Listo: el sistema aprendió lo nuevo y ya lo usa en sus diagnósticos.').
mensaje_aprendizaje(nombre_vacio,
    'Escriba un nombre para la falla.').
mensaje_aprendizaje(nombre_largo,
    'El nombre de la falla es demasiado largo (máximo 60 caracteres).').
mensaje_aprendizaje(ya_existe,
    'Ya existe una falla o un síntoma con ese nombre.').
mensaje_aprendizaje(subsistema_invalido,
    'Elija un subsistema de la lista.').
mensaje_aprendizaje(gravedad_invalida,
    'Elija una gravedad de la lista: leve, moderada o crítica.').
mensaje_aprendizaje(alimentacion_invalida,
    'Elija el tipo de moto al que aplica la falla: carburador, inyección o cualquiera.').
mensaje_aprendizaje(lista_invalida,
    'Las listas de síntomas no son válidas.').
mensaje_aprendizaje(pocos_requisitos,
    'Indique al menos 2 condiciones principales: son los síntomas que definen la falla.').
mensaje_aprendizaje(demasiados_requisitos,
    'Indique como máximo 5 condiciones principales.').
mensaje_aprendizaje(sintoma_desconocido,
    'Algún síntoma elegido no existe en el catálogo. Agréguelo primero como síntoma nuevo.').
mensaje_aprendizaje(sintomas_repetidos,
    'Un mismo síntoma no puede estar repetido ni figurar a la vez como condición principal, de apoyo o excluyente.').
mensaje_aprendizaje(sintomas_contradictorios,
    'Las condiciones principales y de apoyo se contradicen: no pueden presentarse a la vez en una misma moto.').
mensaje_aprendizaje(falla_equivalente,
    'Ya existe una falla con las mismas condiciones principales y para el mismo tipo de moto.').
mensaje_aprendizaje(agravante_invalido,
    'Los agravantes del historial solo pueden ser mantenimiento vencido o batería antigua.').
mensaje_aprendizaje(recomendacion_vacia,
    'Escriba la recomendación que debe recibir el usuario con esta falla.').
mensaje_aprendizaje(recomendacion_larga,
    'La recomendación es demasiado larga (máximo 300 caracteres).').
mensaje_aprendizaje(texto_vacio,
    'Escriba una descripción del síntoma.').
mensaje_aprendizaje(texto_largo,
    'La descripción del síntoma es demasiado larga (máximo 80 caracteres).').
mensaje_aprendizaje(categoria_invalida,
    'Elija una categoría de la lista.').
mensaje_aprendizaje(no_aprendida,
    'Solo se puede olvidar lo que el usuario ensenó; el conocimiento del experto no se borra.').
mensaje_aprendizaje(frase_sin_palabras,
    'La expresión no tiene palabras útiles: escriba al menos una palabra que describa el síntoma.').
mensaje_aprendizaje(frase_larga,
    'La expresión es demasiado larga: use entre 1 y 6 palabras.').
mensaje_aprendizaje(frase_repetida,
    'Esa expresión ya está registrada para ese síntoma.').
mensaje_aprendizaje(frase_ambigua,
    'Esa expresión ya existe y significa otro síntoma.').
mensaje_aprendizaje(elemento_desconocido,
    'El síntoma elegido no existe en el catálogo.').
mensaje_aprendizaje(no_autorizado,
    'Acción reservada al rol Experto: inicie sesión como experto para modificar el conocimiento.').
mensaje_aprendizaje(variable_desconocida,
    'La variable de la lectura no existe.').
mensaje_aprendizaje(lectura_invalida,
    'La lectura debe ser un número.').
mensaje_aprendizaje(en_uso,
    'No se puede olvidar este síntoma porque una falla aprendida todavía lo usa. Olvide primero esa falla.').

% sin_tilde(CaracterConTilde, CaracterSinTilde)
sin_tilde(á, a). sin_tilde(à, a). sin_tilde(â, a). sin_tilde(ä, a).
sin_tilde(é, e). sin_tilde(è, e). sin_tilde(ê, e). sin_tilde(ë, e).
sin_tilde(í, i). sin_tilde(ì, i). sin_tilde(î, i). sin_tilde(ï, i).
sin_tilde(ó, o). sin_tilde(ò, o). sin_tilde(ô, o). sin_tilde(ö, o).
sin_tilde(ú, u). sin_tilde(ù, u). sin_tilde(û, u). sin_tilde(ü, u).
sin_tilde(ñ, n).

% limite_texto(Campo, MaximoDeCaracteres)
limite_texto(nombre_falla,   60).
limite_texto(nombre_sintoma, 80).
limite_texto(recomendacion, 300).
limite_requisitos(2, 5).

% agravante_permitido(Condicion)
agravante_permitido(mantenimiento_vencido).
agravante_permitido(bateria_vieja).

% alimentacion_permitida(Valor)
alimentacion_permitida(cualquiera).
alimentacion_permitida(carburador).
alimentacion_permitida(inyeccion).

% =====================================================================
%  SECCION 13. REGLAS - NORMALIZACION DE TEXTO (procesamiento de listas)
% =====================================================================

% R42. texto_a_atomo(+Texto, -Atomo): convierte un texto libre en un identificador
%      valido (minusculas, sin tildes, guiones bajos). Falla si no queda nada util.
texto_a_atomo(Texto, Atomo) :-
    atom_chars(Texto, Caracteres),
    maplist(normalizar_caracter, Caracteres, Normalizados),
    colapsar_guiones(Normalizados, Colapsados),
    recortar_guiones(Colapsados, [Primero|Resto]),
    (   char_type(Primero, digit)
    ->  Cadena = [x, '_', Primero|Resto]
    ;   Cadena = [Primero|Resto]
    ),
    atom_chars(Completo, Cadena),
    (   atom_length(Completo, Largo), Largo > 40
    ->  sub_atom(Completo, 0, 40, _, Corto0),
        atom_chars(Corto0, CortoChars),
        recortar_guiones(CortoChars, CortoLimpio),
        atom_chars(Atomo, CortoLimpio)
    ;   Atomo = Completo
    ).

% normalizar_caracter(+Caracter, -Normalizado): letra o digito en minuscula, o '_'.
normalizar_caracter(Caracter, Normalizado) :-
    downcase_atom(Caracter, Minuscula),
    (   sin_tilde(Minuscula, Base)
    ->  Letra = Base
    ;   Letra = Minuscula
    ),
    (   atom_length(Letra, 1),
        (   Letra @>= a, Letra @=< z
        ;   Letra @>= '0', Letra @=< '9'
        )
    ->  Normalizado = Letra
    ;   Normalizado = '_'
    ).

% colapsar_guiones(+Lista, -Lista): varios '_' seguidos pasan a uno (recursion).
colapsar_guiones([], []).
colapsar_guiones(['_', '_'|Resto], Lista) :-
    !,
    colapsar_guiones(['_'|Resto], Lista).
colapsar_guiones([C|Resto], [C|Lista]) :-
    colapsar_guiones(Resto, Lista).

% recortar_guiones(+Lista, -Lista): quita los '_' del inicio y del final.
recortar_guiones(['_'|Resto], Recortada) :-
    !,
    recortar_guiones(Resto, Recortada).
recortar_guiones(Lista, Recortada) :-
    reverse(Lista, ['_'|RevResto]),
    !,
    reverse(RevResto, Resto),
    recortar_guiones(Resto, Recortada).
recortar_guiones(Lista, Lista).

% texto_util(+Texto, -Limpio): texto no vacio con los espacios normalizados.
texto_util(Texto, Limpio) :-
    atomic(Texto),
    normalize_space(atom(Limpio), Texto),
    Limpio \== ''.

% capitalizar(+Texto, -Texto): primera letra en mayuscula.
capitalizar(Texto, Capitalizado) :-
    sub_atom(Texto, 0, 1, _, Inicial),
    sub_atom(Texto, 1, _, 0, Resto),
    upcase_atom(Inicial, Mayuscula),
    atom_concat(Mayuscula, Resto, Capitalizado).

% sin_signos(+Texto, -Texto): quita los signos de interrogacion.
sin_signos(Texto, Limpio) :-
    atom_chars(Texto, Caracteres),
    exclude([C]>>memberchk(C, ['¿', '?']), Caracteres, Utiles),
    atom_chars(Sucio, Utiles),
    normalize_space(atom(Limpio), Sucio).

% sintoma_conocido(+Elemento): existe en el catalogo y se puede usar como sintoma de falla.
sintoma_conocido(Elemento) :-
    atom(Elemento),
    categoria_sintoma(Elemento, Categoria),
    Categoria \== dato_moto.

% =====================================================================
%  SECCION 14. REGLAS - VALIDACION Y REGISTRO DE SINTOMAS NUEVOS
% =====================================================================

% R43. validar_sintoma_nuevo(+Texto, +Categoria, -Estado, -Elemento, -Nombre, -Pregunta)
%      Reglas excluyentes con corte; la ultima es el caso "ok".
validar_sintoma_nuevo(Texto, _, texto_vacio, '', '', '') :-
    \+ texto_util(Texto, _),
    !.
validar_sintoma_nuevo(Texto, _, texto_largo, '', '', '') :-
    texto_util(Texto, Limpio),
    atom_length(Limpio, Largo),
    limite_texto(nombre_sintoma, Maximo),
    Largo > Maximo,
    !.
validar_sintoma_nuevo(_, Categoria, categoria_invalida, '', '', '') :-
    \+ ( titulo_categoria(Categoria, _), Categoria \== dato_moto ),
    !.
validar_sintoma_nuevo(Texto, _, texto_vacio, '', '', '') :-
    texto_util(Texto, Limpio),
    sin_signos(Limpio, Sencillo),
    \+ texto_a_atomo(Sencillo, _),
    !.
validar_sintoma_nuevo(Texto, _, ya_existe, Elemento, '', '') :-
    texto_util(Texto, Limpio),
    sin_signos(Limpio, Sencillo),
    texto_a_atomo(Sencillo, Elemento),
    (   categoria_sintoma(Elemento, _)
    ;   falla_subsistema(Elemento, _)
    ),
    !.
validar_sintoma_nuevo(Texto, _, ok, Elemento, Nombre, Pregunta) :-
    texto_util(Texto, Limpio),
    sin_signos(Limpio, Sencillo),
    texto_a_atomo(Sencillo, Elemento),
    downcase_atom(Sencillo, Nombre),
    capitalizar(Sencillo, Frase),
    format(atom(Pregunta), '¿~w?', [Frase]).

% R44. registrar_sintoma(+Elemento, +Categoria, +Nombre, +Pregunta): lo agrega al catalogo
%      con assertz/1 (no guarda en disco; tambien lo usa la carga del archivo).
registrar_sintoma(Elemento, _, _, _) :-
    categoria_sintoma(Elemento, _),
    !.
registrar_sintoma(Elemento, Categoria, Nombre, Pregunta) :-
    findall(O, pregunta_sintoma(O, _, _), Ordenes),
    max_list(Ordenes, Maximo),
    Nuevo is Maximo + 1,
    assertz(categoria_sintoma(Elemento, Categoria)),
    assertz(nombre_elemento(Elemento, Nombre)),
    assertz(pregunta_sintoma(Nuevo, Elemento, Pregunta)),
    assertz(sintoma_aprendido(Elemento, Categoria, Nombre, Pregunta)),
    registrar_frase_de_nombre(Elemento, Nombre).

% R45. PREDICADO DE APRENDIZAJE DE SINTOMAS (lo invoca la interfaz).
%      aprender_sintoma(+Texto, +Categoria, -Estado, -Mensaje, -Elemento)
aprender_sintoma(Texto, Categoria, Estado, Mensaje, Elemento) :-
    validar_sintoma_nuevo(Texto, Categoria, Estado, Elemento, Nombre, Pregunta),
    (   Estado == ok
    ->  registrar_sintoma(Elemento, Categoria, Nombre, Pregunta),
        guardar_aprendizaje
    ;   true
    ),
    mensaje_aprendizaje(Estado, Mensaje).

% =====================================================================
%  SECCION 15. REGLAS - VALIDACION Y REGISTRO DE FALLAS NUEVAS
% =====================================================================

% R46. validar_falla(+Nombre, +Subsistema, +Gravedad, +Requisitos, +Apoyos, +Excluyentes,
%                    +Agravantes, +Alimentacion, +Recomendacion, -Estado, -Falla, -NombreLimpio, -RecLimpia)
%      Cada regla detecta un problema y corta; la ultima es el caso "ok".
validar_falla(Nombre, _, _, _, _, _, _, _, _, nombre_vacio, '', '', '') :-
    \+ texto_util(Nombre, _),
    !.
validar_falla(Nombre, _, _, _, _, _, _, _, _, nombre_largo, '', '', '') :-
    texto_util(Nombre, Limpio),
    atom_length(Limpio, Largo),
    limite_texto(nombre_falla, Maximo),
    Largo > Maximo,
    !.
validar_falla(Nombre, _, _, _, _, _, _, _, _, nombre_vacio, '', '', '') :-
    texto_util(Nombre, Limpio),
    \+ texto_a_atomo(Limpio, _),
    !.
validar_falla(Nombre, _, _, _, _, _, _, _, _, ya_existe, Falla, '', '') :-
    texto_util(Nombre, Limpio),
    texto_a_atomo(Limpio, Falla),
    (   falla_subsistema(Falla, _)
    ;   categoria_sintoma(Falla, _)
    ),
    !.
validar_falla(_, Subsistema, _, _, _, _, _, _, _, subsistema_invalido, '', '', '') :-
    \+ ( nombre_subsistema(Subsistema, _), Subsistema \== general ),
    !.
validar_falla(_, _, Gravedad, _, _, _, _, _, _, gravedad_invalida, '', '', '') :-
    \+ peso_gravedad(Gravedad, _),
    !.
validar_falla(_, _, _, _, _, _, _, Alimentacion, _, alimentacion_invalida, '', '', '') :-
    \+ alimentacion_permitida(Alimentacion),
    !.
validar_falla(_, _, _, Req, Apo, Exc, Agr, _, _, lista_invalida, '', '', '') :-
    (   \+ ground([Req, Apo, Exc, Agr])
    ;   \+ ( is_list(Req), is_list(Apo), is_list(Exc), is_list(Agr) )
    ),
    !.
validar_falla(_, _, _, Req, _, _, _, _, _, pocos_requisitos, '', '', '') :-
    length(Req, N),
    limite_requisitos(Minimo, _),
    N < Minimo,
    !.
validar_falla(_, _, _, Req, _, _, _, _, _, demasiados_requisitos, '', '', '') :-
    length(Req, N),
    limite_requisitos(_, Maximo),
    N > Maximo,
    !.
validar_falla(_, _, _, Req, Apo, Exc, _, _, _, sintoma_desconocido, '', '', '') :-
    append([Req, Apo, Exc], Todos),
    \+ forall(member(S, Todos), sintoma_conocido(S)),
    !.
validar_falla(_, _, _, Req, Apo, Exc, _, _, _, sintomas_repetidos, '', '', '') :-
    append([Req, Apo, Exc], Todos),
    sort(Todos, Unicos),
    length(Todos, N),
    length(Unicos, M),
    N =\= M,
    !.
validar_falla(_, _, _, Req, Apo, _, _, _, _, sintomas_contradictorios, '', '', '') :-
    append(Req, Apo, Juntos),
    validar_coherencia(Juntos, [_|_]),
    !.
validar_falla(_, _, _, _, _, _, Agr, _, _, agravante_invalido, '', '', '') :-
    \+ forall(member(A, Agr), agravante_permitido(A)),
    !.
validar_falla(_, _, _, _, _, _, _, _, Rec, recomendacion_vacia, '', '', '') :-
    \+ texto_util(Rec, _),
    !.
validar_falla(_, _, _, _, _, _, _, _, Rec, recomendacion_larga, '', '', '') :-
    texto_util(Rec, Limpia),
    atom_length(Limpia, Largo),
    limite_texto(recomendacion, Maximo),
    Largo > Maximo,
    !.
validar_falla(_, _, _, Req, _, _, _, Alimentacion, _, falla_equivalente, Existente, '', '') :-
    falla_con_mismos_requisitos(Req, Alimentacion, Existente),
    !.
validar_falla(Nombre, _, _, _, _, _, _, _, Rec, ok, Falla, NombreFinal, RecFinal) :-
    texto_util(Nombre, Limpio),
    texto_a_atomo(Limpio, Falla),
    capitalizar(Limpio, NombreFinal),
    texto_util(Rec, RecFinal).

% R47. registrar_falla(+Falla, +Subsistema, +Nombre, +Req, +Apo, +Exc, +Gravedad, +Rec,
%                      +Alimentacion, +Agravantes): agrega la falla con assertz/1 a
%      los predicados del catalogo (no guarda en disco; tambien lo usa la carga del archivo).
registrar_falla(Falla, _, _, _, _, _, _, _, _, _) :-
    falla_subsistema(Falla, _),
    !.
registrar_falla(Falla, Subsistema, Nombre, Req, Apo, Exc, Gravedad, Rec, Alimentacion, Agr) :-
    assertz(falla_subsistema(Falla, Subsistema)),
    assertz(nombre_falla(Falla, Nombre)),
    assertz(requisitos_falla(Falla, Req)),
    forall(member(S, Apo), assertz(sintoma_apoyo(Falla, S))),
    forall(member(S, Exc), assertz(excluyente(Falla, S))),
    forall(member(A, Agr), assertz(agravante_de(Falla, A))),
    (   Alimentacion == cualquiera
    ->  true
    ;   assertz(restriccion_alimentacion(Falla, Alimentacion))
    ),
    assertz(gravedad_base(Falla, Gravedad)),
    assertz(recomendacion_base(Falla, Rec)),
    assertz(falla_aprendida(Falla, Subsistema, Nombre, Req, Apo, Exc,
                            Gravedad, Rec, Alimentacion, Agr)).

% R48. PREDICADO DE APRENDIZAJE DE FALLAS (lo invoca la interfaz).
%      aprender_falla(+Nombre, +Subsistema, +Gravedad, +Requisitos, +Apoyos, +Excluyentes,
%                     +Agravantes, +Alimentacion, +Recomendacion, -Estado, -Mensaje, -Falla)
aprender_falla(Nombre, Subsistema, Gravedad, Req, Apo, Exc, Agr, Alimentacion, Rec,
               Estado, Mensaje, Falla) :-
    validar_falla(Nombre, Subsistema, Gravedad, Req, Apo, Exc, Agr, Alimentacion, Rec,
                  Estado, Falla, NombreFinal, RecFinal),
    (   Estado == ok
    ->  registrar_falla(Falla, Subsistema, NombreFinal, Req, Apo, Exc, Gravedad,
                        RecFinal, Alimentacion, Agr),
        guardar_aprendizaje
    ;   true
    ),
    mensaje_de_aprendizaje(Estado, Req, Apo, Falla, Mensaje).

% mensaje_de_aprendizaje(+Estado, +Req, +Apo, +Falla, -Mensaje): los dos errores de
%   coherencia agregan el detalle (cual contradiccion, cual falla ya existe).
mensaje_de_aprendizaje(sintomas_contradictorios, Req, Apo, _, Mensaje) :-
    !,
    append(Req, Apo, Juntos),
    validar_coherencia(Juntos, [[_, Detalle]|_]),
    format(atom(Mensaje),
           'Las condiciones principales y de apoyo se contradicen. ~w', [Detalle]).
mensaje_de_aprendizaje(falla_equivalente, _, _, Existente, Mensaje) :-
    !,
    nombre_falla(Existente, Nombre),
    format(atom(Mensaje),
           'Ya existe la falla «~w» con las mismas condiciones principales y para el mismo tipo de moto.',
           [Nombre]).
mensaje_de_aprendizaje(Estado, _, _, _, Mensaje) :-
    mensaje_aprendizaje(Estado, Mensaje).

% falla_con_mismos_requisitos(+Req, +Alimentacion, -Falla): una falla del catalogo ya
%   exige exactamente esas condiciones y aplica al mismo tipo de moto.
falla_con_mismos_requisitos(Req, Alimentacion, Falla) :-
    sort(Req, Ordenados),
    requisitos_falla(Falla, Otros),
    sort(Otros, Ordenados),
    (   restriccion_alimentacion(Falla, Tipo)
    ->  true
    ;   Tipo = cualquiera
    ),
    Tipo == Alimentacion,
    !.

% =====================================================================
%  SECCION 16. REGLAS - OLVIDAR LO APRENDIDO
% =====================================================================

% quitar_falla(+Falla): retira de la memoria todos los hechos de una falla aprendida.
quitar_falla(Falla) :-
    retractall(falla_subsistema(Falla, _)),
    retractall(nombre_falla(Falla, _)),
    retractall(requisitos_falla(Falla, _)),
    retractall(sintoma_apoyo(Falla, _)),
    retractall(excluyente(Falla, _)),
    retractall(agravante_de(Falla, _)),
    retractall(restriccion_alimentacion(Falla, _)),
    retractall(gravedad_base(Falla, _)),
    retractall(recomendacion_base(Falla, _)),
    retractall(falla_aprendida(Falla, _, _, _, _, _, _, _, _, _)).

% quitar_sintoma(+Elemento): retira de la memoria un sintoma aprendido.
quitar_sintoma(Elemento) :-
    retractall(categoria_sintoma(Elemento, _)),
    retractall(nombre_elemento(Elemento, _)),
    retractall(pregunta_sintoma(_, Elemento, _)),
    retractall(sintoma_aprendido(Elemento, _, _, _)),
    retractall(frase_aprendida(_, Elemento)).

% sintoma_en_uso(+Elemento): alguna falla lo usa como condicion, apoyo o excluyente.
sintoma_en_uso(Elemento) :-
    (   requisitos_falla(_, Req), memberchk(Elemento, Req)
    ;   sintoma_apoyo(_, Elemento)
    ;   excluyente(_, Elemento)
    ),
    !.

% R49. olvidar_falla(+Falla, -Estado, -Mensaje): solo fallas aprendidas.
olvidar_falla(Falla, ok, Mensaje) :-
    falla_aprendida(Falla, _, _, _, _, _, _, _, _, _),
    !,
    quitar_falla(Falla),
    guardar_aprendizaje,
    mensaje_aprendizaje(ok, Mensaje).
olvidar_falla(_, no_aprendida, Mensaje) :-
    mensaje_aprendizaje(no_aprendida, Mensaje).

% R50. olvidar_sintoma(+Elemento, -Estado, -Mensaje): solo sintomas aprendidos y sin uso.
olvidar_sintoma(Elemento, no_aprendida, Mensaje) :-
    \+ sintoma_aprendido(Elemento, _, _, _),
    !,
    mensaje_aprendizaje(no_aprendida, Mensaje).
olvidar_sintoma(Elemento, en_uso, Mensaje) :-
    sintoma_en_uso(Elemento),
    !,
    mensaje_aprendizaje(en_uso, Mensaje).
olvidar_sintoma(Elemento, ok, Mensaje) :-
    quitar_sintoma(Elemento),
    guardar_aprendizaje,
    mensaje_aprendizaje(ok, Mensaje).

% =====================================================================
%  SECCION 17. PERSISTENCIA: GUARDAR Y CARGAR LO APRENDIDO
% =====================================================================

% guardar_aprendizaje: escribe conocimiento_aprendido.pl como un archivo de directivas
%   que, al consultarlo, vuelve a registrar todo lo aprendido. Escribe primero en un
%   temporal para no dejar el archivo a medias si algo falla.
guardar_aprendizaje :-
    ruta_aprendizaje(Ruta),
    atom_concat(Ruta, '.tmp', Temporal),
    setup_call_cleanup(
        open(Temporal, write, Salida, [encoding(utf8)]),
        escribir_aprendizaje(Salida),
        close(Salida)),
    (   exists_file(Ruta)
    ->  delete_file(Ruta)
    ;   true
    ),
    rename_file(Temporal, Ruta).

escribir_aprendizaje(Salida) :-
    format(Salida, ':- encoding(utf8).~n', []),
    format(Salida, '% Conocimiento aprendido por MotoDiag. Se genera solo: no lo edite a mano.~n', []),
    forall(sintoma_aprendido(E, C, N, P),
           format(Salida, ':- registrar_sintoma(~q, ~q, ~q, ~q).~n', [E, C, N, P])),
    forall(falla_aprendida(F, S, N, R, A, X, G, T, L, V),
           format(Salida, ':- registrar_falla(~q, ~q, ~q, ~q, ~q, ~q, ~q, ~q, ~q, ~q).~n',
                  [F, S, N, R, A, X, G, T, L, V])),
    forall(frase_aprendida(Palabras, Elemento),
           format(Salida, ':- registrar_frase(~q, ~q).~n', [Palabras, Elemento])).

% cargar_aprendizaje: consulta el archivo si existe; sus directivas registran lo aprendido.
cargar_aprendizaje :-
    ruta_aprendizaje(Ruta),
    exists_file(Ruta),
    !,
    consult(Ruta).
cargar_aprendizaje.

% olvidar_todo_en_memoria: retira de la memoria todo lo aprendido (no toca el archivo).
olvidar_todo_en_memoria :-
    forall(falla_aprendida(F, _, _, _, _, _, _, _, _, _), quitar_falla(F)),
    forall(sintoma_aprendido(E, _, _, _), quitar_sintoma(E)),
    retractall(frase_aprendida(_, _)).

% usar_archivo_aprendizaje(+Ruta): cambia el archivo de aprendizaje y lo carga
%   (sirve para las pruebas, que no deben tocar el archivo real).
usar_archivo_aprendizaje(Ruta) :-
    olvidar_todo_en_memoria,
    retractall(ruta_aprendizaje(_)),
    assertz(ruta_aprendizaje(Ruta)),
    cargar_aprendizaje.

% reiniciar_aprendizaje: el sistema vuelve al conocimiento original del experto.
reiniciar_aprendizaje :-
    olvidar_todo_en_memoria,
    guardar_aprendizaje.

% =====================================================================
%  SECCION 18. CONSULTAS PARA LA INTERFAZ DE APRENDIZAJE
% =====================================================================

% catalogo_sintomas(-Lista): [[Elemento, TituloCategoria, Nombre], ...] (sin datos de la moto)
catalogo_sintomas(Lista) :-
    findall(Clave-[Elemento, Titulo, Nombre],
            (   pregunta_sintoma(Orden, Elemento, _),
                sintoma_conocido(Elemento),
                categoria_sintoma(Elemento, Categoria),
                titulo_categoria(Categoria, Titulo),
                orden_categoria(Categoria, Rango),
                Clave = k(Rango, Orden),
                etiqueta(Elemento, Nombre)
            ),
            Pares),
    keysort(Pares, Ordenados),
    valores_de_pares(Ordenados, Lista).

% catalogo_subsistemas(-Lista): [[Id, Nombre], ...]
catalogo_subsistemas(Lista) :-
    findall([Id, Nombre],
            (   nombre_subsistema(Id, Nombre),
                Id \== general
            ),
            Lista).

% catalogo_categorias(-Lista): [[Id, Titulo], ...]
catalogo_categorias(Lista) :-
    findall([Id, Titulo],
            (   titulo_categoria(Id, Titulo),
                Id \== dato_moto
            ),
            Lista).

% catalogo_gravedades(-Lista): [[Nivel, Texto], ...] de menor a mayor gravedad
catalogo_gravedades(Lista) :-
    findall(Peso-[Nivel, Texto],
            (   peso_gravedad(Nivel, Peso),
                nombre_gravedad(Nivel, Texto)
            ),
            Pares),
    keysort(Pares, Ordenados),
    valores_de_pares(Ordenados, Lista).

% listar_fallas_aprendidas(-Lista):
%   [[Id, Nombre, Subsistema, Gravedad, Requisitos, Apoyos, Excluyentes, Alimentacion, Recomendacion], ...]
listar_fallas_aprendidas(Lista) :-
    findall([Id, Nombre, TSub, TGrav, TReq, TApo, TExc, Alimentacion, Rec],
            (   falla_aprendida(Id, Sub, Nombre, Req, Apo, Exc, Grav, Rec, Alimentacion, _),
                nombre_subsistema(Sub, TSub),
                nombre_gravedad(Grav, TGrav),
                maplist(etiqueta, Req, TReq),
                maplist(etiqueta, Apo, TApo),
                maplist(etiqueta, Exc, TExc)
            ),
            Lista).

% listar_sintomas_aprendidos(-Lista): [[Elemento, TituloCategoria, Nombre], ...]
listar_sintomas_aprendidos(Lista) :-
    findall([Elemento, Titulo, Nombre],
            (   sintoma_aprendido(Elemento, Categoria, Nombre, _),
                titulo_categoria(Categoria, Titulo)
            ),
            Lista).

% =====================================================================
%  SECCION 19. HECHOS Y REGLAS - COHERENCIA DE LA ENTRADA
%  Una moto real no puede presentar a la vez datos que se contradicen
%  (carburador e inyeccion, luces normales y apagadas, humo de dos colores...).
%  Prolog detecta esas contradicciones; la interfaz solo las muestra y evita
%  que se marquen, y ningun diagnostico se calcula con datos contradictorios.
% =====================================================================

% grupo_exclusivo(Id, Descripcion, Miembros): como maximo UNO de los miembros puede ser cierto.
grupo_exclusivo(alimentacion,
    'el tipo de alimentación de la moto',
    [alimentacion_carburador, alimentacion_inyeccion]).
grupo_exclusivo(giro_motor,
    'cómo gira el motor al dar arranque',
    [motor_cranquea_normal, cranquea_lento, motor_no_cranquea]).
grupo_exclusivo(chispa,
    'el estado de la chispa de la bujía',
    [sin_chispa, chispa_debil]).
grupo_exclusivo(color_humo,
    'el color del humo del escape',
    [humo_negro, humo_blanco, humo_azul]).
grupo_exclusivo(intensidad_luces,
    'la intensidad de las luces',
    [luces_normales, luces_debiles, sin_luces]).
grupo_exclusivo(temperatura_falla,
    'la temperatura del motor cuando ocurre la falla',
    [falla_en_frio, falla_en_caliente]).

% incompatible(A, B, Motivo): dos sintomas de grupos distintos que no pueden darse juntos.
incompatible(no_enciende, se_apaga_en_marcha,
    'Si la moto no enciende, no puede apagarse mientras anda.').
incompatible(no_enciende, tirones_al_acelerar,
    'Si la moto no enciende, no puede dar tirones al acelerar.').
incompatible(no_enciende, rpm_sube_sin_avance,
    'Si la moto no enciende, las revoluciones no pueden subir sin avance.').
incompatible(no_enciende, falla_en_aceleracion,
    'Si la moto no enciende, no puede fallar al acelerar en marcha.').
incompatible(no_enciende, bateria_se_descarga_rodando,
    'Si la moto no enciende, la batería no puede descargarse mientras anda.').
incompatible(motor_cranquea_normal, click_al_arrancar,
    'Un clic seco al arrancar significa que el motor no gira; no puede girar con fuerza normal.').
incompatible(temperatura_alta, falla_en_frio,
    'Con temperatura alta el motor no está frío.').

% limite_dato(Dato, Minimo, Maximo): rango razonable de los datos numericos del historial.
limite_dato(km_mantenimiento,   0, 100000).
limite_dato(antiguedad_bateria, 0, 120).

% nombre_dato(Dato, Texto)
nombre_dato(km_mantenimiento,   'kilómetros desde el último mantenimiento').
nombre_dato(antiguedad_bateria, 'meses de la batería instalada').

% R51. problema(+Obs, -Tipo, -Mensaje): una contradiccion concreta dentro de la entrada.
problema(Obs, exclusivo, Mensaje) :-
    grupo_exclusivo(_, Descripcion, Miembros),
    findall(M, ( member(M, Miembros), memberchk(M, Obs) ), Presentes),
    Presentes = [_, _|_],
    legible(Presentes, Texto),
    format(atom(Mensaje),
           'No pueden darse a la vez: ~w. Solo puede elegirse una opción sobre ~w.',
           [Texto, Descripcion]).
problema(Obs, incompatible, Mensaje) :-
    incompatible(A, B, Mensaje),
    memberchk(A, Obs),
    memberchk(B, Obs).
problema(Obs, fuera_de_rango, Mensaje) :-
    limite_dato(Dato, Minimo, Maximo),
    member(Item, Obs),
    compound(Item),
    Item =.. [Dato, Valor],
    \+ ( number(Valor), Valor >= Minimo, Valor =< Maximo ),
    nombre_dato(Dato, Nombre),
    format(atom(Mensaje),
           'Los ~w deben ser un número entre ~w y ~w.', [Nombre, Minimo, Maximo]).
problema(Obs, dato_repetido, Mensaje) :-
    limite_dato(Dato, _, _),
    findall(x, ( member(Item, Obs), compound(Item), functor(Item, Dato, 1) ), Veces),
    Veces = [_, _|_],
    nombre_dato(Dato, Nombre),
    format(atom(Mensaje),
           'Los ~w se indicaron más de una vez: deje un solo valor.', [Nombre]).

% R52. validar_coherencia(+Obs, -Problemas): lista [[Tipo, Mensaje], ...] sin repetidos.
%      Lista vacia = la entrada no se contradice.
validar_coherencia(Obs, Problemas) :-
    findall([Tipo, Mensaje], problema(Obs, Tipo, Mensaje), Lista),
    list_to_set(Lista, Problemas).

% mensajes_de_problemas(+Problemas, -Mensajes): solo los textos (recursion sobre lista).
mensajes_de_problemas([], []).
mensajes_de_problemas([[_, Mensaje]|Resto], [Mensaje|Mensajes]) :-
    mensajes_de_problemas(Resto, Mensajes).

% R53. genera_conflicto(+Sintoma, +Obs): agregar el sintoma a Obs crearia una contradiccion.
genera_conflicto(Sintoma, Obs) :-
    (   grupo_exclusivo(_, _, Miembros),
        memberchk(Sintoma, Miembros),
        member(Otro, Miembros),
        Otro \== Sintoma,
        memberchk(Otro, Obs)
    ;   incompatible(Sintoma, Otro, _),
        memberchk(Otro, Obs)
    ;   incompatible(Otro, Sintoma, _),
        memberchk(Otro, Obs)
    ),
    !.

% hay_sintoma(+Obs): al menos un sintoma (no basta con datos de la moto o del historial).
hay_sintoma(Obs) :-
    member(Elemento, Obs),
    atom(Elemento),
    categoria_sintoma(Elemento, Categoria),
    Categoria \== dato_moto,
    !.

% R54. validar_observaciones(+Obs, -Estado, -Problemas): lo que la interfaz consulta en
%      cada cambio. Estado: ok | entrada_invalida | incoherente | sin_sintomas
validar_observaciones(Obs, entrada_invalida, [[entrada_invalida, Mensaje]]) :-
    validar_entrada(Obs, Validez),
    Validez \== ok,
    !,
    mensaje_evidencia(entrada_invalida, Mensaje).
validar_observaciones(Obs, incoherente, Problemas) :-
    validar_coherencia(Obs, Problemas),
    Problemas = [_|_],
    !.
validar_observaciones(Obs, sin_sintomas, [[sin_sintomas, Mensaje]]) :-
    \+ hay_sintoma(Obs),
    !,
    Mensaje = 'Marque al menos un síntoma que observe en la moto.'.
validar_observaciones(_, ok, []).

% grupos_exclusivos(-Lista): [[Id, Descripcion, Miembros], ...] para la interfaz.
grupos_exclusivos(Lista) :-
    findall([Id, Descripcion, Miembros], grupo_exclusivo(Id, Descripcion, Miembros), Lista).

% limites_numericos(-Lista): [[Dato, Minimo, Maximo], ...] para la interfaz.
limites_numericos(Lista) :-
    findall([Dato, Minimo, Maximo], limite_dato(Dato, Minimo, Maximo), Lista).

% =====================================================================
%  SECCION 26. ROLES Y PERMISOS (Entregable 3)
%  Solo el rol "experto" puede modificar el conocimiento (crear diagnosticos,
%  sintomas y vocabulario, o olvidarlos). Cualquier rol puede diagnosticar.
% =====================================================================

% permiso(Rol, Accion)
permiso(usuario, diagnosticar).
permiso(usuario, describir_en_texto).
permiso(experto, diagnosticar).
permiso(experto, describir_en_texto).
permiso(experto, ensenar_falla).
permiso(experto, ensenar_sintoma).
permiso(experto, ensenar_frase).
permiso(experto, olvidar).

% R71. autorizar(+Rol, +Accion, -Estado, -Mensaje): ok o no_autorizado.
autorizar(Rol, Accion, ok, Mensaje) :-
    permiso(Rol, Accion),
    !,
    mensaje_aprendizaje(ok, Mensaje).
autorizar(_, _, no_autorizado, Mensaje) :-
    mensaje_aprendizaje(no_autorizado, Mensaje).

% =====================================================================
%  ARRANQUE: ruta por defecto del archivo y carga de lo aprendido
% =====================================================================

% Entregable 3: la gramatica DCG vive en su propio archivo, junto a este.
:- prolog_load_context(directory, Directorio),
   directory_file_path(Directorio, 'gramatica_dcg.pl', RutaGramatica),
   consult(RutaGramatica).

:- prolog_load_context(directory, Directorio),
   directory_file_path(Directorio, 'conocimiento_aprendido.pl', Ruta),
   assertz(ruta_aprendizaje(Ruta)).

:- cargar_aprendizaje.
