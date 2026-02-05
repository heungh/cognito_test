#!/bin/bash
# ===========================================
# Step 3: App Client 생성
# ===========================================
# 관련 Q&A: Q2 (인증 플로우), Q11 (멀티 서비스 SSO)
#
# 이 스크립트가 하는 일:
# - 2개의 App Client 생성
#   1) Web App Client: Authorization Code Flow (웹 앱용, Confidential Client)
#   2) Mobile App Client: Authorization Code + PKCE (모바일/SPA용, Public Client)
#
# OAuth Flow 설명:
# - Authorization Code: 가장 안전한 방식, 서버 사이드 앱에서 사용
# - Authorization Code + PKCE: Public Client에서 사용 (모바일, SPA)
#
# 참고 문서:
# - https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-settings-client-apps.html
# - https://docs.aws.amazon.com/cognito/latest/developerguide/federation-endpoints-oauth-grants.html
# ===========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.env"

# 필수 변수 확인
if [ -z "${USER_POOL_ID}" ]; then
  echo "❌ Error: USER_POOL_ID가 설정되지 않았습니다."
  echo "   먼저 01-create-user-pool.sh를 실행하세요."
  exit 1
fi

echo "=========================================="
echo "Step 3: App Client 생성"
echo "=========================================="

# Callback URLs를 JSON 배열로 변환
WEB_CALLBACK_JSON=$(echo "${WEB_CALLBACK_URLS}" | tr ',' '\n' | jq -R . | jq -s .)
WEB_LOGOUT_JSON=$(echo "${WEB_LOGOUT_URLS}" | tr ',' '\n' | jq -R . | jq -s .)
MOBILE_CALLBACK_JSON=$(echo "${MOBILE_CALLBACK_URLS}" | tr ',' '\n' | jq -R . | jq -s .)
MOBILE_LOGOUT_JSON=$(echo "${MOBILE_LOGOUT_URLS}" | tr ',' '\n' | jq -R . | jq -s .)

# ---------------------------------------------
# App Client 1: 웹 앱용 (Authorization Code Flow)
# ---------------------------------------------
echo ""
echo "1. Creating Web App Client (Authorization Code Flow)..."

WEB_CLIENT_RESULT=$(aws cognito-idp create-user-pool-client \
  --user-pool-id "${USER_POOL_ID}" \
  --client-name "${USER_POOL_NAME}-WebApp" \
  --generate-secret \
  --explicit-auth-flows "ALLOW_REFRESH_TOKEN_AUTH" "ALLOW_USER_SRP_AUTH" \
  --supported-identity-providers "COGNITO" \
  --callback-urls "${WEB_CALLBACK_JSON}" \
  --logout-urls "${WEB_LOGOUT_JSON}" \
  --allowed-o-auth-flows "code" \
  --allowed-o-auth-scopes "openid" "email" "profile" \
  --allowed-o-auth-flows-user-pool-client \
  --access-token-validity 1 \
  --id-token-validity 1 \
  --refresh-token-validity 30 \
  --token-validity-units '{
    "AccessToken": "hours",
    "IdToken": "hours",
    "RefreshToken": "days"
  }' \
  --read-attributes '["email", "name", "custom:user_type", "custom:company_name", "custom:employee_id", "custom:approval_status", "custom:is_agency"]' \
  --write-attributes '["email", "name", "custom:user_type", "custom:company_name", "custom:employee_id", "custom:approval_status", "custom:is_agency"]' \
  --region "${AWS_REGION}")

WEB_CLIENT_ID=$(echo $WEB_CLIENT_RESULT | jq -r '.UserPoolClient.ClientId')
WEB_CLIENT_SECRET=$(echo $WEB_CLIENT_RESULT | jq -r '.UserPoolClient.ClientSecret')

echo "   ✅ Web App Client 생성 완료"
echo "      Client ID: ${WEB_CLIENT_ID}"

# ---------------------------------------------
# App Client 2: 모바일 앱용 (PKCE, No Secret)
# ---------------------------------------------
echo ""
echo "2. Creating Mobile App Client (Authorization Code + PKCE)..."

MOBILE_CLIENT_RESULT=$(aws cognito-idp create-user-pool-client \
  --user-pool-id "${USER_POOL_ID}" \
  --client-name "${USER_POOL_NAME}-MobileApp" \
  --no-generate-secret \
  --explicit-auth-flows "ALLOW_REFRESH_TOKEN_AUTH" "ALLOW_USER_SRP_AUTH" \
  --supported-identity-providers "COGNITO" \
  --callback-urls "${MOBILE_CALLBACK_JSON}" \
  --logout-urls "${MOBILE_LOGOUT_JSON}" \
  --allowed-o-auth-flows "code" \
  --allowed-o-auth-scopes "openid" "email" "profile" \
  --allowed-o-auth-flows-user-pool-client \
  --access-token-validity 1 \
  --id-token-validity 1 \
  --refresh-token-validity 30 \
  --token-validity-units '{
    "AccessToken": "hours",
    "IdToken": "hours",
    "RefreshToken": "days"
  }' \
  --read-attributes '["email", "name", "custom:user_type", "custom:company_name", "custom:employee_id", "custom:approval_status", "custom:is_agency"]' \
  --write-attributes '["email", "name", "custom:user_type", "custom:company_name", "custom:employee_id", "custom:approval_status", "custom:is_agency"]' \
  --region "${AWS_REGION}")

MOBILE_CLIENT_ID=$(echo $MOBILE_CLIENT_RESULT | jq -r '.UserPoolClient.ClientId')

echo "   ✅ Mobile App Client 생성 완료"
echo "      Client ID: ${MOBILE_CLIENT_ID}"
echo "      (Public Client - No Secret)"

# 환경 변수 파일에 저장
cat >> "${SCRIPT_DIR}/config.env" << EOF
WEB_CLIENT_ID=${WEB_CLIENT_ID}
WEB_CLIENT_SECRET=${WEB_CLIENT_SECRET}
MOBILE_CLIENT_ID=${MOBILE_CLIENT_ID}
EOF

echo ""
echo "=========================================="
echo "✅ App Client 생성 완료!"
echo "=========================================="
echo ""
echo "| Client Name          | Client ID                         | OAuth Flow              |"
echo "|----------------------|-----------------------------------|-------------------------|"
echo "| ${USER_POOL_NAME}-WebApp    | ${WEB_CLIENT_ID} | Authorization Code      |"
echo "| ${USER_POOL_NAME}-MobileApp | ${MOBILE_CLIENT_ID} | Auth Code + PKCE        |"
echo ""
echo "다음 단계: ./04-create-resource-server.sh"
