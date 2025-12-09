# Students Backend (Node + MSSQL)

Node/Express service exposing `/students` which queries the `Students` table in RDS SQL Server.

Environment variables expected (provided by ECS Task Definition):

- DB_HOST
- DB_PORT (default 1433)
- DB_USER
- DB_PASSWORD
- DB_NAME
