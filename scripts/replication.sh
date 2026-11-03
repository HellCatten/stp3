#!/bin/sh

# Запуск сервера Postgres реплики в фоне
docker-entrypoint.sh postgres &

echo "Ожидание готовности баз данных..."
until pg_isready -h localhost -p 5432 && pg_isready -h c1-db-1 -p 5432; do
  sleep 2
done

echo "Базы данных готовы. Запуск периодической репликации..."

while true; do
  # 1. Синхронизируем пользователей (роли)
  PGPASSWORD="0000" pg_dumpall -h c1-db-1 -U admin --globals-only -f /tmp/globals.sql 2>/dev/null
  PGPASSWORD="0000" psql -h localhost -U admin -f /tmp/globals.sql > /dev/null 2>&1

  # 2. Синхронизируем данные базы
  if PGPASSWORD="0000" pg_dump -h c1-db-1 -U admin -d db1 --clean --if-exists -f /tmp/backup.sql 2>/dev/null; then
    PGPASSWORD="0000" psql -h localhost -U admin -d db1_replica -f /tmp/backup.sql > /dev/null 2>&1
    echo "[РЕПЛИКАЦИЯ] Данные успешно синхронизированы в $(date)"
  else
    echo "[ОШИБКА] Сбой подключения к c1-db-1 в $(date)"
  fi
  sleep 30
done