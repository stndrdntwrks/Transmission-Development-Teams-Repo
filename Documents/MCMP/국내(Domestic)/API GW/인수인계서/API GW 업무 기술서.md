---
프로세스 명: MCMP API G/W
문서 타입: 업무 기술서
작성일: 2024-07-11
작성자: 이재혁
---

| 프로젝트 명 | API-Gateway        |        |            |
| ------ | ------------------ | ------ | ---------- |
| 문서 명   | API-Gateway 업무 기술서 | 버전     | V-0.0.1    |
| 소속     | 전송 개발팀             | 작성일    | 2024-07-11 |
| 작성자    | 이재혁                | 최종 수정일 | 2024-07-11 |
| 문서 번호  |                    |        |            |

## 환경

---

- JDK 17
- Spring Boot Parent 3.2.1
- Spring Cloud Version 2023.0.0

## 기술 스택

---

- JAVA
- WebFlux
- Redis
- RabbitMQ
- Spring Boot
- Spring Cloud
- Spring Security

## API-Gateway ?

---

- Spring Cloud의 일부 모듈인 Spring Cloud Gateway의 라이브러리를 사용하여 개발되었다.
- Client의 요청을 제일 먼저 받아 필터링 한 후 백 서버에게 LoadBalancing 하기 위한 서버
- 모든 검증에 사용되는 비교 데이터(회원 데이터)는 Redis로부터 읽고 캐싱한다.
- API G/W의 성능은 하드웨어의 ulimit 설정과 직접적인 연관이 있으며

1. **File Descriptors (ulimit -n)**:
    - 설명: 프로세스가 동시에 열 수 있는 최대 파일 개수를 제한하는 설정
    - 성능 영향: API Gateway가 많은 연결을 처리하는 경우 파일 디스크립터 부족으로 인해 성능이 저하될 수 있음
    - 권장 설정: 최소 4096 이상으로 설정
2. **Maximum Number of Threads (ulimit -u)**:
    - 설명: 프로세스가 생성할 수 있는 최대 스레드 개수를 제한하는 설정
    - 성능 영향: API Gateway가 멀티스레딩을 사용하는 경우 스레드 개수 제한으로 인해 성능이 저하될 수 있음
    - 권장 설정: 최소 4096 이상으로 설정
3. **TCP Backlog Queue Size (net.core.somaxconn)**:
    - 설명: 서버 소켓의 연결 대기열 크기를 제한하는 설정
    - 성능 영향: 연결 대기열이 부족한 경우 새로운 연결이 지연될 수 있음
    - 권장 설정: 최소 1024 이상으로 설정
4. **TCP Time-Wait Reuse (net.ipv4.tcp_tw_reuse)**:
    - 설명: TIME_WAIT 상태의 소켓을 재사용하도록 허용하는 설정
    - 성능 영향: TIME_WAIT 상태의 소켓을 재사용하면 새로운 연결 생성 시 지연을 줄일 수 있음
    - 권장 설정: 1로 설정
5. **TCP Time-Wait Timeout (net.ipv4.tcp_tw_timeout)**:
    - 설명: TIME_WAIT 상태의 소켓이 유지되는 시간을 설정하는 값
    - 성능 영향: TIME_WAIT 상태 소켓의 유지 시간을 줄이면 새로운 연결 생성 시 지연을 줄일 수 있음
    - 권장 설정: 60초 이하로 설정

![[API GW 이미지1.png]]

## Component

---

# Security

- **스탠다드 네트웍스**의 메시지 서비스 이용을 등록했을 경우 토큰 발급 시 해당 서비스에 대한 권한이 토큰 값 안에 존재하며 각 서비스에 대한 전송 요청 시 이 값이 없다면 권한 없음(**HTTP STATUS:403**)이라는 응답을 받게 된다.
- 관리자들(**Master, Admin**) 내부 관리용도로 사용하는 HTTP 요청들도 존재하며 이들의 권한은 Master = "MASTER", Admin = "C,R,U,D"

# Filter

### 필터 생성 방법

1. Spring Cloud 라이브러리 내용 중 AbstractGatewayFilterFactory를 상속 받아서 Spring Bean으로 등록한다.

![[API GW 이미지2.png]]

해당 필터의 Config은 개발자가 필요 시에 추가 할 수 있다.

![[API GW 이미지3.png]]
### 필터 적용 방법

1. API G/W의 설정 값 중 spring.cloud.gateway.routes 부분에서 API 등록 할 때 filters 부분에 생성했던 Filter를 추가하면 등록 한 순서대로 필터가 동작하게 된다. (yml 참조)

![[API GW 이미지4.png]]

### JwtFilter

- 인증 서버의 공개 키를 사용한 디코더를 사용하여 토큰을 검증하여 백 서버에 필요한 값을 Request Header에 담아준다.

![[API GW 이미지5.png]]

- _gcd : 고객사 식별코드
- vasYn : 재판/직판 구분 값
- reportUrl : 메시지 전송에 대한 결과를 전달 받을 Client측 주소
- _cno : 메시지 전송 요청을 한 Client 번호

### BillCodeFilter

- 메시지 전송 요청에 필요한 값 중의 1개인 BillCode가 고객사 식별코드에 등록된 BillCode인지 확인하고, 광고물량인지 일반물량인지 확인한다. (고객사 식별코드와 정산코드는 1:N 관계)

### VasFilter

- 메시지 전송 요청을 하는 고객이 재판사 인지 직접고객인지 구분하여 직접고객이라면 스탠다드네트웍스의 특수부가 사업자 식별코드를 넣어주고 아닌 경우 PASS한다.

### LimiterFilter

- 이 필터는 메시지 채널마다 각 각 존재하며, 각각의 고객사마다 사용하는 서비스 마다 요청 TPS제한이 존재하며 이 제한 값에 따라 Request TPS를 제한한다.

# Exception Controll

---

API G/W 에서는 예외 코드에 대한 정의를 따로 관리하며

![[API GW 이미지6.png]]

해당 코드를 사용하는 Exception은 Spring 에서 지원하는 Exception 또는 개발자가 직접 정의한 Exception을 사용한다.

![[API GW 이미지7.png]]


