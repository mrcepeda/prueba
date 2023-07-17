#!/bin/bash

dir_lotes=/veritran/migracion-imagenes-BNA/
archivos_lote=$(ls x???5??LoteBNAmm??{3..4}{0..8} x???5??LoteBNAmm??39)

 for lote_file in $archivos_lote; do
  echo "Ejecutando migratev5 para el lote: $lote_file"
  time bash migratev5.sh -lote "$lote_file" -destino /veritran/filesharebna-prod -origen /veritran/bricks/brick1/gv0/BNA/ 

        if [ "$?" -eq 0 ]; then
           mv $lote_file DONE/$lote_file
        else
         cp "$lote_file" TO-CHECK/
        fi

 echo "Finalizada la ejecución de migratev5.sh del lote: $lote_file"
done

echo "Todas las ejecuciones de los archivos de lote han finalizado."

