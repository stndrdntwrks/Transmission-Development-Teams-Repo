---
프로세스 명:
  - MMS 센더
작성자: 심정훈
문서 타입: 인수인계서
작성일: 2024/08/22
---

# 직연동 MMS 센더[MMS-Direct] 인수인계서

|   프로세스 명   |   버전    | 작성자 | 작성일 / 수정일  |
| :--------: | :-----: | :-: | :--------: |
| MMS-Direct | V 1.2.0 | 심정훈 | 2024-08-22 |

---

# 목차

1. [[#들어가기전에]]
	1. [[#용어 정리]]
	2. [[#메세지 전송 큰 흐름 살펴보기]]
2. [[#주요 클래스 살펴보기]]
	1. [[#메세지 클래스 다이어그램]]
	2. [[#MessageConsumer]]
	3. [[#HttpClient]]
	4. [[#HttpClientHandler]]
	5. [[#SoapUtil 및 SoapUtil 구현체]]
	6. [[#MMSReportUtil 및 MMSReportUtil 구현체]]
3. [[#별첨 문서]]
	1. [[#이동통신사(SKT, KTF, LGT) 별 메세지 생성 방식]]
	2. [[#CID 리스트]]

---

# 들어가기전에

**직연동 MMS 센더**는 MCMP 플랫폼에서 MMS(Multimedia Messaging Service) 메세지를 이동통신사(SKT, KTF, LGT) 로 전송하기 위하여 사용하는 프로세스, *이동통신사 == 직연동*,로 이동통신사로 메세지를 전송하기 때문에 스팸 메세지 관련 이슈에서 중계사에 비해 비교적 자유롭다는 장점을 가지고 있으나 복잡한 패킷 작성 방식과 적은 CID, *이동통신사 LGT 의 경우 2개의 MMS CID*, 로 사용하기 힘들다는 단점을 가지고 있다.

> # **CID 란 ?**
> 
>  이동통신사(SKT, KTF, LGT) 에 메세지 전송 요청 시 메세지 패킷에 작성하는 값으로 이동통신사에서 발급해준다. 사실 간편하게 CID 라고 부르나 각 이동통신사마다 명칭이 다르며 이와 관련한 내용은 [[이통사 및 중계사 MMS CID 명칭 정리.pdf]] 에서 확인할 수 있다. 
>  
>  레거시에서 사용하는 CID 를 MCMP 플랫폼에서 사용할 때 주의해야하는 점으로는 아래와 같다.
>  
>  ## **CID 이관 작업 주의사항**
> 	 1. 리포트 수신 URL 변경 요청하기
> 	 2. 리포트 수신 URL 방화벽 확인
> 	 3. CID 와 매핑되어있는 SRC(Source) IP 및 PORT 변경


복잡한 패킷 작성 방식과 관련하여 간략하게 설명하자면 **직연동 MMS 센더**는 해당 센더의 목적지인 **이동통신사(SKT, KTF, LGT)** 와 **HTTP 통신하며 SOAP 규격으로 메세지 전송 요청을 수행**한다. 이는 단문 메세지(SMS), 알림톡(KKO), RCS, 중계사(엘지유플러스, 엘지 헬로비전, 원샷, 한진정보통신 등) 와는 다른 방식으로 XML 기반의 옛통신 방식으로 복잡하고 생소하여 전송 요청 과정(Submit / SubmitAck) 또는 리포트 수신 과정(Report / ReportAck)에서 사용하는 패킷, *내부적으로 사용하는 용어인 전송(Submit), 전송응답(SubmitAck), 결과수신(Report), 결과수신응답(ReportAck) 라고 작성하였으나 이동통신사에서 부르는 방식이 다르다.*, 을 수정할 때 주의하여야 한다.

## 용어 정리


| 용어                          | 설명                                                                                                                                                                                                                                                                                                                                                         |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **이동통신사**                   | 직연동 MMS 센더가 메세지 전송 요청을 수행하는 목적지를 의미하며 SKT, KTF, LGT 가 존재한다.                                                                                                                                                                                                                                                                                                |
| **중계사**                     | **중계사**란 **메세지 전송을 중계해주는 업체**를 의미하며 엘지 유플러스, 엘지헬로비전, SMTNT 등의 업체가 존재하며 *MCMP 플랫폼에서 이동통신사로 메세지를 전송하는 직연동 센더*와 *중계사에 메세지를 전송하는 중계사 센더* 가 존재한다.                                                                                                                                                                                                               |
| **SUBMIT** / **SUBMIT-ACK** | 메세지 전송 요청 수행 시 HTTP 으로 요청하며 요청에 대한 응답을 받는다. 이 때 메세지 전송 요청을 **SUBMIT** 이라고 하며 해당 요청에 응답을 **SUBMIT-ACK** 라고 한다.<br><br>해당 명칭은 보편적으로 사용하는 용어이나 이동통신사의 **연동규격서에 작성되어 있는 명칭은 다르기에 주의**하여야 한다.<br><br>※ MMS 센더 -> 이동통신사 또는 중계사 (**SUBMIT**)<br>※ 이동통신사 또는 중계사 -> MMS 센더 / (**SUBMIT-ACK**)                                                                       |
| **REPORT** / **REPORT-ACK** | **메세지 전송 결과 전달**은 **REPORT** 라고 말하며 **메세지 전송 결과 전달에 대한 응답**을 **REPORT-ACK** 라고 한다. 직연동 MMS 의 경우, 이동통신사로부터 웹 훅(Web Hook) 방식으로 리포트를 수신받는다.<br><br>※ 이동통신사 또는 중계사 -> MMS 센더 (**REPORT**)<br>※ MMS 센더 -> 이동통신사 또는 중계사 (**REPORT-ACK**)                                                                                                                         |
| **영속성(Persistence)**        | **영속성**이란 *데이터를 생성한 프로그램이 종료되어도 사라지지 않는 데이터의 특성*을 말한다. MMS 센더가 인입된 메세지 건에 대하여 영속성을 보장해야하는 이유를 설명하자면  고객사가 전송하는 메세지는 일반적으로 이동통신사와 **1. SUBMIT**, **2. SUBMIT-ACK**, **3. REPORT**, **4. REPORT-ACK** 과정을 마친 후 **5. MCMP 리포터 프로세스에게 리포트를 전송**해주어 **6. 고객사 에이전트에 리포트를 전송**하는 것까지를 하나의 생명주기를 가진다. MMS 센더는 해당 생명주기 동안 메세지(MessageDelivery)가 소실되지 않도록 관리해주어야 한다. |

---

# 별첨 문서

## 이동통신사(SKT, KTF, LGT) 별 메세지 생성 방식

1. [[부록. SKT 메세지 생성 방식]]
2. [[부록. KTF 메세지 생성 방식]]
3. [[부록. LGT 메세지 생성 방식]]


## CID 리스트

1. [[자산. SKT CID 리스트.pdf]]
2. [[자산. KTF CID 리스트.pdf]]
3. [[자산. LGT CID 리스트.pdf]]

---

## 메세지 전송 큰 흐름 살펴보기

- 메세지 전송 흐름
	![[SUBMIT_SUBMIT-ACK.png]]

	메세지 전송의 경우 위의 이미지에는 큰 흐름만 적어놓았을 뿐 각 센더마다 바라보는 RabbitMQ의 Queue 에 적재된 메세지를 가져와 여러 작업을 수행하고 이동통신사에 메세지를 전송한다. 메세지 전송 전 수행하는 작업은 아래와 같다.

	- **메세지 전송 전 수행 작업**
		 1. 메세지 Validation
		 2. 이미지 Valication 및 다운로드
		 3. 이동통신사 메세지 전송 패킷 생성
		 4. 메세지 전송 요청
		 5. 메세지 내부 메모리 및 레디스에 저장
		 6. 메세지 전송 응답에 따른 처리
		 7. SUBMIT-ACK 필드 값 수정 및 리포트 전송
		 8. RabbitMQ Ack/Nack 처리

	각 작업과 관련하여 어떠한 과정으로 어떠한 작업을 수행하는지 이후에 자세하게 설명한다.

- 리포트 전송 흐름
	![[REPORT_REPORT-ACK.png]]

	이동통신사 또는 중계사에게 받은 리포트를 MCMP 리포터에게 바로 전달하는 것이 아니라 메세지 전송 과정에 마찬가지로 여러 작업을 거친 후에 MCMP 리포터에게 리포트를 전달한다. 이 때 수행하는 여러 작업은 아래와 같다.

  - **리포트 전송 전 수행 작업**
	  1. 전달받은 메세지 전송 결과 요청을 이통사 메세지 클래스 형태로 변환
	  2. 메세지 키에 해당하는 `MessageDelivery` 객체 변수 할당
	  3. `MessageDelivery` 필드 값 변경
	  4. `MessageDelivery` 객체를 `ReportProcess` 의 내부 큐에 적재
	  5. `ReportProcess` 가 MCMP 리포터가 바라보는 큐에 적재

# 주요 클래스 살펴보기

직연동 MMS 센더 메세지 전송 흐름을 살펴볼 때 주요 클래스 위주로 살펴보면 큰 흐름을 잡기 쉽다. 자세히 살펴보아야 할 클래스는 아래와 같다.

**주요 클래스**
1. 메세지 클래스 다이어그램
2. Consumer
3. HttpClient
4. (SKT|KTF|LGT)ClientHandler
5. (SKT|KTF|LGT)SoapUtil
6. (SKT|KTF|LGT)Util
7. (SKT|KTF|LGT)MMSReportUtil
8. Storage 클래스 및 구현체

## 메세지 클래스 다이어그램

MMS 센더가 MCMP 내부 플랫폼 간 통신할 떄 사용하는 프로토콜은 `kr.co.seoultel.message.core.dto.MessageDelivery` 이나 MMS 센더의 목적지인 이통동신사/중계사와 통신할 때는 각 목적지의 연동 규격에 맞는 프로토콜을 사용하여야 하기 때문에 각 목적지(이동통신사 및 중계사) 별 메세지 클래스가 작성되어 있으며 이들을 공통으로 묶기 위한 `kr.co.seoultel.message.mt.mms.core.messages.Message` 클래스가 존재한다.

- MMS 메세지 클래스 다이어그램
	![이미지](MMS%20메세지%20클래스%20다이어그램.png)

위의 이미지를 보면 알수있듯이 `kr.co.seoultel.message.mt.mms.core.messages.Message` 클래스가 가장 상위 클래스로서 존재하며 해당 클래스는 아직 어떠한 메서드나 필드도 존재하지 않는 빈 클래스이지만 추후 공통 사용해야하는 메서드가 존재하는 경우에 해당 클래스 내부에 정의하여 사용하면 된다. 또한 부모클래스(`kr.co.seoultel.message.mt.mms.core.messages.Message`)를 두어 SoapUtil 및 MMSReportUtil 에서 형변환을 통하여 좀 더 유연한 코드 작성할 수 있으며 여러 곳에서 공통으로 사용할 수 있도록 개발하였다.

## MessageConsumer

`MessageConsumer` 는 각 센더가 바라보는 RabbitMQ 의 Queue 에서 메세지를 가져온 후 MCMP 에서 사용하는 내부 프로토콜 클래스인 `MessageDelivery` 클래스로 형변환하여 기본적인 Validation 을 진행한다.

- 값 검증(Validation) 작업
  1. **MessageDelivery 형변환 가능 여부 확인**
  2. **전송가능시간(08:00:00 ~ 21:00:00) 확인**
  3. **필수 데이터 값 확인** // 대체 발송 여부에 따라 별도로 진행
	1. *UmsMsgId 값 검증*
	2. *번호 형식 검증* 
		1. 발신자(sender)
		2. 수신자(receiver)
		3. 회신번호(callback)
	3. *최초식별자(OriginCode) 검증*
	4. *이미지 아이디 및 메세지 본문 내용 검증*
	5. *제목이 없는 경우, 기본 값 할당*

각 Validation 과정에 실패한 경우, 각 상황에 맞는 결과코드로 실패 리포트를 전달하게 되는데 어떠한 상황에 어떠한 결과코드로 리포트가 전송되는지와 관련하여 자세하게 확인하고 싶은 경우 [[0. 스탠다드네트웍스_MMS_내부_결과코드표.pdf]] 문서를 참조하자.

이후 Validation 작업이 모두 마치면 `MessageConsumer` 는 CID 별 발송 가능 TPS 가중치로 두어 **Weighted-RoundRobin 방식으로 메세지 전송 책임을 위임할 HttpClient 를 선택**하여 해당 HttpClient 에게 **기본 값에 대하여 Validation 마친 메세지** 의 메세지 전송 책임을 위임한다.


## HttpClient 

HttpClient 는 **이미지에 대한 만료 여부** 및 **전송 가능 여부 확인**, **이동통신사에 메세지 전송 요청** 및 **메세지 전송 요청 응답 처리**를 진행한다.

- **HttpClient 수행 작업**
	1. *이미지 전송 가능 여부 확인 및 이미지 다운로드*
	2. *TPS 초과 여부 확인*
	3. *이동통신사(SKT, KTF, LGT) 에 메세지 전송 요청(SUBMIT)* 및 *메세지 전송 요청 응답 처리(SUBMIT_ACK)*

`MessageConsumer` 는 RabbitMQ 큐 에서 가져온 *메세지의 형변환 및 필수 데이터에 대한 검증*을 수행한다면 **HttpClient 는 메세지의 전송 가능 여부를 판단한다.** 전송 가능 여부라고 하면 추상적일 수 있으나 메세지 전송 요청할 가치 판단을 한다고 보면된다. 해당 기능은 초기 개발 당시 나눈 기준으로 개인적인 생각으로 나눈 것으로 추후 MessageConsumer 에서 모든 Validation 을 수행하도록 수정하여도 문제 없다.

HttpClient 가 수행하는 *1. 이미지 전송 가능 여부 확인 및 이미지 다운로드*, *2. TPS 초과 여부 확인* 의 경우, **MMS-Core-Modules** 에 정의되어 있는 `kr.co.seoultel.message.mt.mms.core_module.modules.multimedia.MultiMediaService` 를 사용하며 이를 이동통신사 및 중계사 센더 모두 공통으로 사용하는데 자세한 사항은 [[MMS-Core-Modules 인수인계서#MultiMediaSerivce]] 를 참고하자.

그렇다면 이제 `HttpClient` 를 어떻게 생성하고 관리하는지 확인하도록 하자. 우선 application.yml 에 작성한 CID 개수만큼 HttpClient 가 생성되어 리스트로 만든 후, 해당 리스트를 빈(Bean)으로 등록하여 다른 클래스에서 주입받아 사용하는 방식으로 설계하였다.

메세지 전송에 대한 책임을 가지는 `HttpClient` 는 RabbitMQ 큐에 적재된 메세지를 가져오는 `MessageConsumer` 만 `List<HttpClient> httpClients` 를 주입받아 HttpClient 가 가지는 CID 의 TPS 값에 따라 가중치 라운드 로빈 방식으로 선택하여 사용하는데 간단하게 보자면 아래와 같다.

- HttpClient 생성 및 주입 이미지
	![[HttpClient 생성 및 주입.png]]


## HttpClientHandler

`kr.co.seoultel.message.mt.mms.direct.modules.client.http.HttpClientHandler` 클래스를 상속받는 `kr.co.seoultel.message.mt.mms.direct.skt.SktClientHandler`, `kr.co.seoultel.message.mt.mms.direct.ktf.KtfClientHandler`, `kr.co.seoultel.message.mt.mms.direct.lgt.LgtClientHandler` 는 HttpClient 가 메세지 전송 요청을 하기위하여 사용하는 클래스로 이동통신사의 규격에 맞게 각 이통사 메세지 클래스를 생성한 후, 메세지 전송 요청 및 전송 요청 응답 처리를 하는 역할을 수행한다. HttpClient 는 고유의 HttpClientHandler 를 가지고 있으며 

**요청 본문에 들어가는 메세지를 생성하는 로직 뿐만 아니라 결과 코드 값은** 다르나 이외의 부분은 동일하기 때문에 난이도가 높지 않다. 메세지 생성 부분과 관련한 자세한 내용은 [[#이동통신사(SKT, KTF, LGT) 별 메세지 생성 방식]] 의 각 이통사의 별첨 문서를 참조하자.

`HttpClientHandler`는 메세지 생성 로직 및 결과 코드에 따른 처리부만 다르고 해당 부분을 제외한 나머지 부분은 비교적 간단하고 단순하다.

- `HttpClientHandler` 공통 메세지 전송 흐름
	1. 이통사에 맞는 `SoapMessage` 생성
	2. 메세지 전송 요청 전, `MessageDelivery` 값 변경하기
	3. 이통사에 메세지 전송 요청
	4. 메세지 전송 요청에 응답에 따른 메세지 처리

`HttpClientHandler` 에서 주요 흐름으로는 위의 4가지로 **1. 전송할 메세지 클래스를 생성**하고 **2. MessageDelivery 의 값을 수정**한 후 **3. 이통사에 메세지 전송 요청** 한다. 이후 **4. 메세지 전송 요청 응답 처리** 하는 순서로 동작한다. 자세한 내용은 코드를 참고하자.

## SoapUtil 및 SoapUtil 구현체

`kr.co.seoultel.message.mt.mms.direct.util.SoapUtil` 클래스는 SOAP 규격의 이동통신사 메세지를 생성하는데 사용하는 유틸리티 추상 클래스로 SOAP 규격의 MMS 메세지를 생성하는 `protected abstract String createSOAPMessage(InboundMessage inboundMessage) throws MCMPSoapRenderException;` 를 비롯하여 여러 추상 메서드가 정의되어있다.

**이동통신사 별로 다른 SOAP 규격**에 맞게 **SOAP 메세지를 생성**하는 역할을 수행하기 때문에 SOAP 메세지를 생성하는 `String createSOAPMessage(InboundMessage inboundMessage)` 를 **재정의(Override)** 하여 사용하여야 한다.

- `Message` 클래스 다이어그램
	![[MMS 메세지 클래스 다이어그램.png]]

> - 주의 사항
> 	**1. `jakarta.xml.soap.SOAPMessage`** : SOAP 규격 메세지를 만들기 위한 라이브러리에서 제공하는 메세지 클래스
> 	**2. `kr.co.seoultel.message.mt.mms.core.messages.direct.SoapMessage`** : MMS 센더가 이동통신사와 통신하기 위해 직접 구현한 메세지 클래스
> 	
> MMS 센더가 직접 구현한 메세지 클래스는 CamelCase 로 작성되어 있다는 것에 주의하자.


## MMSReportUtil 및 MMSReportUtil 구현체

메세지 전송 후 MCMP 리포터에게 리포트를 전송하기 전 `kr.co.seoultel.message.core.dto.MessageDelivery` 객체의 필드 값을 변경주어야 하는데 수정해야 하는 필드 값은 아래와 같다.

- **리포트 전송 시 채워줘야 하는 필수 필드**
	1. Result.MNO_CD
	2. Result.MNO_RESULT
	3. Result.SETTLE_CODE
	4. Result.MESSAGE
	5. Result.PFM_SND_DTTM
	6. Result.PFM_RCV_DTTM

이러한 값들에 적절한 값을 넣지 않고 *다른 형식의 값을 넣거나*, *값을 넣지 않았을 때* *MCMP 리포터에서 예외가 발생하거나 DB에 데이터가 적재되지 않는 등* 의 작업을 정상적으로 마칠 수 없으며 **전송 성공한 메세지 건에 대한 정산과 관련한 문제가 생길 수 있기 때문에 주의**해야하고 관련 문제가 많이 발생하였기 때문에 되도록 **공통된 형태의 메서드를 제공하여 관리할 수 있도록 개발**하였다.

그렇게 작성한 클래스가 `kr.co.seoultel.message.mt.mms.core_module.utils.MMSReportUtil` 클래스로 자세한 코드는 [Github/MMS-Core-Modules/MMSReportUtil.class](https://github.com/seoultel/kr.co.seoultel.message.mt.mms-core-modules/blob/v1.2.0/src/main/java/kr/co/seoultel/message/mt/mms/core_module/utils/MMSReportUtil.java) 에서 확인하자.


- **주요하게 살펴보아야 하는 부분**
	```java
	public abstract class MMSReportUtil<T extends Message> {
		... 
	}
	```

해당 클래스에서 중요한 부분으로는 **MMS 센더가 정의하는 `kr.co.seoultel.message.mt.mms.core.messages.Message` 클래스를 상속받은 클래스를 모두 메서드의 인자로 받을 수 있도록 제네릭(Generic) 을 사용하여 클래스를 정의**하였다는 점으로 아래와 같이 사용할 수 있다.

- MMSReportUtil 클래스를 상속받은 SktMMSReportUtil 클래스
	```java
	package kr.co.seoultel.message.mt.mms.direct.util.skt;
	
	public class SktMMSReportUtil extends MMSReportUtil<SktSoapMessage> {
	
		@Override  
		public void prepareToSubmitAck(MessageDelivery messageDelivery, SktSoapMessage sktSoapMessage) {
			...
		}
		
		@Override  
		public Map<String, Object> getSubmitAckResult(MessageDelivery messageDelivery, SktSoapMessage sktSoapMessage) {
			...
		}
		@Override  
		public void prepareToReport(MessageDelivery messageDelivery, SktSoapMessage sktSoapMessage) {
			...
		}
	
		@Override  
		public Map<String, Object> getReportResult(boolean isSuccess, MessageDelivery messageDelivery, SktSoapMessage sktSoapMessage) {
			...
		}
	}
	```

여러 메세지 클래스를 사용하더라도 해당 메서드의 인자로 넣을 수 있도록 하기 위하여 부모 클래스를 제네릭(Generic)으로 선언해 형변환을 통해 로직을 수행하도록 작성되어 이후 수정 개발시에 주의하여 사용하도록 하자.



