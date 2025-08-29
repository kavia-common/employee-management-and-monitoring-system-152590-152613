#!/bin/bash
set -euo pipefail

# Defaults (can be overridden via env before calling the script)
DB_NAME="${DB_NAME:-myapp}"
DB_USER="${DB_USER:-appuser}"
DB_PASSWORD="${DB_PASSWORD:-dbuser123}"
DB_PORT="${DB_PORT:-5000}"

# Optional flags (default: run migrations and seeds if possible)
APPLY_MIGRATIONS="${APPLY_MIGRATIONS:-true}"
APPLY_SEED="${APPLY_SEED:-true}"

# Args parsing for convenience
for arg in "$@"; do
  case "$arg" in
    --apply-migrations) APPLY_MIGRATIONS=true ;;
    --no-migrate) APPLY_MIGRATIONS=false ;;
    --apply-seed) APPLY_SEED=true ;;
    --no-seed) APPLY_SEED=false ;;
    --no-seeding) APPLY_SEED=false ;; # alias
    --no-seed-data) APPLY_SEED=false ;; # alias
    --help|-h)
      echo "Usage: $0 [--apply-migrations|--no-migrate] [--apply-seed|--no-seed]"
      echo "Environment overrides: DB_NAME, DB_USER, DB_PASSWORD, DB_PORT, APPLY_MIGRATIONS, APPLY_SEED"
      exit 0
      ;;
  esac
done

echo "Starting MySQL setup..."
echo "Config: DB=${DB_NAME} USER=${DB_USER} PORT=${DB_PORT} APPLY_MIGRATIONS=${APPLY_MIGRATIONS} APPLY_SEED=${APPLY_SEED}"

MIGR_DIR="schema/migrations"
MIGR_1="${MIGR_DIR}/001_initial_schema.sql"
MIGR_2="${MIGR_DIR}/002_seed_data.sql"
STATE_DIR=".state"
STATE_FILE="${STATE_DIR}/migrations.applied"

ensure_state_dir() {
  mkdir -p "${STATE_DIR}"
  touch "${STATE_FILE}"
}

mark_applied() {
  ensure_state_dir
  local tag="$1"
  if ! grep -q "^${tag}$" "${STATE_FILE}" ; then
    echo "${tag}" >> "${STATE_FILE}"
  fi
}

was_applied() {
  local tag="$1"
  [ -f "${STATE_FILE}" ] && grep -q "^${tag}$" "${STATE_FILE}"
}

# Try a TCP connection using root
mysql_tcp() {
  mysql -u root -p"${DB_PASSWORD}" -h 127.0.0.1 -P "${DB_PORT}" "$@"
}

# Try a TCP connection using app user
mysql_tcp_app() {
  mysql -u "${DB_USER}" -p"${DB_PASSWORD}" -h 127.0.0.1 -P "${DB_PORT}" "$@"
}

# Try a socket connection with sudo (for local service mgmt)
mysql_socket() {
  sudo mysql --socket=/var/run/mysqld/mysqld.sock "$@"
}

# Check service readiness
is_mysql_ready_socket() {
  sudo mysqladmin ping --socket=/var/run/mysqld/mysqld.sock --silent 2>/dev/null
}

is_mysql_ready_tcp() {
  mysqladmin -u root -p"${DB_PASSWORD}" -h 127.0.0.1 -P "${DB_PORT}" ping --silent 2>/dev/null
}

print_connection_info() {
  echo ""
  echo "Database: ${DB_NAME}"
  echo "Root user: root (password: ${DB_PASSWORD})"
  echo "App user: ${DB_USER} (password: ${DB_PASSWORD})"
  echo "Port: ${DB_PORT}"
  echo ""
  if [ -f "db_connection.txt" ]; then
    echo "To connect to the database, use:"
    cat db_connection.txt
  else
    echo "To connect to the database, use:"
    echo "mysql -u root -p${DB_PASSWORD} -h 127.0.0.1 -P ${DB_PORT} ${DB_NAME}"
  fi
}

# If MySQL already running (socket), short-circuit start, but allow migrations
if is_mysql_ready_socket ; then
  echo "MySQL is already running (socket ready)."
  if mysql_socket -e "USE ${DB_NAME};" 2>/dev/null; then
    echo "Database ${DB_NAME} is accessible via socket."
  fi
else
  # If a mysqld process already bound to our port, and TCP responds, skip start
  if pgrep -f "mysqld.*--port=${DB_PORT}" >/dev/null 2>&1 && is_mysql_ready_tcp ; then
    echo "MySQL already running on port ${DB_PORT}."
  else
    # If socket exists but different port, try graceful shutdown
    if [ -S /var/run/mysqld/mysqld.sock ]; then
      echo "Found MySQL socket, checking port..."
      CURRENT_PORT=$(sudo mysql --socket=/var/run/mysqld/mysqld.sock -e "SHOW VARIABLES LIKE 'port';" 2>/dev/null | awk '/port/ {print $2}')
      if [ "${CURRENT_PORT:-}" != "${DB_PORT}" ]; then
        echo "MySQL running on different port (${CURRENT_PORT}), stopping it..."
        sudo mysqladmin shutdown --socket=/var/run/mysqld/mysqld.sock || true
        sleep 5
      fi
    fi

    # Initialize data dir if needed
    if [ ! -d "/var/lib/mysql/mysql" ]; then
      echo "Initializing MySQL data directory..."
      sudo mysqld --initialize-insecure --user=mysql --datadir=/var/lib/mysql
    fi

    echo "Starting MySQL server on port ${DB_PORT}..."
    sudo mysqld --user=mysql --datadir=/var/lib/mysql \
      --socket=/var/run/mysqld/mysqld.sock \
      --pid-file=/var/run/mysqld/mysqld.pid \
      --port="${DB_PORT}" &

    echo "Waiting for MySQL to start..."
    for i in {1..20}; do
      if is_mysql_ready_socket || is_mysql_ready_tcp ; then
        echo "MySQL is ready!"
        break
      fi
      echo "Waiting... (${i}/20)"
      sleep 2
    done
  fi
fi

# Post-start configuration (idempotent)
echo "Configuring users and database..."
if is_mysql_ready_socket ; then
  mysql_socket <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO 'root'@'localhost';
FLUSH PRIVILEGES;
EOF
else
  # Fallback via TCP
  mysql_tcp -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_PASSWORD}'" || true
  mysql_tcp -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`"
  mysql_tcp -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}'" || true
  mysql_tcp -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%'; FLUSH PRIVILEGES;"
fi

# Save helpers
echo "mysql -u ${DB_USER} -p${DB_PASSWORD} -h 127.0.0.1 -P ${DB_PORT} ${DB_NAME}" > db_connection.txt
cat > db_visualizer/mysql.env << EOF
export MYSQL_URL="mysql://localhost:${DB_PORT}/${DB_NAME}"
export MYSQL_USER="${DB_USER}"
export MYSQL_PASSWORD="${DB_PASSWORD}"
export MYSQL_DB="${DB_NAME}"
export MYSQL_PORT="${DB_PORT}"
EOF

echo "MySQL setup complete!"
print_connection_info
echo "Environment variables saved to db_visualizer/mysql.env"
echo "To use with Node.js viewer, run: source db_visualizer/mysql.env"
echo ""

# Optionally run migrations and seeds non-interactively
run_migrations() {
  ensure_state_dir
  local ran_any=false

  if [ "${APPLY_MIGRITIONS_FIX:-}" != "handled" ]; then
    : # placeholder to avoid shellcheck notice for typo; real logic below
  fi

  if [ "${APPLY_MIGRATIONS}" = "true" ]; then
    if [ -f "${MIGR_1}" ] && ! was_applied "001_initial_schema.sql"; then
      echo "Applying migration: 001_initial_schema.sql"
      mysql_tcp_app "${DB_NAME}" < "${MIGR_1}" || mysql_tcp < "${MIGR_1}"
      mark_applied "001_initial_schema.sql"
      ran_any=true
    else
      echo "Skipping 001_initial_schema.sql (already applied or missing)."
    fi
  else
    echo "Migrations disabled by flag."
  fi

  if [ "${APPLY_SEED}" = "true" ]; then
    if [ -f "${MIGR_2}" ] && ! was_applied "002_seed_data.sql"; then
      echo "Applying seed: 002_seed_data.sql"
      mysql_tcp_app "${DB_NAME}" < "${MIGR_2}" || mysql_tcp < "${MIGR_2}"
      mark_applied "002_seed_data.sql"
      ran_any=true
    else
      echo "Skipping 002_seed_data.sql (already applied or missing)."
    fi
  else
    echo "Seed data disabled by flag."
  fi

  if [ "${ran_any}" = "true" ]; then
    echo "Migrations/seed applied successfully."
  else
    echo "No migrations/seed applied."
  fi
}

# Only attempt if server is reachable
if is_mysql_ready_tcp || is_mysql_ready_socket ; then
  run_migrations
else
  echo "MySQL not reachable; skipping migrations/seed."
fi

echo ""
echo "MySQL is running in the background."
echo "You can now start your application."
