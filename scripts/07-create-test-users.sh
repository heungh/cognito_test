#!/bin/bash
# ===========================================
# Step 7: 테스트 사용자 생성
# ===========================================
# 관련 Q&A: Q4 (추가 회원 정보 저장), Q14 (관리자 기능)
#
# 이 스크립트가 하는 일:
# - 4명의 테스트 사용자 생성
#   1) 내부 직원
#   2) 관리자
#   3) 외부 고객 (승인 완료)
#   4) 외부 파트너 (승인 대기)
# - 각 사용자를 적절한 그룹에 할당
#
# Admin API 사용:
# - AdminCreateUser: 사용자 생성
# - AdminAddUserToGroup: 그룹에 사용자 추가
#
# 참고 문서:
# - https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_AdminCreateUser.html
# - https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_AdminAddUserToGroup.html
# ===========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.env"

# 필수 변수 확인
if [ -z "${USER_POOL_ID}" ]; then
  echo "❌ Error: USER_POOL_ID가 설정되지 않았습니다."
  exit 1
fi

echo "=========================================="
echo "Step 7: 테스트 사용자 생성"
echo "=========================================="

# ---------------------------------------------
# 사용자 1: 내부 직원
# ---------------------------------------------
echo ""
echo "1. Creating internal user (${TEST_INTERNAL_USER_EMAIL})..."

aws cognito-idp admin-create-user \
  --user-pool-id "${USER_POOL_ID}" \
  --username "${TEST_INTERNAL_USER_EMAIL}" \
  --user-attributes \
    Name=email,Value="${TEST_INTERNAL_USER_EMAIL}" \
    Name=email_verified,Value=true \
    Name=name,Value="${TEST_INTERNAL_USER_NAME}" \
    Name=custom:user_type,Value="internal" \
    Name=custom:employee_id,Value="EMP001" \
    Name=custom:approval_status,Value="approved" \
  --temporary-password "${TEST_USER_TEMP_PASSWORD}" \
  --message-action SUPPRESS \
  --region "${AWS_REGION}"

aws cognito-idp admin-add-user-to-group \
  --user-pool-id "${USER_POOL_ID}" \
  --username "${TEST_INTERNAL_USER_EMAIL}" \
  --group-name "internal-users" \
  --region "${AWS_REGION}"

echo "   ✅ 내부 직원 생성 완료 → internal-users 그룹"

# ---------------------------------------------
# 사용자 2: 관리자
# ---------------------------------------------
echo ""
echo "2. Creating admin user (${TEST_ADMIN_EMAIL})..."

aws cognito-idp admin-create-user \
  --user-pool-id "${USER_POOL_ID}" \
  --username "${TEST_ADMIN_EMAIL}" \
  --user-attributes \
    Name=email,Value="${TEST_ADMIN_EMAIL}" \
    Name=email_verified,Value=true \
    Name=name,Value="${TEST_ADMIN_NAME}" \
    Name=custom:user_type,Value="internal" \
    Name=custom:employee_id,Value="ADM001" \
    Name=custom:approval_status,Value="approved" \
  --temporary-password "${TEST_USER_TEMP_PASSWORD}" \
  --message-action SUPPRESS \
  --region "${AWS_REGION}"

aws cognito-idp admin-add-user-to-group \
  --user-pool-id "${USER_POOL_ID}" \
  --username "${TEST_ADMIN_EMAIL}" \
  --group-name "admin-group" \
  --region "${AWS_REGION}"

aws cognito-idp admin-add-user-to-group \
  --user-pool-id "${USER_POOL_ID}" \
  --username "${TEST_ADMIN_EMAIL}" \
  --group-name "internal-users" \
  --region "${AWS_REGION}"

echo "   ✅ 관리자 생성 완료 → admin-group, internal-users 그룹"

# ---------------------------------------------
# 사용자 3: 외부 고객 (승인 완료)
# ---------------------------------------------
echo ""
echo "3. Creating external customer (${TEST_EXTERNAL_ADVERTISER_EMAIL})..."

aws cognito-idp admin-create-user \
  --user-pool-id "${USER_POOL_ID}" \
  --username "${TEST_EXTERNAL_ADVERTISER_EMAIL}" \
  --user-attributes \
    Name=email,Value="${TEST_EXTERNAL_ADVERTISER_EMAIL}" \
    Name=email_verified,Value=true \
    Name=name,Value="${TEST_EXTERNAL_ADVERTISER_NAME}" \
    Name=custom:user_type,Value="external" \
    Name=custom:company_name,Value="${TEST_EXTERNAL_ADVERTISER_COMPANY}" \
    Name=custom:is_agency,Value="false" \
    Name=custom:approval_status,Value="approved" \
  --temporary-password "${TEST_USER_TEMP_PASSWORD}" \
  --message-action SUPPRESS \
  --region "${AWS_REGION}"

aws cognito-idp admin-add-user-to-group \
  --user-pool-id "${USER_POOL_ID}" \
  --username "${TEST_EXTERNAL_ADVERTISER_EMAIL}" \
  --group-name "external-users" \
  --region "${AWS_REGION}"

echo "   ✅ 외부 고객 생성 완료 → external-users 그룹"

# ---------------------------------------------
# 사용자 4: 외부 파트너 (승인 대기)
# ---------------------------------------------
echo ""
echo "4. Creating external partner - pending approval (${TEST_EXTERNAL_AGENCY_EMAIL})..."

aws cognito-idp admin-create-user \
  --user-pool-id "${USER_POOL_ID}" \
  --username "${TEST_EXTERNAL_AGENCY_EMAIL}" \
  --user-attributes \
    Name=email,Value="${TEST_EXTERNAL_AGENCY_EMAIL}" \
    Name=email_verified,Value=true \
    Name=name,Value="${TEST_EXTERNAL_AGENCY_NAME}" \
    Name=custom:user_type,Value="external" \
    Name=custom:company_name,Value="${TEST_EXTERNAL_AGENCY_COMPANY}" \
    Name=custom:is_agency,Value="true" \
    Name=custom:approval_status,Value="pending" \
  --temporary-password "${TEST_USER_TEMP_PASSWORD}" \
  --message-action SUPPRESS \
  --region "${AWS_REGION}"

aws cognito-idp admin-add-user-to-group \
  --user-pool-id "${USER_POOL_ID}" \
  --username "${TEST_EXTERNAL_AGENCY_EMAIL}" \
  --group-name "pending-approval" \
  --region "${AWS_REGION}"

echo "   ✅ 외부 파트너 생성 완료 → pending-approval 그룹"

echo ""
echo "=========================================="
echo "✅ 테스트 사용자 생성 완료!"
echo "=========================================="
echo ""
echo "| Email                              | 이름                          | 유형     | 그룹                         |"
echo "|------------------------------------|-------------------------------|----------|------------------------------|"
echo "| ${TEST_INTERNAL_USER_EMAIL}        | ${TEST_INTERNAL_USER_NAME}    | internal | internal-users               |"
echo "| ${TEST_ADMIN_EMAIL}                | ${TEST_ADMIN_NAME}            | internal | admin-group, internal-users  |"
echo "| ${TEST_EXTERNAL_ADVERTISER_EMAIL}  | ${TEST_EXTERNAL_ADVERTISER_NAME} | external | external-users            |"
echo "| ${TEST_EXTERNAL_AGENCY_EMAIL}      | ${TEST_EXTERNAL_AGENCY_NAME}  | external | pending-approval             |"
echo ""
echo "임시 비밀번호: ${TEST_USER_TEMP_PASSWORD}"
echo "Note: 첫 로그인 시 비밀번호 변경이 필요합니다 (FORCE_CHANGE_PASSWORD 상태)"
echo ""
echo "다음 단계: ./08-setup-google-idp.sh (선택사항)"
