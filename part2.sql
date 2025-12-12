-- Добавлениe P2P проверки
CREATE OR REPLACE PROCEDURE add_p2p_check(
    IN checking_peer VARCHAR,
    IN checked_peer VARCHAR,
    IN task_name VARCHAR,
    IN p2p_status check_status,
    IN check_time TIME DEFAULT NULL
) AS $$
DECLARE
    check_id BIGINT;
    current_date_val DATE := CURRENT_DATE;
BEGIN
    -- Если передано NULL время, используем текущее
    IF check_time IS NULL THEN
        check_time := CURRENT_TIME;
    END IF;
    
    -- Если статус 'Start', создаем новую проверку
    IF p2p_status = 'Start' THEN
        -- Создаем запись в Checks
        INSERT INTO checks(peer, task, date)
        VALUES (checked_peer, task_name, current_date_val)
        RETURNING id INTO check_id;
        
        -- Создаем запись в P2P
        INSERT INTO p2p(check_id, checkingpeer, state, time)
        VALUES (check_id, checking_peer, p2p_status, check_time);
        
        -- Обновляем TransferredPoints
        INSERT INTO transferredpoints(checkingpeer, checkedpeer, pointsamount)
        VALUES (checking_peer, checked_peer, 1)
        ON CONFLICT (checkingpeer, checkedpeer) 
        DO UPDATE SET pointsamount = transferredpoints.pointsamount + 1;
    ELSE
        -- Находим последнюю проверку для этого пира и задачи
        SELECT c.id INTO check_id
        FROM checks c
        JOIN p2p p ON c.id = p.check_id
        WHERE c.peer = checked_peer 
          AND c.task = task_name
          AND p.checkingpeer = checking_peer
          AND p.state = 'Start'
        ORDER BY p.time DESC
        LIMIT 1;
        
        IF check_id IS NOT NULL THEN
            INSERT INTO p2p(check_id, checkingpeer, state, time)
            VALUES (check_id, checking_peer, p2p_status, check_time);
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Добавление проверки Verter'ом
CREATE OR REPLACE PROCEDURE add_verter_check(
    IN checked_peer VARCHAR,
    IN task_name VARCHAR,
    IN verter_status check_status,
    IN check_time TIME DEFAULT NULL
) AS $$
DECLARE
    check_id BIGINT;
BEGIN
    -- Если передано NULL время, используем текущее
    IF check_time IS NULL THEN
        check_time := CURRENT_TIME;
    END IF;
    
    -- Находим последнюю успешную P2P проверку
    SELECT c.id INTO check_id
    FROM checks c
    JOIN p2p p ON c.id = p.check_id
    WHERE c.peer = checked_peer 
      AND c.task = task_name
      AND p.state = 'Success'
    ORDER BY p.time DESC
    LIMIT 1;
    
    IF check_id IS NOT NULL THEN
        -- Добавляем запись в Verter
        INSERT INTO verter(check_id, state, time)
        VALUES (check_id, verter_status, check_time);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Триггерная функция для проверки XP
CREATE OR REPLACE FUNCTION check_xp_amount()
RETURNS TRIGGER AS $$
DECLARE
    max_xp INTEGER;
    p2p_status check_status;
    verter_status check_status;
BEGIN
    -- Получаем максимальное XP для задачи
    SELECT t.maxxp INTO max_xp
    FROM tasks t
    JOIN checks c ON t.title = c.task
    WHERE c.id = NEW.check_id;
    
    -- Проверяем статус P2P проверки
    SELECT state INTO p2p_status
    FROM p2p
    WHERE check_id = NEW.check_id AND state != 'Start'
    ORDER BY time DESC
    LIMIT 1;
    
    -- Проверяем статус Verter проверки (если есть)
    SELECT state INTO verter_status
    FROM verter
    WHERE check_id = NEW.check_id
    ORDER BY time DESC
    LIMIT 1;
    
    -- Проверяем условия для добавления XP
    IF p2p_status != 'Success' OR 
       (verter_status IS NOT NULL AND verter_status != 'Success') THEN
        RAISE EXCEPTION 'Cannot add XP for unsuccessful check';
    END IF;
    
    -- Проверяем, что количество XP не превышает максимальное
    IF NEW.xpamount > max_xp THEN
        RAISE EXCEPTION 'XP amount (%) exceeds maximum for this task (%)', 
        NEW.xpamount, max_xp;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггер для проверки XP
DROP TRIGGER IF EXISTS trg_check_xp ON xp;
CREATE TRIGGER trg_check_xp
BEFORE INSERT ON xp
FOR EACH ROW
EXECUTE FUNCTION check_xp_amount();

-- Триггерная функция для обновления TransferredPoints при отмене P2P
CREATE OR REPLACE FUNCTION update_transferredpoints_on_p2p_cancel()
RETURNS TRIGGER AS $$
BEGIN
    -- Если P2P проверка отменена (Failure), отменяем transferred points
    IF NEW.state = 'Failure' THEN
        UPDATE transferredpoints
        SET pointsamount = pointsamount - 1
        WHERE checkingpeer = NEW.checkingpeer
          AND checkedpeer = (
              SELECT c.peer
              FROM checks c
              WHERE c.id = NEW.check_id
          );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггер для обновления TransferredPoints
DROP TRIGGER IF EXISTS trg_update_transferredpoints ON p2p;
CREATE TRIGGER trg_update_transferredpoints
AFTER INSERT ON p2p
FOR EACH ROW
WHEN (NEW.state IN ('Success', 'Failure'))
EXECUTE FUNCTION update_transferredpoints_on_p2p_cancel();
