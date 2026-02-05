"""
Cognito Pre Sign-Up Lambda Trigger
- 회원가입 시 이메일 도메인 검증
- 허용된 도메인만 가입 허용 (보안 강화)
- 무분별한 계정 생성 방지

환경 변수:
- ALLOWED_SIGNUP_DOMAINS: 가입 허용 이메일 도메인 (콤마 구분)
  예: "your-company.co.kr,partner-agency.com,advertiser.co.kr"

보안 주의사항:
- AllowAdminCreateUserOnly: false (자가등록 허용) 시 반드시 이 Lambda를 연결해야 합니다.
- 허용 도메인 목록을 비워두면 모든 도메인에서 가입이 가능해집니다.
"""

import json
import os
import logging

# 로깅 설정
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# 허용 이메일 도메인 (환경 변수로 설정)
ALLOWED_SIGNUP_DOMAINS = os.environ.get('ALLOWED_SIGNUP_DOMAINS', '').split(',')


def get_email_domain(email):
    """이메일에서 도메인 추출"""
    if '@' in email:
        return email.split('@')[-1].lower().strip()
    return ''


def is_domain_allowed(email):
    """
    이메일 도메인이 허용 목록에 있는지 확인

    허용 도메인 목록이 비어있거나 설정되지 않은 경우:
    - 보안 경고를 로깅하고 가입을 차단 (기본 동작)
    - 운영 환경에서는 반드시 ALLOWED_SIGNUP_DOMAINS를 설정해야 함
    """
    domain = get_email_domain(email)

    # 허용 도메인 목록 정규화
    allowed_domains = [d.lower().strip() for d in ALLOWED_SIGNUP_DOMAINS if d.strip()]

    # 허용 도메인 목록이 비어있는 경우 (보안 강화)
    if not allowed_domains:
        logger.warning("SECURITY WARNING: ALLOWED_SIGNUP_DOMAINS is not configured. Blocking all signups.")
        return False

    # 도메인 확인
    if domain in allowed_domains:
        logger.info(f"Domain '{domain}' is in allowed list")
        return True

    logger.info(f"Domain '{domain}' is NOT in allowed list: {allowed_domains}")
    return False


def lambda_handler(event, context):
    """
    Pre Sign-Up Lambda Trigger Handler

    Event Structure:
    {
        "version": "1",
        "region": "ap-northeast-2",
        "userPoolId": "ap-northeast-2_xxx",
        "userName": "user-sub-id",
        "callerContext": {
            "awsSdkVersion": "aws-sdk-unknown-unknown",
            "clientId": "xxx",
            "sourceIp": "1.2.3.4"  # 클라이언트 IP (참고용)
        },
        "triggerSource": "PreSignUp_SignUp",
        "request": {
            "userAttributes": {
                "email": "user@example.com"
            },
            "validationData": null
        },
        "response": {
            "autoConfirmUser": false,
            "autoVerifyEmail": false,
            "autoVerifyPhone": false
        }
    }

    Returns:
    - 허용: event 반환 (가입 진행)
    - 차단: Exception 발생 (가입 실패)
    """
    logger.info(f"Event received: {json.dumps(event)}")

    trigger_source = event.get('triggerSource', '')

    # PreSignUp 이벤트만 처리 (관리자 생성, 소셜 로그인 등은 건너뜀)
    # PreSignUp_SignUp: 일반 회원가입
    # PreSignUp_ExternalProvider: 소셜 로그인 (Google 등)
    # PreSignUp_AdminCreateUser: 관리자가 생성
    if trigger_source == 'PreSignUp_AdminCreateUser':
        logger.info("Admin created user - skipping domain validation")
        return event

    # 사용자 이메일 추출
    user_attributes = event['request']['userAttributes']
    email = user_attributes.get('email', '')

    if not email:
        logger.error("Email is required for signup")
        raise Exception("이메일 주소가 필요합니다.")

    # 클라이언트 IP 로깅 (모니터링/감사 목적)
    source_ip = event.get('callerContext', {}).get('sourceIp', 'unknown')
    logger.info(f"Signup attempt: email={email}, sourceIp={source_ip}")

    # 도메인 검증
    if not is_domain_allowed(email):
        domain = get_email_domain(email)
        logger.warning(f"Signup blocked: unauthorized domain '{domain}' from IP {source_ip}")
        raise Exception(f"허용되지 않은 이메일 도메인입니다: {domain}. 관리자에게 문의하세요.")

    # 소셜 로그인(ExternalProvider)의 경우 자동 확인 처리 (선택적)
    if trigger_source == 'PreSignUp_ExternalProvider':
        # 소셜 로그인 사용자는 이메일이 이미 검증됨
        event['response']['autoConfirmUser'] = True
        event['response']['autoVerifyEmail'] = True
        logger.info(f"External provider user auto-confirmed: {email}")

    logger.info(f"Signup allowed for email: {email}")
    return event
