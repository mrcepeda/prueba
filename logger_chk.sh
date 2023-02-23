#!/bin/bash

# Obtener el hostname del servidor como argumento
hostname=$1

# Conectarse por SSH al servidor
ssh -t $hostname << EOF

# Verificar si el archivo /veritran/vt-net/log/logger.cfg ha sido modificado

if [[ $(find /veritran/vt-net/log/logger.cfg -mtime -1) ]]; then
  logger "El archivo /veritran/vt-net/log/logger.cfg ha sido modificado"
fi

# Buscar la cadena regexp P1*HOST* en el archivo logger.cfg

while read line; do
  if [[ $line =~ P1.*HOST.*=([0-9]+) ]]; then
    if [[ ${BASH_REMATCH[1]} -gt 6 ]]; then
      logger "El valor de la variable ${BASH_REMATCH[0]} es mayor a 6"
    fi
  fi
done < /veritran/vt-net/log/logger.cfg

EOF

# Verificar que el script haya corrido correctamente
if [[ $? -ne 0 ]]; then
  logger "Hubo un problema en la ejecución del script en el servidor $hostname"
fi
