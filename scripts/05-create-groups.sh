#!/bin/bash
# ===========================================
# Step 5: Cognito Groups 생성
# ===========================================
# 관련 Q&A: Q5 (내부 사용자 판별), Q15 (역할 구분), Q17 (승인 대기)
#
# 이 스크립트가 하는 일:
# - 4개의 사용자 그룹 생성
#   1) admin-group: 운영 관리자
#   2) internal-users: 내부 직원
#   3) external-users: 외부 사용자 (외부 고객/파트너)
#   4) pending-approval: 승인 대기 사용자
#
# Precedence 설명:
# - 숫자가 낮을수록 우선순위가 높음
# - 여러 그룹에 속한 경우 가장 낮은 precedence의 그룹 IAM 역할이 적용됨
#
# 토큰에 포함되는 정보:
# - ID Token의 'cognito:groups' 클레임에 사용자가 속한 그룹 목록 포함
#
# 참고 문서:
# - https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-user-groups.html
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
echo "Step 5: Cognito Groups 생성"
echo "=========================================="

# ---------------------------------------------
# Group 1: admin-group (운영 관리자)
# ---------------------------------------------
echo ""
echo "1. Creating admin-group..."

aws cognito-idp create-group \
  --group-name "admin-group" \
  --user-pool-id "${USER_POOL_ID}" \
  --description "운영 관리자" \
  --precedence 1 \
  --region "${AWS_REGION}"

echo "   ✅ admin-group 생성 완료 (Precedence: 1)"

# ---------------------------------------------
# Group 2: internal-users (내부 직원)
# ---------------------------------------------
echo ""
echo "2. Creating internal-users..."

aws cognito-idp create-group \
  --group-name "internal-users" \
  --user-pool-id "${USER_POOL_ID}" \
  --description "내부 사용자 (사내 직원)" \
  --precedence 10 \
  --region "${AWS_REGION}"

echo "   ✅ internal-users 생성 완료 (Precedence: 10)"

# ---------------------------------------------
# Group 3: external-users (외부 사용자)
# ---------------------------------------------
echo ""
echo "3. Creating external-users..."

aws cognito-idp create-group \
  --group-name "external-users" \
  --user-pool-id "${USER_POOL_ID}" \
  --description "외부 사용자 (외부 고객/파트너)" \
  --precedence 20 \
  --region "${AWS_REGION}"

echo "   ✅ external-users 생성 완료 (Precedence: 20)"

# ---------------------------------------------
# Group 4: pending-approval (승인 대기)
# ---------------------------------------------
echo ""
echo "4. Creating pending-approval..."

aws cognito-idp create-group \
  --group-name "pending-approval" \
  --user-pool-id "${USER_POOL_ID}" \
  --description "승인 대기 사용자" \
  --precedence 30 \
  --region "${AWS_REGION}"

echo "   ✅ pending-approval 생성 완료 (Precedence: 30)"

echo ""
echo "=========================================="
echo "✅ Cognito Groups 생성 완료!"
echo "=========================================="
echo ""
echo "| Group Name       | Precedence | 용도                    |"
echo "|------------------|------------|-------------------------|"
echo "| admin-group      | 1          | 운영 관리자             |"
echo "| internal-users   | 10         | 내부 직원               |"
echo "| external-users   | 20         | 외부 외부 고객/파트너      |"
echo "| pending-approval | 30         | 승인 대기               |"
echo ""
echo "ID Token 예시 (cognito:groups 클레임):"
echo '  {"cognito:groups": ["admin-group", "internal-users"]}'
echo ""
echo "다음 단계: ./06-setup-lambda-triggers.sh"
