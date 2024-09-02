---
문서 타입: 인수인계서
프로세스 명: MMS 센더
작성자: 심정훈
---

# MMS-Core 란 ?

[MMS-Core](https://github.com/seoultel/kr.co.seoultel.message.mt.mms-core/tree/v1.2.0/src/main/java/kr/co/seoultel/message/mt/mms/core) 란 **MCMP(Multi Channel Messaging Platform)** 플랫폼에서 동작하는 MMS 센더에서 공통으로 사용하는 공통 상수 값 및 예외, 메세지 클래스, 유틸 클래스 등을 정의해놓은 라이브러리로서 **MMS-Core-Modules** 에서 주입받아 사용한다.

## common 패키지

`kr.co.seoultel.message.mt.mms.core.common` 패키지 안에는 constant, exceptions, interfaces, protocol, serializer 패키지가 존재하는데 이 중 주요하게 보아야하는 패키지는 `exceptions` 과 `interfaces`, `protocol` 이다.


### exceptions

`MMS-Core` 에서는 MCMP 내부 플랫폼 간의 프로토콜인  `kr.co.seoultel.message.core.dto.MessageDelivery` 객체를 Validation 과정에서 발생하는 예외와 이통사 패킷의 메세지를 생성할 때 발생하는 SoapException 을 핸들링하기 위한 예외를 모아두었다.

MMS 센더는 처리 중 예외가 발생한 메세지 건에 대하여 [리포터](https://github.com/stndrdntwrks?q=reporter&type=all&language=&sort=)에게 전달해주어야 한다. 이 떄 발생하는 `MessageDelivery` 의 



