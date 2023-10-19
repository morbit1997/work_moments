#!/bin/bash

input_log_dir=/net/wsl-17/all_log_station
starttime=$(date +"%Y-%m-%d_%H:%M:%S")
output_log_dir="$PWD"
temp_xdmlog_dir=/root/tmp_xdmlog_data
arch_list_temp=$temp_xdmlog_dir/arch_list

usage() {
  cat <<EOF
Использование: $(basename "${BASH_SOURCE[0]}") [-h] -p path_value arg1 arg2
обязательные параметры arg1 arg2
arg1 - указать путь до папки логов (all_log_station)
arg2 - указать путь куда складывать отчеты
Пример: $(basename "${BASH_SOURCE[0]}") -p /net/wsl-17/all_log_station /root/xdm_logs
Если запустить без параметров, то будет использоваться по умолчанию $input_log_dir, $output_log_dir
EOF
  exit
}

#парсинг параметров запуска(указаны\неуказаны)
parse_params() {
  
  LOG_DIR="${1:-$input_log_dir}"
  output_dir="${2:-$output_log_dir}"

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -p | --param) 
      LOG_DIR="${2-}"
      output_dir="${3-}"
      shift
      ;;
    -?*) echo "Unknown option: $1"; exit 1 ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  # проверка на заданные параметры(пути)
  [[ -z "${LOG_DIR-}" ]] && { echo "Не указан параметр: LOG_DIR - путь к логам-бекапам"; exit 1;}
  [[ -z "${output_dir-}" ]] && { echo "Не указан параметр 2: output_dir - место сохранения отчетов"; output_dir="$PWD";}
  [[ ${#args[@]} -eq 0 ]] && { echo "Используются параметры по-умолчанию: $LOG_DIR, $output_dir";} 
  return 0
}

cleanup() {
  if [ -d "$temp_xdmlog_dir" ]; then
    rm -rf "$temp_xdmlog_dir"
  fi
}

sorting_func(){
input_file=$1
output_path=$2
awk -v output_path="$output_path" '
{
    user=$1
    month=$4
    year=$7
    filename_user=user "_xdmcp_report.txt"
    filename_month=month "_xdmcp_report.txt"
    filename_year=year "_xdmcp_report.txt"
    print $0 >> output_path filename_user
    print $0 >> output_path filename_month
    print $0 >> output_path filename_year
}
' "$input_file"
}

parsing_func(){
if [ -z "$norm_year" ] && [ -z "$log_dirs" ]; then
  last -aFf "${file%.gz}" | tac > "$output_dir/$listdir/$log_dirs/$wsl_name/loglist"
  sed -i '/^$/d' "$output_dir/$listdir/$wsl_name/loglist"
  #echo "мы там где if"
  while read line; do
      columns=($line)
      array_size=${#columns[@]}
      first_elem=$(echo ${columns[1]} | cut -d':' -f1)
      last_elem=$(echo ${columns[$array_size-1]} | cut -d':' -f1)
      flag=0

      for (( i=0; i<${#first_elem}; i++ )); do
          if [ "${first_elem:$i:1}" != "${last_elem:$i:1}" ]; then
              break
          else
              flag=1
          fi
      done

      if [[ $flag -eq 1 ]]; then
          echo "$line" >> "$output_dir/$listdir/$wsl_name/xdm_list_log.log"
      fi
  done < "$output_dir/$listdir/$wsl_name/loglist"
else 
  last -aFf "${file%.gz}" | tac > "$output_dir/$norm_year/$log_dirs/$wsl_name/loglist"
  sed -i '/^$/d' "$output_dir/$norm_year/$log_dirs/$wsl_name/loglist"
  #echo "мы там где else"
  while read line; do
    columns=($line)
    array_size=${#columns[@]}
    first_elem=$(echo ${columns[1]} | cut -d':' -f1)
    last_elem=$(echo ${columns[$array_size-1]} | cut -d':' -f1)
    flag=0

    for (( i=0; i<${#first_elem}; i++ )); do
        if [ "${first_elem:$i:1}" != "${last_elem:$i:1}" ]; then
            break
        else
            flag=1
        fi
    done

    if [[ $flag -eq 1 ]]; then
        echo "$line" >> "$output_dir/$norm_year/$log_dirs/$wsl_name/xdm_list_log.log"
    fi
  done < "$output_dir/$norm_year/$log_dirs/$wsl_name/loglist"
fi

}

# Начало скрипта
parse_params "$@"

if ! [ -d "$output_dir" ]; then
  mkdir "$output_dir"
elif ! [ $(ls "$output_dir" | wc -l) -eq 0 ] && [ "$output_dir" != "." ] && [ "$output_dir" != "$PWD" ]; then
  echo "Директория $output_dir не пустая "
  exit 1
fi

if ! [ $(ls "$temp_xdmlog_dir" | wc -l) -eq 0 ]; then
  echo "Директория $temp_xdmlog_dir не пустая. Удаление временных файлов"
  rm -rfv $temp_xdmlog_dir
fi

if ! [ -d $temp_xdmlog_dir ]; then
  mkdir $temp_xdmlog_dir
  echo "Создал папку $temp_xdmlog_dir"
fi

case "$(basename "$LOG_DIR")" in
  20[0-9][0-9])
    norm_year=$(basename "$LOG_DIR")
    for log_dirs in $(ls -dt $LOG_DIR/*/ | xargs -n1 basename); do
      echo "$log_dirs started parsing!" >> "$output_dir/$starttime"-process.log
      if find "$output_dir/$norm_year" -maxdepth 1 -type d | grep -q "$log_dirs"; then #проверка на существующий бекап(вторрой раз если запустить заново не будет делать если есть папка)
        continue
      fi
      
      if ! [ -d "$temp_xdmlog_dir/$log_dirs" ]; then
        mkdir "$temp_xdmlog_dir/$log_dirs"
      fi

      if ! [ -d "$output_dir/$norm_year/$log_dirs" ]; then 
        mkdir -p "$output_dir/$norm_year/$log_dirs"
      fi

      for arch in $(find "$LOG_DIR" -type f -name "*tar.gz")
      do
        wsl_name=$(basename "$arch" | sed 's/\..*//')
        tar -tf "$arch" | grep -E "(wtmp*)" > $arch_list_temp 
        while IFS= read -r log_files
        do
          case "$(basename "$log_files")" in 
            wtmp-*|wtmp*)
              tar xf "$arch" -C "$temp_xdmlog_dir/$log_dirs" "$log_files"
              if ! [ -d "$output_dir/$norm_year/$log_dirs/$wsl_name" ]; then
                mkdir -p "$output_dir/$norm_year/$log_dirs/$wsl_name"
              fi
              if [[ "${log_files##*.}" == "gz" ]]; then
                file=$temp_xdmlog_dir/$log_dirs$log_files
                gzip -d "$file"
                parsing_func
              else
                  file=$temp_xdmlog_dir/$log_dirs$log_files
                parsing_func
              fi
            ;;
          esac
        done < $arch_list_temp
        sorting_func "$output_dir/$norm_year/$log_dirs/$wsl_name/xdm_list_log.log" "$output_dir/$norm_year/$log_dirs/$wsl_name/"
        echo "$wsl_name done!" >> "$output_dir/$starttime"-process.log
      done
      echo "$log_dirs done!" >> "$output_dir/$starttime"-process.log
    done
  ;;
  list-*)
    listdir=$(basename "$LOG_DIR")
    echo "$listdir started parsing!" >> "$output_dir/$starttime"-process.log
    for arch in $(find "$LOG_DIR" -type f -name "*tar.gz")
    do
      if ! [ -d "$temp_xdmlog_dir/$listdir" ]; then 
        mkdir "$temp_xdmlog_dir/$listdir"
      fi
      wsl_name=$(basename "$arch" | sed 's/\..*//')
      tar -tf "$arch" | grep -E "(wtmp*)" > $arch_list_temp 
      while IFS= read -r log_files
      do
      case "$(basename "$log_files")" in 
        wtmp-*|wtmp*)
          tar xf "$arch" -C "$temp_xdmlog_dir/$listdir" "$log_files"
          if ! [ -d "$output_dir/$listdir/$wsl_name" ]; then
            mkdir -p "$output_dir/$listdir/$wsl_name"
          fi
          if [[ "${log_files##*.}" == "gz" ]]; then
            file=$temp_xdmlog_dir/$listdir$log_files
            gzip -d "$file"
            parsing_func
          else
            file=$temp_xdmlog_dir/$listdir$log_files
            parsing_func
          fi
        ;;
      esac
    done < $arch_list_temp
    sorting_func "$output_dir/$listdir/$wsl_name/xdm_list_log.log" "$output_dir/$listdir/$wsl_name/"
    echo "$wsl_name done!" >> "$output_dir/$starttime"-process.log
  done
  ;;
  *)
    for years in $(ls -dt $LOG_DIR/*/) #список папок с бекапами логов
    do
      norm_year=$(basename "$years")
      for log_dirs in $(ls -dt $years/*/ | xargs -n1 basename); do
        echo "$log_dirs started parsing!" >> "$output_dir/$starttime"-process.log
        if find "$output_dir/$norm_year" -maxdepth 1 -type d | grep -q "$log_dirs"; then #проверка на существующий бекап(вторрой раз если запустить заново не будет делать если есть папка)
          continue
        fi
         
        if ! [ -d "$temp_xdmlog_dir/$log_dirs" ]; then
          mkdir "$temp_xdmlog_dir/$log_dirs"
        fi

        if ! [ -d "$output_dir/$norm_year/$log_dirs" ]; then 
          mkdir -p "$output_dir/$norm_year/$log_dirs"
        fi

        for arch in $(find "$years$log_dirs" -type f -name "*tar.gz")
        do
          wsl_name=$(basename "$arch" | sed 's/\..*//')
          tar -tf "$arch" | grep -E "(wtmp*)" > $arch_list_temp 
          while IFS= read -r log_files
          do
            case "$(basename "$log_files")" in 
              wtmp-*|wtmp*)
                tar xf "$arch" -C "$temp_xdmlog_dir/$log_dirs" "$log_files"
                if ! [ -d "$output_dir/$norm_year/$log_dirs/$wsl_name" ]; then
                  mkdir -p "$output_dir/$norm_year/$log_dirs/$wsl_name"
                fi
                if [[ "${log_files##*.}" == "gz" ]]; then
                  file=$temp_xdmlog_dir/$log_dirs$log_files
                  gzip -d "$file"
                  parsing_func
                else
                  file=$temp_xdmlog_dir/$log_dirs$log_files
                  parsing_func
                fi
                ;;
            esac
          done < $arch_list_temp
          sorting_func "$output_dir/$norm_year/$log_dirs/$wsl_name/xdm_list_log.log" "$output_dir/$norm_year/$log_dirs/$wsl_name/"
          echo "$wsl_name done!" >> "$output_dir/$starttime"-process.log
        done
        echo "$log_dirs done!" >> "$output_dir/$starttime"-process.log
      done
    done
  ;;
esac
echo "All done." >> "$output_dir/$starttime"-process.log
cleanup
