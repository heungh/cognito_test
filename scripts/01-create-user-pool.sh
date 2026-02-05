#!/bin/bash
# ===========================================
# Step 1: Cognito User Pool 생성
# ===========================================
# 관련 Q&A: Q1 (인증 프로토콜), Q3 (사용자 정보 구조)
#
# 이 스크립트가 하는 일:
# - Cognito User Pool 생성
# - Custom Attributes 5개 추가 (user_type, company_name, employee_id, approval_status, is_agency)
# - 비밀번호 정책 설정
# - 이메일 자동 인증 설정
# - 자가등록 허용 (Pre-Sign-Up Lambda로 도메인 검증 필수)
#
# 참고 문서:
# - https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pool-as-user-directory.html
# - https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-settings-attributes.html
# ===========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 설정 파일 확인
if [ ! -f "${SCRIPT_DIR}/config.env" ]; then
  echo "❌ Error: config.env 파일이 없습니다."
  echo "   cp config.env.example config.env 후 설정값을 수정하세요."
  exit 1
fi

source "${SCRIPT_DIR}/config.env"

# 필수 변수 확인
if [ -z "${AWS_REGION}" ] || [ -z "${USER_POOL_NAME}" ]; then
  echo "❌ Error: AWS_REGION 또는 USER_POOL_NAME이 설정되지 않았습니다."
  exit 1
fi

echo "=========================================="
echo "Step 1: Cognito User Pool 생성"
echo "=========================================="
echo "  User Pool Name: ${USER_POOL_NAME}"
echo "  Region: ${AWS_REGION}"
echo ""

# User Pool 생성
echo "Creating User Pool: ${USER_POOL_NAME}..."

USER_POOL_RESULT=$(aws cognito-idp create-user-pool \
  --pool-name "${USER_POOL_NAME}" \
  --policies '{
    "PasswordPolicy": {
      "MinimumLength": 8,
      "RequireUppercase": true,
      "RequireLowercase": true,
      "RequireNumbers": true,
      "RequireSymbols": false,
      "TemporaryPasswordValidityDays": 7
    }
  }' \
  --auto-verified-attributes email \
  --username-attributes email \
  --schema '[
    {
      "Name": "email",
      "Required": true,
      "Mutable": true
    },
    {
      "Name": "name",
      "Required": false,
      "Mutable": true
    },
    {
      "Name": "user_type",
      "AttributeDataType": "String",
      "Mutable": true,
      "Required": false,
      "StringAttributeConstraints": {
        "MinLength": "1",
        "MaxLength": "50"
      }
    },
    {
      "Name": "company_name",
      "AttributeDataType": "String",
      "Mutable": true,
      "Required": false,
      "StringAttributeConstraints": {
        "MinLength": "1",
        "MaxLength": "256"
      }
    },
    {
      "Name": "employee_id",
      "AttributeDataType": "String",
      "Mutable": true,
      "Required": false,
      "StringAttributeConstraints": {
        "MinLength": "1",
        "MaxLength": "50"
      }
    },
    {
      "Name": "approval_status",
      "AttributeDataType": "String",
      "Mutable": true,
      "Required": false,
      "StringAttributeConstraints": {
        "MinLength": "1",
        "MaxLength": "20"
      }
    },
    {
      "Name": "is_agency",
      "AttributeDataType": "String",
      "Mutable": true,
      "Required": false,
      "StringAttributeConstraints": {
        "MinLength": "1",
        "MaxLength": "10"
      }
    }
  ]' \
  --admin-create-user-config '{
    "AllowAdminCreateUserOnly": false,
    "InviteMessageTemplate": {
      "EmailSubject": "계정이 생성되었습니다",
      "EmailMessage": "안녕하세요, {username}님. 임시 비밀번호는 {####} 입니다. 첫 로그인 시 비밀번호를 변경해주세요."
    }
  }' \
  --account-recovery-setting '{
    "RecoveryMechanisms": [
      {
        "Priority": 1,
        "Name": "verified_email"
      }
    ]
  }' \
  --region "${AWS_REGION}")

USER_POOL_ID=$(echo $USER_POOL_RESULT | jq -r '.UserPool.Id')
USER_POOL_ARN=$(echo $USER_POOL_RESULT | jq -r '.UserPool.Arn')

echo ""
echo "✅ User Pool 생성 완료!"
echo "   User Pool ID: ${USER_POOL_ID}"
echo "   User Pool ARN: ${USER_POOL_ARN}"

# 환경 변수 파일에 저장
cat >> "${SCRIPT_DIR}/config.env" << EOF

# ===========================================
# 생성된 리소스 ID (자동 생성됨 - 수정하지 마세요)
# ===========================================
USER_POOL_ID=${USER_POOL_ID}
USER_POOL_ARN=${USER_POOL_ARN}
EOF

echo ""
echo "생성된 Custom Attributes:"
echo "  - custom:user_type      : 내부/외부 사용자 구분"
echo "  - custom:company_name   : 외부 고객/파트너 회사명"
echo "  - custom:employee_id    : 사번 (내부 사용자)"
echo "  - custom:approval_status: 승인 상태 (pending/approved)"
echo "  - custom:is_agency      : 파트너사 여부 (true/false)"
echo ""
echo "다음 단계: ./02-create-domain.sh"
