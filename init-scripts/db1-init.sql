-- 0. Гарантируем наличие пользователя admin с паролем 0000
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'admin') THEN
    CREATE ROLE admin WITH SUPERUSER LOGIN PASSWORD '0000';
  ELSE
    ALTER ROLE admin WITH PASSWORD '0000';
  END IF;
END
$$;

-- 1. Создаем 2 локальные таблицы со случайными данными
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    title VARCHAR(50),
    price NUMERIC(10, 2)
);

CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    order_number VARCHAR(20),
    amount INT
);

INSERT INTO products (title, price)
SELECT 
    'Item_' || substr(md5(random()::text), 1, 5),
    (random() * 1000)::numeric(10,2)
FROM generate_series(1, 10);

INSERT INTO orders (order_number, amount)
SELECT 
    'ORD-' || floor(random() * 90000 + 10000)::text,
    floor(random() * 50 + 1)::int
FROM generate_series(1, 10);

-- 2. Пользователи
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'local_user') THEN
    CREATE USER local_user WITH PASSWORD 'local_pass';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'cross_user') THEN
    CREATE USER cross_user WITH PASSWORD 'cross_pass';
  END IF;
END
$$;

GRANT SELECT ON products, orders TO local_user;
GRANT SELECT ON products, orders TO cross_user;

-- 3. Настройка FDW (доступ к c1-db-2)
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_foreign_server WHERE srvname = 'foreign_c1_db_2') THEN
    CREATE SERVER foreign_c1_db_2
        FOREIGN DATA WRAPPER postgres_fdw
        OPTIONS (host 'c1-db-2', port '5432', dbname 'db2');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_user_mappings WHERE srvname = 'foreign_c1_db_2' AND usename = 'cross_user') THEN
    CREATE USER MAPPING FOR cross_user
        SERVER foreign_c1_db_2
        OPTIONS (user 'remote_reader', password 'reader_pass');
  END IF;
  IF NOT EXISTS (SELECT FROM pg_user_mappings WHERE srvname = 'foreign_c1_db_2' AND usename = 'admin') THEN
    CREATE USER MAPPING FOR admin
        SERVER foreign_c1_db_2
        OPTIONS (user 'remote_reader', password 'reader_pass');
  END IF;
END
$$;

DROP FOREIGN TABLE IF EXISTS server_metrics;
CREATE FOREIGN TABLE server_metrics (
    id INT,
    cpu_load INT,
    ram_usage INT
)
SERVER foreign_c1_db_2
OPTIONS (schema_name 'public', table_name 'server_metrics');

GRANT USAGE ON FOREIGN SERVER foreign_c1_db_2 TO cross_user;
GRANT SELECT ON server_metrics TO cross_user;