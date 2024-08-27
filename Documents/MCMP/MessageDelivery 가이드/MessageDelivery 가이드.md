| 프로젝트명 | Message Delivery |        |            |
| ----- | :--------------: | :----: | :--------: |
| 문서명   | Message Delivery |   버전   |  V-0.0.1   |
| 소속    |      전송 개발팀      |  작성일   | 2024-07-17 |
| 작성자   |       장정호        | 최종 수정일 |            |
| 문서 번호 |                  |        |            |

---

# 목차

1. 개요
    1. git Hub Repository
2. Message Delivery 규격
3. Delivery Parser
4. 주의 사항 및 가이드

---

# 개요

Message Delivery란, MCMP(차세대 전송 플랫폼 개발 프로젝트)에서 사용 되는 프로토콜이다.

기존 Legacy의 프로토콜은 C로 개발된 SMS G/W의 체계와, Java로 개발된 MMS, KKO의 체계가 서로 상이하여 메시지 본문을 다루는 통합 프로토콜이 이루어지지 못하여서 복잡한 구조였다.

차세대는 이 문제를 해결하고자 채널을 통합하는 프로토콜을 개발하게 되었다.

> [MessageDelivery 레파지토리](https://github.com/seoultel/kr.co.seoultel.message.core)

---

# Message Delivery 분석

지금부터 Message Delivery의 구성을 분석하겠다.

## Message Delivery 본문

```java
/**
 * 메시지 전송 내용과 상태를 처리하기 위한 객체
 * @author alchemist
 */
public class MessageDelivery implements Serializable, Cloneable {
    private Long createdTime; // 생성시각
    private String umsMsgId; // 플랫폼에서 생성한 메시지 식별 ID
    private String srcMsgId; // 고객사에서 부여한 메시지 식별 ID
    private String dstMsgId; // 이통사/중계사에서 부여한 메시지 식별 ID
    private String cmpMsgId; // 레거시 규격으로 유입된 고객사 메시지 식별 ID
    private String memberId; // 업체 멤버 아이디
    private String authSeq; // 레거시 규격으로 유입된 세션 인증코드
    private String groupCode;	// 업체 그룹 코드
    private String serviceCode;	// 업체 그룹별 서비스 코드(usrCd)
    private String channel;	// 메세지 채널(SMS,LMS,MMS,KKO,PUSH, ... etc.)
    private String tenant;	// Proxy등 Tenant별로 구분하여 처리하는 경우를 위한 Tenant 구분코드
    private String billCode; // 고객사의 정산코드
    private String clientNo;	// 전송 한 clientNo
    private String type; // 메시지 종류(OTP,INFO,REAL,BULK, ... etc.)
    private String sender; // 발신자
    private String callback; // 회신번호
    private String receiver; // 수신자
    private boolean adFlag; // 광고 검칙 플래그
    private Map<String,Object> content; // 메시지 채널별 메시지 전달 데이터
    private List<ProcessRecord> processHistory; // MessageDelivery 객체가 처리된 히스토리 정보
    private String serviceProvider;	// 서비스 제공자(SKT, KT, LGT, KDDI, KAKAO, ....)
    private String deliveryProcess; // 처리한 프로세스 이름
    private Integer deliveryState; // 전송 진행 상태(0:초기값,1:전송중,2:요청완료,3:전송성공,4:전송실패,5:재시도대기.....)
    private Integer deliveryType; // MessageDelivery type(SUBMIT, SUBMIT_ACK, REPORT, REPORT_ACK.....)
    private Map<String,Object> result; // 처리 결과 데이터
    private String reportTo; // URL Scheme 형식의 리포트 대상 경로
    private Long timeToLive; // 전송 유효시간
    private Integer retryCount; // 리포트 재전송 횟수
}
```

위의 코드 블록에 Message Delivery 필드를 주석으로 설명하였지만,

**content, process History, deliveryState과 deliveryType, result, Fallback** 필드에 한해서는 아래에 따로 추가 설명을 하겠다.

---

### Content 필드 사용 예시

Message Delivery의 **content 필드**는 **채널 별로 전송에 필요한 데이터**를 적재하기 때문에 **매우 중요하다.**

아래는 sms의 content에 필요한 필드를 정의한 Message Delivery의 sms 패키지의 submit 객체이다.

```java
public class Submit implements Serializable {
    public static final String NAT_CODE = "natCode"; // 국가번호
    public static final String MESSAGE = "message"; // 메시지 본문
    public static final String DST_CHARSET = "dstCharset"; // 목적지 문자셋
    public static final String RSRVD_ID = "rsrvdId"; // 정산 후처리 등을 위한 예비 필드
    public static final String ORIGIN_CODE = "originCode"; // 최초 발송사업자 코드
    public static final String RELAY_CODE = "relayCode"; // 중계사 코드(이통사 직접 연동시)
    public static final String VAS_FLAG = "vasFlag"; // 직판매, 재판매 구분
```

아래는 mms의 content에 필요한 필드를 정의한 Message Delivery의 mms패키지의 submit 객체이다.

SMS와 달리 Subject, mediaFiles라는 필드가 추가된 것을 알 수 있다.

```java
public class Submit implements Serializable {
    public static final String NAT_CODE = "natCode"; // 국가번호
    public static final String SUBJECT = "subject"; // 제목
    public static final String MESSAGE = "message"; // 메시지 본문
    public static final String MEDIA_FILES = "mediaFiles"; // 미디어 파일 리스트
    public static final String DST_CHARSET = "dstCharset"; // 목적지 문자셋
    public static final String RSRVD_ID = "rsrvdId"; // 정산 후처리 등을 위한 예비 필드
    public static final String ORIGIN_CODE = "originCode"; // 최초 발송사업자 코드
    public static final String RELAY_CODE = "relayCode"; // 중계사 코드(이통사 직접 연동시)
    public static final String VAS_FLAG = "vasFlag"; //직판매, 재판매 구분
```
아래는 rcs의 content에 필요한 필드를 정의한 Message Delivery의 rcs패키지의 submit 객체이다.

```java
public static final String RCS_MESSAGE_TYPE = "rcsMessageType"; // 메시지 타입 RCS-(SMS/MMS/LMS/TMPLT)
    public static final String RCS_AGENCY_ID = "agencyId"; // 최초 발송 대행사 식별 ID
    public static final String RCS_AGENCY_KEY = "agencyKey"; // 최초 발송 대행사 식별 Key
    public static final String RCS_MSG_GROUP = "msgGb"; // // 메시지 타입 (SMS/MMS/LMS/RCS)
    public static final String RCS_CHATBOT_ID = "chatbotId"; // 챗봇 ID
    public static final String RCS_HEADER = "header"; // 0 : 정보성 메시지, 1: 광고성 메시지
    public static final String RCS_FOOTER = "footer"; // 수신거부 번호 , 광고성 메시지일 경우 필수 값
    public static final String RCS_COPY_ALLOWED = "copyAllowed"; // 메시지에 대한 단말의 메시지 복사 기능
    public static final String RCS_TEMPLATE_ID = "templateId"; // 템플릿 아이디
    public static final String RCS_EXPIRY_OPTION = "expiryOption"; // 만료시간 설정
    public static final String RCS_BUTTONS = "buttons"; // 버튼 데이터
    public static final String RCS_BODY = "body"; // 메시지 본문
    public static final String RCS_GROUP_ID = "groupId";  // 고객사 그룹 아이디
    public static final String RCS_BRAND_KEY = "brandKey"; // 고객사 브랜드 키
    public static final String NAT_CODE = "natCode";
    public static final String VAS_FLAG = "vasFlag";
```

아래는 kko의 content에 필요한 필드를 정의한 Message Delivery의 kko패키지의 submit 객체이다.

```java
public class Submit {
    public static final String TITLE = "title"; // 강조 타이틀
    public static final String MSG_TYPE = "msgType"; // 알림톡, 친구톡 구분 값 ex)AT,FT
    public static final String TEMPLATE_CD = "templateCd"; // 알림톡 템플릿 고유 코드
    public static final String K_PLUS_ID = "kPlusId"; // 카카오톡 채널 ID
    public static final String PROFILE_KEY = "profileKey"; // 발신 프로필 키
    public static final String WIDE = "wide"; // 친구톡 이미지 wide 여부
    public static final String IMG_FLAG = "imageFlag"; // 알림톡 이미지 포함여부
    public static final String AD_FLAG = "adFlag"; // 광고 표기
    public static final String IMG_URL = "imgUrl"; // 이미지 링크
    public static final String IMG_LINK = "imgLink"; // 이미지 누르면 들어갈 링크
    public static final String BUTTONS = "buttons"; // 알림톡 버튼
    public static final String MESSAGE = "message"; // 메시지 본문
    public static final String VAS_FLAG = "vasFlag"; // 직판매, 재판매 구분
```
지금까지 Content 필드에서 각 Message Channel 별 전송 본문 객체를 정의한다.

---

### Fallback Message

Fallback 이란 RCS와 KKO가 실패일 경우 SMS, LMS/MMS로 대체 전송시 필요한 값을 가져가기 위해 설계된 필드이다.

Fallback도 Message Delivery의 content 필드에 담기게 된다.

아래는 content 필드에 담기는 대체 전송 객체인 Fallback이다.

```java
public class Fallback implements Serializable {
    private String channel; // 대체 전송 Channel (SMS,LMS/MMS만)
    private String dstMsgId; // 이통사 식별 메시지 키
    private String subject; // LMS, MMS의 경우 사용될 제목
    private String content; // SMS, LMS/MMS 메시지 본문
    private String serviceProvider; // 이통사
    private List<String> fileIds; // LMS, MMS의 경우 사용될 이미지
    private String originCode; // 최초 식별자 코드
    private Map<String,Object> result; // 처리 결과 데이터
}
```

---

### Process History 사용 예시

Message Delivery는 List\<ProcessHistory\>를 사용하기 때문에 add로 계속 추가한다.

Process History는 MCMP의 프로세스의 처리 이력을 저장하는 객체이다.

```java
public ProcessRecord(Long processedTime, String processor, String action) {
	this.processedTime = processedTime; // 메시지를 처리한 시간
	this.processorName = processor; // 메시지를 처리한 프로세스 이름
	this.action = action; // 메시지를 처리한 동작
}
```

Message Delivery가 처리된 이력을 나중에 확인하면 메시지가 흘러온 흐름을 알 수 있다.

---

#### Message Delivery에서의 Type과 State

현재 메시지가 어떤 상태인지, 어떤 종류의 메시지인지, 알 수 있는 방법이 있다. 바로 Message Delivery의 Type과 State을 확인하면 된다. 아래는 Message Delivery의 Type과 State이다.

**Message State**

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

**MessageDelivery Type**

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

---

#### RESULT

Result 필드는 Message Delivery의 SMS, LMS/MMS, KKO, RCS 등 모든 메시지 채널의 처리 결과를 Message Delivery의 Result 필드에 담는다.

```java
public class Result implements Serializable {
    private String code; // 결과 코드
    private String message; // 결과 메시지
    private String mnoCd; // 최종 MNO
    private String mnoResult; // 이통사에서 보내온 결과코드:결과메시지
    private String settleCode; // 최종 처리한 sender의 settleCode
    private String srcSndDttm; // 클라이언트에서 발송 요청을 수신한 시각
    private String srcRcvDttm; // 클라이언트에 결과 리포트를 전달한 시각
    private String pfmSndDttm; // 플랫폼에서 이통사로 발송 요청을 전달한 시각
    private String pfmRcvDttm; // 플랫폼에서 이통사로부터 결과 리포트를 수신한 시각
    private List<String> triedMnos; // 전송 시도한 이통사 리스트
}
```

---

#### Delivery Parser

Delivery parser는 Fallback Message를 읽어내기 편의성을 제공하기 위해서 제작 되었다.

Message Delivery의 content 필드의 Fallback 객체를 parsing의 편의성을 제공한다.

```java
public static Fallback getFallback(MessageDelivery messageDelivery) {
	return messageDelivery.getContent().get(Fallback.FALLBACK) != null ? gson.fromJson(gson.toJson(messageDelivery.getContent().get(Fallback.FALLBACK)), Fallback.class) : new Fallback();
}
```
---

#### 주의사항 및 가이드