---
문서 타입: 업무 기술서
프로세스 명: MCMP 리포터
작성자: 장정호
작성일: 2024-07-08
---

# 목차

1. 개요
    1. 개발 목적
    2. git Hub Repository
2. 시스템 구성
3. 시스템 흐름
4. 소스 분석
    1. 주요 클래스 분석
5. 실행 및 종료
6. 설정
7. Table Layout or 규격
8. 결과코드
9. 주의 사항 및 가이드

---

# Report Server 개요

국내 Sender(SMS, LMS/MMS, RCS, KKO)로부터 전송 요청이 완료 처리되거나, 진행 중인 메시지의 결과를 수신하여 그 결과를 WebHook 방식으로 클라이언트에 전달한다. 결과를 전달한 뒤 이력을 DB Logger에게도 전달하고, 처리하는 메시지의 Type,과 state에 따라 대체 전송, Port Out을 판별하여 재전송 처리한다.

**개발 환경**

- JAVA
- JDK 17

**활용 기술**

- Spring Cloud
- WebFlux
- Rabbitmq(x-delayed-message)

### 반드시 Message Delivery에 대한 충분한 이해를 갖추거나, Message Delivery 문서와 함께 볼 것을 권장한다.

### 개발 목적

차세대 전송 플랫폼 개발 프로젝트는 Legacy 시스템의 전송 시스템 품질 개선을 목표로 둔 프로젝트이다.

Standard Networks는 C로 개발된 SMS G/W Sylphid Frame works로 개발된 MMS G/W, Multi ADT 이 3개의 G/W의 장점을 계승하고 문제점과 한계점을 개선하려고 노력했다.

### git hub repository

리포트 서버의 깃 주소는 아래와 같다.


---

# 시스템 구성

## Report Server 구성도

![[리포터 이미지1.png]]

### 구성 서버

|   |   |   |
|---|---|---|
|구분|개발계|운영계|
|Report Server|220.95.214.15|222.233.53.39, 119.207.74.9|

---

# Report 서버 흐름도

![[리포터 이미지2.png]]

## Report Server Flow

- - **결과 코드 converting**
    - **PORT OUT 체크**
    - **고객사에 WEB HOOK수행 :** 고객사에 push로 리포트 전달
    - **PNX 체크 :** PNX의 데이터를 UPDATE
    - **Logger에 이력 전달 :** MCMP가 처리한 이력을 HDB에 적재하여 저장한다.
    - **대체 전송 수행 :** RCS/KKO의 실패인 경우
    - **RCS FILE Report :** RCS로 등록된 File(ex 이미지)를 이통망에 등록하고 등록된 결과를 리포트 한다.(RCS 이미지의 경우만 해당)

## 주요 클래스 분석

Report 서버의 주요 클래스에 대해서 설명을 하겠다.

![[리포터 이미지3.png]]

시작하기 앞서 Report 서버에서 주로 사용되는 비즈니스 로직의 흐름을 이해하기 위해서는 Message Delivery의 구성 중 하나인 **Type과 State 필드의 의미를 이해하는 것이 중요**하기 때문에, 한번 짚고 넘어가겠다.

#### Message Delivery의 State

메시지의 상태를 나타내는 값이다.

```
# 준비 상태
STATE_READY = 0;
# 전송 중인 상태
STATE_SENDING = 1;
# 이통망으로 전송이 된 상태
STATE_SUBMIT = 2;
# 전송된 결과가 성공인 상태
STATE_SUCCESS = 3;
# 전송된 결과가 실패인 상태
STATE_FAILED = 4;
# 재처리 상태
STATE_RETRY = 5;
# 대체 전송 준비 상태
STATE_FALLBACK_READY = 6;
# 대체 전송 중인 상태
STATE_FALLBACK_SENDING = 7;
# 대체 전송건이 이통망으로 전송이 된 상태
STATE_FALLBACK_SUBMIT = 8;
# 대체 전송건의 전송 결과가 성공인 상태
STATE_FALLBACK_SUCCESS = 9;
# 대체 전송건의 전송 결과가 실패인 상태
STATE_FALLBACK_FAILED = 10;
# 대체 전송건 재처리 상태
STATE_FALLBACK_RETRY = 11;
```

#### Message Delivery의 Type

메시지의 종류를 타나내는 값이다.

```
# 알수 없는 종류의 메시지
TYPE_UNKNOWN = 0;
# 전송 요청 메시지
TYPE_SUBMIT = 1;
# 전송 요청의 응답 메시지
TYPE_SUBMIT_ACK = 2;
# 전송 요청의 결과 메시지
TYPE_REPORT = 3;
# 전송 요청의 결과 응답 메시지
TYPE_REPORT_ACK = 4;
# 대체 전송시 알수 없는 종류의 메시지
TYPE_FALLBACK_UNKNOWN = 5;
# 대체 전송 요청의 메시지
TYPE_FALLBACK_SUBMIT = 6;
# 대체 전송 요청의 응답 메시지
TYPE_FALLBACK_SUBMIT_ACK = 7;
# 대체 전송 요청의 결과 메시지
TYPE_FALLBACK_REPORT = 8;
# 대체 전송 요청의 결과의 응답 메시지
TYPE_FALLBACK_REPORT_ACK = 9;
```

다시 한번 재차 강조하지만 바로 위의 Message Delivery의 Type과 State은 리포터 서버 전역에서 작성 되어 있는 비즈니스 로직으로 판단하는 기준이 되기 때문에, **리포터 서버를 이해하기 위해서는 반드시 위의 Type과 State의 이해가 필요하다.**

Report 서버는 SMS, MMS, RCS, KKO 4개 채널의 메시지와 4개 채널의 전송 상태, 메시지의 종류에 따라서 처리하는 프로세스가 다르기 때문에 **비즈니스 복잡도가 높다.**

### 각 Channel의 Report 클래스

각 채널 별로(SMS, MMS, RCS, KKO) 존재하며, **메시지를 소비하여 작성된 비즈니스 로직을 수행 할 수 있도록 하는 모듈**, 소비를 수행하며 각 채널 별 예외 처리도 작성 되어 있다.

- 소스 코드의 일부 발췌
	```java
	@Async
	    @RabbitListener(
	            bindings = @QueueBinding(
	                    value = @Queue(value = "${reporter.queue.sms}", durable = "true"),
	                    exchange = @Exchange(value = "${reporter.exchange}", type = ExchangeTypes.TOPIC),
	                    key = "${reporter.queue.sms}"
	            ),
	            ackMode = "MANUAL"
	    )
	    public void Consumer(Message message, Channel channel){
	        reportHandler.reportHandle(message, channel)
	                .publishOn(Schedulers.parallel())
	                .flatMap(this::basicAck)
	                .publishOn(Schedulers.parallel())
	                .onErrorResume(this::errorHandle)
	                .subscribe();
	    }
	```
### Report Handler 클래스

Report Handler는 각 Channel의 Report 클래스에서 호출되어지며, 각 Channel을 공통으로 처리 할 수 있도록 설계 되었다, Rabbitmq로 **인입된 메시지를 Message Delivery로 변환**한다, 변환된 메시지를 **각 채널 별로 알맞은 결과 코드로 convertion**한다, **portOut여부를 판단**하여 Router로 재전송한다.

```java
public Mono<InboundMessageDelivery> reportHandle(Message message, Channel channel){
	return parseData(message, channel)
			.publishOn(Schedulers.parallel())
			.flatMap(this::messageConvertResult)
			.publishOn(Schedulers.parallel())
			.flatMap(this::checkPortOut)
			.publishOn(Schedulers.parallel())
			.flatMap(report -> reportClient.processReport(report));
}
```

Report Handler 클래스부터 실질적으로 Report 서버의 비즈니스 로직이 시작된다고 할 수 있다.

parseData를 통해서 amqp로 부터 인입된 Message를 Message Delivery로 만든다. 만들어진 Message delivery는 순서대로 messageConvertResult ➝ checkPortOut 이 수행된 뒤, Report Client의 processReport를 수행하게 된다.

아래는 Report Handler의 messageConvertResult 메소드이다.

```java
switch (inboundMessageDelivery.getMessageDelivery().getDeliveryType()){
	case MessageDelivery.TYPE_FALLBACK_SUBMIT, MessageDelivery.TYPE_FALLBACK_SUBMIT_ACK, MessageDelivery.TYPE_FALLBACK_REPORT, MessageDelivery.TYPE_FALLBACK_REPORT_ACK -> {
		log.info("[{}] Fallback Message Result Convert , UmsMsgId : %bXNnS2V5%{}%bXNnS2V5%", Util.getMessageChannel(inboundMessageDelivery), inboundMessageDelivery.getMessageDelivery().getUmsMsgId());
		try {
			............ // 중간 소스 생략

					return Mono.just(inboundMessageDelivery);
				});
	}
	default -> {
		//TODO Mono.error 인스턴스로 생성하여 에러 만들어야됨.
		log.info("[{}] Message Result Convert , UmsMsgId : %bXNnS2V5%{}%bXNnS2V5%", Util.getMessageChannel(inboundMessageDelivery), inboundMessageDelivery.getMessageDelivery().getUmsMsgId());
		....................// 중간 소스 
	   
inboundMessageDelivery.getMessageDelivery().getResult().put(Result.CODE, "1");
			return Mono.just(inboundMessageDelivery);
		});
	}
}
```

Report Handler에 최초로 인입된 메시지는 위의 Switch Case문에 따라 Message Delivery의 Type이 대체 전송일 경우와 그 외의 경우로 나뉜다.

- TYPE_FALLBAKC_SUBMIT
- TYPE_FALLBACK_SUBMIT_ACK
- TYPE_FALLBACK_REPORT
- TPYE_FALLBACK_REPORT_ACK

그 다음으로 진행되는 checkPortOut 메소드도 마찬가지이다.

```java
public Mono<InboundMessageDelivery> checkPortOut(InboundMessageDelivery inboundMessageDelivery) {
	switch (inboundMessageDelivery.getMessageDelivery().getDeliveryType()){
		case MessageDelivery.TYPE_FALLBACK_SUBMIT, MessageDelivery.TYPE_FALLBACK_SUBMIT_ACK, MessageDelivery.TYPE_FALLBACK_REPORT, MessageDelivery.TYPE_FALLBACK_REPORT_ACK -> {
			return fallbackPortOut(inboundMessageDelivery);
		}
		default -> {
			if(inboundMessageDelivery.getMessageDelivery().getChannel().equalsIgnoreCase("KKO")) {
				// 알림톡의 경우는 Port Out이 존재하지 않는다.
				return Mono.just(inboundMessageDelivery);
			}
			return normalPorOut(inboundMessageDelivery);
		}
	}
}
```
    

Report Server에서 Message Delivery를 처리 할때 메시지의 Type 과 State에 따라 처리해야 할 메시지가 다르기 때문에 해당하는 Type과 State을 구분하여 처리하는 것은 중요하다.

checkPortOut에서 대체 전송일 경우, 대체 전송 필드를 확인 하여야 하고, 대체 전송이 아니라면 기존 Message Delivery의 channel을 확인하여 처리한다.

**portOut은 Result 객체의 tried Mno 필드를 확인**한다, 이 부분을 조금 더 상세히 설명이 필요한데, 우선 본 문서를 보는 사람은 아래의 내용을 이해할 필요가 있다.

Port Out이란 **전송한 이통망에서 해당 번호 당사 가입자 아님**이 내포된 결과 코드를 내려준 경우 우리는 이 결과를 갖고 **다른 이통사로 재 전송 처리**한다.

| Feild      | Type   | Description                                          |
| ---------- | ------ | ---------------------------------------------------- |
| code       | String | 스탠다드의 결과 코드                                          |
| message    | String | 결과 메시지                                               |
| mnoCd      | String | 전송한 목적지 회사 코드(Ex SKT, LG, KT, LGHV, HIST, LDCC...)   |
| mnoResult  | String | 이통망의 결과 코드                                           |
| settleCode | String | 전송된 Sender의 식별 이름                                    |
| srcSndDttm | String | 고객사에서 전송한 시각<br><br>시간 형식 yyyyMMddHHmmss             |
| srcRcvDttm | String | 고객사에서 리포트를 수신한 시각<br><br>시간 형식yyyyMMddHHmmss         |
| pfmSndDttm | String | 플랫폼에서 이통망으로 전송한 시각<br><br>시간 형식 yyyyMMddHHmmss       |
| pfmRcvDttm | String | 플랫폼에서 이통망으로부터 결과를 수신한 시각<br><br>시간 형식 yyyyMMddHHmmss |
| triedMno   | String | 시도한 Service Provider (이통3사만 존재함)                     |

일반 전송의 포트 아웃을 검칙 하는 비즈니스 로직이다.

```java
public Mono<InboundMessageDelivery> normalPorOut(InboundMessageDelivery inboundMessageDelivery){
	if(((List<?>) inboundMessageDelivery.getMessageDelivery().getResult().get(Result.TRIED_MNOS)).size() > 2) {
inboundMessageDelivery.getMessageDelivery().toString());
		if(!(inboundMessageDelivery.getMessageDelivery().getDeliveryState() == MessageDelivery.STATE_SUBMIT ||
			inboundMessageDelivery.getMessageDelivery().getDeliveryState() == MessageDelivery.STATE_SUCCESS)){
			return overPortOutOverCount(inboundMessageDelivery);
		}
	} else if (codeConvertionFetcher.isPortOut(inboundMessageDelivery.getMessageDelivery().getChannel(),(String) inboundMessageDelivery.getMessageDelivery().getResult().get(Result.CODE)) && ((List<?>) inboundMessageDelivery.getMessageDelivery().getResult().get(Result.TRIED_MNOS)).size() < 3){
		//TODO 채널에 맞는 QUEUE 지정해서 PORT OUT 처리 해줘야댐
		log.info("[{}] Message PortOut Message , UmsMsgId : %bXNnS2V5%{}%bXNnS2V5%", Util.getMessageChannel(inboundMessageDelivery), inboundMessageDelivery.getMessageDelivery().getUmsMsgId());
		Util.addRptProcess(inboundMessageDelivery, reporterStartUpTask.getReporterAddress(),"send_portout");
		return rabbitmqRouter.findRabbitmq(portOutExchange, getQueueName(inboundMessageDelivery), getPortOutSend(inboundMessageDelivery), Reporter.DeliveryType.PORT);
	}
	//3번의 재시도가 되지 않고, 포트아웃 결과코드도 아닌 submit Ack와 Report의 경우
	return Mono.just(inboundMessageDelivery);
}
```

Message Delivery의 Result에서 TriedMno의 size가 2보다 크고 성공이 아닌 State이라면 포트아웃 실패로 재처리하지 않고 실패로 리포트 하게 된다.

Message Delivery의 Code Convertion한 코드가 port out이고, Tried Mno가 3보다 작다면 포트아웃 처리하여 재시도 하게된다.

## Report Client

Report Client는 고객사로 리포트를 직접 보내는 기능을 담당하는 클래스이다. 인입된 **메시지의 ReportUri를 검칙**하고, Type을 구분하여 인입된 메시지가 리포트를 수행해야 하는지 여부를 판단하고 리포트를 수행한다.

```java
public Mono<InboundMessageDelivery> processReport(InboundMessageDelivery inboundMessageDelivery) {
	return reportProcess(inboundMessageDelivery)
			.publishOn(Schedulers.parallel())
			.flatMap(report -> rabbitmqRouter.processRouteRabbitmq(report));
}

public Mono<InboundMessageDelivery> reportProcess(InboundMessageDelivery inboundMessageDelivery) {
	switch (inboundMessageDelivery.getMessageDelivery().getDeliveryType()){
		case MessageDelivery.TYPE_SUBMIT_ACK, MessageDelivery.TYPE_FALLBACK_SUBMIT_ACK -> {
			if(isFailed(inboundMessageDelivery)){
				return webHookSend(inboundMessageDelivery);
			}
			return Mono.just(inboundMessageDelivery);
		}
		case MessageDelivery.TYPE_REPORT, MessageDelivery.TYPE_FALLBACK_REPORT -> {
			return webHookSend(inboundMessageDelivery);
		}
		default -> {
			return Mono.just(inboundMessageDelivery);
		}
	}
}
```

reportProcess 메소드를 보면 이전과 같이 인입된 메시지의 Type을 나눈다.

- 리포트를 해야하는 경우
    - Submit Ack 실패
    - Fallback Submit Ack 실패
    - Report
    - Fallback Report
- 리포트를 수행하지 않아도 되는 경우
    - 위의 경우가 아닌 모든 경우

Message Delivery의 Type을 조건으로 Message Delivery를 검칙한 리포트를 한번 더 webHookSend 메소드에서 분기점을 나눈다.

```java
public Mono<InboundMessageDelivery> webHookSend(InboundMessageDelivery inboundMessageDelivery){
        Util.addRptProcess(inboundMessageDelivery, reporterStartUpTask.getReporterAddress(),"WebHookSend");
        return validateReport(inboundMessageDelivery)
                .flatMap(reportData -> {
                    switch (reportData.getChannel().toUpperCase()) {
                        case "RCS","KKO" -> {
                            switch (reportData.getDeliveryType()){
                                case MessageDelivery.TYPE_FALLBACK_SUBMIT, MessageDelivery.TYPE_FALLBACK_SUBMIT_ACK, MessageDelivery.TYPE_FALLBACK_REPORT, MessageDelivery.TYPE_FALLBACK_REPORT_ACK -> {
                                    return fallbackReport(inboundMessageDelivery);

                                }
                                default -> {
                                    return sendReport(inboundMessageDelivery, BASE_URL);
                                }
                            }
                        }
                        case "MMS,LMS" -> {
                            return sendReport(inboundMessageDelivery, BASE_URL);
                        }
                        default -> {
                            return sendReport(inboundMessageDelivery, BASE_URL);
                        }
                    }
                }).flatMap(response -> {
                    중간 생략
                    ......
                }).onErrorResume(throwable -> {
                    inboundMessageDelivery.getMessageDelivery().setRetryCount(
                            inboundMessageDelivery.getMessageDelivery().getRetryCount() + 1
                    );
                    if (throwable instanceof WebHookValidationException) {
                        return Mono.error(new WebHookValidationException(inboundMessageDelivery, throwable));
                    } else if (throwable instanceof TimeoutException) {
                        return Mono.error(new WebHookSocketException(inboundMessageDelivery, throwable));
                    } else if (throwable instanceof PoolAcquirePendingLimitException){
                        log.error("PoolAcquirePendingLimit Exception :", throwable);
                    } else if (throwable instanceof NullPointerException){
                        log.error("NullPointException Exception :", throwable);
                        return Mono.error(new WebHookValidationException(inboundMessageDelivery, throwable));
                    }
                    log.error("Unknown Exception :", throwable);
                    return Mono.error(new WebHookSocketException(inboundMessageDelivery, throwable));
                });

    }
```

리포트 메시지의 Report Uri를 validateReport메소드로 검증한 후, Message 채널과 또 Message Delivery의 Type에 알맞는 처리를 할 수 있도록 분기 처리한다.

Webhook으로 전송한 리포트를 처리하는 과정에서 발생한 예외를 onErrorResume에서 catch하여 Mono.error를 통해 커스텀된 각 에러로 방출한다.

각 에러는 처음 메시지가 출발하였던, 각 Channel의 Report 클래스로 방출되고 그 클래스의 ErrorHandle 메소드에 작성 되어 있는 재처리 전략에 따라 알맞게 처리가 된다.

## RabbitmqRouter

RabbitmqRouter 클래스는 모듈들에서 담당하는 기능을 수행하고 보내는 메시지를 메시지의 종류에 따라 지정된 **목직지로 라우팅 해주는 모듈이다.**

```java
public Mono<InboundMessageDelivery> processRouteRabbitmq(InboundMessageDelivery inboundMessageDelivery){
	return pnxCheck(inboundMessageDelivery)
			.publishOn(Schedulers.parallel())
			.flatMap(pnxMessage-> findRabbitmq(loggerExchange, getLoggerQueue(inboundMessageDelivery), inboundMessageDelivery, Reporter.DeliveryType.LOGGER));

}
```

pnxCheck의 경우 PortOut이 발생했던 메시지 건이 다시 재처리하여 성공으로 리포트 되는 경우, PNX정보를 성공한 이통사로 변경 할 수 있도록 PNX Updater에게 전달한다.

```java
public Mono<InboundMessageDelivery> findRabbitmq(String exchangeName, String queueName, InboundMessageDelivery inboundMessageDelivery, Reporter.DeliveryType deliveryType){
	return Mono.defer(() -> {
		log.debug("Delivery Type : {}", deliveryType);
		return switch (deliveryType) {
			//
			case LOGGER,FILE,DELIVERED,PORT,FALLBACK -> sendRabbitmq(exchangeName, queueName, new AMQP.BasicProperties().builder().build(), inboundMessageDelivery);
//                case FALLBACK -> sendRabbitmq(exchangeName, queueName, new AMQP.BasicProperties().builder().build(), inboundMessageDelivery);
			case RETRY -> sendRabbitmq(exchangeName, queueName, properties, inboundMessageDelivery);
			case PNX -> sendPnx(exchangeName,queueName,new AMQP.BasicProperties().builder().build(), inboundMessageDelivery);
		};
	}).onErrorResume(throwable -> {
		log.error("Rabbitmq Send Failed Exception", throwable);
		return Mono.error(new ReporterRabbitmqException(inboundMessageDelivery, throwable));
	});
}
```

Message Delivery가 지금까지 처리되면서 특별히 이상이 없는 건이라고 한다면, 마지막에 DB Logger에게 전달된다.

중요하게 봐야할 것은 RETRY 이다. Retry의 경우 SendRabbitmq의 properties가 다르다.

나머지 case의 경우는 builder를 통해 깡통으로 생성하지만 Retry의 경우 아래의 properties를 쓴다.

```java
this.headers = new HashMap<>();
        headers.put("x-delay", delayTime);
properties = new AMQP.BasicProperties.Builder()
                .headers(headers)
                .build();
```

설정 값인 delayTime을 받아서 Rabbitmq의 X-Delayed-Message의 옵션인 x-delay 시간을 지정한다.

이 시간을 지정하는 방법은 아래에서 자세히 설명하겠다.

x-delay를 지정하여 Rabbtimq에 전송하면 지정한 시간만큼 amqp 서버에 늦게 도달한다.

자세한 설명은 Rabbitmq의 x-delayed- message plugin을 찾아보길 바란다.

위 메소드인 findRabbitmq의 작성된 비즈니스대로 Rabbitmq에 라우팅 된다.

### FallbackHandler

FallbackHandler는 **RCS와 KKO의 경우 실패된 메시지의 경우** (Submit Ack 실패 or Report 실패) **대체 전송으로 지정된 SMS, MMS로 재전송** 한다 이때, 재전송이 가능한지 validation하여 불가능 하면 대체 전송 불가능으로 리포트 수행한다.

```java
public Mono<InboundMessageDelivery> fallbackSend(InboundMessageDelivery inboundMessageDelivery) {
	switch (inboundMessageDelivery.getMessageDelivery().getChannel()){
		case "RCS", "KKO" -> {
			switch (inboundMessageDelivery.getMessageDelivery().getDeliveryType()){
				case MessageDelivery.TYPE_UNKNOWN,MessageDelivery.TYPE_SUBMIT,MessageDelivery.TYPE_SUBMIT_ACK,MessageDelivery.TYPE_REPORT,MessageDelivery.TYPE_REPORT_ACK ->{
					if(((Boolean)(inboundMessageDelivery.getMessageDelivery().getContent().get(Fallback.FALLBACK_FLAG)))){
						log.info("[{}]Send Fallback Message, UmsMsgId : %bXNnS2V5%{}%bXNnS2V5%", inboundMessageDelivery.getMessageDelivery().getChannel(), inboundMessageDelivery.getMessageDelivery().getUmsMsgId());
						Util.addRptProcess(inboundMessageDelivery, reporterStartUpTask.getReporterAddress(),"Fallback-Send");
						if(isFailed(inboundMessageDelivery)){
							if (fallbackValidate(inboundMessageDelivery)) {
								log.info("[{}] Fallback Validate Success, Send router Queue : {}", inboundMessageDelivery.getMessageDelivery().getChannel(), getFallbackQueue(inboundMessageDelivery));
								return findFallback(inboundMessageDelivery);
							} else {
								log.info("[{}] Fallback Validate Failed", inboundMessageDelivery.getMessageDelivery().getChannel());
								return unableFallbackCase(inboundMessageDelivery);
							}
							//TODO FALLBACK이 실패한 경우 실패에 대하여 리포트를 수행해야하는데, VALIDATE에 실패한 경우 특히나, 어캐 앎?
						}
					}
				}
			}
			return Mono.just(inboundMessageDelivery);
		}
		default -> {
			return Mono.just(inboundMessageDelivery);
		}
	}
}
```

위 로직을 수도 코드로 대입하면 인입된 메시지가 RCS이거나 KKO이고, 일반 전송 상태이며, 대체 전송을 허용하고 해당 메시지가 실패한 상태인 경우에 대체 전송이 가능한 경우 대체 전송을 수행한다.

Report Server를 이해하는데 필요한 최소한의 코드만 설명을 하였다, 자세한 비즈니스 로직은 소스코드를 참고 바란다.

---

# 실행 및 종료

### 설치 환경

OS JDK17이 설치되는 모든 OS

#### 프로세스 홈

| 구분  | 개발계                | 운영계                    |
| --- | ------------------ | ---------------------- |
| 위치  | /svc/mcmp/reporter | /svc/std-mcmp-reporter |

### 시작

서버 홈이 되는 경로의 폴더에서

./start.sh

### 종료

서버 홈이 되는 경로의 폴더에서

./stop.sh

---

# 설정

Report Server의 주요 기능을 위에서 설명하였는데, 생각보다 복잡한 비즈니스 로직을 갖췄다. 따라서 기능도 복잡하고, Report Server의 설정이 생각보다 길기 때문에, 끊어서 설명하겠다.

**Eureka 설정**

```
eureka:
  instance: 
# 인스턴스 ID를 IP 주소와 포트 번호로
    instance-id: ${spring.cloud.client.ip-address}:${server.port}  
# IP 주소를 선호하지 않도록 설정
    prefer-ip-address: false 
# 호스트 네임
    hostname: 220.95.214.15  
  client:
#Eureka 서버에 레지스트리 가져오는 간격
    registryFetchIntervalSeconds: 5 
#인스턴스 정보 복제 간격
    instanceInfoReplicationIntervalSeconds: 5 
# 리스 갱신 간격(초)
    leaseRenewalIntervalInSeconds: 10
# 리스 만료 기간(초)
    leaseExpirationDurationInSeconds: 30
# Eureka 서버에 인스턴스를 등록할지 여부
    register-with-eureka: true
# 레지스트리를 가져올지 여부
    fetch-registry: true
# Eureka 서버의 기본 URL을 설정 콤마로 여러서버 구분
    service-url:
      defaultZone: http://220.95.214.11:9000/eureka, http://220.95.214.12:9000/eureka
      

유레카 클라이언트와 서버 구성 관련 상세 설정 방법은 구굴링하여 찾아보길 바란다.

연관된 설정으로는 Eureka Server인 Discovery와 Config Server를 확인하면 된다.

다음은 Rabbitmq의 설정값을 설명하겠다.

spring:
  application:
# 애플리케이션 이름
    name: STD-REPORTER
  rabbitmq:
    cluster:
# RabbitMQ 클러스터를 사용할지 여부
      use: true
# RabbitMQ 클러스터 노드의 주소 여러 노드를 콤마로 구분하여 설정
      nodes: "220.95.214.8:5672, 220.95.214.9:5672, 220.95.214.10:5672"
 # RabbitMQ 가상 호스트
    virtual-host: /mcmp
 # RabbitMQ 호스트 주소
    host: 192.168.50.19
# RabbitMQ 포트 번호
    port: 5672
# RabbitMQ 접속 계정 ID
    username: admin
# RabbitMQ 접속 계정 PassWord
    password: egarreo01!
```

Report 서버에서 필요한 Rabbitmq의 기본적인 접속 설정이다. 크게 바뀔것은 없다.

다음은 Report 서버의 기능에 따른 주 기능 설정 옵션에 대해서 설명 하겠다.

```
reporter:
# Consumer 1개가 동시 소비 할 수 있는 량
  qos: 3000
# Reporter의 각 Channel의 Consumer가 사용할 Exchange
  exchange: xrpt
# Reporter의 각 Channel에 할당된 Consumer가 소비할 Queue 이름
  queue:
    sms: mr.sms.report
    mms: mr.mms.report
    kko: mr.kko.report
    rcs: mr.rcs.report
    backup: mr.report.backu
    rcsFile: mr.rcs.fileReport
# File Logger에게도 전달이 불가능한 건을 파일로 저장할 
  filePath: file:../logs

다음은 Reporter서버에서 주기능 다음으로 사용하는 Queue의 설정을 설명하겠다.

# Port Out 발생시 각 Channel에 따라 보낼 목적지 Queue 이름름
portOut:
  exchange: xmt
  queue:
    sms: sms.portOut
    mms: mms.portOut
    rcs: rcs.portOut
    kko: kko.portOut

# DB Logger의 각 채널에 따라 보낼 목적지 Queue 이름
logger:
  exchange: xrpt
  queue:
    sms: mr.sms.logger
    mms: mr.mms.logger
    kko: mr.kko.logger
    rcs: mr.rcs.logger
    deliverySms: mr.sms.deliveryLogger
    deliveryMms: mr.mms.deliveryLogger
    deliveryKko: mr.kko.deliveryLogger
    deliveryRcs: mr.rcs.deliveryLogger

# Web Hook이 실패하여 재처리 할 경우 각 채널에 따라 보낼 목적지 Queue 이름
retry:
  exchange: retry
  queue:
    sms: mr.sms.retryReport
    mms: mr.mms.retryReport
    kko: mr.kko.retryReport
    rcs: mr.rcs.retryReport
    rcsFile: mr.rcs.retryFileReport
# delay Time 고의적으로 지연을 발생시킬 시간 아래에서 자세히 설명하겠다.
  delayTime: 90000
  maxCount: 1000

# Router의 Queue 이름
# Deprecated
router:
  exchange: xmt
  queue:
    sms: mt.kr.standard.sms
    mms: mt.kr.standard.mms
    kko: mt.kr.standard.kko
    rcs: mt.kr.standard.rcs

# 대체 전송이 개발 되면서 대체전송 발생시 
fallback:
  exchange: xmt
  queue:
    rcs: mt.ptp.rcs
    kko: mt.ptp.kko

# PNX Update의 Queue 이름 
pnx:
  exchange: xrpt
  queue: mr.pnx

# File Logger의 Queue 이름
failed:
  exchange: file
  queue: mr.rptFileWriter

다음은 Report 서버의 기능에 해당하는 설정에 대해서 설명하겠다.

converter:
# codeConvertion.josn 파일의 존재 경로를 지정한다.
  filePath: ../conf/codeConvert.json
# codeConvertion.json 파일을 주기적으로 읽어갈 시간을 ms로 설정한다.
  interval: 1800000

webHookConfig:
# WebHook Client가 max로 들고 있을 수 있는 Connection의 갯수이다.
  maxConnectionCount: 5000
# 요청 대기건을 최대로 대기 할 수 있는 갯수이다.
  pendingAcquireMaxCount: 10000
# Web Hoook 요청시 지정한 시간이 지나면 실패로 간주한다.
  normalTimeOut: 3
# retry시 지정할 Time Out 시간이었으나, Retry Reporter 개발 후 현재는 미사용
# Deprecated
  retryTimeOut: 5

# Report 서버의 Worker Thread 개수 
# Deprecated
worker:
  sms: 8
  retrySms: 8
  mms: 8
  retryMms: 8
  rcs: 8
  retryRcs: 8

# Deprecated
management:
  endpoints:
    web:
      exposure:
        include: refresh, health, beans, busrefresh
```

---

# Report Message 규격

Report Server에는 리포트 메시지 규격이 총 3개 존재한다.

1. Report Message
2. Fallback Report Message
3. Rcs File Report Message

, Report Message는 SMS, MMS, RCS, KKO **모든 메시지 채널을 호환하는 메시지 전송 결과**이다.

아래는 **Report Message**의 규격이다.

| field           | Type   | Description                                                    |
| --------------- | ------ | -------------------------------------------------------------- |
| cmpMsgId        | String | 메시지 발급키 (예비)                                                   |
| srcMsgId        | String | 고객사 Agent에서 발급한 메시지 식별키                                        |
| umsMsgId        | String | STD 발급 식별키                                                     |
| channel         | String | 메시지 채널                                                         |
| resultCode      | String | 메시지 처리 결과 코드                                                   |
| resultMessage   | String | 메시지 처리 결과 메시지 (통신사 마다 다름)                                      |
| serviceProvider | String | 이동 통신사                                                         |
| srcSndDttm      | String | Client에서 전송한 시간<br><br>시간 형식 yyyyMMddHHmmss                    |
| pfmRcvDttm      | String | platform에서 메시지의 결과를 이통사로 부터 수신한 시간<br><br>시간 형식 yyyyMMddHHmmss |
| pfmSndDttm      | String | platform에서 메시지를 이통사로 전송한 시간<br><br>시간 형식 yyyyMMddHHmmss        |

Fallback Report Message는 RCS와 KKO의 메시지가 실패 했을때, 대체전송 기능을 통해 전송 된 SMS, MMS의 결과 메시지이다. 기존 Report Message와 규격이 비슷해 헷갈릴 수 있는 필드에 fb (Fallback)을 의미하는 단어를 붙였다.

아래는 Fallback Report Message의 규격이다.

| field/            | Type   | Description                                                          |
| ----------------- | ------ | -------------------------------------------------------------------- |
| cmpMsgId          | String | 메시지 발급키 (예비)                                                         |
| srcMsgId          | String | 고객사 Agent에서 발급한 메시지 식별키                                              |
| umsMsgId          | String | STD 발급 식별키                                                           |
| channel           | String | 최초로 발송된 메시지 채널 (RCS or KKO)                                          |
| fbChannel         | String | 실패시 대체 전송된 채널 (SMS or MMS)                                           |
| fbResultcode      | String | 대체 전송 처리 결과 코드                                                       |
| fbResultMessage   | String | 대체 전송 처리 결과 메시지                                                      |
| fbServiceProvider | String | 대체 전송 이동 통신사<br><br>시간 형식 yyyyMMddHHmmss                             |
| fbPfmSndDttm      | String | platform에서 대체 전송 메시지를 이통사로 전송한 시간<br><br>시간 형식 yyyyMMddHHmmss        |
| fbPfmRcvDttm      | String | platform에서 대체 전송 메시지의 결과를 이통사로 부터 수신한 시간<br><br>시간 형식 yyyyMMddHHmmss |

Rcs File Report Message는 Rcs의 이미지 메시지를 전송하려면 전송하기전 사용할 이미지를 이동통신사에 등록하여야 한다. 이때, 이통망에 이미지 등록 요청 후 수신 받은 결과를 Client에 전달하는 규격이다.

아래는 Rcs File Report Mesasge의 규격이다

| field         | Type   | Description                           |
| ------------- | ------ | ------------------------------------- |
| chatbotId     | Stirng | 챗봇 아이디                                |
| filedId       | Stirng | 파일 이름                                 |
| userCode      | Stirng | 내부적으로 생성된, file Server 내부의 저장되어 지는 이름 |
| expireTime    | Stirng | 만료 시간<br><br>시간 형식 yyyyMMddHHmmss     |
| result        | Stirng | 처리 결과                                 |
| resultMessage | Stirng | 처리 결과 메시지                             |

---

# 결과 코드

Legacy 시스템에선 결과 코드를 바꾸거나 수정하려면 서버를 사용 중인 고객사에게 작업 공지를 작업 3일 전에 공지 해야 하고, 또 자정이 넘는 시간에 소스를 재배포 해야 했다. 단순히 결과 코드 하나만 추가되는데, 이런 작업 공수가 들어가는 것을 개선하고자 시스템은 주기적으로 결과 코드를 읽어 갈 수 있도록 개발 했다.

Report Server에서 Code를 Convertion 하는 규격은 json 규격이며 아래와 같은 규격으로 설정 되어 있다. 결과 코드는 Report 서버에게 상당히 중요하다

파일의 위치는 위에 설정에 나와있다.

실제 파일을 열어보면 아래처럼 되어있다.

```json
"codeList":
    [
        {
            "provider": "SKT",
            "msgType": "1",
            "resultType": "1",
            "originResult": "0",
            "convertResult": "99",
            "resultMessage": "GI_RES_NO_ERR"
        },
        {
            "provider": "SKT",
            "msgType": "1",
            "resultType": "1",
            "originResult": "10",
            "convertResult": "1",
            "resultMessage": "GI_RES_SUBS_INVALID"
        },
        {
            "provider": "SKT",
            "msgType": "1",
            "resultType": "1",
            "originResult": "11",
            "convertResult": "1",
            "resultMessage": "GI_RES_SUBS_SUSPENDED"
        }
........
]
```

| field         | Description                                                            |
| ------------- | ---------------------------------------------------------------------- |
| provider      | 메시지를 처리한 서비스 제공자(skt, ktf, lgt, lgagt, system, lgcns, ldcc, ksp......) |
| msgType       | 메시지의 Channel 구분 (1: sms, 2: mms, 3: kko, 4: rcs)                       |
| resultType    | 메시지의 상태 구분(1: SubmitAck, 2: Report)                                    |
| originResult  | 서비스 제공자의 원본 결과 코드                                                      |
| convertResult | 바뀔 코드                                                                  |
| resultMessage | 결과 값의 메시지                                                              |

Report Server에서 Code Convertion을 통해 STD 내부 코드로 결과 코드를 Convertion 하지만, 결과 코드 표의 담당은 각 연동 Sender의 담당자에게 있다, Report 서버 개발 담당자가 혼자 각 채널의, 각 중계사의 각 메시지의 결과 코드를 모두 담당하기는 어렵다.

각 Sender의 결과 코드 표와 차세대 Agent의 결과 코드 표를 참고하길 바란다.

---

# 주의사항 및 가이드