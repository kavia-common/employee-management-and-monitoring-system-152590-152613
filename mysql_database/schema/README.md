# MySQL Schema & Migrations

This folder contains SQL migration scripts for the Employee Management & Monitoring System.

Structure:
- migrations/001_initial_schema.sql – creates normalized tables, constraints, indexes
- migrations/002_seed_data.sql – seeds roles and example data for development

How to apply:
1) Ensure MySQL is running. In this environment, use the provided startup script:
   ./startup.sh

2) Load migrations using the connection details saved by the startup script:
   source ./db_visualizer/mysql.env
   # or check the helper
   cat db_connection.txt

3) Apply schema:
   mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h 127.0.0.1 -P "$MYSQL_PORT" "$MYSQL_DB" < schema/migrations/001_initial_schema.sql

4) Apply seed data (optional for dev):
   mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h 127.0.0.1 -P "$MYSQL_PORT" "$MYSQL_DB" < schema/migrations/002_seed_data.sql

Notes:
- This schema is designed for integration with Sequelize in the Express backend.
- All credentials are loaded via environment variables (see db_visualizer/mysql.env).
- If you prefer non-destructive updates, comment out the DROP TABLE statements in 001_initial_schema.sql before running in shared environments.
