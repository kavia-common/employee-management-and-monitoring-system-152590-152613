# employee-management-and-monitoring-system-152590-152613

Database (MySQL) setup:
- Use mysql_database/startup.sh to initialize local MySQL and set env in mysql_database/db_visualizer/mysql.env
- Migrations are under mysql_database/schema/migrations
  - 001_initial_schema.sql – creates tables, constraints, indexes
  - 002_seed_data.sql – seeds basic roles/users/projects/tasks etc. for development

Quick apply:
1) cd mysql_database
2) ./startup.sh
3) source db_visualizer/mysql.env
4) mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h 127.0.0.1 -P "$MYSQL_PORT" "$MYSQL_DB" < schema/migrations/001_initial_schema.sql
5) mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h 127.0.0.1 -P "$MYSQL_PORT" "$MYSQL_DB" < schema/migrations/002_seed_data.sql