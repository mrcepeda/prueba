#!/bin/bash

source /veritran/migracion-imagenes-BNA/db-access.pwd
batch_size=1000
log_dir="/veritran/migracion-imagenes-BNA/logs/"
progress_log_dir="/procesos/"
progress_log_file="${progress_log_dir}/progress_log_$(date +%d%m%H%m%N).log"

selected_month="2022-12"  # Formato YYYY-MM
days_type="todos"  # Valores posibles: "par", "impar", "todos"

base_query="SELECT RTRIM(TC_IMG_ID) || ',' || RTRIM(TO_CHAR(TC_IMG_CREATE_DATE, 'YYYY-MM-DD HH24:MI:SS')) || ',' || RTRIM(OICM_PATH_TO_FILE) || ',' || RTRIM(STATUS) FROM (
    SELECT TC_IMG_ID, TC_IMG_CREATE_DATE, OICM_PATH_TO_FILE, STATUS, rn
    FROM (
        SELECT TC_IMG_ID, TC_IMG_CREATE_DATE, OICM_PATH_TO_FILE, STATUS, ROW_NUMBER() OVER (ORDER BY TC_IMG_ID ASC) AS rn
        FROM tmp_c4_tentative_clients_img
        WHERE status = 'COPIEDOK' AND TC_IMG_CREATE_DATE >= TO_DATE('${selected_month}-01', 'YYYY-MM-DD') AND TC_IMG_CREATE_DATE < ADD_MONTHS(TO_DATE('${selected_month}-01', 'YYYY-MM-DD'), 1)
    )
    WHERE rn >= :offset AND rn < :end_offset
) ORDER BY TC_IMG_ID DESC"

if [ "$days_type" == "par" ]; then
    base_query=$(echo "$base_query" | sed "s/WHERE status/WHERE MOD(TO_CHAR(TC_IMG_CREATE_DATE, 'DD'), 2) = 0 AND status/")
elif [ "$days_type" == "impar" ]; then
    base_query=$(echo "$base_query" | sed "s/WHERE status/WHERE MOD(TO_CHAR(TC_IMG_CREATE_DATE, 'DD'), 2) = 1 AND status/")
fi

no_new_records_count=0
max_empty_iterations=3

process_batch() {
    offset=$1
    end_offset=$2
    current_date=$(date +%d%m%H%m%N)
    output_file="$log_dir/batch.copiedok.$selected_month.$current_date.DELETELoteBNA.log"
    output_file2="batch.copiedok.$selected_month.$current_date.DELETELoteBNA.log"

    /veritran/migracion-imagenes-BNA/sql/sqlplus -S -l "$DBUSER/$DBPASS@$DBSERVICE" <<EOF
        set feedback off
        set pages 0
        set heading off
        set colsep ,
        set trimspool on
        set linesize 32767
        spool $output_file
        variable offset number
        variable end_offset number
        exec :offset := $offset;
        exec :end_offset := $end_offset;
        $base_query;
        spool off
EOF

    /veritran/migracion-imagenes-BNA/V4delete-PROD.sh -lote "$output_file2" -dir_a_purgar /veritran/statics-storage-volume/BNA/

    line_count=$(wc -l < "$output_file" | awk '{print $1}')

    echo "Batch processed from offset $offset to $end_offset with $line_count records at $(date)" >> "$progress_log_file"

    return $line_count
}

offset=0
while true; do
    end_offset=$((offset + batch_size))
    
    process_batch $offset $end_offset
    records_processed=$?
    
    if [ "$records_processed" -eq 0 ]; then
        no_new_records_count=$((no_new_records_count + 1))
    else
        no_new_records_count=0
    fi

    if [ "$no_new_records_count" -ge "$max_empty_iterations" ]; then
        echo "$(date): No se encontraron registros COPIEDOK. Saliendo." >> $progress_log_file
        break
    fi
    
    offset=$end_offset
    sleep 60
done
