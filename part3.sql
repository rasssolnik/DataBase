-- 1. Функция для получения таблицы TransferredPoints
CREATE OR REPLACE FUNCTION fnc_transferredpoints_human_readable()
RETURNS TABLE(
    peer VARCHAR,
    pointschange BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH all_transfers AS (
        SELECT checkingpeer AS peer, 
               SUM(pointsamount) AS points_change
        FROM transferredpoints
        GROUP BY checkingpeer
        
        UNION ALL

        SELECT checkedpeer AS peer,
               -SUM(pointsamount) AS points_change
        FROM transferredpoints
        GROUP BY checkedpeer
    )
    SELECT peer,
           SUM(points_change) AS pointschange
    FROM all_transfers
    GROUP BY peer
    ORDER BY pointschange DESC;
END;
$$ LANGUAGE plpgsql;

-- 2. Функция для получения таблицы с именем пользователя, задачей и количеством XP
CREATE OR REPLACE FUNCTION fnc_task_xp()
RETURNS TABLE(
    peer VARCHAR,
    task VARCHAR,
    xp INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT p.nickname AS peer,
           c.task,
           x.xpamount AS xp
    FROM peers p
    JOIN checks c ON p.nickname = c.peer
    JOIN xp x ON c.id = x.check_id
    ORDER BY p.nickname, c.task;
END;
$$ LANGUAGE plpgsql;

-- 3. Найти пиров, которые не выходили из кампуса в течение всего дня
CREATE OR REPLACE FUNCTION fnc_peers_never_left_campus(check_date DATE DEFAULT CURRENT_DATE)
RETURNS TABLE(
    peer VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    WITH peer_entries AS (
        SELECT peer,
               COUNT(*) FILTER (WHERE state = 1) AS entries,
               COUNT(*) FILTER (WHERE state = 2) AS exits
        FROM timetracking
        WHERE date = check_date
        GROUP BY peer
    )
    SELECT p.peer
    FROM peer_entries p
    WHERE p.entries > 0 AND p.exits = 0;
END;
$$ LANGUAGE plpgsql;

-- 4. Рассчитать изменение в количестве пир поинтов каждого пира
CREATE OR REPLACE FUNCTION fnc_peer_points_change()
RETURNS TABLE(
    peer VARCHAR,
    pointschange BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM fnc_transferredpoints_human_readable();
END;
$$ LANGUAGE plpgsql;

-- 5. Найти пиров с наибольшим количеством XP
CREATE OR REPLACE FUNCTION fnc_top_peers_by_xp()
RETURNS TABLE(
    peer VARCHAR,
    totalxp BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT p.nickname AS peer,
           COALESCE(SUM(x.xpamount), 0) AS totalxp
    FROM peers p
    LEFT JOIN checks c ON p.nickname = c.peer
    LEFT JOIN xp x ON c.id = x.check_id
    GROUP BY p.nickname
    ORDER BY totalxp DESC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- 6. Найти самых популярных проверяющих (кто проверял чаще всего)
CREATE OR REPLACE FUNCTION fnc_top_checking_peers()
RETURNS TABLE(
    checkingpeer VARCHAR,
    checkcount BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT p.checkingpeer,
           COUNT(*) AS checkcount
    FROM p2p p
    WHERE p.state != 'Start'
    GROUP BY p.checkingpeer
    ORDER BY checkcount DESC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- 7. Найти пиров, выполнивших наибольшее количество задач в определенный день
CREATE OR REPLACE FUNCTION fnc_top_peers_by_tasks_on_date(check_date DATE DEFAULT CURRENT_DATE)
RETURNS TABLE(
    peer VARCHAR,
    taskscompleted BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT c.peer,
           COUNT(DISTINCT c.task) AS taskscompleted
    FROM checks c
    JOIN p2p p ON c.id = p.check_id
    WHERE c.date = check_date
      AND p.state = 'Success'
    GROUP BY c.peer
    ORDER BY taskscompleted DESC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- 8. Найти пиров, которые рекомендуют друг друга
CREATE OR REPLACE FUNCTION fnc_mutual_recommendations()
RETURNS TABLE(
    peer1 VARCHAR,
    peer2 VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT r1.peer AS peer1,
           r1.recommendedpeer AS peer2
    FROM recommendations r1
    JOIN recommendations r2 ON r1.peer = r2.recommendedpeer 
                            AND r1.recommendedpeer = r2.peer
    WHERE r1.peer < r1.recommendedpeer;
END;
$$ LANGUAGE plpgsql;

-- 9. Процент успешных и неуспешных проверок
CREATE OR REPLACE FUNCTION fnc_success_failure_stats()
RETURNS TABLE(
    successful_checks_percent DECIMAL,
    failure_checks_percent DECIMAL
) AS $$
DECLARE
    total_checks BIGINT;
    successful_checks BIGINT;
    failure_checks BIGINT;
BEGIN
    SELECT COUNT(*) INTO total_checks
    FROM p2p
    WHERE state != 'Start';
    
    SELECT COUNT(*) INTO successful_checks
    FROM p2p
    WHERE state = 'Success';
    
    SELECT COUNT(*) INTO failure_checks
    FROM p2p
    WHERE state = 'Failure';
    
    IF total_checks > 0 THEN
        successful_checks_percent := (successful_checks::DECIMAL / total_checks) * 100;
        failure_checks_percent := (failure_checks::DECIMAL / total_checks) * 100;
    ELSE
        successful_checks_percent := 0;
        failure_checks_percent := 0;
    END IF;
    
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;
