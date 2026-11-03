-- Создаем 2 таблицы
CREATE TABLE users_log (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50),
    action VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE server_metrics (
    id SERIAL PRIMARY KEY,
    cpu_load INT,
    ram_usage INT
);

-- Генерируем случайные данные
INSERT INTO users_log (username, action)
SELECT 
    'user_' || substr(md5(random()::text), 1, 6),
    (ARRAY['LOGIN', 'LOGOUT', 'UPDATE', 'DELETE'])[floor(random() * 4 + 1)]
FROM generate_series(1, 10);

INSERT INTO server_metrics (cpu_load, ram_usage)
SELECT 
    floor(random() * 100)::int,
    floor(random() * 16384)::int
FROM generate_series(1, 10);

-- Создаем пользователя, под которым первый контейнер сможет читать эти данные
CREATE USER remote_reader WITH PASSWORD 'reader_pass';
GRANT SELECT ON ALL TABLES IN SCHEMA public TO remote_reader;