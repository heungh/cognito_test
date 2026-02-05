#!/bin/bash
# ===========================================
# Step 2: Cognito Domain 생성
# ===========================================
# 관련 Q&A: Q7 (자체 UI + OIDC), Q8 (Hosted UI 커스터마이징)
#
# 이 스크립트가 하는 일:
# - Cognito Hosted UI용 도메인 생성
# - OAuth 2.0 엔드포인트 활성화
#
# 생성되는 엔드포인트:
# - Login UI: https://{domain}.auth.{region}.amazoncognito.com/login
# - Authorize: https://{domain}.auth.{region}.amazoncognito.com/oauth2/authorize
# - Token: https://{domain}.auth.{region}.amazoncognito.com/oauth2/token
# - Logout: https://{domain}.auth.{region}.amazoncognito.com/logout
#
# 참고 문서:
# - https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-assign-domain.html
# - https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-app-integration.html
# ===========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.env"

# 필수 변수 확인
if [ -z "${USER_POOL_ID}" ] || [ -z "${DOMAIN_PREFIX}" ]; then
  echo "❌ Error: USER_POOL_ID 또는 DOMAIN_PREFIX가 설정되지 않았습니다."
  echo "   먼저 01-create-user-pool.sh를 실행하세요."
  exit 1
fi

echo "=========================================="
echo "Step 2: Cognito Domain 생성"
echo "=========================================="

# 도메인 이름에 타임스탬프 추가 (고유성 보장)
TIMESTAMP=$(date +%s)
FULL_DOMAIN="${DOMAIN_PREFIX}-${TIMESTAMP}"

echo "  Domain: ${FULL_DOMAIN}"
echo "  User Pool ID: ${USER_POOL_ID}"
echo ""

echo "Creating Cognito Domain: ${FULL_DOMAIN}..."

aws cognito-idp create-user-pool-domain \
  --domain "${FULL_DOMAIN}" \
  --user-pool-id "${USER_POOL_ID}" \
  --region "${AWS_REGION}"

echo ""
echo "✅ Cognito Domain 생성 완료!"
echo "   Domain: ${FULL_DOMAIN}"
echo ""
echo "생성된 OAuth 엔드포인트:"
echo "  - Hosted UI:  https://${FULL_DOMAIN}.auth.${AWS_REGION}.amazoncognito.com/login"
echo "  - Authorize:  https://${FULL_DOMAIN}.auth.${AWS_REGION}.amazoncognito.com/oauth2/authorize"
echo "  - Token:      https://${FULL_DOMAIN}.auth.${AWS_REGION}.amazoncognito.com/oauth2/token"
echo "  - Logout:     https://${FULL_DOMAIN}.auth.${AWS_REGION}.amazoncognito.com/logout"
echo "  - IdP Response (소셜 로그인용): https://${FULL_DOMAIN}.auth.${AWS_REGION}.amazoncognito.com/oauth2/idpresponse"

# 환경 변수 파일에 저장
echo "COGNITO_DOMAIN=${FULL_DOMAIN}" >> "${SCRIPT_DIR}/config.env"

echo ""
echo "다음 단계: ./03-create-app-clients.sh"
