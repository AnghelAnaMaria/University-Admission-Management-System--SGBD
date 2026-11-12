--Ex 7)
--1)Afisati programele de studiu care au un numar de dosare depuse mai mare decat media numarului de dosare pe program, 
--ordonate descrescator dupa numarul de dosare.
--Notiuni ilustrate: GROUP BY, HAVING (cu subinterogare), ORDER BY, COUNT, AVG, INNER JOIN.
SELECT ps.denumire, COUNT(d.id_dosar) AS nr_dosare
FROM PROGRAM_STUDIU ps
JOIN DOSAR d ON d.id_program_studiu = ps.id_program
GROUP BY ps.denumire
HAVING COUNT(d.id_dosar) > (
    SELECT AVG(cnt)
    FROM (SELECT COUNT(*) AS cnt FROM DOSAR GROUP BY id_program_studiu)
)
ORDER BY nr_dosare DESC;

--2)Afisati ierarhia completa a profesorilor corectori, pornind de la coordonatorii de varf (cei fara coordonator propriu) 
--pana la ultimul nivel de subordonare, cu indentare vizuala dupa nivelul din ierarhie.
--Notiuni ilustrate: START WITH, CONNECT BY PRIOR, LEVEL, ORDER SIBLINGS BY.
SELECT LPAD(' ', 3*(LEVEL-1)) || nume || ' ' || prenume AS ierarhie,
       LEVEL AS nivel
FROM PROFESOR_CORECTOR
START WITH id_coordonator IS NULL
CONNECT BY PRIOR id_profesor = id_coordonator
ORDER SIBLINGS BY nume;

---3)Pentru fiecare candidat, afisati prenumele scris cu majuscule, numele scris cu litere mici, primele 3 caractere 
--din adresa de email si pozitia caracterului '@' in email.
--Notiuni ilustrate: UPPER, LOWER, SUBSTR, INSTR.
SELECT UPPER(prenume) AS prenume_majuscule,
LOWER(nume) AS nume_minuscule,
SUBSTR(email, 1, 3) AS inceput_email,
INSTR(email, '@') AS pozitie_arond
FROM CANDIDAT
ORDER BY nume_minuscule;

--4) Pentru profesorii corectori inscrisi inainte de 31.12.2021, afiseaza data inscrierii formatata zi-luna-an, data la care ar implini 10 ani de activitate si numarul de luni scurse de la inscriere pana azi.
--Notiuni ilustrate: TO_CHAR, TO_DATE, ADD_MONTHS, MONTHS_BETWEEN.
SELECT nume, prenume,
TO_CHAR(data_inscriere, 'DD-MM-YYYY') AS data_inscriere_fmt,
TO_CHAR(ADD_MONTHS(data_inscriere, 120), 'DD-MM-YYYY') AS data_10_ani_vechime,
ROUND(MONTHS_BETWEEN(SYSDATE, data_inscriere), 1) AS luni_vechime
FROM PROFESOR_CORECTOR
WHERE data_inscriere <= TO_DATE('31-12-2021', 'DD-MM-YYYY')
ORDER BY data_inscriere;

--5) Pentru fiecare dosar, afisati statusul tradus in limbaj natural, nota de admitere (sau textul 'Neevaluat' daca lipseste) 
--si o clasificare a performantei candidatului.
--Notiuni ilustrate: DECODE, NVL, CASE
SELECT d.id_dosar,
       DECODE(d.status_dosar,
              'IN_CURS', 'In curs de procesare',
              'APROBAT', 'Aprobat',
              'RESPINS', 'Respins',
              'Necunoscut')  AS status_tradus,
       NVL(TO_CHAR(d.nota_admitere), 'Neevaluat')   AS nota,
       CASE
           WHEN d.nota_admitere IS NULL THEN 'Fara nota'
           WHEN d.nota_admitere >= 9 THEN 'Excelent'
           WHEN d.nota_admitere >= 7 THEN 'Bine'
           ELSE 'Sub asteptari'
       END   AS clasificare
FROM DOSAR d
ORDER BY d.id_dosar;

--6) Pentru fiecare program de studiu afisati numarul de locuri, numarul de dosare depuse si gradul de ocupare procentual,
--evitand impartirea la zero.
--Notiuni ilustrate: NULLIF, subinterogare in SELECT, COUNT.
SELECT ps.denumire, ps.nr_locuri,
       (SELECT COUNT(*) FROM DOSAR d WHERE d.id_program_studiu = ps.id_program) AS nr_dosare,
       ROUND(
           (SELECT COUNT(*) FROM DOSAR d WHERE d.id_program_studiu = ps.id_program)
           / NULLIF(ps.nr_locuri, 0) * 100, 2) AS grad_ocupare_procent
FROM PROGRAM_STUDIU ps
ORDER BY grad_ocupare_procent DESC;


--7) Pentru fiecare universitate, afisati numarul de programe de studiu distincte, totalul locurilor disponibile, 
--durata medie a programelor si numarul minim/maxim de locuri per program.
--Notiuni ilustrate: INNER JOIN (4 tabele), GROUP BY, COUNT, SUM, AVG, MIN, MAX.
SELECT u.denumire_universitate,
       COUNT(DISTINCT ps.id_program) AS nr_programe,
       SUM(ps.nr_locuri)             AS total_locuri,
       ROUND(AVG(ps.durata_ani), 1)  AS durata_medie,
       MIN(ps.nr_locuri)             AS min_locuri,
       MAX(ps.nr_locuri)             AS max_locuri
FROM UNIVERSITATE u
INNER JOIN FACULTATE f      ON f.id_universitate = u.id_universitate
INNER JOIN ARE a            ON a.id_facultate = f.id_institutie
INNER JOIN PROGRAM_STUDIU ps ON ps.id_program = a.id_program_studiu
GROUP BY u.denumire_universitate
ORDER BY total_locuri DESC;

--8) Pentru fiecare program de studiu, afiseaza dosarele aprobate aferente (daca exista). Se vor afisa si programele care 
--nu au inca niciun dosar aprobat.
--Notiuni ilustrate: LEFT JOIN
SELECT ps.denumire, d.id_dosar, d.status_dosar
FROM PROGRAM_STUDIU ps
LEFT JOIN DOSAR d ON d.id_program_studiu = ps.id_program AND d.status_dosar = 'APROBAT'
ORDER BY ps.denumire;

--9) Verificati care profesori au fost evaluatori la proba de admitere numita "Proba practica programare".
--Rezultatul va cuprinde toti profesorii.
--Notiuni ilustrate: RIGHT JOIN, subinterogare in ON (identificare proba dupa denumire)
SELECT p.nume, p.prenume,
       CASE WHEN e.id_proba IS NOT NULL THEN 'Proba practica programare' END AS proba_evaluata
FROM EVALUEAZA e
RIGHT JOIN PROFESOR_CORECTOR p
       ON p.id_profesor = e.id_profesor
      AND e.id_proba = (SELECT id_proba FROM PROBA_ADMITERE WHERE denumire = 'Proba practica programare')
ORDER BY p.nume;


--10) Verificati dacă generația 2003 e suprareprezentată printre candidatii cu dosar aprobat.
--Notiuni ilustrate: FULL JOIN, subinterogare in FROM.
SELECT COALESCE(a.id_candidat, b.id_candidat) AS id_candidat,
       a.id_candidat AS in_aprobati,
       b.id_candidat AS nascut_2003
FROM (SELECT DISTINCT id_candidat FROM DOSAR WHERE status_dosar = 'APROBAT') a
FULL JOIN (SELECT id_candidat FROM CANDIDAT
           WHERE data_nastere BETWEEN DATE '2003-01-01' AND DATE '2003-12-31') b
       ON a.id_candidat = b.id_candidat
ORDER BY id_candidat;

--11) Afisati o lista unica cu toate persoanele active din sistem: fie candidati cu dosar aprobat, fie profesori cu grad
--de Prof.univ.dr. sau Conf.univ.dr., impreuna cu rolul lor.
--Notiuni ilustrate: UNION.
SELECT nume, prenume, 'CANDIDAT APROBAT' AS rol
FROM CANDIDAT c
WHERE EXISTS (SELECT 1 FROM DOSAR d
              WHERE d.id_candidat = c.id_candidat AND d.status_dosar = 'APROBAT')
UNION
SELECT nume, prenume, 'PROFESOR SENIOR' AS rol
FROM PROFESOR_CORECTOR
WHERE grad IN ('Prof.univ.dr.', 'Conf.univ.dr.')
ORDER BY nume;
-- Nota: daca nu ne intereseaza eliminarea duplicatelor, se poate folosi UNION ALL.


--12) Gasiti candidatii care au dosarul aprobat si sunt inscrisi la proba de admitere "Matematica - proba scrisa".
--Notiuni ilustrate: INTERSECT , subinterogare in WHERE, subinterogare in FROM, JOIN.
SELECT c.id_candidat, c.nume, c.prenume
FROM CANDIDAT c
JOIN (
    SELECT id_candidat FROM DOSAR WHERE status_dosar = 'APROBAT'
    INTERSECT
    SELECT id_candidat FROM SE_INSCRIE_LA
    WHERE id_proba = (SELECT id_proba FROM PROBA_ADMITERE WHERE denumire = 'Matematica - proba scrisa')
) rezultat ON rezultat.id_candidat = c.id_candidat
ORDER BY c.nume;


--13) Afisati candidatii care au depus un dosar, dar nu s-au inscris la nicio proba de tip "Examen scris".
--Notiuni ilustrate: MINUS, subinterogare in WHERE, JOIN
SELECT c.id_candidat, c.nume, c.prenume
FROM CANDIDAT c
JOIN (
    SELECT DISTINCT id_candidat FROM DOSAR
    MINUS
    SELECT DISTINCT se.id_candidat
    FROM SE_INSCRIE_LA se
    JOIN PROBA_ADMITERE pa ON pa.id_proba = se.id_proba
    WHERE pa.id_tip = (SELECT id_tip FROM TIP_PROBA WHERE tip = 'Examen scris')
) rezultat ON rezultat.id_candidat = c.id_candidat
ORDER BY c.nume;


--14) Afisati candidatii al caror dosar are o nota de admitere mai mare decat media notelor tuturor dosarelor aprobate, 
--impreuna cu numarul de documente atasate dosarului lor.
--Notiuni ilustrate: subinterogare in WHERE, subinterogare corelata in SELECT, AVG.
SELECT c.nume, c.prenume, d.nota_admitere,
       (SELECT COUNT(*) FROM CONTINE ct WHERE ct.id_dosar = d.id_dosar) AS nr_documente
FROM CANDIDAT c
JOIN DOSAR d ON d.id_candidat = c.id_candidat
WHERE d.nota_admitere > (SELECT AVG(nota_admitere) FROM DOSAR WHERE status_dosar = 'APROBAT')
ORDER BY d.nota_admitere DESC;


--15) Sa se gaseasca toti profesorii pentru care mulțimea probelor evaluate acopera integral mulțimea probelor evaluate de 
--Nistor Diana.
--Notiuni ilustrate: DIVISION, LOWER, UPPER, subinterogare in WHERE
SELECT DISTINCT p.id_profesor, UPPER(p.nume) AS nume, UPPER(p.prenume) AS prenume
FROM PROFESOR_CORECTOR p
WHERE NOT EXISTS (
    SELECT e2.id_proba
    FROM EVALUEAZA e2
    WHERE e2.id_profesor = (
        SELECT id_profesor FROM PROFESOR_CORECTOR
        WHERE LOWER(nume) = LOWER('Nistor') AND LOWER(prenume) = LOWER('Diana')
    )
    AND NOT EXISTS (
        SELECT 1 FROM EVALUEAZA e1
        WHERE e1.id_profesor = p.id_profesor
        AND e1.id_proba = e2.id_proba
    )
)
ORDER BY p.id_profesor;