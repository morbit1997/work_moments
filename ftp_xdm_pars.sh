#!/bin/bash
#2в1 xdmcp и ftp парс

starttime=$(date +"%Y-%m-%d_%H:%M:%S")
actual_log_dirs="/net/wsl-17/all_log_station"
log_dir="$PWD" 
temp_dir="/root/tmp_log_data"
arch_list_temp="$temp_ftp_dir/arch_list"
pars_opt="ftp"

usage() {
  cat <<EOF
Использование: $(basename "${BASH_SOURCE[0]}") -p arg1 arg2 pars_opt
обязательные параметры arg1 arg2
arg1 - указать путь до папки логов
arg2 - указать путь куда складывать отчеты
pars_opt - ftp или xdmcp(указать что парсить. По умолчанию стоит ftp)
Пример: $(basename "${BASH_SOURCE[0]}") -p /net/wsl-17/all_log_station/2023 /root/logs xdmcp

EOF
  exit
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
if [ -z "$norm_year" ] && [ -z "$dir" ]; then
  last -aFf "${file%.gz}" | tac > "$data_dir/$listdir/$dir/$wsl_name/loglist"
  sed -i '/^$/d' "$data_dir/$listdir/$wsl_name/loglist"
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
          echo "$line" >> "$data_dir/$listdir/$wsl_name/xdm_list_log.log"
      fi
  done < "$data_dir/$listdir/$wsl_name/loglist"
else 
  last -aFf "${file%.gz}" | tac > "$data_dir/$norm_year/$dir/$wsl_name/loglist"
  sed -i '/^$/d' "$data_dir/$norm_year/$dir/$wsl_name/loglist"
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
        echo "$line" >> "$data_dir/$norm_year/$dir/$wsl_name/xdm_list_log.log"
    fi
  done < "$data_dir/$norm_year/$dir/$wsl_name/loglist"
fi

}
#та самая функция очистки, доведенная до ума
cleanup() {
  if [ -d "$temp_dir" ]; then
    rm -rvf "$temp_dir"
  fi
}

#парсинг параметров запуска(указаны\неуказаны)
parse_params() {
  
  actual_log_dir="${1:-$actual_log_dirs}"
  data_dir="${2:-$log_dir}"
	pars_opt="${3:-}"
  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -p | --param) # example named parameter
      actual_log_dir="${2-}"
      data_dir="${3-}"
      pars_opt="${4-}"
      shift
      ;;
    -?*) echo "Unknown option: $1"; exit 1 ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  # проверка на заданные параметры(пути)
  [[ -z "${actual_log_dir-}" ]] && { echo "Не указан параметр: actual_log_dir - путь к логам-бекапам"; exit 1;}
  [[ -z "${data_dir-}" ]] && { echo "Не указан параметр 2: data_dir - место сохранения отчетов"; data_dir="$PWD";}
  [[ ${#args[@]} -eq 0 ]] && { echo "Используются параметры по-умолчанию: $actual_log_dir, $data_dir";} 
  return 0
}
#парсер для vsftpd логов
vsftpd_pars() {
output_path=$2
input_log=$1
awk --re-interval -v output_path="$output_path" '
/\[.*\] \[.*\] OK/ {
  match($0, /\[([^]]+)\] \[([^]]+)\] OK/, groups)
  pid = groups[1]
  user = groups[2]
  action = substr($0, RSTART + RLENGTH)
  date = substr($2, 1, 3)
  day = substr($3, 1, 2)
  time = substr($4, 1, length($4))
  year = substr($5, 1, 4)
  filename_all = "ftp_logs.txt"
  filename_users = user ".txt"
  filename_year = year "_" "report.txt"
  filename_month = date "_" "report.txt"
  match(action, "(([0-9]{1,3}).){3}([0-9]{1,3}){1}" , ip)
  ip_addr = ip[0]
  filename_user_ip = user "_" ip_addr ".txt"
  print "Date: " date, day, "| Time:" time, year, "| PID: " pid, "| Status :" action >> output_path filename_users
  print "Date: " date, day, "| Time:" time, year, "| PID: " pid, "| User: " user, "| Status: " action >> output_path filename_all
  print "Date: " date, day, "| Time:" time, year, "| PID: " pid, "| User: " user, "| Status: " action >> output_path filename_year
  print "Date: " date, day, "| Time:" time, year, "| PID: " pid, "| User: " user, "| Status: " action >> output_path filename_month
  print "Date: " date, day, "| Time:" time, year, "| PID: " pid, "| Status :" action >> output_path filename_user_ip

}
' "$input_log"
}
#парсер для pure-ftpd логов
pureftpd_pars() {
output_path=$1
awk --re-interval -v output_path="$output_path" '
/pure-ftpd: \(([^]]+)@(([0-9]{1,3}[\.]){3}[0-9]{1,3})\)/ {
  match($0, /pure-ftpd: \(([^]]+)@(([0-9]{1,3}[\.]){3}[0-9]{1,3})\)/, matches)
  month = $1
  date = $2
  time = $3
  host = $4
  client = matches[1]
  ip = matches[2]
  status = substr($0, RSTART + RLENGTH)
  filename_users = client ".txt"
  filename_users_ip = client "_" ip ".txt"
  filename_all = "ftp_logs.txt"
  filename_month = month "_" "report.txt"
  print "Date: " month, date, "| Time:" time, "| Host: " host, "| IP: " ip, "| Status: " status >> output_path filename_users
  print "Date: " month, date, "| Time:" time, "| Host: " host, "| User: " client, ip, "| Status: " status >> output_path filename_all
  print "Date: " month, date, "| Time:" time, "| Host: " host, "| Status : " status >> output_path filename_users_ip
  print "Date: " month, date, "| Time:" time, "| Host: " host, "| User: " client, ip, "| Status: " status >> output_path filename_month
}
'
}
#оформление шапочки время генерации и юзер-айпи
shapka(){
folder_path=$1
datetime=$(date +"%Y-%m-%d %H:%M:%S")
pattern="^[^_]+_[0-9]{1,3}(\.[0-9]{1,3}){3}"
for file in "$folder_path"/*.txt; do
    filename=$(basename "$file" .txt)
    if [[ $filename =~ $pattern ]]; then
        sed -i "1i\\User: $filename\ngeneration time: $datetime \n" "$file"
    else
        sed -i "1igeneration time: $datetime \n" "$file"
    fi
done
}

parse_params "$@"

path_last_elem1=${actual_log_dir:$((${#actual_log_dir}-1)):1}
if [ $path_last_elem1 == "/" ]; then
  echo "все хорошо"
else
  echo "забыли \ в пути"
  exit 1
fi

if ! [ -d "$data_dir" ]; then
  mkdir "$data_dir"
elif ! [ $(ls "$data_dir" | wc -l) -eq 0 ] && [ "$data_dir" != "$PWD" ] && [ "$data_dir" != "." ]; then
  echo "Директория $data_dir не пустая "
  exit 1
fi

if ! [ $(ls "$temp_dir" | wc -l) -eq 0 ]; then
  echo "$temp_dir Не пустая"
  rm -rfv $temp_dir
fi

if ! [ -d $temp_dir ]; then
  mkdir "$temp_dir"
	echo "создаем папку"
fi

case "$(basename "$actual_log_dir")" in
  20[0-9][0-9])
    norm_year=$(basename "$actual_log_dir")
    for dir in $(ls -dt "$actual_log_dir"/*/ | xargs -n1 basename) #список папок с бекапами логов
    do
      (
        dir_name="$dir"   #получить нормальное имя папки 
        if find "$data_dir/$norm_year" -maxdepth 1 -type d | grep -q "$dir"; then #проверка на существующий бекап(вторрой раз если запустить заново не будет делать если есть папка)
            continue
        fi

        if ! [ -d "$temp_dir/$dir" ]; then 
            mkdir "$temp_dir/$dir"
        fi

        if ! [ -d "$data_dir/$norm_year/$dir" ]; then 
            mkdir -p "$data_dir/$norm_year/$dir"
        fi

        for arch in $(find "$actual_log_dir$dir" -type f -name "*tar.gz") #проходка по архивам
        do
          wsl_name=$(basename "$arch" | sed 's/\..*//')
          echo "$wsl_name processing..."
					tar --use-compress-program=pigz -tf "$arch" | grep -E "(messages*|vsftpd*|wtmp*)" > "$temp_dir/$dir_name-$wsl_name" #просмотр содержимого архива и поиск лог файлов
					while IFS= read -r log_files
					do
						case $pars_opt in
							ftp)
								case "$(basename "$log_files")" in 
									messages-*|messages|vsftpd.log*)
										tar --use-compress-program=pigz -xf "$arch" -C "$temp_dir/$dir" "$log_files"
										if ! [ -d "$data_dir/$norm_year/$dir_name/$wsl_name" ]; then
												mkdir -p "$data_dir/$norm_year/$dir_name/$wsl_name"
										fi
										if [[ "${log_files##*.}" == "gz" ]]; then
												zcat "$temp_dir/$dir/$log_files" | pureftpd_pars "$data_dir/$norm_year/$dir/$wsl_name/"
										else
												cat "$temp_dir/$dir/$log_files" | pureftpd_pars "$data_dir/$norm_year/$dir/$wsl_name/"
												vsftpd_pars "$temp_dir/$dir/$log_files" "$data_dir/$norm_year/$dir/$wsl_name/"
										fi
									;;               
							esac
							;;
							xdmcp)
								case "$(basename "$log_files")" in
									wtmp-*|wtmp*)
											tar --use-compress-program=pigz -xf "$arch" -C "$temp_dir/$dir" "$log_files"
											if ! [ -d "$data_dir/$norm_year/$dir_name/$wsl_name" ]; then
													mkdir -p "$data_dir/$norm_year/$dir_name/$wsl_name"
											fi
											if [[ "${log_files##*.}" == "gz" ]]; then
													file=$temp_dir/$dir$log_files
													gzip -d "$file"
													parsing_func
											else
													file=$temp_dir/$dir$log_files
													parsing_func
											fi
									;;                    
							esac
							;;
						esac
						done < "$temp_dir/$dir_name-$wsl_name"
					case $pars_opt in
						ftp)
							shapka "$data_dir/$norm_year/$dir/$wsl_name/"
						;;
						xdmcp)
							sorting_func "$data_dir/$norm_year/$dir/$wsl_name/xdm_list_log.log" "$data_dir/$norm_year/$dir/$wsl_name/"
						;;
					esac
					done
          #echo "$dir_name done!" >> "$starttime"-process.log #минилог результатов
        ) &
      done
    wait
  ;;
  list-*)
    listdir=$(basename "$actual_log_dir")
    for arch in $(find "$actual_log_dir" -type f -name "*tar.gz") #проходка по архивам
    do
      (
        wsl_name=$(basename "$arch" | sed 's/\..*//')
        echo "$wsl_name processing..."
        tar --use-compress-program=pigz -tf "$arch" | grep -E "(messages*|vsftpd*|wtmp*)" > "$temp_dir/$listdir-$wsl_name" #просмотр содержимого архива и поиск лог файлов
        if ! [ -d "$temp_dir/$listdir" ]; then 
          mkdir "$temp_dir/$listdir"
        fi
				while IFS= read -r log_files
				do
					case $pars_opt in
						ftp)
							case "$(basename "$log_files")" in 
								messages-*|messages|vsftpd.log*)
									tar --use-compress-program=pigz -xf "$arch" -C "$temp_dir/$listdir" "$log_files"
									if ! [ -d "$data_dir/$listdir/$wsl_name" ]; then
											mkdir -p "$data_dir/$listdir/$wsl_name"
									fi
									if [[ "${log_files##*.}" == "gz" ]]; then
											zcat "$temp_dir/$listdir/$log_files" | pureftpd_pars "$data_dir/$listdir/$wsl_name/"
									else
											cat "$temp_dir/$listdir/$log_files" | pureftpd_pars "$data_dir/$listdir/$wsl_name/"
											vsftpd_pars "$temp_dir/$listdir/$log_files" "$data_dir/$listdir/$wsl_name/"
									fi
								;;               
						esac
						;;
						xdmcp)
							case "$(basename "$log_files")" in
								wtmp-*|wtmp*)
										tar --use-compress-program=pigz -xf "$arch" -C "$temp_dir/$listdir" "$log_files"
										if ! [ -d "$data_dir/$listdir/$wsl_name" ]; then
												mkdir -p "$data_dir/$listdir/$wsl_name"
										fi
										if [[ "${log_files##*.}" == "gz" ]]; then
												file=$temp_dir/$listdir$log_files
												gzip -d "$file"
												parsing_func
										else
												file=$temp_dir/$listdir$log_files
												parsing_func
										fi
								;;                    
						esac
						;;
					esac
				done < "$temp_dir/$listdir-$wsl_name"
				case $pars_opt in
					ftp)
						shapka "$data_dir/$listdir/$wsl_name/"
					;;
					xdmcp)
						sorting_func "$data_dir/$listdir/$wsl_name/xdm_list_log.log" "$data_dir/$listdir/$wsl_name/"
					;;
				esac
      ) &
    done
    wait
    #echo "$listdir done!" >> "$starttime"-process.log #минилог результатов
  ;;
  *)
    for years in $(ls -dt $actual_log_dir/*/) #список папок с бекапами логов
    do
      norm_year=$(basename "$years")
      for dir in $(ls -dt $years/*/ | xargs -n1 basename) #список папок с бекапами логов
      do
        (
          dir_name="$dir"   #получить нормальное имя папки 
          if find "$data_dir/$norm_year" -maxdepth 1 -type d | grep -q "$dir"; then #проверка на существующий бекап(вторрой раз если запустить заново не будет делать если есть папка)
              continue
          fi

          if ! [ -d "$temp_dir/$dir" ]; then 
              mkdir "$temp_dir/$dir"
          fi

          if ! [ -d "$data_dir/$norm_year/$dir" ]; then 
              mkdir -p "$data_dir/$norm_year/$dir"
          fi

          for arch in $(find "$years$dir" -type f -name "*tar.gz") #проходка по архивам
          do
              wsl_name=$(basename "$arch" | sed 's/\..*//')
              echo "$wsl_name processing..."
							tar --use-compress-program=pigz -tf "$arch" | grep -E "(messages*|vsftpd*|wtmp*)" > "$temp_dir/$dir_name-$wsl_name" #просмотр содержимого архива и поиск лог файлов
							while IFS= read -r log_files
							do
								case $pars_opt in
									ftp)
										case "$(basename "$log_files")" in 
											messages-*|messages|vsftpd.log*)
												tar --use-compress-program=pigz -xf "$arch" -C "$temp_dir/$dir" "$log_files"
												if ! [ -d "$data_dir/$norm_year/$dir_name/$wsl_name" ]; then
														mkdir -p "$data_dir/$norm_year/$dir_name/$wsl_name"
												fi
												if [[ "${log_files##*.}" == "gz" ]]; then
														zcat "$temp_dir/$dir/$log_files" | pureftpd_pars "$data_dir/$norm_year/$dir/$wsl_name/"
												else
														cat "$temp_dir/$dir/$log_files" | pureftpd_pars "$data_dir/$norm_year/$dir/$wsl_name/"
														vsftpd_pars "$temp_dir/$dir/$log_files" "$data_dir/$norm_year/$dir/$wsl_name/"
												fi
											;;               
									esac
									;;
									xdmcp)
										case "$(basename "$log_files")" in
											wtmp-*|wtmp*)
													tar --use-compress-program=pigz -xf "$arch" -C "$temp_dir/$dir" "$log_files"
													if ! [ -d "$data_dir/$norm_year/$dir_name/$wsl_name" ]; then
															mkdir -p "$data_dir/$norm_year/$dir_name/$wsl_name"
													fi
													if [[ "${log_files##*.}" == "gz" ]]; then
															file=$temp_dir/$dir$log_files
															gzip -d "$file"
															parsing_func
													else
															file=$temp_dir/$dir$log_files
															parsing_func
													fi
											;;                    
									esac
									;;
								esac
								done < "$temp_dir/$dir_name-$wsl_name"
							case $pars_opt in
								ftp)
									shapka "$data_dir/$norm_year/$dir/$wsl_name/"
								;;
								xdmcp)
									sorting_func "$data_dir/$norm_year/$dir/$wsl_name/xdm_list_log.log" "$data_dir/$norm_year/$dir/$wsl_name/"
								;;
							esac
					done
          #echo "$dir_name done!" >> "$starttime"-process.log #минилог результатов
        ) &
      done
    wait
    done
  ;;
esac
echo "All done." >> "$starttime"-process.log
cleanup