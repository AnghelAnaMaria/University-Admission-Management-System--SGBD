--Ex 8) Cod Tabela "mesaje":
CREATE TABLE mesaje (
    cod_mesaj NUMBER CONSTRAINT pk_mesaje PRIMARY KEY,
    mesaj     VARCHAR2(255),
    tip_mesaj VARCHAR2(1)
        CONSTRAINT chk_tip_mesaj CHECK (tip_mesaj IN ('E', 'W', 'I')),
    creat_de  VARCHAR2(40) NOT NULL,
    creat_la  DATE NOT NULL
);

--TRUNCATE TABLE mesaje;

--secventa
--ALTER SEQUENCE seq_mesaje RESTART START WITH 1;
CREATE SEQUENCE seq_mesaje START WITH 1 INCREMENT BY 1;

--trigger
CREATE OR REPLACE TRIGGER trg_mesaje_bir
BEFORE INSERT ON mesaje
FOR EACH ROW
BEGIN
    IF :NEW.cod_mesaj IS NULL THEN
        :NEW.cod_mesaj := seq_mesaje.NEXTVAL;
    END IF;
END;
/

CREATE OR REPLACE PROCEDURE log_mesaj(
    p_text IN VARCHAR2,
    p_tip  IN CHAR
) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO MESAJE (mesaj, tip_mesaj, creat_de, creat_la)
    VALUES (SUBSTR(p_text, 1, 255), p_tip, USER, SYSDATE);

    COMMIT;
END log_mesaj;
/

--testare trigger pt generare id
INSERT INTO mesaje (mesaj, tip_mesaj, creat_de, creat_la)
VALUES ('Test trigger auto-numerotare', 'I', USER, SYSDATE);

SELECT * FROM mesaje ORDER BY cod_mesaj;

--comentarii
COMMENT ON COLUMN mesaje.cod_mesaj IS 'Cheie primara';
COMMENT ON COLUMN mesaje.tip_mesaj IS
'Valori valide: E - Eroare, W - Avertisment, I - Informatie';
COMMENT ON COLUMN mesaje.creat_de IS 'NOT NULL';
COMMENT ON COLUMN mesaje.creat_la IS 'NOT NULL';


SELECT column_name, comments
FROM user_col_comments
WHERE table_name = 'MESAJE'
ORDER BY column_name;

SELECT constraint_name, constraint_type, search_condition
FROM user_constraints
WHERE table_name = 'MESAJE';

SELECT column_name, nullable
FROM user_tab_columns
WHERE table_name = 'MESAJE'
ORDER BY column_name;


--Ex 9.1
CREATE OR REPLACE PROCEDURE raport_admitere_complet IS
    TYPE t_praguri IS VARRAY(4) OF NUMBER;
    v_praguri t_praguri := t_praguri(9, 7, 5, 0);

    TYPE t_calificative IS VARRAY(4) OF VARCHAR2(20);
    v_calificative t_calificative := t_calificative('Excelent', 'Bine', 'Satisfacator', 'Slab');

    TYPE t_cache_aprobate IS TABLE OF NUMBER INDEX BY VARCHAR2(150);
    v_cache_aprobate t_cache_aprobate;

    TYPE t_candidat_admis IS RECORD (
        id_candidat  NUMBER,
        nume_complet VARCHAR2(102),
        nota         NUMBER,
        program      VARCHAR2(150)
    );
    TYPE t_lista_admisi IS TABLE OF t_candidat_admis;
    v_admisi_program t_lista_admisi;                    --lot per program (BULK COLLECT)
    v_toti_admisii   t_lista_admisi := t_lista_admisi(); --colectia globala, cumulativa

    --colectie auxiliara pentru programele de studiu
    TYPE t_program_rec IS RECORD (
        id_program NUMBER,
        denumire   VARCHAR2(150),
        nr_locuri  NUMBER
    );
    TYPE t_programe_tab IS TABLE OF t_program_rec;
    v_programe t_programe_tab;

    v_medie        NUMBER;
    v_nr_aprobate  NUMBER;
    v_calificativ  VARCHAR2(20);
    v_idx_start    NUMBER;

BEGIN
    SELECT id_program, denumire, nr_locuri
    BULK COLLECT INTO v_programe
    FROM PROGRAM_STUDIU
    ORDER BY denumire;

    --parcurgere rezultat din BULK COLLECT care e dens
    FOR i IN v_programe.FIRST..v_programe.LAST LOOP
        SELECT COUNT(*), NVL(AVG(nota_admitere), 0) --statistici pentru programul curent
        INTO v_nr_aprobate, v_medie
        FROM DOSAR
        WHERE id_program_studiu = v_programe(i).id_program
          AND status_dosar = 'APROBAT';

        v_cache_aprobate(v_programe(i).denumire) := v_nr_aprobate; --retinem in Associative Array

        v_calificativ := v_calificative(v_calificative.LAST); 
        FOR p IN v_praguri.FIRST..v_praguri.LAST LOOP
            IF v_medie >= v_praguri(p) THEN
                v_calificativ := v_calificative(p);
                EXIT;
            END IF;
        END LOOP;

        --afisare informatii program
        DBMS_OUTPUT.PUT_LINE('Program: ' || v_programe(i).denumire);
        DBMS_OUTPUT.PUT_LINE('  Dosare aprobate: ' || v_nr_aprobate || ' / ' || v_programe(i).nr_locuri || ' locuri');
        DBMS_OUTPUT.PUT_LINE('  Media notelor: ' || ROUND(v_medie, 2) || '   Calificativ: ' || v_calificativ);

        SELECT c.id_candidat, c.nume || ' ' || c.prenume, d.nota_admitere, v_programe(i).denumire
        BULK COLLECT INTO v_admisi_program
        FROM DOSAR d
        JOIN CANDIDAT c ON c.id_candidat = d.id_candidat
        WHERE d.id_program_studiu = v_programe(i).id_program
          AND d.status_dosar = 'APROBAT'
        ORDER BY d.nota_admitere DESC;

        IF v_admisi_program.COUNT > 0 THEN
            DBMS_OUTPUT.PUT_LINE('  Candidati admisi:');
            FOR j IN 1..v_admisi_program.COUNT LOOP
                DBMS_OUTPUT.PUT_LINE('    - ' || v_admisi_program(j).nume_complet ||' (nota: ' || v_admisi_program(j).nota || ')');
            END LOOP;

            --adaugare candidati admisi in colectia globala
            v_idx_start := v_toti_admisii.COUNT + 1;
            v_toti_admisii.EXTEND(v_admisi_program.COUNT);
            FOR j IN 1..v_admisi_program.COUNT LOOP
                v_toti_admisii(v_idx_start + j - 1) := v_admisi_program(j);
            END LOOP;
        ELSE
            DBMS_OUTPUT.PUT_LINE('  Niciun candidat admis momentan.');
        END IF;

        DBMS_OUTPUT.PUT_LINE(' ');
    END LOOP;

    --afisare sumar pt fiecare program de studiu
    DECLARE
        v_prog VARCHAR2(150);
    BEGIN
        v_prog := v_cache_aprobate.FIRST;
        WHILE v_prog IS NOT NULL LOOP
            DBMS_OUTPUT.PUT_LINE('  ' || v_prog || ': ' || v_cache_aprobate(v_prog) || ' dosare aprobate');
            v_prog := v_cache_aprobate.NEXT(v_prog);
        END LOOP;
    END;

    DBMS_OUTPUT.PUT_LINE(' ');
    DBMS_OUTPUT.PUT_LINE('Total candidati admisi (toate programele): ' ||v_toti_admisii.COUNT);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Nu exista date de raportat.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Eroare neasteptata: ' || SQLERRM);
END raport_admitere_complet;
/
SET SERVEROUTPUT ON;
EXEC raport_admitere_complet;



--Ex 9.2
CREATE OR REPLACE PROCEDURE p_log_acoperire_probe IS
    --toate dosarele, cu date de candidat si program
    CURSOR c_dosare IS
        SELECT d.id_dosar, d.id_candidat, d.id_program_studiu,
               d.nota_admitere,
               c.nume, c.prenume,
               p.denumire AS program
        FROM   DOSAR d
        JOIN   CANDIDAT c ON c.id_candidat = d.id_candidat
        JOIN   PROGRAM_STUDIU p ON p.id_program = d.id_program_studiu
        ORDER BY d.id_dosar;

    v_id_dosar      DOSAR.id_dosar%TYPE;
    v_id_candidat   DOSAR.id_candidat%TYPE;
    v_id_program    DOSAR.id_program_studiu%TYPE;
    v_nota_admitere DOSAR.nota_admitere%TYPE;
    v_nume          CANDIDAT.nume%TYPE;
    v_prenume       CANDIDAT.prenume%TYPE;
    v_program       PROGRAM_STUDIU.denumire%TYPE;

    CURSOR c_probe_candidat(p_id_candidat CANDIDAT.id_candidat%TYPE,
                             p_id_program PROGRAM_STUDIU.id_program%TYPE) IS
        SELECT pa.denumire AS proba, tp.tip AS tip_proba, tp.pondere
        FROM   SE_INSCRIE_LA sil
        JOIN   PROBA_ADMITERE pa ON pa.id_proba = sil.id_proba
        JOIN   TIP_PROBA tp ON tp.id_tip = pa.id_tip
        WHERE  sil.id_candidat = p_id_candidat
          AND  sil.id_program_studiu = p_id_program;

    v_proba      PROBA_ADMITERE.denumire%TYPE;
    v_tip_proba  TIP_PROBA.tip%TYPE;
    v_pondere    TIP_PROBA.pondere%TYPE;
    v_sum_pond   NUMBER;
    v_nr_probe   NUMBER;

    v_total_dosare  NUMBER := 0;
    c_toleranta CONSTANT NUMBER := 0.01;

BEGIN
    SELECT COUNT(*) INTO v_total_dosare FROM DOSAR;
    DBMS_OUTPUT.PUT_LINE('Incepe procesarea a ' || v_total_dosare || ' dosare...');

    OPEN c_dosare;
    LOOP
        FETCH c_dosare INTO v_id_dosar, v_id_candidat, v_id_program,
                             v_nota_admitere, v_nume, v_prenume, v_program;
        EXIT WHEN c_dosare%NOTFOUND;

        v_sum_pond := 0;
        v_nr_probe := 0;

        OPEN c_probe_candidat(v_id_candidat, v_id_program);
        LOOP
            FETCH c_probe_candidat INTO v_proba, v_tip_proba, v_pondere;
            EXIT WHEN c_probe_candidat%NOTFOUND;

            v_sum_pond := v_sum_pond + NVL(v_pondere, 0);
            v_nr_probe := v_nr_probe + 1;
        END LOOP;
        CLOSE c_probe_candidat;

        IF v_nr_probe = 0 THEN
            log_mesaj(
                'Dosar ' || v_id_dosar || ' (' || v_nume || ' ' || v_prenume ||
                ', ' || v_program || '): candidatul nu este inscris la nicio proba.',
                'W'
            );

        ELSIF ABS(v_sum_pond - 1) > c_toleranta THEN
            log_mesaj(
                'Dosar ' || v_id_dosar || ' (' || v_nume || ' ' || v_prenume ||
                ', ' || v_program || '): acoperire incompleta a probelor, ' ||
                'pondere totala = ' || TO_CHAR(v_sum_pond, 'FM0.00') ||
                ' (asteptat 1.00), ' || v_nr_probe || ' probe inscrise.',
                'W'
            );

        ELSE
            log_mesaj(
                'Dosar ' || v_id_dosar || ' (' || v_nume || ' ' || v_prenume ||
                ', ' || v_program || '): probe complet acoperite (pondere = 1.00), ' ||
                'nota admitere = ' ||
                NVL(TO_CHAR(v_nota_admitere, 'FM0.00'), 'nesetata') || '.',
                'I'
            );
        END IF;

    END LOOP;
    CLOSE c_dosare;

    DBMS_OUTPUT.PUT_LINE('Procesare finalizata.');
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        IF c_dosare%ISOPEN THEN
            CLOSE c_dosare;
        END IF;
        IF c_probe_candidat%ISOPEN THEN
            CLOSE c_probe_candidat;
        END IF;

        DBMS_OUTPUT.PUT_LINE('Eroare in timpul procesarii: ' || SQLERRM);

        log_mesaj(
            'Eroare in p_log_acoperire_probe' ||
            CASE WHEN v_id_dosar IS NOT NULL
                 THEN ' (ultimul dosar procesat: ' || v_id_dosar || ')'
                 ELSE NULL
            END ||
            ': ' || SQLERRM,
            'E'
        );

        RAISE;
END p_log_acoperire_probe;
/

EXEC p_log_acoperire_probe;

SELECT cod_mesaj, mesaj, tip_mesaj, creat_la
FROM MESAJE
ORDER BY cod_mesaj;

--Ex 9.3
CREATE OR REPLACE TYPE t_proba_rezultat AS OBJECT (
    id_candidat   NUMBER,
    id_program    NUMBER,
    cod_rezultat  VARCHAR2(10),
    mesaj         VARCHAR2(300),
    proba         VARCHAR2(150),
    tip_proba     VARCHAR2(50),
    pondere       NUMBER(3,2)
);
/

CREATE OR REPLACE TYPE t_proba_tab AS TABLE OF t_proba_rezultat;
/

CREATE OR REPLACE FUNCTION f_probe_candidat_pipe(
    p_id_candidat IN CANDIDAT.id_candidat%TYPE,
    p_id_program  IN PROGRAM_STUDIU.id_program%TYPE
) RETURN t_proba_tab PIPELINED
IS
    --exceptii proprii
    ex_parametri_invalizi  EXCEPTION;
    ex_candidat_inexistent EXCEPTION;
    ex_program_inexistent  EXCEPTION;

    PRAGMA EXCEPTION_INIT(ex_parametri_invalizi,  -20001);
    PRAGMA EXCEPTION_INIT(ex_candidat_inexistent, -20002);
    PRAGMA EXCEPTION_INIT(ex_program_inexistent,  -20003);

    v_cnt            NUMBER;
    v_gasit          BOOLEAN := FALSE;
    v_nota_admitere  DOSAR.nota_admitere%TYPE;
    v_nr_locuri      PROGRAM_STUDIU.nr_locuri%TYPE;
    v_nr_aprobate    NUMBER;
    v_rata_ocupare   NUMBER;

    --subprogram local fara sectiune EXCEPTION proprie
    --daca declanseaza eroarea, aceasta se propaga automat catre blocul apelant
    PROCEDURE verifica_parametri(
        p_cand IN NUMBER,
        p_prog IN NUMBER
    ) IS
    BEGIN
        IF p_cand IS NULL OR p_cand <= 0 OR p_prog IS NULL OR p_prog <= 0 THEN
            RAISE_APPLICATION_ERROR( -20001, 'Parametri invalizi: candidat=' || p_cand || ', program=' || p_prog);
        END IF;
    END verifica_parametri;

BEGIN

    verifica_parametri(p_id_candidat, p_id_program);

    SELECT COUNT(*) INTO v_cnt FROM CANDIDAT WHERE id_candidat = p_id_candidat;
    IF v_cnt = 0 THEN
        RAISE ex_candidat_inexistent;
    END IF;

    --raise cu procedura predefinita Oracle
    SELECT COUNT(*) INTO v_cnt FROM PROGRAM_STUDIU WHERE id_program = p_id_program;
    IF v_cnt = 0 THEN
        RAISE_APPLICATION_ERROR( -20003, 'Programul de studiu cu id ' || p_id_program || ' nu exista.'
        );
    END IF;

    --pentru calculul ratei de ocupare (folosit mai jos)
    SELECT nr_locuri INTO v_nr_locuri
    FROM PROGRAM_STUDIU
    WHERE id_program = p_id_program;


    --verificare pe DOSAR: relatie GARANTATA de UNIQUE(id_candidat, id_program_studiu)
    --0 randuri  -> NO_DATA_FOUND  (candidatul nu a depus dosar pt acest program)
    --2+ randuri -> TOO_MANY_ROWS  (imposibil structural, doar plasa defensiva)
    SELECT nota_admitere INTO v_nota_admitere
    FROM DOSAR
    WHERE id_candidat = p_id_candidat
      AND id_program_studiu = p_id_program;

    --comanda SQL pe 3 tabele (cerinta principala)
    FOR r IN (
        SELECT pa.denumire AS proba, tp.tip AS tip_proba, tp.pondere
        FROM   SE_INSCRIE_LA sil
        JOIN   PROBA_ADMITERE pa ON pa.id_proba = sil.id_proba
        JOIN   TIP_PROBA tp      ON tp.id_tip   = pa.id_tip
        WHERE  sil.id_candidat       = p_id_candidat
          AND  sil.id_program_studiu = p_id_program
    ) LOOP
        v_gasit := TRUE;
        PIPE ROW (t_proba_rezultat( p_id_candidat, p_id_program, 'OK',
            'Inscriere gasita. Nota admitere (dosar): ' ||
            NVL(TO_CHAR(v_nota_admitere, 'FM0.00'), 'nesetata') || '.',
            r.proba, r.tip_proba, r.pondere ));
    END LOOP;

    IF NOT v_gasit THEN
        PIPE ROW (t_proba_rezultat( p_id_candidat, p_id_program, 'INFO',
            'Candidatul are dosar depus, dar nu este inscris la nicio proba pentru acest program.',
            NULL, NULL, NULL));
    END IF;

    --ZERO_DIVIDE daca v_nr_locuri = 0
    --CHECK-ul din PROGRAM_STUDIU garanteaza nr_locuri > 0, dar tratam oricum cazul ca practica corecta
    SELECT COUNT(*) INTO v_nr_aprobate
    FROM DOSAR
    WHERE id_program_studiu = p_id_program AND status_dosar = 'APROBAT';

    v_rata_ocupare := v_nr_aprobate / v_nr_locuri;

    RETURN;

EXCEPTION

    WHEN ex_parametri_invalizi THEN
        log_mesaj('[propagata din verifica_parametri] ' || SQLERRM, 'E');
        PIPE ROW (t_proba_rezultat( p_id_candidat, p_id_program, 'EROARE',
            'Parametrii id_candidat si id_program trebuie sa fie numere pozitive.', NULL, NULL, NULL));
        RETURN;

    WHEN ex_candidat_inexistent THEN
        log_mesaj('Candidat inexistent [' || SQLCODE || ']: id=' || p_id_candidat, 'E');
        PIPE ROW (t_proba_rezultat( p_id_candidat, p_id_program, 'EROARE',
            'Candidatul cu id ' || p_id_candidat || ' nu exista.', NULL, NULL, NULL ));
        RETURN;

    WHEN ex_program_inexistent THEN
        log_mesaj('[RAISE_APPLICATION_ERROR direct] ' || SQLERRM, 'E');
        PIPE ROW (t_proba_rezultat( p_id_candidat, p_id_program, 'EROARE',
            'Programul de studiu cu id ' || p_id_program || ' nu exista.', NULL, NULL, NULL));
        RETURN;

    WHEN NO_DATA_FOUND THEN
        log_mesaj('NO_DATA_FOUND: candidatul ' || p_id_candidat ||
                   ' nu a depus dosar pentru programul ' || p_id_program || '.', 'I');
        PIPE ROW (t_proba_rezultat( p_id_candidat, p_id_program, 'EROARE',
            'Candidatul nu are dosar depus pentru acest program de studiu.', NULL, NULL, NULL));
        RETURN;

    WHEN TOO_MANY_ROWS THEN
        log_mesaj('TOO_MANY_ROWS: candidatul ' || p_id_candidat ||
                   ' are mai multe dosare pentru programul ' || p_id_program ||
                   ' - incalcare a constrangerii UNIQUE, verificati integritatea datelor.', 'E');
        PIPE ROW (t_proba_rezultat( p_id_candidat, p_id_program, 'EROARE',
            'Date inconsistente: mai multe dosare gasite pentru aceeasi combinatie candidat-program.',
            NULL, NULL, NULL));
        RETURN;

    WHEN ZERO_DIVIDE THEN
        log_mesaj('ZERO_DIVIDE: nr_locuri = 0 pentru programul ' || p_id_program, 'E');
        PIPE ROW (t_proba_rezultat( p_id_candidat, p_id_program, 'EROARE',
            'Programul are 0 locuri definite - imposibil de calculat rata de ocupare.', NULL, NULL, NULL));
        RETURN;

    WHEN OTHERS THEN
        log_mesaj('Eroare neasteptata [' || SQLCODE || ']: ' || SQLERRM ||
                   ' (candidat=' || p_id_candidat || ', program=' || p_id_program || ')', 'E');
        PIPE ROW (t_proba_rezultat( p_id_candidat, p_id_program, 'EROARE',
            'Eroare neasteptata: ' || SQLERRM, NULL, NULL, NULL));
        RETURN;
END f_probe_candidat_pipe;
/

--bloc testare
SELECT object_name, object_type, status
FROM user_objects
WHERE object_name IN ('T_PROBA_REZULTAT', 'T_PROBA_TAB', 'LOG_MESAJ', 'F_PROBE_CANDIDAT_PIPE')
ORDER BY object_type;

INSERT INTO PROGRAM_STUDIU (id_program, denumire, forma_invatamant, nivel, durata_ani, nr_locuri)
VALUES (99, 'Program test fara facultate', 'IF', 'Licenta', 3, 10);
COMMIT;

SELECT 'Caz1_NULL' caz, t.* FROM TABLE(f_probe_candidat_pipe(NULL, 1)) t
UNION ALL SELECT 'Caz2_negativ',         t.* FROM TABLE(f_probe_candidat_pipe(-5, 1)) t
UNION ALL SELECT 'Caz3_cand_inexistent', t.* FROM TABLE(f_probe_candidat_pipe(999, 1)) t
UNION ALL SELECT 'Caz4_prog_inexistent', t.* FROM TABLE(f_probe_candidat_pipe(1, 999)) t
UNION ALL SELECT 'Caz5_fara_dosar',      t.* FROM TABLE(f_probe_candidat_pipe(2, 2)) t   --candidatul 2 nu are dosar la programul 2
UNION ALL SELECT 'Caz6_OK',              t.* FROM TABLE(f_probe_candidat_pipe(1, 1)) t   --candidatul 1, dosar 1, inscris la 2 probe
UNION ALL SELECT 'Caz7_INFO',            t.* FROM TABLE(f_probe_candidat_pipe(6, 4)) t;   --candidatul 6, dosar 6 la program 4, dar 0 inscrieri la probele de admitere

SELECT cod_mesaj, mesaj, tip_mesaj, creat_de, creat_la
FROM MESAJE
ORDER BY creat_la DESC;

--Ex 9.4
--Sol 1: trigger comanda, trigger linie si pachet:
CREATE OR REPLACE PACKAGE pkg_verif_max_dosare AS
    PROCEDURE reset_context;
    PROCEDURE marcheaza_candidat(p_id_candidat IN NUMBER);
    PROCEDURE verifica_limite;
END pkg_verif_max_dosare;
/

CREATE OR REPLACE PACKAGE BODY pkg_verif_max_dosare AS
    c_max_dosare CONSTANT NUMBER := 3;

    TYPE t_set_candidati IS TABLE OF BOOLEAN INDEX BY PLS_INTEGER;
    v_candidati_atinsi t_set_candidati;

    PROCEDURE reset_context IS
    BEGIN
        v_candidati_atinsi.DELETE;
    END reset_context;

    PROCEDURE marcheaza_candidat(p_id_candidat IN NUMBER) IS
    BEGIN
        IF p_id_candidat IS NOT NULL THEN
            v_candidati_atinsi(p_id_candidat) := TRUE;
        END IF;
    END marcheaza_candidat;

    PROCEDURE verifica_limite IS
        v_id_candidat  PLS_INTEGER;
        v_nr_dosare    NUMBER;
        v_nume_complet VARCHAR2(102);
    BEGIN
        v_id_candidat := v_candidati_atinsi.FIRST;
        WHILE v_id_candidat IS NOT NULL LOOP
            SELECT COUNT(*) INTO v_nr_dosare --numaram dosarele fiecarui candidat
            FROM DOSAR
            WHERE id_candidat = v_id_candidat;

            IF v_nr_dosare > c_max_dosare THEN
                SELECT nume || ' ' || prenume INTO v_nume_complet
                FROM CANDIDAT
                WHERE id_candidat = v_id_candidat;

                RAISE_APPLICATION_ERROR(-20050,
                    'Candidatul "' || v_nume_complet || '" (id ' || v_id_candidat ||
                    ') ar depasi limita de ' || c_max_dosare || ' dosare depuse ' ||
                    '(curent: ' || v_nr_dosare || ').');
            END IF;

            v_id_candidat := v_candidati_atinsi.NEXT(v_id_candidat);
        END LOOP;

        reset_context;
    END verifica_limite;

END pkg_verif_max_dosare;
/


CREATE OR REPLACE TRIGGER trg_dosar_bef_stmt_max
BEFORE INSERT OR UPDATE OR DELETE ON DOSAR
BEGIN
    pkg_verif_max_dosare.reset_context;
END;
/


CREATE OR REPLACE TRIGGER trg_dosar_aft_row_max
AFTER INSERT OR UPDATE OF id_candidat OR DELETE ON DOSAR
FOR EACH ROW
BEGIN
    IF DELETING THEN
        pkg_verif_max_dosare.marcheaza_candidat(:OLD.id_candidat);
    ELSE
        pkg_verif_max_dosare.marcheaza_candidat(:NEW.id_candidat);

        IF UPDATING AND :OLD.id_candidat IS NOT NULL AND :OLD.id_candidat <> :NEW.id_candidat THEN
            pkg_verif_max_dosare.marcheaza_candidat(:OLD.id_candidat);
        END IF;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_dosar_aft_stmt_max
AFTER INSERT OR UPDATE OR DELETE ON DOSAR
BEGIN
    pkg_verif_max_dosare.verifica_limite;
END;
/

ALTER TRIGGER trg_dosar_max_compound DISABLE;

ALTER TRIGGER trg_dosar_bef_stmt_max ENABLE;
ALTER TRIGGER trg_dosar_aft_row_max ENABLE;
ALTER TRIGGER trg_dosar_aft_stmt_max ENABLE;

--testam
SELECT id_candidat, COUNT(*) AS nr_dosare FROM DOSAR
WHERE id_candidat = 5
GROUP BY id_candidat;

--sincronizam secventa interna de generare a id-ului pt entitatea DOSAR
SELECT MAX(id_dosar) FROM DOSAR;
ALTER TABLE DOSAR MODIFY id_dosar
    GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE);

--aducem candidatul la limita de 3 dosare
INSERT INTO DOSAR (data_depunere, status_dosar, id_candidat, id_program_studiu) VALUES (SYSDATE, 'IN_CURS', 5, 2);
INSERT INTO DOSAR (data_depunere, status_dosar, id_candidat, id_program_studiu) VALUES (SYSDATE, 'IN_CURS', 5, 3);
--al 4-lea dosar 
INSERT INTO DOSAR (data_depunere, status_dosar, id_candidat, id_program_studiu) VALUES (SYSDATE, 'IN_CURS', 5, 4);

SELECT id_dosar, id_candidat, id_program_studiu FROM DOSAR WHERE id_candidat = 5 ORDER BY id_dosar;

--stergem unul dintre cele 3 dosare 
DELETE FROM DOSAR WHERE id_candidat = 5 AND id_program_studiu = 3;

SELECT id_candidat, COUNT(*) AS nr_dosare FROM DOSAR
WHERE id_candidat = 5
GROUP BY id_candidat;

--acum candidatul are din nou 2 dosare si un dosar nou trebuie sa treaca
INSERT INTO DOSAR (data_depunere, status_dosar, id_candidat, id_program_studiu) VALUES (SYSDATE, 'IN_CURS', 5, 5);

SELECT id_dosar, id_candidat, id_program_studiu FROM DOSAR WHERE id_candidat = 5 ORDER BY id_dosar;

ROLLBACK;


--Ex 9.4
--Sol 2 cu COMPOUND TRIGGER:
CREATE OR REPLACE TRIGGER trg_dosar_max_compound
FOR INSERT OR UPDATE OR DELETE ON DOSAR
COMPOUND TRIGGER
    c_max_dosare CONSTANT NUMBER := 3;

    TYPE t_set_candidati IS TABLE OF BOOLEAN INDEX BY PLS_INTEGER;
    v_candidati_atinsi t_set_candidati;

    BEFORE STATEMENT IS
    BEGIN
        v_candidati_atinsi.DELETE;
    END BEFORE STATEMENT;

    AFTER EACH ROW IS
    BEGIN
        IF DELETING THEN
            IF :OLD.id_candidat IS NOT NULL THEN
                v_candidati_atinsi(:OLD.id_candidat) := TRUE;
            END IF;
        ELSE
            IF :NEW.id_candidat IS NOT NULL THEN
                v_candidati_atinsi(:NEW.id_candidat) := TRUE;
            END IF;

            IF UPDATING AND :OLD.id_candidat IS NOT NULL AND :OLD.id_candidat <> :NEW.id_candidat THEN
                v_candidati_atinsi(:OLD.id_candidat) := TRUE;
            END IF;
        END IF;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
        v_id_candidat  PLS_INTEGER;
        v_nr_dosare    NUMBER;
        v_nume_complet VARCHAR2(102);
    BEGIN
        v_id_candidat := v_candidati_atinsi.FIRST;
        WHILE v_id_candidat IS NOT NULL LOOP
            SELECT COUNT(*) INTO v_nr_dosare
            FROM DOSAR
            WHERE id_candidat = v_id_candidat;

            IF v_nr_dosare > c_max_dosare THEN
                SELECT nume || ' ' || prenume INTO v_nume_complet
                FROM CANDIDAT
                WHERE id_candidat = v_id_candidat;

                RAISE_APPLICATION_ERROR(-20050,
                    'Candidatul "' || v_nume_complet || '" (id ' || v_id_candidat ||
                    ') ar depasi limita de ' || c_max_dosare || ' dosare depuse ' ||
                    '(curent: ' || v_nr_dosare || ').');
            END IF;

            v_id_candidat := v_candidati_atinsi.NEXT(v_id_candidat);
        END LOOP;
    END AFTER STATEMENT;

END trg_dosar_max_compound;
/

--testare
SELECT id_candidat, COUNT(*) AS nr_dosare FROM DOSAR
WHERE id_candidat = 6
GROUP BY id_candidat;

--aducem la limita de dosare
INSERT INTO DOSAR (data_depunere, status_dosar, id_candidat, id_program_studiu) VALUES (SYSDATE, 'IN_CURS', 6, 1);
INSERT INTO DOSAR (data_depunere, status_dosar, id_candidat, id_program_studiu) VALUES (SYSDATE, 'IN_CURS', 6, 2);

--al 4-lea dosar
INSERT INTO DOSAR (data_depunere, status_dosar, id_candidat, id_program_studiu) VALUES (SYSDATE, 'IN_CURS', 6, 3);

SELECT id_dosar, id_candidat, id_program_studiu FROM DOSAR WHERE id_candidat = 6 ORDER BY id_dosar;

--stergem un dosar/ eliberam un loc
DELETE FROM DOSAR WHERE id_candidat = 6 AND id_program_studiu = 2;

SELECT id_candidat, COUNT(*) AS nr_dosare FROM DOSAR
WHERE id_candidat = 6
GROUP BY id_candidat;

--acum trebuie sa treaca un dosar nou
INSERT INTO DOSAR (data_depunere, status_dosar, id_candidat, id_program_studiu) VALUES (SYSDATE, 'IN_CURS', 6, 3);

SELECT id_dosar, id_candidat, id_program_studiu FROM DOSAR WHERE id_candidat = 6 ORDER BY id_dosar;

ROLLBACK; 

ALTER TRIGGER trg_dosar_bef_stmt_max DISABLE;
ALTER TRIGGER trg_dosar_aft_row_max DISABLE;
ALTER TRIGGER trg_dosar_aft_stmt_max DISABLE;

ALTER TRIGGER trg_dosar_max_compound ENABLE;

SELECT object_name, object_type, status
FROM user_objects
WHERE object_name IN (
    'PKG_VERIF_MAX_DOSARE',
    'TRG_DOSAR_BEF_STMT_MAX','TRG_DOSAR_AFT_ROW_MAX','TRG_DOSAR_AFT_STMT_MAX',
    'TRG_DOSAR_MAX_COMPOUND'
)
ORDER BY object_type, object_name;

SELECT trigger_name, triggering_event, status
FROM user_triggers
WHERE table_name = 'DOSAR'
  AND trigger_name LIKE '%MAX%'
ORDER BY trigger_name;

--Ex 9.4
--Instead of trigger

--tabelele copie
CREATE TABLE nou_candidat (
    id_candidat     NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY,
    nume            VARCHAR2(50) NOT NULL,
    prenume         VARCHAR2(50) NOT NULL,
    email           VARCHAR2(100) NOT NULL,
    medie_generala  NUMBER(4,2),   --media notelor de admitere 
    CONSTRAINT pk_nou_candidat PRIMARY KEY (id_candidat),
    CONSTRAINT uq_nou_candidat_email UNIQUE (email)
);

CREATE TABLE nou_dosar (
    id_dosar           NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY,
    data_depunere      DATE NOT NULL,
    status_dosar       VARCHAR2(20) DEFAULT 'IN_CURS' NOT NULL,
    nota_admitere      NUMBER(4,2),
    id_candidat        NUMBER NOT NULL,
    id_program_studiu  NUMBER NOT NULL,
    CONSTRAINT pk_nou_dosar PRIMARY KEY (id_dosar),
    CONSTRAINT fk_nou_dosar_candidat FOREIGN KEY (id_candidat)
        REFERENCES nou_candidat(id_candidat)
        ON DELETE CASCADE
);

INSERT INTO nou_candidat (id_candidat, nume, prenume, email, medie_generala)
SELECT c.id_candidat, c.nume, c.prenume, c.email,
       (SELECT ROUND(AVG(d.nota_admitere), 2) FROM DOSAR d
        WHERE d.id_candidat = c.id_candidat AND d.nota_admitere IS NOT NULL)
FROM CANDIDAT c;

INSERT INTO nou_dosar (id_dosar, data_depunere, status_dosar, nota_admitere, id_candidat, id_program_studiu)
SELECT id_dosar, data_depunere, status_dosar, nota_admitere, id_candidat, id_program_studiu
FROM DOSAR;

COMMIT;

--sincronizam secventele identity cu datele copiate manual 
ALTER TABLE nou_candidat MODIFY id_candidat GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE nou_dosar MODIFY id_dosar GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE);

--pentru a crea un view m-am conectat ca administrator al bazei de date si am oferit schemei MARIA privilegiu pentru a crea vizualizari.
SELECT * FROM session_privs WHERE privilege LIKE '%VIEW%';

--vizualizarea 
CREATE OR REPLACE VIEW vi_dosar_candidat AS
SELECT d.id_dosar, d.data_depunere, d.status_dosar, d.nota_admitere,
       d.id_program_studiu,
       c.id_candidat, c.nume, c.prenume, c.email, c.medie_generala
FROM nou_dosar d
JOIN nou_candidat c ON c.id_candidat = d.id_candidat;

SELECT * FROM vi_dosar_candidat ORDER BY id_dosar;

--trigger INSTEAD OF pt INSERT
--id_candidat e generat automat (IDENTITY)
--verificam daca avem un candidat nou, uitandu-ne la campul email care e unique
CREATE OR REPLACE TRIGGER trg_vi_dosar_candidat_insert
INSTEAD OF INSERT ON vi_dosar_candidat
DECLARE
    v_id_candidat NUMBER;
BEGIN
    BEGIN
        SELECT id_candidat INTO v_id_candidat
        FROM nou_candidat
        WHERE email = :NEW.email;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            INSERT INTO nou_candidat (nume, prenume, email, medie_generala)
            VALUES (:NEW.nume, :NEW.prenume, :NEW.email, :NEW.medie_generala)
            RETURNING id_candidat INTO v_id_candidat; --id generat automat
    END;

    INSERT INTO nou_dosar (data_depunere, status_dosar, nota_admitere, id_candidat, id_program_studiu)
    VALUES (NVL(:NEW.data_depunere, SYSDATE), NVL(:NEW.status_dosar, 'IN_CURS'), :NEW.nota_admitere, v_id_candidat, :NEW.id_program_studiu);
END;
/


--trigger pt update
CREATE OR REPLACE TRIGGER trg_vi_dosar_candidat_update
INSTEAD OF UPDATE ON vi_dosar_candidat
BEGIN
    UPDATE nou_dosar
    SET data_depunere     = :NEW.data_depunere,
        status_dosar      = :NEW.status_dosar,
        nota_admitere     = :NEW.nota_admitere,
        id_program_studiu = :NEW.id_program_studiu
    WHERE id_dosar = :OLD.id_dosar;

    UPDATE nou_candidat
    SET nume           = :NEW.nume,
        prenume        = :NEW.prenume,
        email          = :NEW.email,
        medie_generala = :NEW.medie_generala
    WHERE id_candidat = :OLD.id_candidat;
END;
/


--trigger pt delete
CREATE OR REPLACE TRIGGER trg_vi_dosar_candidat_delete
INSTEAD OF DELETE ON vi_dosar_candidat
DECLARE
    v_alte_dosare NUMBER;
BEGIN
    DELETE FROM nou_dosar WHERE id_dosar = :OLD.id_dosar;

    --candidatul este sters daca nu mai are dosare asociate
     SELECT COUNT(*) INTO v_alte_dosare FROM nou_dosar WHERE id_candidat = :OLD.id_candidat;
     IF v_alte_dosare = 0 THEN
         DELETE FROM nou_candidat WHERE id_candidat = :OLD.id_candidat;
     END IF;
END;
/


--testam insert de candidat si dosar
INSERT INTO vi_dosar_candidat
    (data_depunere, status_dosar, nota_admitere, id_program_studiu, nume, prenume, email, medie_generala)
VALUES
    (DATE '2026-08-19', 'IN_CURS', NULL, 2, 'Popa', 'Vlad', 'vlad.popa@mail.com', NULL);

SELECT * FROM vi_dosar_candidat WHERE email = 'vlad.popa@mail.com';
SELECT * FROM nou_candidat WHERE email = 'vlad.popa@mail.com';
SELECT * FROM nou_dosar
WHERE id_candidat = (SELECT id_candidat FROM nou_candidat WHERE email = 'vlad.popa@mail.com');

--adaugam inca un dosar pt acc candidat
INSERT INTO vi_dosar_candidat
    (data_depunere, status_dosar, nota_admitere, id_program_studiu, nume, prenume, email, medie_generala)
VALUES
    (DATE '2026-08-19', 'IN_CURS', NULL, 4, 'Popa', 'Vlad', 'vlad.popa@mail.com', NULL);

SELECT COUNT(*) AS nr_candidati_vlad FROM nou_candidat WHERE email = 'vlad.popa@mail.com'; --1 candidat
SELECT COUNT(*) AS nr_dosare_vlad
FROM nou_dosar d JOIN nou_candidat c ON c.id_candidat = d.id_candidat
WHERE c.email = 'vlad.popa@mail.com';  --2 dosare


--update la dosarul candidatului
UPDATE vi_dosar_candidat
SET status_dosar = 'APROBAT', nota_admitere = 8.20
WHERE email = 'vlad.popa@mail.com' AND id_program_studiu = 2;

SELECT status_dosar, nota_admitere FROM nou_dosar
WHERE id_candidat = (SELECT id_candidat FROM nou_candidat WHERE email = 'vlad.popa@mail.com')
  AND id_program_studiu = 2;


--update aprobam si al 2-lea dosar
UPDATE vi_dosar_candidat
SET status_dosar = 'APROBAT', nota_admitere = 9.40
WHERE email = 'vlad.popa@mail.com' AND id_program_studiu = 4;

SELECT id_program_studiu, status_dosar, nota_admitere FROM nou_dosar
WHERE id_candidat = (SELECT id_candidat FROM nou_candidat WHERE email = 'vlad.popa@mail.com')
ORDER BY id_program_studiu;


--calculam media reala a notelor din nou_dosar pentru acest candidat
SELECT ROUND(AVG(nota_admitere), 2) AS medie_calculata
FROM nou_dosar
WHERE id_candidat = (SELECT id_candidat FROM nou_candidat WHERE email = 'vlad.popa@mail.com')
  AND nota_admitere IS NOT NULL;

UPDATE vi_dosar_candidat
SET medie_generala = (
    SELECT ROUND(AVG(nota_admitere), 2)
    FROM nou_dosar
    WHERE id_candidat = (SELECT id_candidat FROM nou_candidat WHERE email = 'vlad.popa@mail.com')
      AND nota_admitere IS NOT NULL
)
WHERE email = 'vlad.popa@mail.com' AND id_program_studiu = 2;
--WHERE-ul view-ului cere si id_program_studiu pentru ca vi_dosar_candidat are un rand per dosar, nu per candidat.
--UPDATE-ul de mai sus scrie in nou_candidat, care e unic per candidat, deci efectul se vede pe AMBELE randuri ale 
--candidatului in view.

SELECT medie_generala FROM nou_candidat WHERE email = 'vlad.popa@mail.com';

--9.6
--logheaza comenzile LDD reusite
CREATE OR REPLACE TRIGGER trg_ldd_log
AFTER CREATE OR ALTER OR DROP ON SCHEMA
DECLARE
    v_tip_mesaj VARCHAR2(1);
    v_mesaj     VARCHAR2(255);
    v_eroare    VARCHAR2(255);
BEGIN
    IF SYS.SYSEVENT = 'DROP' THEN
        v_tip_mesaj := 'W'; --pt drop
    ELSE
        v_tip_mesaj := 'I'; --pt create si alter
    END IF;

    v_mesaj := 'Eveniment ' || SYS.SYSEVENT || ' pe obiectul ' || SYS.DICTIONARY_OBJ_NAME;
    INSERT INTO mesaje (mesaj, tip_mesaj, creat_de, creat_la)
    VALUES (SUBSTR(v_mesaj, 1, 255), v_tip_mesaj, SYS.LOGIN_USER, SYSDATE);

EXCEPTION
    WHEN OTHERS THEN
        v_eroare := SQLERRM;  
        BEGIN
            INSERT INTO mesaje (mesaj, tip_mesaj, creat_de, creat_la)
            VALUES ( SUBSTR('Eroare la logare LDD: ' || v_eroare, 1, 255), 'E', SYS.LOGIN_USER, SYSDATE);
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;
END trg_ldd_log;
/

--logheaza orice eroare din schema
CREATE OR REPLACE TRIGGER trg_ldd_erori
AFTER SERVERERROR ON SCHEMA
DECLARE
    v_mesaj VARCHAR2(255);
BEGIN
    v_mesaj := 'Eroare cod ' || SYS.SERVER_ERROR(1) || ': ' || DBMS_UTILITY.FORMAT_ERROR_STACK;
    INSERT INTO mesaje (mesaj, tip_mesaj, creat_de, creat_la)
    VALUES (SUBSTR(v_mesaj, 1, 255), 'E', SYS.LOGIN_USER, SYSDATE);
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END trg_ldd_erori;
/

--teste
CREATE TABLE test_ldd (id NUMBER);
ALTER TABLE test_ldd ADD nume VARCHAR2(50);
DROP TABLE test_ldd;
BEGIN
    RAISE_APPLICATION_ERROR(-20099, 'Eroare de test pentru trigger SERVERERROR');
END;
/
SELECT * FROM mesaje ORDER BY cod_mesaj DESC;

--Ex 9.7
CREATE OR REPLACE PACKAGE pkg_ex9 AS

    PROCEDURE raport_admitere_complet;

    PROCEDURE p_log_acoperire_probe;

    --tipurile raman la nivel de schema
    FUNCTION f_probe_candidat_pipe(
        p_id_candidat IN CANDIDAT.id_candidat%TYPE,
        p_id_program  IN PROGRAM_STUDIU.id_program%TYPE
    ) RETURN t_proba_tab PIPELINED;


    PROCEDURE reset_context;
    PROCEDURE marcheaza_candidat(p_id_candidat IN NUMBER);
    PROCEDURE verifica_limite;


    PROCEDURE demo_raport;
    PROCEDURE demo_acoperire_probe;
    PROCEDURE demo_probe_pipe;
    PROCEDURE demo_max_dosare(p_id_candidat IN NUMBER, p_face_rollback IN BOOLEAN DEFAULT TRUE);
    PROCEDURE demo_view_instead_of;
    PROCEDURE demo_toate;

END pkg_ex9;
/

CREATE OR REPLACE PACKAGE BODY pkg_ex9 AS

    --stare interna pt. verificarea max 3 dosare
    c_max_dosare CONSTANT NUMBER := 3;

    TYPE t_set_candidati IS TABLE OF BOOLEAN INDEX BY PLS_INTEGER;
    v_candidati_atinsi t_set_candidati;

    --Ex 9.1
    PROCEDURE raport_admitere_complet IS
        TYPE t_praguri IS VARRAY(4) OF NUMBER;
        v_praguri t_praguri := t_praguri(9, 7, 5, 0);

        TYPE t_calificative IS VARRAY(4) OF VARCHAR2(20);
        v_calificative t_calificative := t_calificative('Excelent', 'Bine', 'Satisfacator', 'Slab');

        TYPE t_cache_aprobate IS TABLE OF NUMBER INDEX BY VARCHAR2(150);
        v_cache_aprobate t_cache_aprobate;

        TYPE t_candidat_admis IS RECORD (
            id_candidat  NUMBER,
            nume_complet VARCHAR2(102),
            nota         NUMBER,
            program      VARCHAR2(150)
        );
        TYPE t_lista_admisi IS TABLE OF t_candidat_admis;
        v_admisi_program t_lista_admisi;
        v_toti_admisii   t_lista_admisi := t_lista_admisi();

        TYPE t_program_rec IS RECORD (
            id_program NUMBER,
            denumire   VARCHAR2(150),
            nr_locuri  NUMBER
        );
        TYPE t_programe_tab IS TABLE OF t_program_rec;
        v_programe t_programe_tab;

        v_medie        NUMBER;
        v_nr_aprobate  NUMBER;
        v_calificativ  VARCHAR2(20);
        v_idx_start    NUMBER;
    BEGIN
        SELECT id_program, denumire, nr_locuri
        BULK COLLECT INTO v_programe
        FROM PROGRAM_STUDIU
        ORDER BY denumire;

        FOR i IN v_programe.FIRST..v_programe.LAST LOOP
            SELECT COUNT(*), NVL(AVG(nota_admitere), 0)
            INTO v_nr_aprobate, v_medie
            FROM DOSAR
            WHERE id_program_studiu = v_programe(i).id_program
              AND status_dosar = 'APROBAT';

            v_cache_aprobate(v_programe(i).denumire) := v_nr_aprobate;

            v_calificativ := v_calificative(v_calificative.LAST);
            FOR p IN v_praguri.FIRST..v_praguri.LAST LOOP
                IF v_medie >= v_praguri(p) THEN
                    v_calificativ := v_calificative(p);
                    EXIT;
                END IF;
            END LOOP;

            DBMS_OUTPUT.PUT_LINE('Program: ' || v_programe(i).denumire);
            DBMS_OUTPUT.PUT_LINE('  Dosare aprobate: ' || v_nr_aprobate || ' / ' || v_programe(i).nr_locuri || ' locuri');
            DBMS_OUTPUT.PUT_LINE('  Media notelor: ' || ROUND(v_medie, 2) || '   Calificativ: ' || v_calificativ);

            SELECT c.id_candidat, c.nume || ' ' || c.prenume, d.nota_admitere, v_programe(i).denumire
            BULK COLLECT INTO v_admisi_program
            FROM DOSAR d
            JOIN CANDIDAT c ON c.id_candidat = d.id_candidat
            WHERE d.id_program_studiu = v_programe(i).id_program
              AND d.status_dosar = 'APROBAT'
            ORDER BY d.nota_admitere DESC;

            IF v_admisi_program.COUNT > 0 THEN
                DBMS_OUTPUT.PUT_LINE('  Candidati admisi:');
                FOR j IN 1..v_admisi_program.COUNT LOOP
                    DBMS_OUTPUT.PUT_LINE('    - ' || v_admisi_program(j).nume_complet ||' (nota: ' || v_admisi_program(j).nota || ')');
                END LOOP;

                v_idx_start := v_toti_admisii.COUNT + 1;
                v_toti_admisii.EXTEND(v_admisi_program.COUNT);
                FOR j IN 1..v_admisi_program.COUNT LOOP
                    v_toti_admisii(v_idx_start + j - 1) := v_admisi_program(j);
                END LOOP;
            ELSE
                DBMS_OUTPUT.PUT_LINE('  Niciun candidat admis momentan.');
            END IF;

            DBMS_OUTPUT.PUT_LINE(' ');
        END LOOP;

        DECLARE
            v_prog VARCHAR2(150);
        BEGIN
            v_prog := v_cache_aprobate.FIRST;
            WHILE v_prog IS NOT NULL LOOP
                DBMS_OUTPUT.PUT_LINE('  ' || v_prog || ': ' || v_cache_aprobate(v_prog) || ' dosare aprobate');
                v_prog := v_cache_aprobate.NEXT(v_prog);
            END LOOP;
        END;

        DBMS_OUTPUT.PUT_LINE(' ');
        DBMS_OUTPUT.PUT_LINE('Total candidati admisi (toate programele): ' || v_toti_admisii.COUNT);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Nu exista date de raportat.');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Eroare neasteptata: ' || SQLERRM);
    END raport_admitere_complet;

 
    --Ex 9.2  (log_mesaj ramane procedura standalone din Ex 8, apelata neschimbat)
    PROCEDURE p_log_acoperire_probe IS
        CURSOR c_dosare IS
            SELECT d.id_dosar, d.id_candidat, d.id_program_studiu,
                   d.nota_admitere, c.nume, c.prenume, p.denumire AS program
            FROM   DOSAR d
            JOIN   CANDIDAT c ON c.id_candidat = d.id_candidat
            JOIN   PROGRAM_STUDIU p ON p.id_program = d.id_program_studiu
            ORDER BY d.id_dosar;

        v_id_dosar      DOSAR.id_dosar%TYPE;
        v_id_candidat   DOSAR.id_candidat%TYPE;
        v_id_program    DOSAR.id_program_studiu%TYPE;
        v_nota_admitere DOSAR.nota_admitere%TYPE;
        v_nume          CANDIDAT.nume%TYPE;
        v_prenume       CANDIDAT.prenume%TYPE;
        v_program       PROGRAM_STUDIU.denumire%TYPE;

        CURSOR c_probe_candidat(p_id_candidat CANDIDAT.id_candidat%TYPE,
                                 p_id_program PROGRAM_STUDIU.id_program%TYPE) IS
            SELECT pa.denumire AS proba, tp.tip AS tip_proba, tp.pondere
            FROM   SE_INSCRIE_LA sil
            JOIN   PROBA_ADMITERE pa ON pa.id_proba = sil.id_proba
            JOIN   TIP_PROBA tp ON tp.id_tip = pa.id_tip
            WHERE  sil.id_candidat = p_id_candidat
              AND  sil.id_program_studiu = p_id_program;

        v_proba      PROBA_ADMITERE.denumire%TYPE;
        v_tip_proba  TIP_PROBA.tip%TYPE;
        v_pondere    TIP_PROBA.pondere%TYPE;
        v_sum_pond   NUMBER;
        v_nr_probe   NUMBER;
        v_total_dosare NUMBER := 0;
        c_toleranta CONSTANT NUMBER := 0.01;
    BEGIN
        SELECT COUNT(*) INTO v_total_dosare FROM DOSAR;
        DBMS_OUTPUT.PUT_LINE('Incepe procesarea a ' || v_total_dosare || ' dosare...');

        OPEN c_dosare;
        LOOP
            FETCH c_dosare INTO v_id_dosar, v_id_candidat, v_id_program,
                                 v_nota_admitere, v_nume, v_prenume, v_program;
            EXIT WHEN c_dosare%NOTFOUND;

            v_sum_pond := 0;
            v_nr_probe := 0;

            OPEN c_probe_candidat(v_id_candidat, v_id_program);
            LOOP
                FETCH c_probe_candidat INTO v_proba, v_tip_proba, v_pondere;
                EXIT WHEN c_probe_candidat%NOTFOUND;
                v_sum_pond := v_sum_pond + NVL(v_pondere, 0);
                v_nr_probe := v_nr_probe + 1;
            END LOOP;
            CLOSE c_probe_candidat;

            IF v_nr_probe = 0 THEN
                log_mesaj('Dosar ' || v_id_dosar || ' (' || v_nume || ' ' || v_prenume ||
                    ', ' || v_program || '): candidatul nu este inscris la nicio proba.', 'W');
            ELSIF ABS(v_sum_pond - 1) > c_toleranta THEN
                log_mesaj('Dosar ' || v_id_dosar || ' (' || v_nume || ' ' || v_prenume ||
                    ', ' || v_program || '): acoperire incompleta a probelor, pondere totala = ' ||
                    TO_CHAR(v_sum_pond, 'FM0.00') || ' (asteptat 1.00), ' || v_nr_probe || ' probe inscrise.', 'W');
            ELSE
                log_mesaj('Dosar ' || v_id_dosar || ' (' || v_nume || ' ' || v_prenume ||
                    ', ' || v_program || '): probe complet acoperite (pondere = 1.00), nota admitere = ' ||
                    NVL(TO_CHAR(v_nota_admitere, 'FM0.00'), 'nesetata') || '.', 'I');
            END IF;
        END LOOP;
        CLOSE c_dosare;

        DBMS_OUTPUT.PUT_LINE('Procesare finalizata.');
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            IF c_dosare%ISOPEN THEN CLOSE c_dosare; END IF;
            IF c_probe_candidat%ISOPEN THEN CLOSE c_probe_candidat; END IF;
            DBMS_OUTPUT.PUT_LINE('Eroare in timpul procesarii: ' || SQLERRM);
            log_mesaj('Eroare in p_log_acoperire_probe' ||
                CASE WHEN v_id_dosar IS NOT NULL
                     THEN ' (ultimul dosar procesat: ' || v_id_dosar || ')'
                     ELSE NULL END || ': ' || SQLERRM, 'E');
            RAISE;
    END p_log_acoperire_probe;


    --Ex 9.3
    FUNCTION f_probe_candidat_pipe(
        p_id_candidat IN CANDIDAT.id_candidat%TYPE,
        p_id_program  IN PROGRAM_STUDIU.id_program%TYPE
    ) RETURN t_proba_tab PIPELINED
    IS
        ex_parametri_invalizi  EXCEPTION;
        ex_candidat_inexistent EXCEPTION;
        ex_program_inexistent  EXCEPTION;
        PRAGMA EXCEPTION_INIT(ex_parametri_invalizi,  -20001);
        PRAGMA EXCEPTION_INIT(ex_candidat_inexistent, -20002);
        PRAGMA EXCEPTION_INIT(ex_program_inexistent,  -20003);

        v_cnt            NUMBER;
        v_gasit          BOOLEAN := FALSE;
        v_nota_admitere  DOSAR.nota_admitere%TYPE;
        v_nr_locuri      PROGRAM_STUDIU.nr_locuri%TYPE;
        v_nr_aprobate    NUMBER;
        v_rata_ocupare   NUMBER;

        PROCEDURE verifica_parametri(p_cand IN NUMBER, p_prog IN NUMBER) IS
        BEGIN
            IF p_cand IS NULL OR p_cand <= 0 OR p_prog IS NULL OR p_prog <= 0 THEN
                RAISE_APPLICATION_ERROR(-20001, 'Parametri invalizi: candidat=' || p_cand || ', program=' || p_prog);
            END IF;
        END verifica_parametri;
    BEGIN
        verifica_parametri(p_id_candidat, p_id_program);

        SELECT COUNT(*) INTO v_cnt FROM CANDIDAT WHERE id_candidat = p_id_candidat;
        IF v_cnt = 0 THEN RAISE ex_candidat_inexistent; END IF;

        SELECT COUNT(*) INTO v_cnt FROM PROGRAM_STUDIU WHERE id_program = p_id_program;
        IF v_cnt = 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Programul de studiu cu id ' || p_id_program || ' nu exista.');
        END IF;

        SELECT nr_locuri INTO v_nr_locuri FROM PROGRAM_STUDIU WHERE id_program = p_id_program;

        SELECT nota_admitere INTO v_nota_admitere
        FROM DOSAR
        WHERE id_candidat = p_id_candidat AND id_program_studiu = p_id_program;

        FOR r IN (
            SELECT pa.denumire AS proba, tp.tip AS tip_proba, tp.pondere
            FROM   SE_INSCRIE_LA sil
            JOIN   PROBA_ADMITERE pa ON pa.id_proba = sil.id_proba
            JOIN   TIP_PROBA tp      ON tp.id_tip   = pa.id_tip
            WHERE  sil.id_candidat       = p_id_candidat
              AND  sil.id_program_studiu = p_id_program
        ) LOOP
            v_gasit := TRUE;
            PIPE ROW (t_proba_rezultat(p_id_candidat, p_id_program, 'OK',
                'Inscriere gasita. Nota admitere (dosar): ' ||
                NVL(TO_CHAR(v_nota_admitere, 'FM0.00'), 'nesetata') || '.',
                r.proba, r.tip_proba, r.pondere));
        END LOOP;

        IF NOT v_gasit THEN
            PIPE ROW (t_proba_rezultat(p_id_candidat, p_id_program, 'INFO',
                'Candidatul are dosar depus, dar nu este inscris la nicio proba pentru acest program.',
                NULL, NULL, NULL));
        END IF;

        SELECT COUNT(*) INTO v_nr_aprobate
        FROM DOSAR
        WHERE id_program_studiu = p_id_program AND status_dosar = 'APROBAT';

        v_rata_ocupare := v_nr_aprobate / v_nr_locuri;

        RETURN;
    EXCEPTION
        WHEN ex_parametri_invalizi THEN
            log_mesaj('[propagata din verifica_parametri] ' || SQLERRM, 'E');
            PIPE ROW (t_proba_rezultat(p_id_candidat, p_id_program, 'EROARE',
                'Parametrii id_candidat si id_program trebuie sa fie numere pozitive.', NULL, NULL, NULL));
            RETURN;
        WHEN ex_candidat_inexistent THEN
            log_mesaj('Candidat inexistent [' || SQLCODE || ']: id=' || p_id_candidat, 'E');
            PIPE ROW (t_proba_rezultat(p_id_candidat, p_id_program, 'EROARE',
                'Candidatul cu id ' || p_id_candidat || ' nu exista.', NULL, NULL, NULL));
            RETURN;
        WHEN ex_program_inexistent THEN
            log_mesaj('[RAISE_APPLICATION_ERROR direct] ' || SQLERRM, 'E');
            PIPE ROW (t_proba_rezultat(p_id_candidat, p_id_program, 'EROARE',
                'Programul de studiu cu id ' || p_id_program || ' nu exista.', NULL, NULL, NULL));
            RETURN;
        WHEN NO_DATA_FOUND THEN
            log_mesaj('NO_DATA_FOUND: candidatul ' || p_id_candidat ||
                ' nu a depus dosar pentru programul ' || p_id_program || '.', 'I');
            PIPE ROW (t_proba_rezultat(p_id_candidat, p_id_program, 'EROARE',
                'Candidatul nu are dosar depus pentru acest program de studiu.', NULL, NULL, NULL));
            RETURN;
        WHEN TOO_MANY_ROWS THEN
            log_mesaj('TOO_MANY_ROWS: candidatul ' || p_id_candidat ||
                ' are mai multe dosare pentru programul ' || p_id_program ||
                ' - incalcare a constrangerii UNIQUE, verificati integritatea datelor.', 'E');
            PIPE ROW (t_proba_rezultat(p_id_candidat, p_id_program, 'EROARE',
                'Date inconsistente: mai multe dosare gasite pentru aceeasi combinatie candidat-program.',
                NULL, NULL, NULL));
            RETURN;
        WHEN ZERO_DIVIDE THEN
            log_mesaj('ZERO_DIVIDE: nr_locuri = 0 pentru programul ' || p_id_program, 'E');
            PIPE ROW (t_proba_rezultat(p_id_candidat, p_id_program, 'EROARE',
                'Programul are 0 locuri definite - imposibil de calculat rata de ocupare.', NULL, NULL, NULL));
            RETURN;
        WHEN OTHERS THEN
            log_mesaj('Eroare neasteptata [' || SQLCODE || ']: ' || SQLERRM ||
                ' (candidat=' || p_id_candidat || ', program=' || p_id_program || ')', 'E');
            PIPE ROW (t_proba_rezultat(p_id_candidat, p_id_program, 'EROARE',
                'Eroare neasteptata: ' || SQLERRM, NULL, NULL, NULL));
            RETURN;
    END f_probe_candidat_pipe;


    --Ex 9.4 - fost pkg_verif_max_dosare, apelat acum din trigger-ele externe
    PROCEDURE reset_context IS
    BEGIN
        v_candidati_atinsi.DELETE;
    END reset_context;

    PROCEDURE marcheaza_candidat(p_id_candidat IN NUMBER) IS
    BEGIN
        IF p_id_candidat IS NOT NULL THEN
            v_candidati_atinsi(p_id_candidat) := TRUE;
        END IF;
    END marcheaza_candidat;

    PROCEDURE verifica_limite IS
        v_id_candidat  PLS_INTEGER;
        v_nr_dosare    NUMBER;
        v_nume_complet VARCHAR2(102);
    BEGIN
        v_id_candidat := v_candidati_atinsi.FIRST;
        WHILE v_id_candidat IS NOT NULL LOOP
            SELECT COUNT(*) INTO v_nr_dosare FROM DOSAR WHERE id_candidat = v_id_candidat;

            IF v_nr_dosare > c_max_dosare THEN
                SELECT nume || ' ' || prenume INTO v_nume_complet
                FROM CANDIDAT WHERE id_candidat = v_id_candidat;

                RAISE_APPLICATION_ERROR(-20050,
                    'Candidatul "' || v_nume_complet || '" (id ' || v_id_candidat ||
                    ') ar depasi limita de ' || c_max_dosare || ' dosare depuse ' ||
                    '(curent: ' || v_nr_dosare || ').');
            END IF;

            v_id_candidat := v_candidati_atinsi.NEXT(v_id_candidat);
        END LOOP;

        reset_context;
    END verifica_limite;
    
        PROCEDURE demo_raport IS
    BEGIN
        raport_admitere_complet;
    END demo_raport;

    PROCEDURE demo_acoperire_probe IS
    BEGIN
        p_log_acoperire_probe;
    END demo_acoperire_probe;

  
    --apelarea efectiva
    PROCEDURE demo_probe_pipe IS
    BEGIN
        FOR r IN (
            SELECT 'Caz1_NULL' caz, t.* FROM TABLE(f_probe_candidat_pipe(NULL, 1)) t
            UNION ALL SELECT 'Caz2_negativ',         t.* FROM TABLE(f_probe_candidat_pipe(-5, 1)) t
            UNION ALL SELECT 'Caz3_cand_inexistent', t.* FROM TABLE(f_probe_candidat_pipe(999, 1)) t
            UNION ALL SELECT 'Caz4_prog_inexistent', t.* FROM TABLE(f_probe_candidat_pipe(1, 999)) t
            UNION ALL SELECT 'Caz5_fara_dosar',      t.* FROM TABLE(f_probe_candidat_pipe(2, 2)) t
            UNION ALL SELECT 'Caz6_OK',              t.* FROM TABLE(f_probe_candidat_pipe(1, 1)) t
            UNION ALL SELECT 'Caz7_INFO',            t.* FROM TABLE(f_probe_candidat_pipe(6, 4)) t
        ) LOOP
            DBMS_OUTPUT.PUT_LINE(r.caz || ' | ' || r.cod_rezultat || ' | ' || r.mesaj);
        END LOOP;
    END demo_probe_pipe;

    -- ruleaza DML pe DOSAR care declanseaza trg_dosar_bef_stmt_max / aft_row_max / aft_stmt_max
    -- alege dinamic programe la care candidatul NU are deja dosar, ca sa nu loveasca
    -- UQ_DOSAR_CANDIDAT_PROGRAM (unique pe id_candidat+id_program_studiu) inaintea
    -- verificarii de "max 3 dosare"
    PROCEDURE demo_max_dosare(p_id_candidat IN NUMBER, p_face_rollback IN BOOLEAN DEFAULT TRUE) IS
        TYPE t_id_tab IS TABLE OF PROGRAM_STUDIU.id_program%TYPE;
        v_programe_libere t_id_tab;
    BEGIN
        -- primele 3 programe la care candidatul NU are inca dosar depus
        SELECT id_program
        BULK COLLECT INTO v_programe_libere
        FROM PROGRAM_STUDIU p
        WHERE NOT EXISTS (
            SELECT 1 FROM DOSAR d
            WHERE d.id_candidat = p_id_candidat
              AND d.id_program_studiu = p.id_program
        )
        ORDER BY id_program
        FETCH FIRST 3 ROWS ONLY;

        IF v_programe_libere.COUNT < 3 THEN
            DBMS_OUTPUT.PUT_LINE('demo_max_dosare: candidatul ' || p_id_candidat ||
                ' nu are cel putin 3 programe libere la care sa depuna dosar de test.');
            RETURN;
        END IF;

        FOR i IN 1..3 LOOP
            INSERT INTO DOSAR (data_depunere, status_dosar, id_candidat, id_program_studiu)
            VALUES (SYSDATE, 'IN_CURS', p_id_candidat, v_programe_libere(i));
            -- la al 3-lea INSERT de aici, daca acesta e al 4-lea dosar total al
            -- candidatului, trg_dosar_aft_stmt_max declanseaza RAISE_APPLICATION_ERROR(-20050,...)
        END LOOP;

        IF p_face_rollback THEN
            ROLLBACK;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('demo_max_dosare: ' || SQLERRM);
            IF p_face_rollback THEN ROLLBACK; END IF;
            RAISE;
    END demo_max_dosare;

    -- ruleaza DML pe vi_dosar_candidat care declanseaza trg_vi_dosar_candidat_insert/update/delete
    PROCEDURE demo_view_instead_of IS
        v_email VARCHAR2(100) := 'demo.pkg.' || TO_CHAR(SYSTIMESTAMP, 'FF6') || '@mail.com';
        v_prog1 NUMBER; v_prog2 NUMBER;
    BEGIN
        SELECT MIN(id_program), MAX(id_program) INTO v_prog1, v_prog2 FROM PROGRAM_STUDIU;

        INSERT INTO vi_dosar_candidat
            (data_depunere, status_dosar, nota_admitere, id_program_studiu, nume, prenume, email, medie_generala)
        VALUES
            (SYSDATE, 'IN_CURS', NULL, v_prog1, 'Demo', 'Pachet', v_email, NULL);

        UPDATE vi_dosar_candidat
        SET status_dosar = 'APROBAT', nota_admitere = 8.20
        WHERE email = v_email AND id_program_studiu = v_prog1;

        DELETE FROM vi_dosar_candidat
        WHERE email = v_email AND id_program_studiu = v_prog1;
    END demo_view_instead_of;

    PROCEDURE demo_toate IS
    BEGIN
        demo_raport;
        demo_acoperire_probe;
        demo_probe_pipe;
        demo_max_dosare(5);
        demo_view_instead_of;
    END demo_toate;

END pkg_ex9;
/

SELECT object_name, object_type, status
FROM user_objects
WHERE object_name = 'PKG_EX9'
ORDER BY object_type;

-- trigger 1
CREATE OR REPLACE TRIGGER trg_dosar_bef_stmt_max
BEFORE INSERT OR UPDATE OR DELETE ON DOSAR
BEGIN
    pkg_ex9.reset_context;
END;
/

-- trigger 2: pt. fiecare rand afectat, marcheaza candidatul respectiv
CREATE OR REPLACE TRIGGER trg_dosar_aft_row_max
AFTER INSERT OR UPDATE OF id_candidat OR DELETE ON DOSAR
FOR EACH ROW
BEGIN
    IF DELETING THEN
        pkg_ex9.marcheaza_candidat(:OLD.id_candidat);
    ELSE
        pkg_ex9.marcheaza_candidat(:NEW.id_candidat);
        IF UPDATING AND :OLD.id_candidat IS NOT NULL AND :OLD.id_candidat <> :NEW.id_candidat THEN
            pkg_ex9.marcheaza_candidat(:OLD.id_candidat);
        END IF;
    END IF;
END;
/

-- trigger 3: la finalul comenzii, verifica limita pt. toti candidatii marcati
CREATE OR REPLACE TRIGGER trg_dosar_aft_stmt_max
AFTER INSERT OR UPDATE OR DELETE ON DOSAR
BEGIN
    pkg_ex9.verifica_limite;
END;
/

--testare pachet
SELECT trigger_name, status
FROM user_triggers
WHERE table_name = 'DOSAR'
  AND trigger_name LIKE '%MAX%'
ORDER BY trigger_name;

ALTER TRIGGER trg_vi_dosar_candidat_delete COMPILE;

SET SERVEROUTPUT ON

BEGIN
    pkg_ex9.raport_admitere_complet;
END;
/

BEGIN
    pkg_ex9.p_log_acoperire_probe;
END;
/

BEGIN
    pkg_ex9.demo_probe_pipe;
END;
/

SELECT cod_mesaj, tip_mesaj, mesaj
FROM MESAJE
ORDER BY cod_mesaj DESC
FETCH FIRST 10 ROWS ONLY;

ALTER TABLE CANDIDAT MODIFY id_candidat
    GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE);
    
INSERT INTO CANDIDAT (nume, prenume, data_nastere, sex, email, telefon)
VALUES ('Test', 'Pachet', DATE '2004-01-01', 'M', 'test.pachet.pkg@mail.com', '0700000000');
COMMIT;

SELECT id_candidat FROM CANDIDAT WHERE email = 'test.pachet.pkg@mail.com';

SELECT COUNT(*) FROM DOSAR WHERE id_candidat = 7;

--BEGIN
--    pkg_ex9.demo_max_dosare(p_id_candidat => 7, p_face_rollback => TRUE);
--END;
--/

BEGIN
    pkg_ex9.demo_max_dosare(p_id_candidat => 7, p_face_rollback => FALSE);
END;
/

SELECT id_dosar, id_candidat, id_program_studiu, status_dosar
FROM DOSAR WHERE id_candidat = 7;

DELETE FROM DOSAR WHERE id_candidat = 7;
COMMIT;

SELECT id_dosar, id_candidat, id_program_studiu, status_dosar
FROM DOSAR WHERE id_candidat = 7
ORDER BY id_dosar;

SELECT id_program
FROM PROGRAM_STUDIU p
WHERE NOT EXISTS (
    SELECT 1 FROM DOSAR d
    WHERE d.id_candidat = 7 AND d.id_program_studiu = p.id_program
);

BEGIN
    pkg_ex9.demo_view_instead_of;
END;
/

INSERT INTO vi_dosar_candidat
    (data_depunere, status_dosar, nota_admitere, id_program_studiu, nume, prenume, email, medie_generala)
VALUES
    (SYSDATE, 'IN_CURS', NULL, 1, 'Demo', 'Manual', 'demo.manual.test@mail.com', NULL);

SELECT * FROM vi_dosar_candidat WHERE email = 'demo.manual.test@mail.com';

UPDATE vi_dosar_candidat
SET status_dosar = 'APROBAT', nota_admitere = 8.20
WHERE email = 'demo.manual.test@mail.com';

SELECT * FROM vi_dosar_candidat WHERE email = 'demo.manual.test@mail.com';

DELETE FROM vi_dosar_candidat WHERE email = 'demo.manual.test@mail.com';

SELECT * FROM vi_dosar_candidat WHERE email = 'demo.manual.test@mail.com';

