FROM mcr.microsoft.com/mssql-tools

WORKDIR /app
COPY students_seed.sql /app/students_seed.sql

CMD /opt/mssql-tools/bin/sqlcmd \
    -S $DB_HOST,$DB_PORT \
    -U $DB_USER \
    -P $DB_PASSWORD \
    -d $DB_NAME \
    -i /app/students_seed.sql
