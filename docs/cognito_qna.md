# Amazon Cognito Q&A 상세 답변

---

## 인증 프로토콜 & 인증 플로우

### Q1. Cognito(User Pool)에서 지원하는 인증 프로토콜은 무엇인가요?

**질문 상세:**
- OAuth 2.0 / OpenID Connect
- SAML 2.0
- 각 프로토콜의 주 사용 목적(기본 인증 vs 외부 IdP 연동)과 권장 사용 시나리오

**답변:**

Cognito User Pool은 다음 프로토콜을 지원합니다:

| 프로토콜 | 주 사용 목적 | 권장 시나리오 |
|---------|------------|-------------|
| **OAuth 2.0 / OIDC** | 기본 인증, 자체 앱 인증 | 모바일/웹 앱, SPA, 자체 서비스 인증 |
| **SAML 2.0** | 외부 IdP 연동 (SP 역할) | 기업 IdP(AD FS, Okta 등) 연동 |

**근거 문서:**
- [Amazon Cognito User Pools - Adding user pool sign-in through a third party](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-identity-federation.html)
  - "You can add federation with SAML or OIDC IdPs" 섹션 참조
- [Using Amazon Cognito user pools security features](https://docs.aws.amazon.com/cognito/latest/developerguide/managing-security.html)

---

### Q2. 인증 플로우별 권장/비권장 및 App Client 단위 분리 가능 범위

**질문 상세:**
- Authorization Code Flow (PKCE 포함)
- Implicit Flow
- Client Credentials Flow(서버 to 서버)
- 중 권장 / 비권장 / 불가한 방식과 클라이언트별로 분리 제어 가능한 항목 범위

**답변:**

| 플로우 | 지원 여부 | 권장 |
|-------|---------|------|
| Authorization Code Flow (+ PKCE) | ✅ | **권장** - 가장 안전, 웹/모바일 |
| Implicit Flow | ✅ | ⚠️ **비권장** - 레거시 지원용 |
| Client Credentials Flow | ✅ | 서버 to 서버 통신용 |

**App Client 단위 분리 가능 항목:**
- OAuth 플로우 타입 (Allowed OAuth Flows)
- Callback URL / Sign-out URL
- Token 유효기간 (Access/ID/Refresh Token)
- 허용 OAuth Scope
- Identity Provider 연동 설정

**근거 문서:**
- [App client settings in User Pools](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-app-idp-settings.html)
  - "Configure app client settings" 섹션에서 각 App Client별 OAuth 플로우 설정 방법 설명
- [OAuth 2.0 grants in Amazon Cognito](https://docs.aws.amazon.com/cognito/latest/developerguide/federation-endpoints-oauth-grants.html)
  - Authorization code grant, Implicit grant, Client credentials grant 설명

---

## 사용자 정보(회원 정보) 저장 구조

### Q3. Cognito에서 관리하는 사용자 정보 구조는 어떻게 되나요?

**질문 상세:**
- 표준 Attribute와 Custom Attribute의 차이
- Custom Attribute 개수/길이/제약 사항

**답변:**

**표준 Attribute (OIDC 표준 클레임):**
- `email`, `phone_number`, `name`, `given_name`, `family_name`, `nickname`
- `birthdate`, `address`, `locale`, `zoneinfo`, `gender`, `picture`, `profile`, `website`
- `preferred_username`, `updated_at`, `sub` (사용자 고유 ID)

**Custom Attribute 제약사항:**

| 항목 | 제한 |
|-----|-----|
| 최대 개수 | **50개** |
| 타입 | String, Number, DateTime, Boolean |
| 최대 길이 | **2048자** (String) |
| 접두사 | `custom:` 필수 (예: `custom:company_name`) |
| 삭제 | **생성 후 삭제 불가** (값만 수정 가능) |
| 변경 가능성 | mutable/immutable 설정 가능 |

**근거 문서:**
- [Configuring user pool attributes](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-settings-attributes.html)
  - "Custom attributes" 섹션: "You can add up to 50 custom attributes to your user pool"
  - "You cannot remove or change the configuration of custom attributes after you create them"

---

### Q4. 로그인(SNS) 이후, 추가 회원 정보를 입력받아 Cognito 사용자 정보로 저장·수정하는 것이 가능한가요?

**질문 상세:**
- 외부 고객/파트너 여부, 회사명, 사번 등 추가 회원 정보
- 사용자 본인 / 관리자 / 서버(API) 각 주체별 가능 범위와 권장 방식

**답변:**

**가능합니다.** 각 주체별 방식:

| 주체 | API | 필요 권한 | 비고 |
|-----|-----|---------|-----|
| 사용자 본인 | `UpdateUserAttributes` | Access Token | mutable attribute만 수정 가능 |
| 관리자 | `AdminUpdateUserAttributes` | IAM 권한 | 모든 attribute 수정 가능 |
| 서버(API) | `AdminUpdateUserAttributes` | IAM 권한 | **권장 방식** |

**권장 방식:** 서버 측에서 Lambda 또는 백엔드 API를 통해 `AdminUpdateUserAttributes` 호출

**근거 문서:**
- [AdminUpdateUserAttributes API Reference](https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_AdminUpdateUserAttributes.html)
  - "Updates the specified user's attributes, including developer attributes, as an administrator"
- [UpdateUserAttributes API Reference](https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_UpdateUserAttributes.html)

---

## 내부 사용자 자동 판별 / 즉시 활성화

### Q5. SNS 로그인 이후, 사용자가 입력한 추가 정보를 기준으로 내부 사용자를 자동 판별하고 즉시 활성화하는 구조가 가능한가요?

**질문 상세:**
- 사번, 사내 이메일 등을 기준으로 관리자 승인 없이 자동 판별
- 동일 사용자 계정을 유지한 채, attribute 또는 group 변경 방식으로 내부/외부 사용자 구분 관리

**답변:**

**가능합니다.**

**구현 방법:**
1. **Post Confirmation Lambda Trigger** 사용
2. 사용자 입력 정보(사번, 사내 이메일) 검증
3. 검증 통과 시 자동으로 Group 추가 또는 Attribute 설정

**내부/외부 사용자 구분 방식:**
- **Cognito Group** 사용 (권장): `internal-users`, `external-users`
- **Custom Attribute** 사용: `custom:user_type = internal | external`

**근거 문서:**
- [Post confirmation Lambda trigger](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-post-confirmation.html)
  - "Amazon Cognito invokes this trigger after a user is confirmed"
- [Adding users to groups](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-user-groups.html)

---

### Q6. 내부 사용자 판별 로직을 Cognito Trigger(Lambda)를 활용하여 구현할 수 있나요?

**질문 상세:**
- 입력값 검증
- 외부 사내 시스템(DB/API) 연동
- 검증 결과를 사용자 attribute/group에 반영
- 권장 아키텍처와 주요 제약 사항(타임아웃, 재시도, 보안 등)

**답변:**

**가능합니다.**

**권장 아키텍처:**
```
SNS 로그인 → Post Confirmation Trigger → Lambda
    → 사내 DB/API 조회 → AdminAddUserToGroup / AdminUpdateUserAttributes
```

**주요 제약사항:**

| 항목 | 제한 |
|-----|-----|
| Lambda 타임아웃 | **5초** (Cognito Trigger 제한) |
| 호출 방식 | 동기 호출 (외부 API 타임아웃 주의) |
| 실패 시 | **재시도 없음** - 사용자 가입 자체가 실패 |
| VPC 접근 | Cold Start 지연 고려 필요 |
| 보안 | Lambda 실행 역할에 최소 권한 부여 |

**근거 문서:**
- [Customizing user pool workflows with Lambda triggers](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-identity-pools-working-with-aws-lambda-triggers.html)
  - "Lambda trigger timeout" 섹션: "Amazon Cognito invokes Lambda functions synchronously... limit the timeout to 5 seconds"
- [Lambda function handler](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-post-confirmation.html)

---

## 로그인 UI(Hosted UI) 사용 범위

### Q7. Cognito Hosted UI를 사용하지 않고, 자체 UI에서 로그인 화면을 구현한 뒤 OIDC 방식으로 Cognito와 연동하는 것이 가능한가요?

**질문 상세:**
- 실무에서의 권장 패턴

**답변:**

**가능합니다.**

**구현 방식:**
1. **Cognito User Pool API 직접 호출**: `InitiateAuth`, `RespondToAuthChallenge` 등
2. **AWS Amplify SDK 사용** (권장)
3. **OIDC Authorization Endpoint 리다이렉트**

**권장 패턴:** Amplify Auth 라이브러리 사용하여 자체 UI 구현

```javascript
// Amplify 예시
import { signIn } from 'aws-amplify/auth';
await signIn({ username, password });
```

**추가 질문: 자체 UI에서 소셜 로그인(Google, Facebook 등)은 가능한가요?**

**가능합니다.** 자체 UI를 사용하면서도 소셜 로그인을 지원할 수 있습니다.

**방법 1: OAuth Authorize Endpoint 직접 호출 (권장)**

자체 UI에서 "Google로 로그인" 버튼 클릭 시, Cognito OAuth endpoint로 리다이렉트하면서 `identity_provider` 파라미터를 지정합니다.

```javascript
// 자체 UI에서 Google 로그인 버튼 클릭 시
const googleLoginUrl = `https://${COGNITO_DOMAIN}.auth.${REGION}.amazoncognito.com/oauth2/authorize?` +
  `identity_provider=Google&` +  // 특정 IdP 지정 - Hosted UI를 거치지 않고 바로 Google로 이동
  `client_id=${CLIENT_ID}&` +
  `response_type=code&` +
  `scope=openid+email+profile&` +
  `redirect_uri=${CALLBACK_URL}`;

window.location.href = googleLoginUrl;
```

**방법 2: Amplify federatedSignIn**

```javascript
import { signInWithRedirect } from 'aws-amplify/auth';

// Google 로그인
await signInWithRedirect({ provider: 'Google' });

// Facebook 로그인
await signInWithRedirect({ provider: 'Facebook' });
```

**정리:**

| 로그인 방식 | 자체 UI 가능 | 설명 |
|------------|-------------|------|
| ID/PW 로그인 | ✅ 완전 가능 | `InitiateAuth` API 또는 Amplify `signIn` |
| 소셜 로그인 | ✅ 가능 (리다이렉트) | OAuth endpoint + `identity_provider` 파라미터 |

**핵심:** 소셜 로그인 버튼 UI는 자체 구현하고, 실제 인증은 해당 IdP(Google/Facebook) 화면으로 리다이렉트됩니다. Hosted UI 전체를 사용하지 않고 특정 IdP로 바로 이동 가능합니다.

**근거 문서:**
- [Using the Amazon Cognito user pools API](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pools-API-operations.html)
- [InitiateAuth API Reference](https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_InitiateAuth.html)
- [Amplify Auth documentation](https://docs.amplify.aws/lib/auth/getting-started/)
- [Authorization endpoint](https://docs.aws.amazon.com/cognito/latest/developerguide/authorization-endpoint.html) - `identity_provider` 파라미터 설명

---

### Q8. Hosted UI를 사용하는 경우, 커스터마이징 가능한 범위는?

**질문 상세:**
- 로고/컬러/문구 등 커스터마이징 범위
- App Client 단위 UI 분기 가능 여부
- redirect URI 등 요청 파라미터 제어 가능 범위

**답변:**

**커스터마이징 가능 항목:**
- 로고 이미지
- 배경색
- CSS 스타일링 (제한적)

**제한사항:**

| 항목 | 가능 여부 |
|-----|---------|
| App Client 단위 UI 분기 | ❌ **불가** (User Pool 단위로 하나의 UI) |
| 레이아웃 변경 | ❌ **불가** |
| redirect URI | ✅ App Client 설정에서 제어 가능 |

**근거 문서:**
- [Customizing the built-in sign-in and sign-up webpages](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-app-ui-customization.html)
  - "You can customize the appearance of the hosted UI pages"
  - 제한적 CSS 커스터마이징만 지원

---

## 소셜 로그인 연동 범위

### Q9. Cognito에서 기본 지원하는 소셜 로그인 Provider는 무엇인가요?

**질문 상세:**
- Google 등 기본 지원
- Custom OIDC Provider 연동 가능 여부

**답변:**

**기본 지원 Provider:**
- Google
- Facebook
- Amazon (Login with Amazon)
- Apple (Sign in with Apple)

**추가 지원:**
- ✅ **Custom OIDC Provider**: OpenID Connect 호환 IdP 연동 가능
- ✅ **SAML 2.0 IdP**: 기업 IdP 연동 지원

**근거 문서:**
- [Adding social identity providers](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-social-idp.html)
  - "Amazon Cognito user pools support sign-in with social identity providers such as Facebook, Google, Amazon, and Apple"
- [Adding OIDC identity providers](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-oidc-idp.html)

---

### Q10. 소셜 로그인 이후에도 일반 로그인과 동일하게 추가 사용자 정보 입력 및 Cognito 저장이 가능한가요?

**질문 상세:**
- 차이점이나 제한 사항

**답변:**

**가능합니다.** 일반 로그인과 동일하게 처리 가능.

**차이점/주의사항:**

| 항목 | 설명 |
|-----|-----|
| 초기 Attribute | IdP에서 제공받은 값으로 설정 |
| 매 로그인 시 | IdP Attribute가 **덮어쓰기될 수 있음** (Attribute Mapping 설정에 따라) |
| Custom Attribute | 자유롭게 추가/수정 가능 |

**권장:** Attribute Mapping 설정 시 덮어쓰기 동작 고려

**근거 문서:**
- [Specifying identity provider attribute mappings](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-specifying-attribute-mapping.html)
  - "When a user signs in to your application through an identity provider, Amazon Cognito maps the identity provider's user attributes to user pool attributes"

---

## 멀티 서비스 SSO & 세션 모델

### Q11. 서로 다른 도메인의 여러 서비스에서 동일 User Pool 기반 SSO 구성이 가능한가요?

**답변:**

**가능합니다.**

**구현 방법:**
1. 동일 User Pool에 여러 App Client 생성
2. 각 App Client에 서로 다른 도메인의 Callback URL 설정
3. Hosted UI 또는 OIDC 방식으로 SSO 구현

**근거 문서:**
- [Configuring a user pool app client](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-settings-client-apps.html)
  - "You can create multiple app clients for a user pool"
- [Adding user pool sign-in through a third party](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-identity-federation.html)

---

### Q12. A 서비스에서 로그인 후, B 서비스 접근 시 재로그인 없이 세션 유지가 가능한가요?

**질문 상세:**
- 각 서비스에서 로그인 상태를 확인하는 방식
- 토큰 검증/갱신 책임이 어디에 있는지

**답변:**

**조건부 가능합니다.**

| 방식 | SSO 세션 유지 | 구현 |
|-----|-------------|-----|
| **Hosted UI 사용** | ✅ 자동 | Cognito 도메인 세션 쿠키로 유지 |
| **자체 UI 사용** | 별도 구현 필요 | Refresh Token 공유 또는 공유 세션 스토리지 |

**토큰 검증/갱신 책임:** 각 서비스(클라이언트) 측

**근거 문서:**
- [Using the Amazon Cognito hosted UI](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-app-integration.html)
  - Hosted UI 세션 관리 설명
- [Using tokens with user pools](https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-using-tokens-with-identity-providers.html)

---

### Q13. 로그아웃 시, 전체 서비스에 대한 SSO 로그아웃을 일관되게 처리할 수 있나요?

**질문 상세:**
- 주의해야 할 제약 사항

**답변:**

**Hosted UI 사용 시:** `GlobalSignOut` API로 전체 세션 무효화 가능

**제약사항:**

| 항목 | 설명 |
|-----|-----|
| Refresh Token | ✅ 무효화 가능 |
| Access Token | ⚠️ **만료까지 유효** (기본 1시간) |
| 로컬 세션 | 각 서비스에서 별도 클리어 필요 |
| SAML IdP | IdP 측 로그아웃 별도 처리 필요 |

**근거 문서:**
- [GlobalSignOut API Reference](https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_GlobalSignOut.html)
  - "Signs out users from all devices"
- [Revoking tokens](https://docs.aws.amazon.com/cognito/latest/developerguide/token-revocation.html)

---

## 관리자(운영) 기능

### Q14. Cognito 기준에서 관리자(Admin)가 기본적으로 수행할 수 있는 기능 범위는 어디까지인가요?

**질문 상세:**
- 사용자 조회/검색
- 사용자 활성/비활성(disable)
- 사용자 attribute 수정
- 강제 로그아웃/토큰 무효화
- MFA 설정 관리 등

**답변:**

| 기능 | API | 지원 |
|-----|-----|------|
| 사용자 조회 | `ListUsers`, `AdminGetUser` | ✅ |
| 사용자 검색 | `ListUsers` (filter) | ✅ |
| 사용자 활성화 | `AdminEnableUser` | ✅ |
| 사용자 비활성화 | `AdminDisableUser` | ✅ |
| Attribute 수정 | `AdminUpdateUserAttributes` | ✅ |
| 강제 로그아웃 | `AdminUserGlobalSignOut` | ✅ |
| 토큰 무효화 | `RevokeToken` | ✅ (Refresh Token만) |
| MFA 설정 | `AdminSetUserMFAPreference` | ✅ |
| 사용자 삭제 | `AdminDeleteUser` | ✅ |

**근거 문서:**
- [Amazon Cognito API Reference](https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/Welcome.html)
  - Admin* API 시리즈 참조

---

### Q15. "일반 사용자"와 "운영 어드민 사용자" 구분을 어떤 방식으로 관리하는 것이 권장되나요?

**질문 상세:**
- attribute / group / custom claim 중 어떤 방식이 일반적이며 권장 패턴

**답변:**

**권장 패턴: Cognito Group 사용**

```
admin-group, user-group 생성
→ Group 정보가 ID Token의 cognito:groups 클레임에 포함
→ 애플리케이션에서 토큰의 groups 클레임으로 권한 분기
```

**대안:**

| 방식 | 적합 상황 |
|-----|---------|
| Custom Attribute (`custom:role`) | 단순 역할 구분 |
| Custom Claim (Pre Token Generation Lambda) | 복잡한 권한 로직 |

**근거 문서:**
- [Adding groups to a user pool](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-user-groups.html)
  - "You can add groups to a user pool... The ID token contains the cognito:groups claim with all the groups a user belongs to"

---

### Q16. 사용자 역할(Role)이나 서비스 접근 권한(RBAC)을 Cognito 자체 기능으로 관리하는 것이 가능한가요?

**질문 상세:**
- Cognito는 인증(Authentication)까지만 담당하고 역할/권한은 애플리케이션 또는 별도 권한 DB에서 관리하는 구조가 권장되는지

**답변:**

**권장 구조:**
- **Cognito**: 인증(Authentication) + 기본 역할 구분 (Group)
- **애플리케이션/별도 DB**: 세부 권한(Authorization) 관리

**이유:**
- Cognito Group은 단순 그룹핑에 적합
- 복잡한 RBAC (리소스별 권한, 계층적 역할)은 애플리케이션 레벨 권장
- **Amazon Verified Permissions** 연동으로 세밀한 권한 관리 가능

**참고:** 알라딘 사례 - 인증은 Cognito / RBAC은 Keycloak 사용

**근거 문서:**
- [Using groups to control access with Amazon Cognito](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-user-groups.html)
- [Amazon Verified Permissions](https://docs.aws.amazon.com/verifiedpermissions/latest/userguide/what-is-avp.html)

---

### Q17. 외부 사용자의 경우 SNS 로그인으로 Cognito 계정은 생성되지만, 서비스 상태는 '승인대기(PENDING)'로 관리하려는 구조가 가능한가요?

**질문 상세:**
- 운영 어드민 승인 전까지는 로그인은 가능하되 실제 서비스 접근은 제한
- 승인 이후에만 서비스 접근 권한 부여
- Cognito와 애플리케이션의 책임 경계

**답변:**

**아키텍처적으로 문제없습니다.**

**권장 구조:**
```
Cognito: 인증 담당 (계정 생성/로그인 허용)
애플리케이션 DB: 서비스 상태 관리 (PENDING/APPROVED)
```

**책임 경계:**

| 담당 | 역할 |
|-----|-----|
| **Cognito** | 사용자 인증, 토큰 발급 |
| **애플리케이션** | 토큰의 사용자 상태 확인 후 서비스 접근 제어 |

**구현 방식:**
1. `custom:approval_status` Attribute 사용
2. 별도 DB에서 승인 상태 관리 (권장)

**근거 문서:**
- [Customizing user pool workflows with Lambda triggers](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-identity-pools-working-with-aws-lambda-triggers.html)
- [Pre token generation Lambda trigger](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-pre-token-generation.html)

---

## API 연동 & 외부 시스템 연계

### Q18. 사용자 로그인/로그아웃/비활성화/속성 변경 등에 대한 감사 로그(Audit Log)는 Cognito에서 어디까지 제공되나요?

**질문 상세:**
- 운영 관점에서 일반적으로 어떤 방식으로 보완 구현하는지

**답변:**

**Cognito 기본 제공:**
- **AWS CloudTrail**: 모든 Cognito API 호출 로깅
- 로그인/로그아웃/속성 변경 등 기록

**보완 구현 방식:**
```
CloudTrail → CloudWatch Logs → CloudWatch Logs Insights (분석/알림)
Lambda Trigger → 커스텀 로깅 (DynamoDB, S3, OpenSearch 등)
```

**일반적 보완:**
- Pre/Post Authentication Lambda에서 상세 로그 기록
- 사용자 행동 분석을 위한 별도 로깅 시스템 구축

**근거 문서:**
- [Logging Amazon Cognito API calls with AWS CloudTrail](https://docs.aws.amazon.com/cognito/latest/developerguide/logging-using-cloudtrail.html)
  - "Amazon Cognito is integrated with AWS CloudTrail... CloudTrail captures all API calls for Amazon Cognito"

---

## 문서 링크 요약

| 주제 | AWS 공식 문서 |
|-----|-------------|
| User Pool 연합 인증 | https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-identity-federation.html |
| App Client 설정 | https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-app-idp-settings.html |
| OAuth 2.0 Grants | https://docs.aws.amazon.com/cognito/latest/developerguide/federation-endpoints-oauth-grants.html |
| User Pool Attributes | https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-settings-attributes.html |
| Lambda Triggers | https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-identity-pools-working-with-aws-lambda-triggers.html |
| Post Confirmation Trigger | https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-post-confirmation.html |
| Hosted UI 커스터마이징 | https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-app-ui-customization.html |
| Social IdP 연동 | https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-social-idp.html |
| OIDC IdP 연동 | https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-oidc-idp.html |
| Attribute Mapping | https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-specifying-attribute-mapping.html |
| User Groups | https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-user-groups.html |
| Token Revocation | https://docs.aws.amazon.com/cognito/latest/developerguide/token-revocation.html |
| CloudTrail 로깅 | https://docs.aws.amazon.com/cognito/latest/developerguide/logging-using-cloudtrail.html |
| Amazon Verified Permissions | https://docs.aws.amazon.com/verifiedpermissions/latest/userguide/what-is-avp.html |
| Cognito API Reference | https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/Welcome.html |
