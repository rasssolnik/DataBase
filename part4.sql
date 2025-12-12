-- Создаем несколько тестовых таблиц
CREATE TABLE test_table1 (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50)
);

CREATE TABLE test_table2 (
    id SERIAL PRIMARY KEY,
    value INTEGER
);

CREATE TABLE test_table3 (
    id SERIAL PRIMARY KEY,
    description TEXT
);

-- Создаем несколько функций для тестирования
CREATE OR REPLACE FUNCTION test_func1(param1 INTEGER, param2 VARCHAR)
RETURNS INTEGER AS $$
BEGIN
    RETURN param1 * LENGTH(param2);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION test_func2(param DATE)
RETURNS VARCHAR AS $$
BEGIN
    RETURN TO_CHAR(param, 'YYYY-MM-DD');
END;
$$ LANGUAGE plpgsql;

-- Создаем триггеры для тестирования
CREATE OR REPLACE FUNCTION test_trigger_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.name := UPPER(NEW.name);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER test_trigger
BEFORE INSERT ON test_table1
FOR EACH ROW
EXECUTE FUNCTION test_trigger_func();

-- 1. Процедура для удаления всех таблиц в текущей базе данных
CREATE OR REPLACE PROCEDURE destroy_all_tables()
AS $$
DECLARE
    table_record RECORD;
    sql_statement TEXT;
BEGIN
    -- Отключаем триггеры для избежания ошибок
    SET session_replication_role = 'replica';
    
    FOR table_record IN (
        SELECT schemaname, tablename
        FROM pg_tables
        WHERE schemaname = 'public'
    ) LOOP
        sql_statement := 'DROP TABLE IF EXISTS ' || 
                         quote_ident(table_record.schemaname) || '.' || 
                         quote_ident(table_record.tablename) || ' CASCADE';
        EXECUTE sql_statement;
        RAISE NOTICE 'Dropped table: %.%', 
                     table_record.schemaname, 
                     table_record.tablename;
    END LOOP;
    
    -- Включаем триггеры обратно
    SET session_replication_role = 'origin';
END;
$$ LANGUAGE plpgsql;

-- 2. Процедура для вывода списка скалярных пользовательских функций
CREATE OR REPLACE PROCEDURE list_scalar_functions()
AS $$
DECLARE
    func_record RECORD;
BEGIN
    RAISE NOTICE 'List of scalar user-defined functions:';
    RAISE NOTICE '---------------------------------------';
    
    FOR func_record IN (
        SELECT 
            p.proname AS function_name,
            pg_get_function_arguments(p.oid) AS parameters,
            pg_get_function_result(p.oid) AS return_type
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
          AND p.prokind = 'f'  -- Function (not procedure)
          AND p.prorettype <> 2278  -- Not returning void
        ORDER BY p.proname
    ) LOOP
        RAISE NOTICE 'Function: %', func_record.function_name;
        RAISE NOTICE 'Parameters: %', func_record.parameters;
        RAISE NOTICE 'Returns: %', func_record.return_type;
        RAISE NOTICE '---';
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 3. Процедура для удаления всех DML триггеров
CREATE OR REPLACE PROCEDURE destroy_all_dml_triggers()
AS $$
DECLARE
    trigger_record RECORD;
    sql_statement TEXT;
BEGIN
    RAISE NOTICE 'Dropping all DML triggers...';
    
    FOR trigger_record IN (
        SELECT 
            tgname AS trigger_name,
            relname AS table_name
        FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        WHERE NOT t.tgisinternal
          AND c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
    ) LOOP
        sql_statement := 'DROP TRIGGER IF EXISTS ' || 
                         quote_ident(trigger_record.trigger_name) || 
                         ' ON ' || 
                         quote_ident(trigger_record.table_name);
        EXECUTE sql_statement;
        RAISE NOTICE 'Dropped trigger: % on table %', 
                     trigger_record.trigger_name, 
                     trigger_record.table_name;
    END LOOP;
    
    RAISE NOTICE 'All DML triggers have been dropped.';
END;
$$ LANGUAGE plpgsql;

-- 4. Процедура для поиска объектов по строке
CREATE OR REPLACE PROCEDURE find_objects_by_string(
    search_string VARCHAR
)
AS $$
DECLARE
    obj_record RECORD;
BEGIN
    RAISE NOTICE 'Objects containing "%":', search_string;
    RAISE NOTICE '------------------------';
    
    -- Таблицы
    FOR obj_record IN (
        SELECT 
            'TABLE' AS object_type,
            tablename AS object_name,
            'Table in public schema' AS description
        FROM pg_tables
        WHERE schemaname = 'public'
          AND tablename ILIKE '%' || search_string || '%'
        
        UNION ALL
        
        -- Функции
        SELECT 
            'FUNCTION' AS object_type,
            proname AS object_name,
            'User-defined function' AS description
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
          AND proname ILIKE '%' || search_string || '%'
        
        UNION ALL
        
        -- Триггеры
        SELECT 
            'TRIGGER' AS object_type,
            tgname AS object_name,
            'Trigger on table ' || c.relname AS description
        FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        WHERE NOT t.tgisinternal
          AND c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
          AND tgname ILIKE '%' || search_string || '%'
        
        ORDER BY object_type, object_name
    ) LOOP
        RAISE NOTICE 'Type: %, Name: %, Description: %', 
                     obj_record.object_type,
                     obj_record.object_name,
                     obj_record.description;
    END LOOP;
    
    IF NOT FOUND THEN
        RAISE NOTICE 'No objects found containing "%"', search_string;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Тестируем процедуры
CALL list_scalar_functions();

-- Поиск объектов содержащих "test"
CALL find_objects_by_string('test');
