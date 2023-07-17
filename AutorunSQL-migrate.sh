Script que se encarga de buscar todos los archivos lista*query* del directorio logs y ejecutarlos para impactar en la db, el script:
#!/bin/bash


LOCK_FILE="/veritran/migracion-imagenes-BNA/logs/AutoRunSQL-migratev5.lock"
if [ -f "$LOCK_FILE" ]; then
  echo "El script ya está en ejecución. No se puede iniciar nuevamente."
  exit 1
fi

touch "$LOCK_FILE"

source /veritran/migracion-imagenes-BNA/db-access.pwd
DATE=$(date +"%Y%m%d-%H%M%S")
log_file="autorun-sql-migratev5-"$DATE".log"
sqls_done_dir="/veritran/migracion-imagenes-BNA/logs/sqls-migratev5-done"

mkdir -p "$sqls_done_dir"

sql_files=$(find /veritran/migracion-imagenes-BNA/logs  -name "lista_imagenes*.query*" -type f)

for sql_file in $sql_files; do
  echo "$DATE" "Ejecutando archivo: $sql_file" >> "$log_file"

  /veritran/migracion-imagenes-BNA/sql/sqlplus "$DBUSER/$DBPASS@$DBSERVICE" < "$sql_file" >> "$log_file" 2>&1

  if [ $? -eq 0 ]; then
    echo "Ejecución exitosa" >> "$log_file"

    mv "$sql_file" "$sqls_done_dir/"
  else
    echo "Error durante la ejecución" >> "$log_file"
  fi

  echo "$DATE" "----------------------------------------------" >> "$log_file"
done

rm "$LOCK_FILE"
