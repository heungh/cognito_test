#!/bin/bash
# ===========================================
# 리소스 정리 스크립트
# ===========================================
# 생성된 모든 Cognito 리소스를 삭제합니다.
#
# 삭제 순서:
# 1. Lambda Triggers 연결 해제
# 2. Lambda 함수 삭제
# 3. IAM 역할/정책 삭제
# 4. User Pool Domain 삭제
# 5. User Pool 삭제 (App Clients, Groups, Users 포함)
#
# 주의: 이 작업은 되돌릴 수 없습니다!
# ===========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.env"

echo "=========================================="
echo "Amazon Cognito 리소스 정리"
echo "=========================================="
echo ""
echo "⚠️  주의: 다음 리소스가 삭제됩니다:"
echo "  - User Pool: ${USER_POOL_ID:-'(not set)'}"
echo "  - Domain: ${COGNITO_DOMAIN:-'(not set)'}"
echo "  - Lambda Functions: ${LAMBDA_PREFIX}-PostConfirmation, ${LAMBDA_PREFIX}-PreTokenGeneration"
echo "  - IAM Role: ${LAMBDA_ROLE_NAME}"
echo ""
echo "⚠️  이 작업은 되돌릴 수 없습니다!"
echo ""
read -p "정말로 삭제하시겠습니까? (yes를 입력하세요) " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "취소되었습니다."
  exit 0
fi

echo ""
echo "리소스 삭제를 시작합니다..."

# ---------------------------------------------
# 1. Lambda Triggers 연결 해제
# ---------------------------------------------
echo ""
echo "1. Removing Lambda Triggers from User Pool..."

if [ -n "${USER_POOL_ID}" ]; then
  aws cognito-idp update-user-pool \
    --user-pool-id "${USER_POOL_ID}" \
    --lambda-config '{}' \
    --region "${AWS_REGION}" 2>/dev/null || echo "   (Skipped - User Pool may not exist)"
fi

echo "   ✅ Lambda Triggers 연결 해제 완료"

# ---------------------------------------------
# 2. Lambda 함수 삭제
# ---------------------------------------------
echo ""
echo "2. Deleting Lambda Functions..."

aws lambda delete-function \
  --function-name "${LAMBDA_PREFIX}-PostConfirmation" \
  --region "${AWS_REGION}" 2>/dev/null || echo "   (${LAMBDA_PREFIX}-PostConfirmation not found)"

aws lambda delete-function \
  --function-name "${LAMBDA_PREFIX}-PreTokenGeneration" \
  --region "${AWS_REGION}" 2>/dev/null || echo "   (${LAMBDA_PREFIX}-PreTokenGeneration not found)"

echo "   ✅ Lambda Functions 삭제 완료"

# ---------------------------------------------
# 3. IAM 역할/정책 삭제
# ---------------------------------------------
echo ""
echo "3. Deleting IAM Role and Policy..."

aws iam delete-role-policy \
  --role-name "${LAMBDA_ROLE_NAME}" \
  --policy-name "${LAMBDA_ROLE_NAME}-Policy" 2>/dev/null || echo "   (Policy not found)"

aws iam delete-role \
  --role-name "${LAMBDA_ROLE_NAME}" 2>/dev/null || echo "   (Role not found)"

echo "   ✅ IAM Role 삭제 완료"

# ---------------------------------------------
# 4. User Pool Domain 삭제
# ---------------------------------------------
echo ""
echo "4. Deleting User Pool Domain..."

if [ -n "${COGNITO_DOMAIN}" ] && [ -n "${USER_POOL_ID}" ]; then
  aws cognito-idp delete-user-pool-domain \
    --domain "${COGNITO_DOMAIN}" \
    --user-pool-id "${USER_POOL_ID}" \
    --region "${AWS_REGION}" 2>/dev/null || echo "   (Domain not found)"
fi

echo "   ✅ Domain 삭제 완료"

# ---------------------------------------------
# 5. User Pool 삭제
# ---------------------------------------------
echo ""
echo "5. Deleting User Pool..."

if [ -n "${USER_POOL_ID}" ]; then
  aws cognito-idp delete-user-pool \
    --user-pool-id "${USER_POOL_ID}" \
    --region "${AWS_REGION}" 2>/dev/null || echo "   (User Pool not found)"
fi

echo "   ✅ User Pool 삭제 완료"

# ---------------------------------------------
# config.env에서 생성된 리소스 ID 제거
# ---------------------------------------------
echo ""
echo "6. Cleaning up config.env..."

# 생성된 리소스 ID 라인 제거 (macOS/Linux 호환)
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' '/^# ===.*생성된 리소스/d' "${SCRIPT_DIR}/config.env" 2>/dev/null || true
  sed -i '' '/^USER_POOL_ID=/d' "${SCRIPT_DIR}/config.env" 2>/dev/null || true
  sed -i '' '/^USER_POOL_ARN=/d' "${SCRIPT_DIR}/config.env" 2>/dev/null || true
  sed -i '' '/^COGNITO_DOMAIN=/d' "${SCRIPT_DIR}/config.env" 2>/dev/null || true
  sed -i '' '/^WEB_CLIENT_ID=/d' "${SCRIPT_DIR}/config.env" 2>/dev/null || true
  sed -i '' '/^WEB_CLIENT_SECRET=/d' "${SCRIPT_DIR}/config.env" 2>/dev/null || true
  sed -i '' '/^MOBILE_CLIENT_ID=/d' "${SCRIPT_DIR}/config.env" 2>/dev/null || true
  sed -i '' '/^SERVER_CLIENT_ID=/d' "${SCRIPT_DIR}/config.env" 2>/dev/null || true
  sed -i '' '/^SERVER_CLIENT_SECRET=/d' "${SCRIPT_DIR}/config.env" 2>/dev/null || true
else
  sed -i '/^# ===.*생성된 리소스/d' "${SCRIPT_DIR}/config.env" 2>/dev/null || true
  sed -i '/^USER_POOL_ID=/d' "${SCRIPT_DIR}/config.env" 2>/dev/null || true
  sed -i '/^USER_POOL_ARN=/d' "${SCRIPT_DIR}/config.env" 2>/dev/null || true
  sed -i '/^COGNITO_DOMAIN=/d' "${SCRIPT_DIR}/config.env" 2>/dev/null || true
  sed -i '/^WEB_CLIENT_ID=/d' "${SCRIPT_DIR}/config.env" 2>/dev/null || true
  sed -i '/^WEB_CLIENT_SECRET=/d' "${SCRIPT_DIR}/config.env" 2>/dev/null || true
  sed -i '/^MOBILE_CLIENT_ID=/d' "${SCRIPT_DIR}/config.env" 2>/dev/null || true
  sed -i '/^SERVER_CLIENT_ID=/d' "${SCRIPT_DIR}/config.env" 2>/dev/null || true
  sed -i '/^SERVER_CLIENT_SECRET=/d' "${SCRIPT_DIR}/config.env" 2>/dev/null || true
fi

echo "   ✅ config.env 정리 완료"

echo ""
echo "=========================================="
echo "🗑️  리소스 정리 완료!"
echo "=========================================="
echo ""
echo "다시 프로비저닝하려면: ./provision-all.sh"
