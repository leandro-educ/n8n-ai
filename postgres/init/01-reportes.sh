#!/bin/sh
set -eu

echo "Preparando base de ejemplo 'reportes'..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<EOSQL
SELECT 'CREATE DATABASE reportes OWNER "$POSTGRES_USER"'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'reportes')\gexec
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname reportes <<'EOSQL'
CREATE TABLE IF NOT EXISTS ventas (
    id BIGSERIAL PRIMARY KEY,
    fecha DATE NOT NULL,
    cliente VARCHAR(150) NOT NULL,
    producto VARCHAR(150) NOT NULL,
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    importe_total NUMERIC(14,2) NOT NULL CHECK (importe_total >= 0)
);

INSERT INTO ventas (fecha, cliente, producto, cantidad, importe_total)
SELECT *
FROM (
    VALUES
      ('2026-08-01'::date, 'ACME S.A.', 'Notebook', 2, 2600000.00),
      ('2026-08-03'::date, 'ACME S.A.', 'Monitor', 4, 920000.00),
      ('2026-08-05'::date, 'Globex', 'Notebook', 1, 1320000.00),
      ('2026-08-10'::date, 'ACME S.A.', 'Teclado', 8, 480000.00)
) AS demo(fecha, cliente, producto, cantidad, importe_total)
WHERE NOT EXISTS (SELECT 1 FROM ventas);
EOSQL

echo "Base de ejemplo lista."
