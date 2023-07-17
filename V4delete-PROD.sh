#!/bin/bash

CSV=""
EXISTE_ARCHIVO=false
deleted_ids=()
deletefail_ids=()
deletenotexist_ids=()

 


while [[ "$#" -gt 0 ]]; do
  case $1 in
    -lote) CSV="$2" lote="$2"; shift ;;
    -origen) origen="$2"; shift ;;
    -dir_a_purgar) destino="$2"; shift ;;
    -velocidad) RATE="$2"; shift ;;
    *) echo "Opción inválida. Use -lote ARCHIVO-LOTE y -velocidad para limitar de tasa de transferencia (default en K, si no se especifica no setea limite) y -destino para elegir el patch destino."; exit 1 ;;

 

  esac
  shift
done

 

log_dir="/veritran/migracion-imagenes-BNA/logs/"
archivo_existente="$log_dir/$lote"

 

if ls $archivo_existente >/dev/null 2>&1; then
  archivo_total="$(ls -t $archivo_existente | head -1)"
  EXISTE_ARCHIVO=true
else
  export archivo_total="$log_dir/$lote"
  touch $archivo_total
fi

 

IFS=$'\n' read -d '' -r -a tc_img_id_array <<< "$(cut -d ',' -f1 "logs/$CSV")"
IFS=$'\n' read -d '' -r -a create_date_array <<< "$(cut -d ',' -f2 "logs/$CSV")"
IFS=$'\n' read -d '' -r -a create_time_array <<< "$(cut -d ',' -f2 "logs/$CSV")"
IFS=$'\n' read -d '' -r -a oicm_path_array <<< "$(cut -d ',' -f3 "logs/$CSV")"
IFS=$'\n' read -d '' -r -a img_status <<< "$(cut -d ',' -f4 "logs/$CSV")"

 


num_lines="${#tc_img_id_array[@]}"

 

function borrar_imagen {
    local id=$1
    local fecha=$2
    local path=$3
    local dir_user=$4

    if [ -e "$path" ]; then
        rm -f $path
        if [ "$?" -eq 0 ]; then
            sed -i "s/^\($id,[^;]*,[^;]*\),.*/\1,DELETED/" "$archivo_total"
            deleted_ids+=("$id")
        else
            sed -i "s/^\($id,[^;]*,[^;]*\),.*/\1,DELETEFAIL/" "$archivo_total"
            deletefail_ids+=("$id")
        fi
    else
        sed -i "s/^\($id,[^;]*,[^;]*\),.*/\1,DELETENOTEXIST/" "$archivo_total"
        deletenotexist_ids+=("$id")
    fi
}

 

for ((i=0; i<num_lines; i++)); do
    tc_img_id="${tc_img_id_array[i]}"
    create_date="${create_date_array[i]}"
    create_time="${create_time_array[i]}"
    oicm_path="${oicm_path_array[i]}"
    dir_user="$(echo "$oicm_path" | awk -F'/' '{ print $1 }')"
    file="$(echo "$oicm_path" | awk -F'/' '{ print $2 }' | cut -d ";" -f1)"
    status="${img_status[i]}"

       echo "Borrando imagen: $tc_img_id $destino $oicm_path $file"
       borrar_imagen "$tc_img_id" "$create_date" "$destino/$oicm_path" "$destino/$dir_user"

done

############################
if [ "${#deleted_ids[@]}" -gt 0 ]; then
  deleted_ids_str=""
  log_file="$archivo_total.sqldeleted"
  query_counter=1

  echo "Realizando UPDATE en la base de datos como DELETEDOK para los registros que FUERON BORRADOS EN ORIGEN (GLUSTER)"

  for id in "${deleted_ids[@]}"; do
    deleted_ids_str+=" $id,"
    counter=$((counter + 1))
    
    if [ $counter -eq 250 ]; then
      query_filedok="$archivo_total.querydok$query_counter"

      echo "SET HEADING OFF" > "$query_filedok"
      echo "SET FEEDBACK OFF" >> "$query_filedok"
      echo "WHENEVER SQLERROR EXIT SQL.SQLCODE;" >> "$query_filedok"
      echo "" >> "$query_filedok"
      echo "UPDATE vtdb.TMP_C4_TENTATIVE_CLIENTS_IMG" >> "$query_filedok"
      echo "SET STATUS = 'DELETEDOK'" >> "$query_filedok"
      echo "WHERE TC_IMG_ID IN (${deleted_ids_str::-1});" >> "$query_filedok"
      echo "COMMIT;" >> "$query_filedok"
      echo "EXIT" >> "$query_filedok"
      
      
      if [ $? -ne 0 ]; then
        echo "Error durante el UPDATE o el COMMIT de los registros deleted en la base de datos. Enviar a Veritran el archivo: $query_filedok"
      else
        echo "UPDATE en $query_filedok EXITOSO"
      fi
      
      deleted_ids_str=""
      counter=0
      
      query_counter=$((query_counter + 1))
    fi
  done

  if [ -n "$deleted_ids_str" ]; then
    query_filedok="$archivo_total.querydok$query_counter"

    echo "SET HEADING OFF" > "$query_filedok"
    echo "SET FEEDBACK OFF" >> "$query_filedok"
    echo "WHENEVER SQLERROR EXIT SQL.SQLCODE;" >> "$query_filedok"
    echo "" >> "$query_filedok"
    echo "UPDATE vtdb.TMP_C4_TENTATIVE_CLIENTS_IMG" >> "$query_filedok"
    echo "SET STATUS = 'DELETEDOK'" >> "$query_filedok"
    echo "WHERE TC_IMG_ID IN (${deleted_ids_str::-1});" >> "$query_filedok"
    echo "COMMIT;" >> "$query_filedok"
    echo "EXIT" >> "$query_filedok"

    if [ $? -ne 0 ]; then
      echo "Error durante el UPDATE o el COMMIT de los registros deleted en la base de datos. Enviar a Veritran el archivo: $query_filedok"
    else
      echo "UPDATE en $query_filedok EXITOSO"
    fi
  fi
fi


############################
if [ "${#deletefail_ids[@]}" -gt 0 ]; then
  deletefail_ids_str=""
  log_file="$archivo_total.sqldeletefail"
  query_counter=1

  echo "Realizando UPDATE en la base de datos como DELETEFAIL para los registros que FUERON BORRADOS EN ORIGEN (GLUSTER)"

  for id in "${deletefail_ids[@]}"; do
    deletefail_ids_str+=" $id,"
    counter=$((counter + 1))
    
    if [ $counter -eq 250 ]; then
      query_filedf="$archivo_total.querydf$query_counter"

      echo "SET HEADING OFF" > "$query_filedf"
      echo "SET FEEDBACK OFF" >> "$query_filedf"
      echo "WHENEVER SQLERROR EXIT SQL.SQLCODE;" >> "$query_filedf"
      echo "" >> "$query_filedf"
      echo "UPDATE vtdb.TMP_C4_TENTATIVE_CLIENTS_IMG" >> "$query_filedf"
      echo "SET STATUS = 'DELETEFAIL'" >> "$query_filedf"
      echo "WHERE TC_IMG_ID IN (${deletefail_ids_str::-1});" >> "$query_filedf"
      echo "COMMIT;" >> "$query_filedf"
      echo "EXIT" >> "$query_filedf"
            
      if [ $? -ne 0 ]; then
        echo "Error durante el UPDATE o el COMMIT de los registros deletefail en la base de datos. Enviar a Veritran el archivo: $query_filedf"
      else
        echo "UPDATE en $query_filedf EXITOSO"
      fi
      
      deletefail_ids_str=""
      counter=0
      query_counter=$((query_counter + 1))
    fi
  done

  if [ -n "$deletefail_ids_str" ]; then
    query_filedf="$archivo_total.querydf$query_counter"

    echo "SET HEADING OFF" > "$query_filedf"
    echo "SET FEEDBACK OFF" >> "$query_filedf"
    echo "WHENEVER SQLERROR EXIT SQL.SQLCODE;" >> "$query_filedf"
    echo "" >> "$query_filedf"
    echo "UPDATE vtdb.TMP_C4_TENTATIVE_CLIENTS_IMG" >> "$query_filedf"
    echo "SET STATUS = 'DELETEFAIL'" >> "$query_filedf"
    echo "WHERE TC_IMG_ID IN (${deletefail_ids_str::-1});" >> "$query_filedf"
    echo "COMMIT;" >> "$query_filedf"
    echo "EXIT" >> "$query_filedf"

    if [ $? -ne 0 ]; then
      echo "Error durante el UPDATE o el COMMIT de los registros deletefail en la base de datos. Enviar a Veritran el archivo: $query_filedf"
    else
      echo "UPDATE en $query_filedf EXITOSO"
    fi
  fi
fi


############################
 
 if [ "${#deletenotexist_ids[@]}" -gt 0 ]; then
  deletenotexist_ids_str=""
  log_file="$archivo_total.sqldeletenotexist"
  query_counter=1

  echo "Realizando UPDATE en la base de datos como DELETENOTEXIST para los registros que NO EXISTEN EN ORIGEN (GLUSTER)"

  for id in "${deletenotexist_ids[@]}"; do
    deletenotexist_ids_str+=" $id,"
    counter=$((counter + 1))
    
    if [ $counter -eq 250 ]; then
      query_filedne="$archivo_total.querydne$query_counter"

      echo "SET HEADING OFF" > "$query_filedne"
      echo "SET FEEDBACK OFF" >> "$query_filedne"
      echo "WHENEVER SQLERROR EXIT SQL.SQLCODE;" >> "$query_filedne"
      echo "" >> "$query_filedne"
      echo "UPDATE vtdb.TMP_C4_TENTATIVE_CLIENTS_IMG" >> "$query_filedne"
      echo "SET STATUS = 'DELETENOTEXIST'" >> "$query_filedne"
      echo "WHERE TC_IMG_ID IN (${deletenotexist_ids_str::-1});" >> "$query_filedne"
      echo "COMMIT;" >> "$query_filedne"
      echo "EXIT" >> "$query_filedne"
            
      if [ $? -ne 0 ]; then
        echo "Error durante generacion del UPDATE o el COMMIT de los registros DELETENOTEXIST en la base de datos. Enviar a Veritran el archivo: $query_filedne"
      else
        echo "Archivo SQL en $query_filedne generado OK"
      fi
      
      deletenotexist_ids_str=""
      counter=0
      query_counter=$((query_counter + 1))
    fi
  done

  if [ -n "$deletenotexist_ids_str" ]; then
    query_filedne="$archivo_total.querydne$query_counter"

    echo "SET HEADING OFF" > "$query_filedne"
    echo "SET FEEDBACK OFF" >> "$query_filedne"
    echo "WHENEVER SQLERROR EXIT SQL.SQLCODE;" >> "$query_filedne"
    echo "" >> "$query_filedne"
    echo "UPDATE vtdb.TMP_C4_TENTATIVE_CLIENTS_IMG" >> "$query_filedne"
    echo "SET STATUS = 'DELETENOTEXIST'" >> "$query_filedne"
    echo "WHERE TC_IMG_ID IN (${deletenotexist_ids_str::-1});" >> "$query_filedne"
    echo "COMMIT;" >> "$query_filedne"
    echo "EXIT" >> "$query_filedne"

    if [ $? -ne 0 ]; then
      echo "Error durante el UPDATE o el COMMIT de los registros DELETENOTEXIST en la base de datos. Enviar a Veritran el archivo: $query_filedne"
    else
      echo "Archivo SQL en $query_filedne generado OK"
    fi
  fi
fi

echo "Ejecucion finalizada para el lote $CSV "

