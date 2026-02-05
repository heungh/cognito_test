"""
Cognito Post Confirmation Lambda Trigger
- 사용자 확인 후 내부/외부 사용자 자동 판별
- 사내 이메일 도메인 또는 사번으로 내부 사용자 판별
- 자동으로 Group 할당

환경 변수:
- INTERNAL_EMAIL_DOMAINS: 내부 사용자 판별용 이메일 도메인 (콤마 구분)
- EMPLOYEE_ID_PREFIX: 내부 사용자 사번 접두사 (콤마 구분)
"""

import json
import boto3
import os
import logging

# 로깅 설정
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Cognito Identity Provider 클라이언트
cognito_client = boto3.client('cognito-idp')

# 내부 사용자 판별 기준 (환경 변수로 설정)
INTERNAL_EMAIL_DOMAINS = os.environ.get('INTERNAL_EMAIL_DOMAINS', 'your-company.co.kr').split(',')
EMPLOYEE_ID_PREFIX = os.environ.get('EMPLOYEE_ID_PREFIX', 'EMP,ADM')


def is_internal_user(user_attributes):
    """
    내부 사용자 여부 판별
    - 사내 이메일 도메인 확인
    - 사번(employee_id) 존재 여부 확인
    """
    email = user_attributes.get('email', '')
    employee_id = user_attributes.get('custom:employee_id', '')

    # 1. 사내 이메일 도메인 확인
    email_domain = email.split('@')[-1].lower() if '@' in email else ''
    if email_domain in [d.lower().strip() for d in INTERNAL_EMAIL_DOMAINS]:
        logger.info(f"Internal user detected by email domain: {email_domain}")
        return True

    # 2. 사번 존재 및 유효성 확인
    if employee_id:
        prefixes = [p.strip() for p in EMPLOYEE_ID_PREFIX.split(',')]
        for prefix in prefixes:
            if employee_id.upper().startswith(prefix.upper()):
                logger.info(f"Internal user detected by employee_id: {employee_id}")
                return True

    return False


def add_user_to_group(user_pool_id, username, group_name):
    """사용자를 그룹에 추가"""
    try:
        cognito_client.admin_add_user_to_group(
            UserPoolId=user_pool_id,
            Username=username,
            GroupName=group_name
        )
        logger.info(f"User {username} added to group {group_name}")
    except cognito_client.exceptions.ResourceNotFoundException:
        logger.error(f"Group {group_name} not found")
        raise
    except Exception as e:
        logger.error(f"Error adding user to group: {str(e)}")
        raise


def update_user_attributes(user_pool_id, username, attributes):
    """사용자 속성 업데이트"""
    try:
        cognito_client.admin_update_user_attributes(
            UserPoolId=user_pool_id,
            Username=username,
            UserAttributes=[
                {'Name': k, 'Value': v} for k, v in attributes.items()
            ]
        )
        logger.info(f"User {username} attributes updated: {attributes}")
    except Exception as e:
        logger.error(f"Error updating user attributes: {str(e)}")
        raise


def lambda_handler(event, context):
    """
    Post Confirmation Lambda Trigger Handler

    Event Structure:
    {
        "version": "1",
        "region": "ap-northeast-2",
        "userPoolId": "ap-northeast-2_xxx",
        "userName": "user-sub-id",
        "callerContext": {...},
        "triggerSource": "PostConfirmation_ConfirmSignUp",
        "request": {
            "userAttributes": {
                "sub": "xxx",
                "email": "user@example.com",
                "email_verified": "true",
                "custom:employee_id": "EMP001"
            }
        },
        "response": {}
    }
    """
    logger.info(f"Event received: {json.dumps(event)}")

    # 이벤트 정보 추출
    user_pool_id = event['userPoolId']
    username = event['userName']
    user_attributes = event['request']['userAttributes']
    trigger_source = event['triggerSource']

    # PostConfirmation_ConfirmSignUp 또는 PostConfirmation_ConfirmForgotPassword 처리
    if not trigger_source.startswith('PostConfirmation'):
        logger.info(f"Skipping trigger source: {trigger_source}")
        return event

    try:
        # 내부/외부 사용자 판별
        if is_internal_user(user_attributes):
            # 내부 사용자: internal-users 그룹 추가, 즉시 승인
            add_user_to_group(user_pool_id, username, 'internal-users')
            update_user_attributes(user_pool_id, username, {
                'custom:user_type': 'internal',
                'custom:approval_status': 'approved'
            })
            logger.info(f"Internal user {username} auto-approved")
        else:
            # 외부 사용자: pending-approval 그룹 추가, 승인 대기
            add_user_to_group(user_pool_id, username, 'pending-approval')
            update_user_attributes(user_pool_id, username, {
                'custom:user_type': 'external',
                'custom:approval_status': 'pending'
            })
            logger.info(f"External user {username} set to pending approval")

    except Exception as e:
        logger.error(f"Error processing user: {str(e)}")
        # 오류 발생 시에도 가입 자체는 완료시킴 (선택적)
        # raise를 사용하면 가입이 실패함

    return event
