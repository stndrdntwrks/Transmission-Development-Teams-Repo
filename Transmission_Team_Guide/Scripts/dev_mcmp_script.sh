#!/bin/bash

# MCMP EUREKA 등록 서버 정보 요청 
url="http://220.95.214.11:9000/eureka/apps"

# URL 에 GET 요청 후 응답 값 저장
response=$(curl -s "$url")


# 각 application의 name과 instanceId를 추출하여 출력
#echo "$response" | xmlstarlet sel -t -m "//application" -v "concat(name, ': ', instance/instanceId)" -n


# echo "$response" | xmlstarlet sel -t -m "//application" -v "concat(name, ': ', instance/instanceId)" -n | while read line; do printf "%-20s\n" "$line"; done

printf "=======================================\n"
printf "=              DEV MCMP               =\n"
printf "=======================================\n"
printf "\n"

echo "$response" | xmlstarlet sel -t -m "//application" -v "concat(name, ': ', instance/instanceId)" -n | while read process_info; do
    # 여기에 원하는 코드를 작성 (예: 출력, 다른 명령어 실행 등)
    # cut 명령어로 ':'를 기준으로 분리
    name=$(echo "$process_info" | cut -d':' -f1)
    instance=$(echo "$process_info" | cut -d':' -f2)

    # 결과 출력 
    printf "%-20s : %-22s\n" "$name" "$instance"
done

printf "\n"
