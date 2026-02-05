"""
Cognito Pre Token Generation Lambda Trigger
- ID Token에 커스텀 클레임 추가
- 승인 상태(approval_status), 사용자 유형(user_type) 등을 토큰에 포함
"""

import json
import logging

# 로깅 설정
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    """
    Pre Token Generation Lambda Trigger Handler

    Event Structure:
    {
        "version": "1",
        "triggerSource": "TokenGeneration_*",
        "region": "ap-northeast-2",
        "userPoolId": "ap-northeast-2_xxx",
        "userName": "user-sub-id",
        "callerContext": {...},
        "request": {
            "userAttributes": {...},
            "groupConfiguration": {
                "groupsToOverride": ["group1", "group2"],
                "iamRolesToOverride": [],
                "preferredRole": null
            }
        },
        "response": {
            "claimsOverrideDetails": null
        }
    }
    """
    logger.info(f"Event received: {json.dumps(event)}")

    user_attributes = event['request']['userAttributes']

    # 커스텀 클레임 추가
    claims_to_add = {}

    # 승인 상태
    approval_status = user_attributes.get('custom:approval_status', 'pending')
    claims_to_add['approval_status'] = approval_status

    # 사용자 유형
    user_type = user_attributes.get('custom:user_type', 'unknown')
    claims_to_add['user_type'] = user_type

    # 파트너사 여부
    is_agency = user_attributes.get('custom:is_agency', 'false')
    claims_to_add['is_agency'] = is_agency

    # 회사명
    company_name = user_attributes.get('custom:company_name', '')
    if company_name:
        claims_to_add['company_name'] = company_name

    # 사번
    employee_id = user_attributes.get('custom:employee_id', '')
    if employee_id:
        claims_to_add['employee_id'] = employee_id

    # 서비스 접근 가능 여부 (승인된 사용자만)
    claims_to_add['service_access_allowed'] = 'true' if approval_status == 'approved' else 'false'

    # 응답에 클레임 추가
    event['response']['claimsOverrideDetails'] = {
        'claimsToAddOrOverride': claims_to_add
    }

    logger.info(f"Claims added: {claims_to_add}")

    return event
