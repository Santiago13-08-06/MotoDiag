:- encoding(utf8).
% =====================================================================
%  MotoDiag - Entregable 3
%  gramatica_dcg.pl: LENGUAJE NATURAL CON DCG (Definite Clause Grammar)
%
%  Recibe lo que el usuario escribe con sus propias palabras, por ejemplo
%     "la moto no enciende y las luces se ven debiles, hace 9000 km que
%      no le hago mantenimiento"
%  lo analiza sintacticamente y entrega los hechos simbolicos que alimentan
%  al motor de inferencia: [no_enciende, luces_debiles, km_mantenimiento(9000)].
%
%  base_conocimiento.pl consulta este archivo al arrancar (cargar_gramatica/0).
%  Aqui vive TODO el analisis; Python solo envia el texto y muestra el resultado.
%
%  Estructura:
%     SECCION 20. Lexico (hechos): frases, palabras de relleno, conectores, unidades
%     SECCION 21. Tokenizador (recursion sobre listas de caracteres)
%     SECCION 22. La gramatica DCG (R55 a R63)
%     SECCION 23. Predicado principal interpretar_texto/8 (R64)
%     SECCION 24. Vocabulario que el experto puede ampliar (R65 a R68)
%     SECCION 25. Lecturas numericas -> niveles -> hechos (R69 a R70)
% =====================================================================

:- dynamic frase_aprendida/2.

% =====================================================================
%  SECCION 20. LEXICO
% =====================================================================

% frase(Palabras, Elemento): una expresion (palabras ya normalizadas: minuscula, sin
%   tildes) y el sintoma o dato que significa. Se permiten palabras de relleno entre
%   las palabras de la frase ("las luces se ven muy debiles" = [luces, debiles]).
% --- tipo de alimentacion
frase([carburador],  alimentacion_carburador).
frase([carburada],   alimentacion_carburador).
frase([carburacion], alimentacion_carburador).
frase([inyeccion],   alimentacion_inyeccion).
frase([inyectada],   alimentacion_inyeccion).
% --- arranque y encendido
frase([no, enciende],        no_enciende).
frase([no, prende],          no_enciende).
frase([no, arranca],         no_enciende).
frase([no, pega],            no_enciende).
frase([no, encendio],        no_enciende).
frase([no, prendio],         no_enciende).
frase([no, arranco],         no_enciende).
frase([no, quiere, encender], no_enciende).
frase([no, quiere, prender],  no_enciende).
frase([no, quiere, arrancar], no_enciende).
frase([gira, normal],        motor_cranquea_normal).
frase([gira, bien],          motor_cranquea_normal).
frase([gira, fuerte],        motor_cranquea_normal).
frase([cranquea, normal],    motor_cranquea_normal).
frase([gira, lento],         cranquea_lento).
frase([gira, despacio],      cranquea_lento).
frase([cranquea, lento],     cranquea_lento).
frase([arranque, lento],     cranquea_lento).
frase([arranque, debil],     cranquea_lento).
frase([no, gira],            motor_no_cranquea).
frase([no, cranquea],        motor_no_cranquea).
frase([no, da, vueltas],     motor_no_cranquea).
frase([clic],                click_al_arrancar).
frase([click],               click_al_arrancar).
frase([chasquido],           click_al_arrancar).
frase([no, chispa],          sin_chispa).
frase([sin, chispa],         sin_chispa).
frase([no, tiene, chispa],   sin_chispa).
frase([no, salta, chispa],   sin_chispa).
frase([chispa, debil],       chispa_debil).
frase([chispa, amarilla],    chispa_debil).
frase([chispa, amarillenta], chispa_debil).
frase([chispa, floja],       chispa_debil).
frase([poca, chispa],        chispa_debil).
frase([cuesta, arrancar],    arranque_dificil).
frase([cuesta, encender],    arranque_dificil).
frase([cuesta, prender],     arranque_dificil).
frase([dificil, arrancar],   arranque_dificil).
frase([dificil, encender],   arranque_dificil).
frase([arranque, dificil],   arranque_dificil).
frase([arranca, dificultad], arranque_dificil).
% --- combustible y potencia
frase([pierde, potencia],    pierde_potencia).
frase([perdida, potencia],   pierde_potencia).
frase([pierde, fuerza],      pierde_potencia).
frase([falta, potencia],     pierde_potencia).
frase([falta, fuerza],       pierde_potencia).
frase([poca, potencia],      pierde_potencia).
frase([poca, fuerza],        pierde_potencia).
frase([sin, potencia],       pierde_potencia).
frase([no, acelera],         pierde_potencia).
frase([no, jala],            pierde_potencia).
frase([se, apaga],           se_apaga_en_marcha).
frase([se, para],            se_apaga_en_marcha).
frase([se, muere],           se_apaga_en_marcha).
frase([se, ahoga],           se_apaga_en_marcha).
frase([olor, gasolina],      olor_gasolina).
frase([huele, gasolina],     olor_gasolina).
frase([consume, gasolina],   consumo_alto_gasolina).
frase([gasta, gasolina],     consumo_alto_gasolina).
frase([consumo, alto],       consumo_alto_gasolina).
frase([consume, mas],        consumo_alto_gasolina).
frase([gasta, mas],          consumo_alto_gasolina).
frase([humo, negro],         humo_negro).
frase([humo, oscuro],        humo_negro).
% --- motor y lubricacion
frase([se, calienta],        temperatura_alta).
frase([se, sobrecalienta],   temperatura_alta).
frase([sobrecalienta],       temperatura_alta).
frase([sobrecalentamiento],  temperatura_alta).
frase([recalienta],          temperatura_alta).
frase([recalentamiento],     temperatura_alta).
frase([temperatura, alta],   temperatura_alta).
frase([muy, caliente],       temperatura_alta).
frase([mucho, calor],        temperatura_alta).
frase([ruido, metalico],     ruido_metalico).
frase([sonido, metalico],    ruido_metalico).
frase([golpeteo],            ruido_metalico).
frase([cascabeleo],          ruido_metalico).
frase([traqueteo],           ruido_metalico).
frase([metalico],            ruido_metalico).
frase([vibra],               vibracion_excesiva).
frase([vibracion],           vibracion_excesiva).
frase([vibraciones],         vibracion_excesiva).
frase([vibrando],            vibracion_excesiva).
frase([tiembla],             vibracion_excesiva).
frase([humo, blanco],        humo_blanco).
frase([humo, azul],          humo_azul).
frase([humo, azulado],       humo_azul).
frase([luz, aceite],         luz_aceite).
frase([testigo, aceite],     luz_aceite).
frase([indicador, aceite],   luz_aceite).
frase([aceite, bajo],        aceite_bajo_varilla).
frase([poco, aceite],        aceite_bajo_varilla).
frase([falta, aceite],       aceite_bajo_varilla).
frase([aceite, minimo],      aceite_bajo_varilla).
frase([sin, aceite],         aceite_bajo_varilla).
frase([fuga, aceite],        fuga_aceite).
frase([gotea, aceite],       fuga_aceite).
frase([bota, aceite],        fuga_aceite).
frase([pierde, aceite],      fuga_aceite).
frase([goteo, aceite],       fuga_aceite).
frase([mancha, aceite],      fuga_aceite).
frase([manchas, aceite],     fuga_aceite).
% --- frenos y transmision
frase([freno, esponjoso],    freno_esponjoso).
frase([frenos, esponjosos],  freno_esponjoso).
frase([freno, blando],       freno_esponjoso).
frase([frenos, blandos],     freno_esponjoso).
frase([esponjoso],           freno_esponjoso).
frase([palanca, recorre],    palanca_freno_larga).
frase([palanca, larga],      palanca_freno_larga).
frase([palanca, fondo],      palanca_freno_larga).
frase([palanca, recorrido],  palanca_freno_larga).
frase([recorrido, palanca],  palanca_freno_larga).
frase([pedal, recorre],      palanca_freno_larga).
frase([pedal, largo],        palanca_freno_larga).
frase([freno, chirria],      freno_chirria).
frase([freno, rechina],      freno_chirria).
frase([freno, chilla],       freno_chirria).
frase([chirria],             freno_chirria).
frase([rechina],             freno_chirria).
frase([chirrido],            freno_chirria).
frase([tarda, detenerse],    frenada_larga).
frase([tarda, frenar],       frenada_larga).
frase([tarda, parar],        frenada_larga).
frase([no, frena],           frenada_larga).
frase([frena, poco],         frenada_larga).
frase([frena, mal],          frenada_larga).
frase([frenada, larga],      frenada_larga).
frase([cadena, floja],       cadena_holgura_visible).
frase([cadena, suelta],      cadena_holgura_visible).
frase([cadena, holgura],     cadena_holgura_visible).
frase([holgura, cadena],     cadena_holgura_visible).
frase([cadena, ruido],       cadena_ruido).
frase([cadena, golpetea],    cadena_ruido).
frase([cadena, suena],       cadena_ruido).
frase([ruido, cadena],       cadena_ruido).
frase([tirones],             tirones_al_acelerar).
frase([jalones],             tirones_al_acelerar).
frase([tironea],             tirones_al_acelerar).
frase([jalonea],             tirones_al_acelerar).
frase([revoluciones, suben], rpm_sube_sin_avance).
frase([rpm, suben],          rpm_sube_sin_avance).
frase([no, avanza],          rpm_sube_sin_avance).
frase([patina],              rpm_sube_sin_avance).
frase([olor, quemado],       olor_quemado).
frase([huele, quemado],      olor_quemado).
frase([olor, embrague],      olor_quemado).
% --- sistema electrico
frase([luces, debiles],      luces_debiles).
frase([luces, amarillas],    luces_debiles).
frase([luces, amarillentas], luces_debiles).
frase([luces, tenues],       luces_debiles).
frase([luces, flojas],       luces_debiles).
frase([luces, opacas],       luces_debiles).
frase([luz, debil],          luces_debiles).
frase([poca, luz],           luces_debiles).
frase([faro, debil],         luces_debiles).
frase([luces, normales],     luces_normales).
frase([luces, funcionan],    luces_normales).
frase([sin, luces],          sin_luces).
frase([sin, luz],            sin_luces).
frase([no, luces],           sin_luces).
frase([luces, no, encienden], sin_luces).
frase([luces, no, prenden],  sin_luces).
frase([no, encienden, luces], sin_luces).
frase([no, prenden, luces],  sin_luces).
frase([luces, apagadas],     sin_luces).
frase([luz, bateria],        luz_bateria).
frase([testigo, bateria],    luz_bateria).
frase([indicador, bateria],  luz_bateria).
frase([fusible, quemado],    fusible_visible_quemado).
frase([fusible, roto],       fusible_visible_quemado).
frase([fusible, fundido],    fusible_visible_quemado).
frase([fusibles, quemados],  fusible_visible_quemado).
frase([quemo, fusible],      fusible_visible_quemado).
frase([falla, electrica],    falla_electrica_repentina).
frase([cortocircuito],       falla_electrica_repentina).
frase([corto, circuito],     falla_electrica_repentina).
frase([bateria, descarga],   bateria_se_descarga_rodando).
frase([bateria, descargada], bateria_se_descarga_rodando).
frase([bateria, agota],      bateria_se_descarga_rodando).
frase([bateria, no, carga],  bateria_se_descarga_rodando).
frase([no, carga, bateria],  bateria_se_descarga_rodando).
frase([queman, focos],       foco_quemado_frecuente).
frase([queman, bombillos],   foco_quemado_frecuente).
frase([queman, bombillas],   foco_quemado_frecuente).
frase([focos, quemados],     foco_quemado_frecuente).
frase([focos, queman],       foco_quemado_frecuente).
frase([foco, quemado],       foco_quemado_frecuente).
frase([bombillos, quemados], foco_quemado_frecuente).
% --- condiciones en que ocurre la falla
frase([en, frio],            falla_en_frio).
frase([motor, frio],         falla_en_frio).
frase([cuando, frio],        falla_en_frio).
frase([en, caliente],        falla_en_caliente).
frase([cuando, caliente],    falla_en_caliente).
frase([ya, caliente],        falla_en_caliente).
frase([al, acelerar],        falla_en_aceleracion).
frase([cuando, acelera],     falla_en_aceleracion).
frase([cuando, acelero],     falla_en_aceleracion).
frase([acelerando],          falla_en_aceleracion).
frase([en, aceleracion],     falla_en_aceleracion).
frase([ralenti],             falla_en_ralenti).
frase([en, minimo],          falla_en_ralenti).
frase([lluvia],              despues_de_lluvia).
frase([llovio],              despues_de_lluvia).
frase([lavado],              despues_de_lluvia).
frase([lavada],              despues_de_lluvia).
frase([mojada],              despues_de_lluvia).
frase([charco],              despues_de_lluvia).

% frase_conocida(?Palabras, ?Elemento): el lexico del experto mas lo que se ensena.
frase_conocida(Palabras, Elemento) :- frase(Palabras, Elemento).
frase_conocida(Palabras, Elemento) :- frase_aprendida(Palabras, Elemento).

% relleno(Palabra): palabras que pueden aparecer dentro de una frase sin cambiar su
%   sentido (articulos, preposiciones, verbos auxiliares, adverbios de grado...).
relleno(la).     relleno(el).      relleno(los).    relleno(las).
relleno(un).     relleno(una).     relleno(unos).   relleno(unas).
relleno(de).     relleno(del).     relleno(a).      relleno(al).
relleno(en).     relleno(con).     relleno(por).    relleno(que).
relleno(mi).     relleno(su).      relleno(le).     relleno(lo).
relleno(me).     relleno(se).      relleno(te).     relleno(como).
relleno(esta).   relleno(estan).   relleno(es).     relleno(son).
relleno(esta).   relleno(tiene).   relleno(tienen).  relleno(hace).
relleno(hacen).  relleno(hay).     relleno(sale).   relleno(salen).
relleno(ve).     relleno(ven).     relleno(veo).    relleno(siente).
relleno(siento). relleno(noto).    relleno(escucho). relleno(oigo).
relleno(presenta). relleno(muy).   relleno(mucho).  relleno(mucha).
relleno(muchos). relleno(muchas).  relleno(bastante). relleno(algo).
relleno(demasiado). relleno(moto).   relleno(motocicleta).
relleno(mientras). relleno(anda).  relleno(andando). relleno(manejo).
relleno(manejando). relleno(rodando). relleno(cuando). relleno(ya).
relleno(todo).   relleno(toda).    relleno(este).   relleno(esta).
relleno(pues).   relleno(entonces). relleno(bien).  relleno(mal).
relleno(solo).   relleno(sola).    relleno(mismo).  relleno(tambien).
relleno(sigue).  relleno(queda).   relleno(quedo).  relleno(pone).
relleno(ponen).  relleno(puso).    relleno(fue).    relleno(era).
relleno(tuve).   relleno(he).      relleno(ha).     relleno(han).
relleno(hoy).    relleno(ayer).    relleno(desde).  relleno(para).
relleno(mas).    relleno(menos).   relleno(casi).   relleno(nada).
relleno(parece). relleno(parecen). relleno(suena).  relleno(suenan).
relleno(un).     relleno(unos).    relleno(ese).    relleno(esa).
relleno(eso).    relleno(esto).    relleno(otra).   relleno(otro).
relleno(vez).    relleno(veces).   relleno(algun).  relleno(alguna).
relleno(hola).   relleno(buenas).  relleno(favor).  relleno(ayuda).
relleno(voltaje). relleno(temperatura). relleno(holgura). relleno(distancia).
relleno(frenado). relleno(consumo). relleno(rendimiento). relleno(carga).
relleno(mide).   relleno(marca).   relleno(indica). relleno(aproximadamente).
relleno(cerca).  relleno(unos).    relleno(estoy).  relleno(tengo).
relleno(motor).  relleno(usa).     relleno(usan).   relleno(rinde).
relleno(ultimo). relleno(ultima).  relleno(que).    relleno(hago).
relleno(hizo).   relleno(hicieron). relleno(llevo). relleno(lleva).
relleno(van).    relleno(voy).     relleno(va).     relleno(esta).

% conector(Palabra): separa una clausula de la siguiente.
conector(y).        conector(e).       conector(o).      conector(u).
conector(pero).     conector(ademas).
conector(aunque).   conector(ni).      conector(luego).  conector(porque).
conector(sino).

% negacion(Palabra): niega la frase que sigue.
negacion(no).
negacion(nunca).
negacion(tampoco).

% palabra_numero(Palabra, Valor): cantidades escritas con letras.
palabra_numero(un, 1).       palabra_numero(uno, 1).      palabra_numero(una, 1).
palabra_numero(dos, 2).      palabra_numero(tres, 3).     palabra_numero(cuatro, 4).
palabra_numero(cinco, 5).    palabra_numero(seis, 6).     palabra_numero(siete, 7).
palabra_numero(ocho, 8).     palabra_numero(nueve, 9).    palabra_numero(diez, 10).
palabra_numero(once, 11).    palabra_numero(doce, 12).    palabra_numero(quince, 15).
palabra_numero(veinte, 20).  palabra_numero(treinta, 30). palabra_numero(cuarenta, 40).
palabra_numero(cincuenta, 50).

% unidad(Palabra, Canonica): unidades escritas de varias formas.
unidad(km, km).          unidad(kms, km).        unidad(kilometro, km).
unidad(kilometros, km).  unidad(k, km).
unidad(grados, grados).  unidad(grado, grados).  unidad(c, grados).
unidad(celsius, grados). unidad(centigrados, grados).
unidad(v, voltios).      unidad(volt, voltios).  unidad(volts, voltios).
unidad(voltio, voltios). unidad(voltios, voltios).
unidad(mm, mm).          unidad(milimetro, mm).  unidad(milimetros, mm).
unidad(m, metros).       unidad(metro, metros).  unidad(metros, metros).
unidad(mts, metros).
unidad(mes, meses).      unidad(meses, meses).
unidad(ano, anos).       unidad(anos, anos).

% palabra_mantenimiento(Palabra): indica que un kilometraje habla del mantenimiento.
palabra_mantenimiento(mantenimiento).
palabra_mantenimiento(mantencion).
palabra_mantenimiento(servicio).
palabra_mantenimiento(revision).
palabra_mantenimiento(sincronizacion).

% lectura_unidad(Variable, UnidadCanonica): unidad con la que se escribe cada lectura
%   continua del taller (km/l se trata aparte, porque son tres palabras).
lectura_unidad(temperatura_motor, grados).
lectura_unidad(voltaje_carga,     voltios).
lectura_unidad(holgura_cadena,    mm).
lectura_unidad(distancia_frenado, metros).

% =====================================================================
%  SECCION 21. TOKENIZADOR (recursion sobre listas de caracteres)
% =====================================================================

% tokenizar(+Texto, -Tokens): el texto pasa a minusculas y sin tildes y se parte en
%   palabras (atomos), numeros num(N) y el marcador sep (puntuacion).
%   "Hace 9.000 km, y las luces..." -> [hace, num(9000), km, sep, y, las, luces, ...]
tokenizar(Texto, Tokens) :-
    atom_chars(Texto, Caracteres0),
    maplist(minuscula_sin_tilde, Caracteres0, Caracteres1),
    unir_numeros(Caracteres1, Caracteres2),
    partir_palabras(Caracteres2, Tokens).

% minuscula_sin_tilde(+Caracter, -Normalizado)
minuscula_sin_tilde(Caracter, Normalizado) :-
    downcase_atom(Caracter, Minuscula),
    (   sin_tilde(Minuscula, Base)
    ->  Normalizado = Base
    ;   Normalizado = Minuscula
    ).

% unir_numeros(+Chars, -Chars): "9.000" -> "9000" (separador de miles) y "12,5" -> "12.5".
unir_numeros([], []).
unir_numeros([D, '.', A, B, C|Resto], [D|Salida]) :-
    maplist(es_digito, [D, A, B, C]),
    \+ ( Resto = [E|_], es_digito(E) ),
    !,
    unir_numeros([A, B, C|Resto], Salida).
unir_numeros([D, ',', E|Resto], [D, '.'|Salida]) :-
    es_digito(D),
    es_digito(E),
    !,
    unir_numeros([E|Resto], Salida).
unir_numeros([C|Resto], [C|Salida]) :-
    unir_numeros(Resto, Salida).

es_digito(C) :- atom(C), memberchk(C, ['0','1','2','3','4','5','6','7','8','9']).
es_letra(C)  :- atom(C), C @>= a, C @=< z, atom_length(C, 1).

% partir_palabras(+Chars, -Tokens)
partir_palabras([], []).
partir_palabras([C|Resto], [Token|Tokens]) :-
    clase_caracter(C, Clase),
    !,
    tomar_clase(Clase, [C|Resto], Cadena, Sobra),
    cadena_a_token(Clase, Cadena, Token),
    partir_palabras(Sobra, Tokens).
partir_palabras([C|Resto], [sep|Tokens]) :-
    memberchk(C, ['.', ',', ';', ':', '!', '?', '(', ')', '\n', '¡', '¿']),
    !,
    partir_palabras(Resto, Tokens).
partir_palabras([_|Resto], Tokens) :-
    partir_palabras(Resto, Tokens).

clase_caracter(C, digito) :- es_digito(C), !.
clase_caracter(C, letra)  :- es_letra(C).

% tomar_clase(+Clase, +Chars, -Tomados, -Resto): toma los caracteres seguidos de la
%   misma clase (un punto entre dos digitos es parte del numero decimal).
tomar_clase(digito, [D, '.', E|Resto], [D, '.'|Tomados], Sobra) :-
    es_digito(D),
    es_digito(E),
    !,
    tomar_clase(digito, [E|Resto], Tomados, Sobra).
tomar_clase(Clase, [C|Resto], [C|Tomados], Sobra) :-
    clase_caracter(C, Clase),
    !,
    tomar_clase(Clase, Resto, Tomados, Sobra).
tomar_clase(_, Resto, [], Resto).

cadena_a_token(digito, Cadena, num(Numero)) :-
    !,
    atom_chars(Atomo, Cadena),
    atom_number(Atomo, Numero).
cadena_a_token(letra, Cadena, Palabra) :-
    atom_chars(Palabra, Cadena).

% token_texto(+Token, -Texto): para mostrar un token.
token_texto(num(N), Texto) :- !, format(atom(Texto), '~w', [N]).
token_texto(sep, ',') :- !.
token_texto(Palabra, Palabra).

% =====================================================================
%  SECCION 22. LA GRAMATICA DCG
%
%  oracion      --> clausulas
%  clausulas    --> clausula, separador, clausulas  |  clausula
%  clausula     --> sintagma, clausula  |  (vacia)
%  sintagma     --> lectura | dato_historial | sintoma | sintoma_negado
%                   | palabra_de_relleno | palabra_desconocida
%
%  Cada sintagma produce un elemento de la lista de resultados:
%     hecho(Elemento, Frase)        el usuario presenta ese sintoma
%     ausente(Elemento, Frase)      el usuario dice que NO lo presenta
%     dato(Dato, Valor, Frase)      dato del historial (km, meses)
%     lectura(Variable, Valor, Frase)   medida continua (se discretiza en Python)
%     desconocida(Palabra)          palabra que no pudo interpretar
% =====================================================================

% R55. oracion//1: una oracion es una secuencia de clausulas.
oracion(Items) --> clausulas(Items).

% R56. clausulas//1: las clausulas se separan por puntuacion o por conectores ("y", "pero"...).
clausulas(Items) -->
    clausula(Primeros),
    separador,
    !,
    clausulas(Siguientes),
    { append(Primeros, Siguientes, Items) }.
clausulas(Items) --> clausula(Items).

separador --> [sep], !.
separador --> [Palabra], { conector(Palabra) }.

% R57. clausula//1: una clausula es una secuencia de sintagmas hasta el siguiente separador.
clausula([Item|Items]) -->
    sintagma(Item),
    !,
    clausula(Items).
clausula([]) --> [].

% R58. sintagma//1: se prueba en este orden (el primero que encaje gana).
sintagma(Item) --> lectura(Item), !.
sintagma(Item) --> dato_historial(Item), !.
sintagma(Item) --> sintoma(Item), !.
sintagma(Item) --> sintoma_negado(Item), !.
sintagma(omitida) --> [Palabra], { relleno(Palabra) }, !.
sintagma(desconocida(Palabra)) --> [Palabra], { \+ Palabra = sep, \+ conector(Palabra) }.

% R59. sintoma//1: una frase del lexico; gana la coincidencia mas larga (se comprueba
%      con findall/3 porque debe comparar todas las candidatas antes de elegir).
sintoma(hecho(Elemento, Frase), Tokens, Resto) :-
    coincidencia_mas_larga(Tokens, Elemento, Resto),
    consumidos(Tokens, Resto, Frase).

% R60. sintoma_negado//1: "no" + frase = el usuario descarta ese sintoma
%      ("no sale humo negro" -> ausente(humo_negro)).
sintoma_negado(ausente(Elemento, Frase), [No|Tokens], Resto) :-
    negacion(No),
    saltar_relleno(Tokens, 2, Tokens1),
    coincidencia_mas_larga(Tokens1, Elemento, Resto),
    consumidos([No|Tokens], Resto, Frase).

% saltar_relleno(+Tokens, +Maximo, -Resto): salta hasta Maximo palabras de relleno.
saltar_relleno(Tokens, _, Tokens).
saltar_relleno([P|Tokens], N, Resto) :-
    N > 0,
    relleno(P),
    N1 is N - 1,
    saltar_relleno(Tokens, N1, Resto).

% coincidencia_mas_larga(+Tokens, -Elemento, -Resto)
%   La frase puede empezar tras saltar hasta 3 palabras de relleno ("se muere en subida"
%   encuentra "muere subida"); gana la que consume mas palabras del texto.
coincidencia_mas_larga(Tokens, Elemento, Resto) :-
    length(Tokens, Total),
    findall(Clave-Candidato-Sobra,
            (   saltar_relleno(Tokens, 3, Desde),
                frase_conocida(Palabras, Candidato),
                coincide(Palabras, Desde, Sobra),
                length(Sobra, Quedan),
                Clave is Quedan - Total
            ),
            Candidatas),
    Candidatas \== [],
    keysort(Candidatas, [_-Elemento-Resto|_]).

% coincide(+Palabras, +Tokens, -Resto): la frase aparece al inicio de Tokens; entre sus
%   palabras puede haber hasta 3 palabras de relleno.
coincide([Primera|Otras], [Primera|Tokens], Resto) :-
    coincide_resto(Otras, Tokens, Resto).

coincide_resto([], Resto, Resto).
coincide_resto([Palabra|Otras], Tokens, Resto) :-
    palabra_siguiente(Palabra, Tokens, Tokens1, 3),
    coincide_resto(Otras, Tokens1, Resto).

palabra_siguiente(Palabra, [Palabra|Resto], Resto, _).
palabra_siguiente(Palabra, [Relleno|Tokens], Resto, N) :-
    N > 0,
    Relleno \== Palabra,
    relleno(Relleno),
    N1 is N - 1,
    palabra_siguiente(Palabra, Tokens, Resto, N1).

% consumidos(+Antes, +Despues, -Frase): los tokens que se consumieron.
consumidos(Antes, Despues, Frase) :-
    append(Frase, Despues, Antes),
    !.

% R61. cantidad//1: "9000", "9 mil", "nueve mil", "tres"...
cantidad(N) --> [num(A)], [mil], !, { N is A * 1000 }.
cantidad(N) --> [P], [mil], { palabra_numero(P, A) }, !, { N is A * 1000 }.
cantidad(1000) --> [mil], !.
cantidad(N) --> [num(N)], !.
cantidad(N) --> [P], { palabra_numero(P, N) }.

% R62. lectura//1: medida continua con su unidad: "120 grados", "12,5 voltios",
%      "45 mm", "18 metros", "22 km por litro". Python la convierte en un nivel.
lectura(lectura(Variable, Valor, Frase), Tokens, Resto) :-
    cantidad(Valor, Tokens, Despues),
    (   unidad_consumo(Despues, Resto)
    ->  Variable = consumo_combustible
    ;   Despues = [Palabra|Resto],
        unidad(Palabra, Unidad),
        lectura_unidad(Variable, Unidad)
    ),
    consumidos(Tokens, Resto, Frase).

% "km por litro", "km/l" (llega como km, l) y "kilometros por litro".
unidad_consumo([Km, por, litro|Resto], Resto) :- unidad(Km, km), !.
unidad_consumo([Km, por, litros|Resto], Resto) :- unidad(Km, km), !.
unidad_consumo([Km, l|Resto], Resto)           :- unidad(Km, km), !.
unidad_consumo([kml|Resto], Resto).

% R63. dato_historial//1: kilometros desde el ultimo mantenimiento y meses de la bateria.
%      Orden 1: "9000 km desde el ultimo mantenimiento"
%      Orden 2: "el ultimo mantenimiento fue hace 9000 km"
%      Bateria: "la bateria tiene 18 meses" / "bateria de 3 anos"
dato_historial(dato(km_mantenimiento, Valor, Frase), Tokens, Resto) :-
    (   cantidad(Valor, Tokens, [Km|Despues]),
        unidad(Km, km),
        hasta_palabra(palabra_mantenimiento, Despues, 6, Resto)
    ;   Tokens = [Palabra|Siguientes],
        palabra_mantenimiento(Palabra),
        saltar_hasta_cantidad(Siguientes, 6, Valor, [Km|Resto]),
        unidad(Km, km)
    ),
    !,
    consumidos(Tokens, Resto, Frase).
dato_historial(dato(antiguedad_bateria, Meses, Frase), [bateria|Siguientes], Resto) :-
    saltar_hasta_cantidad(Siguientes, 4, Valor, [Unidad|Resto]),
    unidad(Unidad, Medida),
    (   Medida == meses
    ->  Meses is round(Valor)
    ;   Medida == anos
    ->  Meses is round(Valor * 12)
    ),
    !,
    consumidos([bateria|Siguientes], Resto, Frase).

% hasta_palabra(+Condicion, +Tokens, +Maximo, -Resto): avanza hasta una palabra que
%   cumpla la condicion (sin cruzar un separador) y la consume.
hasta_palabra(Condicion, [P|Resto], _, Resto) :-
    call(Condicion, P),
    !.
hasta_palabra(Condicion, [P|Tokens], N, Resto) :-
    N > 0,
    P \== sep,
    \+ conector(P),
    N1 is N - 1,
    hasta_palabra(Condicion, Tokens, N1, Resto).

% saltar_hasta_cantidad(+Tokens, +Maximo, -Valor, -Resto): salta palabras sueltas hasta
%   encontrar una cantidad; Resto empieza justo despues de ella.
saltar_hasta_cantidad(Tokens, _, Valor, Resto) :-
    cantidad(Valor, Tokens, Resto),
    !.
saltar_hasta_cantidad([P|Tokens], N, Valor, Resto) :-
    N > 0,
    P \== sep,
    \+ conector(P),
    N1 is N - 1,
    saltar_hasta_cantidad(Tokens, N1, Valor, Resto).

% =====================================================================
%  SECCION 23. PREDICADO PRINCIPAL
% =====================================================================

% R64. interpretar_texto(+Texto, -Estado, -Hechos, -Datos, -Ausentes, -Lecturas,
%                        -Interpretacion, -Desconocidas)
%   Estado: ok | texto_vacio | texto_largo | no_entendido
%   Hechos: sintomas que el usuario presenta (atomos, sin repetir)
%   Datos: [[Dato, Valor], ...] del historial       Ausentes: sintomas que descarta
%   Lecturas: [[Variable, Valor], ...] medidas continuas (Python las discretiza)
%   Interpretacion: [[Frase, Tipo, Nombre, Valor], ...] que palabras dieron que hecho
%   Desconocidas: palabras que no pudo interpretar
interpretar_texto(Texto, Estado, Hechos, Datos, Ausentes, Lecturas, Interpretacion, Desconocidas) :-
    estado_texto(Texto, Estado0),
    (   Estado0 == ok
    ->  tokenizar(Texto, Tokens),
        (   phrase(oracion(Items), Tokens)
        ->  true
        ;   Items = []
        ),
        separar_items(Items, Hechos, Datos, Ausentes, Lecturas, Interpretacion, Desconocidas),
        (   Hechos == [], Datos == [], Ausentes == [], Lecturas == []
        ->  Estado = no_entendido
        ;   Estado = ok
        )
    ;   Estado = Estado0,
        Hechos = [], Datos = [], Ausentes = [], Lecturas = [],
        Interpretacion = [], Desconocidas = []
    ).

% estado_texto(+Texto, -Estado): validacion del texto recibido.
estado_texto(Texto, texto_vacio) :-
    \+ texto_util(Texto, _),
    !.
estado_texto(Texto, texto_largo) :-
    atom_length(Texto, Largo),
    limite_entrada(texto_libre, Maximo),
    Largo > Maximo,
    !.
estado_texto(Texto, texto_vacio) :-
    tokenizar(Texto, Tokens),
    \+ ( member(T, Tokens), T \== sep ),
    !.
estado_texto(_, ok).

limite_entrada(texto_libre, 600).
limite_entrada(frase_vocabulario, 60).
limite_frase(1, 6).     % entre 1 y 6 palabras utiles

% separar_items(+Items, -Hechos, -Datos, -Ausentes, -Lecturas, -Interpretacion, -Desconocidas)
%   Recorre la lista de resultados de la gramatica (recursion con acumuladores en findall).
separar_items(Items, Hechos, Datos, Ausentes, Lecturas, Interpretacion, Desconocidas) :-
    findall(E, member(hecho(E, _), Items), H0),
    list_to_set(H0, Hechos),
    findall([D, V], member(dato(D, V, _), Items), Datos0),
    list_to_set(Datos0, Datos),
    findall(E, member(ausente(E, _), Items), A0),
    list_to_set(A0, Ausentes),
    findall([Var, V], member(lectura(Var, V, _), Items), L0),
    list_to_set(L0, Lecturas),
    findall([Texto, Tipo, Nombre, Valor],
            (   member(Item, Items),
                item_interpretado(Item, Frase, Tipo, Nombre, Valor),
                frase_a_texto(Frase, Texto)
            ),
            Interpretacion),
    findall(Texto,
            (   member(desconocida(P), Items),
                token_texto(P, Texto)
            ),
            D0),
    list_to_set(D0, Desconocidas).

item_interpretado(hecho(E, F),         F, hecho,   E, '').
item_interpretado(ausente(E, F),       F, ausente, E, '').
item_interpretado(dato(D, V, F),       F, dato,    D, V).
item_interpretado(lectura(Var, V, F),  F, lectura, Var, V).

% frase_a_texto(+Tokens, -Texto): las palabras separadas por espacios.
frase_a_texto(Tokens, Texto) :-
    maplist(token_texto, Tokens, Palabras),
    atomic_list_concat(Palabras, ' ', Texto).

% =====================================================================
%  SECCION 24. VOCABULARIO QUE EL EXPERTO PUEDE AMPLIAR
%  El experto agrega expresiones nuevas ("se ahoga" = se apaga en marcha); Prolog las
%  valida, las agrega con assertz/1 y las guarda en conocimiento_aprendido.pl.
% =====================================================================

% R65. palabras_utiles(+Texto, -Palabras): las palabras de la expresion, sin relleno.
palabras_utiles(Texto, Palabras) :-
    tokenizar(Texto, Tokens),
    findall(P,
            (   member(P, Tokens),
                atom(P),
                P \== sep,
                \+ relleno(P)
            ),
            Palabras).

% R66. validar_frase(+Texto, +Elemento, -Estado, -Palabras)
validar_frase(Texto, _, texto_vacio, []) :-
    \+ texto_util(Texto, _),
    !.
validar_frase(Texto, _, texto_largo, []) :-
    texto_util(Texto, Limpio),
    atom_length(Limpio, Largo),
    limite_entrada(frase_vocabulario, Maximo),
    Largo > Maximo,
    !.
validar_frase(Texto, _, frase_sin_palabras, []) :-
    palabras_utiles(Texto, Palabras),
    exclude(negacion, Palabras, Contenido),
    Contenido == [],
    !.
validar_frase(Texto, _, frase_larga, Palabras) :-
    palabras_utiles(Texto, Palabras),
    length(Palabras, N),
    limite_frase(_, Maximo),
    N > Maximo,
    !.
validar_frase(_, Elemento, elemento_desconocido, []) :-
    \+ categoria_sintoma(Elemento, _),
    !.
validar_frase(Texto, Elemento, frase_repetida, Palabras) :-
    palabras_utiles(Texto, Palabras),
    frase_conocida(Palabras, Elemento),
    !.
validar_frase(Texto, _, frase_ambigua, Palabras) :-
    palabras_utiles(Texto, Palabras),
    frase_conocida(Palabras, _),
    !.
validar_frase(Texto, _, ok, Palabras) :-
    palabras_utiles(Texto, Palabras).

% R67. registrar_frase(+Palabras, +Elemento): agrega la expresion con assertz/1
%      (idempotente; tambien la usa la carga del archivo).
registrar_frase(Palabras, Elemento) :-
    frase_aprendida(Palabras, Elemento),
    !.
registrar_frase(Palabras, Elemento) :-
    assertz(frase_aprendida(Palabras, Elemento)).

% registrar_frase_de_nombre(+Elemento, +Nombre): un sintoma aprendido se puede describir
%   con sus propias palabras desde el momento en que se agrega.
registrar_frase_de_nombre(Elemento, Nombre) :-
    palabras_utiles(Nombre, Palabras),
    Palabras = [_|_],
    \+ frase_conocida(Palabras, _),
    !,
    registrar_frase(Palabras, Elemento).
registrar_frase_de_nombre(_, _).

% R68. aprender_frase(+Texto, +Elemento, -Estado, -Mensaje)
aprender_frase(Texto, Elemento, Estado, Mensaje) :-
    validar_frase(Texto, Elemento, Estado, Palabras),
    (   Estado == ok
    ->  registrar_frase(Palabras, Elemento),
        guardar_aprendizaje
    ;   true
    ),
    mensaje_de_frase(Estado, Palabras, Mensaje).

mensaje_de_frase(frase_ambigua, Palabras, Mensaje) :-
    !,
    frase_conocida(Palabras, Otro),
    etiqueta(Otro, Nombre),
    format(atom(Mensaje),
           'Esa expresión ya existe y significa «~w». Use otra o corrija la existente.',
           [Nombre]).
mensaje_de_frase(Estado, _, Mensaje) :-
    mensaje_aprendizaje(Estado, Mensaje).

% olvidar_frase(+Texto, -Estado, -Mensaje): solo expresiones que se ensenaron.
olvidar_frase(Texto, ok, Mensaje) :-
    palabras_utiles(Texto, Palabras),
    frase_aprendida(Palabras, _),
    !,
    retractall(frase_aprendida(Palabras, _)),
    guardar_aprendizaje,
    mensaje_aprendizaje(ok, Mensaje).
olvidar_frase(_, no_aprendida, Mensaje) :-
    mensaje_aprendizaje(no_aprendida, Mensaje).

% listar_frases_aprendidas(-Lista): [[Texto, Elemento, Nombre], ...]
listar_frases_aprendidas(Lista) :-
    findall([Texto, Elemento, Nombre],
            (   frase_aprendida(Palabras, Elemento),
                atomic_list_concat(Palabras, ' ', Texto),
                etiqueta(Elemento, Nombre)
            ),
            Lista).

% =====================================================================
%  SECCION 25. LECTURAS NUMERICAS -> NIVELES -> HECHOS
%  Python (scikit-learn) convierte una medida continua en un nivel discreto
%  (bajo / normal / alto). Prolog decide que hecho simbolico significa cada nivel.
% =====================================================================

% variable_lectura(Variable, Unidad, Minimo, Maximo, Descripcion)
variable_lectura(temperatura_motor, '°C',  0, 200, 'Temperatura del motor').
variable_lectura(voltaje_carga,     'V',   0,  30, 'Voltaje de carga de la batería (motor encendido)').
variable_lectura(holgura_cadena,    'mm',  0, 150, 'Holgura de la cadena').
variable_lectura(distancia_frenado, 'm',   0, 100, 'Distancia de frenado desde 40 km/h').
variable_lectura(consumo_combustible, 'km/l', 0, 100, 'Rendimiento de combustible').

% lectura_nivel(Variable, Nivel, Elemento): que sintoma significa un nivel anormal.
lectura_nivel(temperatura_motor,   alto, temperatura_alta).
lectura_nivel(voltaje_carga,       bajo, bateria_se_descarga_rodando).
lectura_nivel(voltaje_carga,       alto, foco_quemado_frecuente).
lectura_nivel(holgura_cadena,      alto, cadena_holgura_visible).
lectura_nivel(distancia_frenado,   alto, frenada_larga).
lectura_nivel(consumo_combustible, bajo, consumo_alto_gasolina).

% R69. validar_lectura(+Variable, +Valor, -Estado, -Mensaje)
validar_lectura(Variable, _, variable_desconocida, Mensaje) :-
    \+ variable_lectura(Variable, _, _, _, _),
    !,
    mensaje_aprendizaje(variable_desconocida, Mensaje).
validar_lectura(_, Valor, lectura_invalida, Mensaje) :-
    \+ number(Valor),
    !,
    mensaje_aprendizaje(lectura_invalida, Mensaje).
validar_lectura(Variable, Valor, fuera_de_rango, Mensaje) :-
    variable_lectura(Variable, Unidad, Minimo, Maximo, Descripcion),
    ( Valor < Minimo ; Valor > Maximo ),
    !,
    format(atom(Mensaje), '~w debe estar entre ~w y ~w ~w.',
           [Descripcion, Minimo, Maximo, Unidad]).
validar_lectura(_, _, ok, '').

% R70. hecho_de_lectura(+Variable, +Nivel, -Elemento): falla si el nivel es normal.
hecho_de_lectura(Variable, Nivel, Elemento) :-
    lectura_nivel(Variable, Nivel, Elemento).

% variables_lectura(-Lista): [[Variable, Unidad, Minimo, Maximo, Descripcion], ...]
variables_lectura(Lista) :-
    findall([Variable, Unidad, Minimo, Maximo, Descripcion],
            variable_lectura(Variable, Unidad, Minimo, Maximo, Descripcion),
            Lista).
