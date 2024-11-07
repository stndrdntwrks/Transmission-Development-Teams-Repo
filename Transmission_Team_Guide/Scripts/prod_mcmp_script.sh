#!/bin/bash

# MCMP EUREKA 등록 서버 정보 요청 
url="http://211.206.122.85:9000/eureka/apps"

# URL 에 GET 요청 후 응답 값 저장
response=$(curl -s "$url")

printf "=======================================\n"
printf "=             PROD MCMP               =\n"
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
