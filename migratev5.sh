#!/bin/bash
CSV=""
EXISTE_ARCHIVO=false
ok_ids=()
fail_ids=()
exist_ids=()

source db-access.pwd

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -lote) CSV="$2" lote="$2"; shift ;;
    -origen) origen="$2"; shift ;;
    -destino) destino="$2"; shift ;;
    -velocidad) RATE="$2"; shift ;;

    *) echo "Opción inválida. Use -lote ARCHIVO-LOTE y -velocidad para limitar de tasa de transferencia (default en K, si no se especifica no setea limite) y -destino para elegir el patch destino."; exit 1 ;;

  esac
  shift
done

 

log_dir="/veritran/migracion-imagenes-BNA/logs"
archivo_existente="$log_dir/lista_imagenes_$lote"*.log

 

if ls $archivo_existente >/dev/null 2>&1; then
  archivo_total="$(ls -t $archivo_existente | head -1)"
  EXISTE_ARCHIVO=true
else
  export archivo_total="$log_dir/lista_imagenes_"$lote".log"
  touch $archivo_total
fi

 

cp $CSV $archivo_total
 
if [[ -z "$RATE" ]] ; then
  export RATE=0
fi


# Cargar datos en arrays
IFS=$'\n' read -d '' -r -a tc_img_id_array <<< "$(cut -d ',' -f1 "$CSV")"
IFS=$'\n' read -d '' -r -a create_date_array <<< "$(cut -d ',' -f2 "$CSV")"
IFS=$'\n' read -d '' -r -a create_time_array <<< "$(cut -d ',' -f3 "$CSV")"
IFS=$'\n' read -d '' -r -a oicm_path_array <<< "$(cut -d ',' -f4 "$CSV")"

num_lines="${#tc_img_id_array[@]}"

function migrar_imagen {
    local id=$1
    local fecha=$2
    local path=$4
    if [ ! -e "$path" ]; then
        mkdir -p "$destino/$dir_user" && rsync -rpt --inplace -W -h --bwlimit=$RATE "$origen/$dir_user/$file" "$path"

 

        if [ "$?" -eq 0 ]; then
        registros_log+=("$id,${create_date},${create_time},${oicm_path},OK")
        ok_ids+=("$id")
        else
        registros_log+=("$id,${create_date},${create_time},${oicm_path},FAIL")
        fail_ids+=("$id")
        fi
    else
        registros_log+=("$id,${create_date},${create_time},${oicm_path},EXIST")
        exist_ids+=("$id")

    fi
}

########################


### MAIN
registros_log=()

 

for ((i=0; i<num_lines; i++)); do
    tc_img_id="${tc_img_id_array[i]}"
    create_date="${create_date_array[i]}"
    create_time="${create_time_array[i]}"
    oicm_path="${oicm_path_array[i]}"
    dir_user="$(echo "$oicm_path" | awk -F'/' '{ print $1 }')"
    file="$(echo "$oicm_path" | awk -F'/' '{ print $2 }' | cut -d ";" -f1)"

 

        echo "Migrando con ARRAYS: $tc_img_id $destino $oicm_path $file"
        migrar_imagen $tc_img_id $create_date "$destino/$oicm_path"

 

done

 

for registro in "${registros_log[@]}"; do
    echo "$registro"
done > "$archivo_total"
 



 if [ "${#ok_ids[@]}" -gt 0 ]; then
  ok_ids_str=""
  log_file="$archivo_total.sqlOK"
  query_counter=1

  echo "Realizando UPDATE en la base de datos como COPIED para los registros que FUERON COPIADOS EN DESTINO (NFS-AWS)"

  for id in "${ok_ids[@]}"; do
    ok_ids_str+=" $id,"
    counter=$((counter + 1))
    
    if [ $counter -eq 250 ]; then
      query_fileok="$archivo_total.queryok$query_counter"

      echo "SET HEADING OFF" > "$query_fileok"
      echo "SET FEEDBACK OFF" >> "$query_fileok"
      echo "WHENEVER SQLERROR EXIT SQL.SQLCODE;" >> "$query_fileok"
      echo "" >> "$query_fileok"
      echo "UPDATE vtdb.TMP_C4_TENTATIVE_CLIENTS_IMG" >> "$query_fileok"
      echo "SET STATUS = 'COPIEDOK'" >> "$query_fileok"
      echo "WHERE TC_IMG_ID IN (${ok_ids_str::-1});" >> "$query_fileok"
      echo "COMMIT;" >> "$query_fileok"
      echo "EXIT" >> "$query_fileok"
      
      
      if [ $? -ne 0 ]; then
        echo "Error durante el UPDATE o el COMMIT de los registros COPIED en la base de datos. Enviar a Veritran el archivo: $query_fileok"
      else
        echo "UPDATE en $query_fileok EXITOSO"
      fi
      
      ok_ids_str=""
      counter=0
      
      query_counter=$((query_counter + 1))
    fi
  done

  if [ -n "$ok_ids_str" ]; then
    query_fileok="$archivo_total.queryok$query_counter"

    echo "SET HEADING OFF" > "$query_fileok"
    echo "SET FEEDBACK OFF" >> "$query_fileok"
    echo "WHENEVER SQLERROR EXIT SQL.SQLCODE;" >> "$query_fileok"
    echo "" >> "$query_fileok"
    echo "UPDATE vtdb.TMP_C4_TENTATIVE_CLIENTS_IMG" >> "$query_fileok"
    echo "SET STATUS = 'COPIEDOK'" >> "$query_fileok"
    echo "WHERE TC_IMG_ID IN (${ok_ids_str::-1});" >> "$query_fileok"
    echo "COMMIT;" >> "$query_fileok"
    echo "EXIT" >> "$query_fileok"

    if [ $? -ne 0 ]; then
      echo "Error durante el UPDATE o el COMMIT de los registros COPIED en la base de datos. Enviar a Veritran el archivo: $query_fileok"
    else
      echo "UPDATE en $query_fileok EXITOSO"
    fi
  fi
fi
#################################################
if [ "${#fail_ids[@]}" -gt 0 ]; then
  fail_ids_str=""
  log_file="$archivo_total.sqlfail"
  query_counter=1

  echo "Realizando UPDATE en la base de datos como FAIL para los registros que FALLARON AL INTENTAR SER COPIADOS EN DESTINO (NFS-AWS)"

  for id in "${fail_ids[@]}"; do
    fail_ids_str+=" $id,"
    counter=$((counter + 1))
    
    if [ $counter -eq 250 ]; then
      query_filefail="$archivo_total.queryfail$query_counter"

      echo "SET HEADING OFF" > "$query_filefail"
      echo "SET FEEDBACK OFF" >> "$query_filefail"
      echo "WHENEVER SQLERROR EXIT SQL.SQLCODE;" >> "$query_filefail"
      echo "" >> "$query_filefail"
      echo "UPDATE vtdb.TMP_C4_TENTATIVE_CLIENTS_IMG" >> "$query_filefail"
      echo "SET STATUS = 'FAILOK'" >> "$query_filefail"
      echo "WHERE TC_IMG_ID IN (${fail_ids_str::-1});" >> "$query_filefail"
      echo "COMMIT;" >> "$query_filefail"
      echo "EXIT" >> "$query_filefail"
      
      
      if [ $? -ne 0 ]; then
        echo "Error durante el UPDATE o el COMMIT de los registros FAIL en la base de datos. Enviar a Veritran el archivo: $query_filefail"
      else
        echo "UPDATE en $query_filefail EXITOSO"
      fi
      
      fail_ids_str=""
      counter=0
      
      query_counter=$((query_counter + 1))
    fi
  done

  if [ -n "$fail_ids_str" ]; then
    query_filefail="$archivo_total.queryfail$query_counter"

    echo "SET HEADING OFF" > "$query_filefail"
    echo "SET FEEDBACK OFF" >> "$query_filefail"
    echo "WHENEVER SQLERROR EXIT SQL.SQLCODE;" >> "$query_filefail"
    echo "" >> "$query_filefail"
    echo "UPDATE vtdb.TMP_C4_TENTATIVE_CLIENTS_IMG" >> "$query_filefail"
    echo "SET STATUS = 'FAILOK'" >> "$query_filefail"
    echo "WHERE TC_IMG_ID IN (${fail_ids_str::-1});" >> "$query_filefail"
    echo "COMMIT;" >> "$query_filefail"
    echo "EXIT" >> "$query_filefail"

    if [ $? -ne 0 ]; then
      echo "Error durante el UPDATE o el COMMIT de los registros FAIL en la base de datos. Enviar a Veritran el archivo: $query_filefail"
    else
      echo "UPDATE en $query_filefail EXITOSO"
    fi
  fi
fi

#################################################

if [ "${#exist_ids[@]}" -gt 0 ]; then
  exist_ids_str=""
  log_file="$archivo_total.sqlexist"
  query_counter=1

  echo "Realizando UPDATE en la base de datos como EXIST para los registros que FALLARON AL INTENTAR SER COPIADOS EN DESTINO (NFS-AWS)"

  for id in "${exist_ids[@]}"; do
    exist_ids_str+=" $id,"
    counter=$((counter + 1))
    
    if [ $counter -eq 250 ]; then
      query_fileexist="$archivo_total.queryexist$query_counter"

      echo "SET HEADING OFF" > "$query_fileexist"
      echo "SET FEEDBACK OFF" >> "$query_fileexist"
      echo "WHENEVER SQLERROR EXIT SQL.SQLCODE;" >> "$query_fileexist"
      echo "" >> "$query_fileexist"
      echo "UPDATE vtdb.TMP_C4_TENTATIVE_CLIENTS_IMG" >> "$query_fileexist"
      echo "SET STATUS = 'EXISTOK'" >> "$query_fileexist"
      echo "WHERE TC_IMG_ID IN (${exist_ids_str::-1});" >> "$query_fileexist"
      echo "COMMIT;" >> "$query_fileexist"
      echo "EXIT" >> "$query_fileexist"
      
      
      if [ $? -ne 0 ]; then
        echo "Error durante el UPDATE o el COMMIT de los registros EXIST en la base de datos. Enviar a Veritran el archivo: $query_fileexist"
      else
        echo "UPDATE en $query_fileexist EXITOSO"
      fi
      
      exist_ids_str=""
      counter=0
      
      query_counter=$((query_counter + 1))
    fi
  done

  if [ -n "$exist_ids_str" ]; then
    query_fileexist="$archivo_total.queryexist$query_counter"

    echo "SET HEADING OFF" > "$query_fileexist"
    echo "SET FEEDBACK OFF" >> "$query_fileexist"
    echo "WHENEVER SQLERROR EXIT SQL.SQLCODE;" >> "$query_fileexist"
    echo "" >> "$query_fileexist"
    echo "UPDATE vtdb.TMP_C4_TENTATIVE_CLIENTS_IMG" >> "$query_fileexist"
    echo "SET STATUS = 'EXISTOK'" >> "$query_fileexist"
    echo "WHERE TC_IMG_ID IN (${exist_ids_str::-1});" >> "$query_fileexist"
    echo "COMMIT;" >> "$query_fileexist"
    echo "EXIT" >> "$query_fileexist"

    if [ $? -ne 0 ]; then
      echo "Error durante el UPDATE o el COMMIT de los registros EXIST en la base de datos. Enviar a Veritran el archivo: $query_fileexist"
    else
      echo "UPDATE en $query_fileexist EXITOSO"
    fi
  fi
fi


echo "Ejecucion finalizada para el lote $CSV "

