#!/bin/bash

clients=() #массив для клиентов
start_times=() #массив для подсчета времени
PORTS1=5910 #первый порт из диапазона
PORTS2=5913 #второй порт

while true; do #бесконечный цикл для мониторинга портов

    for (( i="$PORTS1"; i <= "$PORTS2"; i++ )); do #проходка по портам 
        #echo $i
        vnc_connections=$(netstat -ant | grep ":$i.*ESTABLISHED")
        if [[ -z "$vnc_connections" ]]; then
            echo "no connections on port $i"
            #sleep 1
        fi
        ip_addresses=$(echo "$vnc_connections" | awk '{print $5}' | sort | uniq) #список клиентво на порту(айпишников)
        #проверка на подключение
        for ip_address in $ip_addresses; do 
            found=0
            for (( j=0; j<${#clients[@]}; j++ )); do #проходка по массиву и проверка есть ли среди подключенных айпишников на порту такой в массиве, если нет то идем на следующий айпишник
                if [ "${clients[$j]}" == "$ip_address:$i" ]; then
                    found=1 #флаг 
                    break
                fi
            done
            
            if [ "$found" -eq 0 ]; then #если такого айпишника нету в массиве то добавляем его (учитывая порт)
                clients[${#clients[@]}]="$ip_address:$i"
                ip_client=$(echo "$ip_address" | cut -d':' -f1) #получение просто айпи без порта
                #echo "$ip_client"
                start_times[${#start_times[@]}]=$(date +%s) #время подключения
                echo "${start_times[@]}"
                echo "$(date +%F\ %T) Session started: Connection from: $ip_address on port $i" >> "$ip_client:$i.log" #логирование
                echo "$ip_address connected on port $i" #все эхо на терминал я для дебага юзал, потом можно закоментить для прода чтобы в фоне крутилось
            fi
        done
        #проверка на отключение клиента
        for (( j=0; j<${#clients[@]}; j++ )); do #проходка по элементам массива
            client_ip=$(echo "${clients[$j]}" | cut -d':' -f1) #получаю айпи
            client_port=$(echo "${clients[$j]}" | cut -d':' -f3) #получаю порт
            client_ip_port=$(echo "${clients[$j]}" | cut -d ':' -f 1,2) #получаю айпи и порт(не тот порт что выше)
            if [[ $client_port -eq $i ]] && ! netstat -ant | grep -q "$client_ip_port.*ESTABLISHED"; then #проверка, отключен ли клиент, если в массиве он есть а в нетстате нету значит он отключен
                session_start=${start_times[$j]} #извлекаю время подключения
                session_end=$(date +%s) #время дисконекта 
                duration=$((session_end - session_start))
                duration_formatted=$(printf '%02d:%02d:%02d\n' $(($duration/3600)) $(($duration%3600/60)) $(($duration%60))) #формат времени
                clients=("${clients[@]:0:$j}" "${clients[@]:$((j+1))}") #Удаление из массива клиента
                start_times=("${start_times[@]:0:$j}" "${start_times[@]:$((j+1))}") #удаление времени подключения этого клиента
                echo "$(date +%F\ %T) Session down: Disconnected $client_ip_port from port $client_port. Session duration: $duration_formatted" >> "$client_ip:$client_port.log"
                echo "$client_ip disconnected from port $client_port"
            fi
        done
    done
    sleep 2
done
