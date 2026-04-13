/* ============================================================
   0️⃣ Vérification du périmètre temporel des données
   Objectif :
   - Identifier les années disponibles
   - Vérifier le nombre d'enregistrements
   - Déterminer la date minimale et maximale par année
============================================================ */

SELECT
    substr(heure_de_paris, 1, 4) AS annee_extraite,
    COUNT(*) AS nombre_enregistrements,
    MIN(heure_de_paris) AS premiere_date,
    MAX(heure_de_paris) AS derniere_date
FROM "toulouse_weather_db"."curated"
GROUP BY substr(heure_de_paris, 1, 4)
ORDER BY annee_extraite ASC;


/* ============================================================
   1️⃣ Moyennes mensuelles par année
   Objectif :
   - Calculer température moyenne, humidité moyenne
   - Calculer vitesse moyenne du vent
   - Analyse saisonnière et interannuelle
============================================================ */

SELECT
    year(from_iso8601_timestamp(heure_utc)) AS annee,
    month(from_iso8601_timestamp(heure_utc)) AS mois,
    ROUND(AVG(temperature_en_degre_c), 2) AS temperature_moyenne,
    ROUND(AVG(humidite), 2) AS humidite_moyenne,
    ROUND(AVG(force_moyenne_du_vecteur_vent), 2) AS vent_moyen
FROM curated
GROUP BY
    year(from_iso8601_timestamp(heure_utc)),
    month(from_iso8601_timestamp(heure_utc))
ORDER BY annee, mois;


/* ============================================================
   2️⃣ Moyennes journalières pour l’année 2025
   Objectif :
   - Observer l’évolution quotidienne
   - Analyse intra-annuelle détaillée
============================================================ */

SELECT
    date(from_iso8601_timestamp(heure_utc)) AS jour,
    ROUND(AVG(temperature_en_degre_c), 2) AS temperature_moyenne,
    ROUND(AVG(humidite), 2) AS humidite_moyenne,
    ROUND(AVG(force_moyenne_du_vecteur_vent), 2) AS vent_moyen
FROM curated
WHERE year(from_iso8601_timestamp(heure_utc)) = 2025
GROUP BY date(from_iso8601_timestamp(heure_utc))
ORDER BY jour;


/* ============================================================
   3️⃣ Répartition annuelle des catégories de température
   Objectif :
   - Construire un KPI climatique
   - Classer les journées selon 3 niveaux
============================================================ */

WITH daily_temperature AS (
    SELECT
        date(from_iso8601_timestamp(heure_utc)) AS jour,
        year(from_iso8601_timestamp(heure_utc)) AS annee,
        AVG(temperature_en_degre_c) AS temperature_moyenne
    FROM curated
    GROUP BY
        date(from_iso8601_timestamp(heure_utc)),
        year(from_iso8601_timestamp(heure_utc))
)

SELECT
    annee,
    CASE
        WHEN temperature_moyenne >= 25 THEN 'High'
        WHEN temperature_moyenne BETWEEN 15 AND 25 THEN 'Moderate'
        ELSE 'Low'
    END AS categorie_temperature,
    COUNT(*) AS nombre_jours
FROM daily_temperature
GROUP BY
    annee,
    CASE
        WHEN temperature_moyenne >= 25 THEN 'High'
        WHEN temperature_moyenne BETWEEN 15 AND 25 THEN 'Moderate'
        ELSE 'Low'
    END
ORDER BY annee;


/* ============================================================
   4️⃣ Corrélation annuelle entre pression et température
   Objectif :
   - Mesurer la relation statistique
   - Identifier influence partielle de la pression
============================================================ */

WITH daily_pression AS (
    SELECT
        year(from_iso8601_timestamp(heure_utc)) AS annee,
        date(from_iso8601_timestamp(heure_utc)) AS jour,
        AVG(temperature_en_degre_c) AS temperature_moyenne,
        AVG(pression) AS pression_moyenne
    FROM curated
    GROUP BY
        year(from_iso8601_timestamp(heure_utc)),
        date(from_iso8601_timestamp(heure_utc))
)

SELECT
    annee,
    ROUND(corr(pression_moyenne, temperature_moyenne), 3)
        AS correlation_pression_temperature
FROM daily_pression
GROUP BY annee
ORDER BY annee;

/* ============================================================
   5️⃣ Analyse trimestrielle :
      Influence de l’humidité et de la pression
      sur l’amplitude thermique
   Objectif :
   - Étudier les facteurs explicatifs saisonniers
   - Mesurer l’impact de l’humidité moyenne
   - Mesurer l’impact de la pression moyenne
============================================================ */

WITH daily_indicators AS (
    SELECT
        year(from_iso8601_timestamp(heure_utc)) AS annee,
        quarter(from_iso8601_timestamp(heure_utc)) AS trimestre,

        -- Amplitude thermique journalière (昼夜温差)
        MAX(temperature_en_degre_c) - MIN(temperature_en_degre_c)
            AS amplitude_thermique,

        -- Humidité moyenne journalière
        AVG(humidite) AS humidite_moyenne,

        -- Pression moyenne journalière
        AVG(pression) AS pression_moyenne

    FROM curated
    GROUP BY
        date(from_iso8601_timestamp(heure_utc)),
        year(from_iso8601_timestamp(heure_utc)),
        quarter(from_iso8601_timestamp(heure_utc))
)

SELECT
    annee,
    trimestre,

    /* Corrélation humidité moyenne vs amplitude thermique */
    CASE
        WHEN corr(humidite_moyenne, amplitude_thermique) IS NULL
             OR ABS(corr(humidite_moyenne, amplitude_thermique)) < 0.01
        THEN 0
        ELSE ROUND(corr(humidite_moyenne, amplitude_thermique), 3)
    END AS correlation_humidite_amplitude,

    /* Corrélation pression moyenne vs amplitude thermique */
    CASE
        WHEN corr(pression_moyenne, amplitude_thermique) IS NULL
             OR ABS(corr(pression_moyenne, amplitude_thermique)) < 0.01
        THEN 0
        ELSE ROUND(corr(pression_moyenne, amplitude_thermique), 3)
    END AS correlation_pression_amplitude

FROM daily_indicators
GROUP BY annee, trimestre
ORDER BY annee, trimestre;
