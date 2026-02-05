#!/bin/bash
# ===========================================
# Step 8: Google 소셜 로그인 연동
# ===========================================
# 관련 Q&A: Q9 (소셜 로그인 Provider), Q10 (소셜 로그인 후 추가 정보)
#
# 사전 작업 (Google Cloud Console):
# 1. https://console.cloud.google.com/ 접속
# 2. APIs & Services > Credentials > CREATE CREDENTIALS > OAuth client ID
# 3. Application type: Web application
# 4. Authorized redirect URIs에 추가:
#    https://{COGNITO_DOMAIN}.auth.{REGION}.amazoncognito.com/oauth2/idpresponse
# 5. Client ID와 Client Secret을 config.env에 설정
#
# 이 스크립트가 하는 일:
# - Google Identity Provider를 Cognito User Pool에 등록
# - Attribute Mapping 설정 (email, name, picture)
# - App Client에 Google을 Supported Identity Provider로 추가
#
# 참고 문서:
# - https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-social-idp.html
# - https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-specifying-attribute-mapping.html
# ===========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.env"

echo "=========================================="
echo "Step 8: Google 소셜 로그인 연동"
echo "=========================================="

# Google 자격 증명 확인
if [ -z "${GOOGLE_CLIENT_ID}" ] || [ "${GOOGLE_CLIENT_ID}" == "your-google-client-id.apps.googleusercontent.com" ]; then
  echo ""
  echo "❌ Error: GOOGLE_CLIENT_ID가 설정되지 않았습니다."
  echo ""
  echo "사전 작업이 필요합니다:"
  echo ""
  echo "1. Google Cloud Console (https://console.cloud.google.com/) 접속"
  echo "2. APIs & Services > Credentials > CREATE CREDENTIALS > OAuth client ID"
  echo "3. Application type: Web application"
  echo "4. Authorized redirect URIs에 추가:"
  echo "   https://${COGNITO_DOMAIN}.auth.${AWS_REGION}.amazoncognito.com/oauth2/idpresponse"
  echo ""
  echo "5. 생성된 Client ID와 Client Secret을 config.env에 설정:"
  echo "   GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com"
  echo "   GOOGLE_CLIENT_SECRET=xxx"
  echo ""
  exit 1
fi

# ---------------------------------------------
# Google Identity Provider 생성
# ---------------------------------------------
echo ""
echo "1. Creating Google Identity Provider..."

aws cognito-idp create-identity-provider \
  --user-pool-id "${USER_POOL_ID}" \
  --provider-name "Google" \
  --provider-type "Google" \
  --provider-details "{
    \"client_id\": \"${GOOGLE_CLIENT_ID}\",
    \"client_secret\": \"${GOOGLE_CLIENT_SECRET}\",
    \"authorize_scopes\": \"openid email profile\"
  }" \
  --attribute-mapping '{
    "email": "email",
    "name": "name",
    "picture": "picture",
    "username": "sub"
  }' \
  --region "${AWS_REGION}"

echo "   ✅ Google Identity Provider 생성 완료"

# ---------------------------------------------
# App Client에 Google IdP 추가
# ---------------------------------------------
echo ""
echo "2. Adding Google to App Clients..."

# Callback URLs를 JSON 배열로 변환
WEB_CALLBACK_JSON=$(echo "${WEB_CALLBACK_URLS}" | tr ',' '\n' | jq -R . | jq -s .)
WEB_LOGOUT_JSON=$(echo "${WEB_LOGOUT_URLS}" | tr ',' '\n' | jq -R . | jq -s .)
MOBILE_CALLBACK_JSON=$(echo "${MOBILE_CALLBACK_URLS}" | tr ',' '\n' | jq -R . | jq -s .)
MOBILE_LOGOUT_JSON=$(echo "${MOBILE_LOGOUT_URLS}" | tr ',' '\n' | jq -R . | jq -s .)

# Web App Client 업데이트
aws cognito-idp update-user-pool-client \
  --user-pool-id "${USER_POOL_ID}" \
  --client-id "${WEB_CLIENT_ID}" \
  --supported-identity-providers "COGNITO" "Google" \
  --callback-urls "${WEB_CALLBACK_JSON}" \
  --logout-urls "${WEB_LOGOUT_JSON}" \
  --allowed-o-auth-flows "code" \
  --allowed-o-auth-scopes "openid" "email" "profile" \
  --allowed-o-auth-flows-user-pool-client \
  --region "${AWS_REGION}"

echo "   ✅ Web App Client에 Google 추가 완료"

# Mobile App Client 업데이트
aws cognito-idp update-user-pool-client \
  --user-pool-id "${USER_POOL_ID}" \
  --client-id "${MOBILE_CLIENT_ID}" \
  --supported-identity-providers "COGNITO" "Google" \
  --callback-urls "${MOBILE_CALLBACK_JSON}" \
  --logout-urls "${MOBILE_LOGOUT_JSON}" \
  --allowed-o-auth-flows "code" \
  --allowed-o-auth-scopes "openid" "email" "profile" \
  --allowed-o-auth-flows-user-pool-client \
  --region "${AWS_REGION}"

echo "   ✅ Mobile App Client에 Google 추가 완료"

echo ""
echo "=========================================="
echo "✅ Google 소셜 로그인 연동 완료!"
echo "=========================================="
echo ""
echo "Google 로그인 테스트 URL:"
echo ""
echo "https://${COGNITO_DOMAIN}.auth.${AWS_REGION}.amazoncognito.com/oauth2/authorize?\\"
echo "  identity_provider=Google&\\"
echo "  client_id=${WEB_CLIENT_ID}&\\"
echo "  response_type=code&\\"
echo "  scope=openid+email+profile&\\"
echo "  redirect_uri=http://localhost:3000/callback"
echo ""
echo "자체 UI에서 Google 로그인 버튼 구현:"
echo ""
echo "  // JavaScript"
echo "  const googleLoginUrl = \`https://${COGNITO_DOMAIN}.auth.${AWS_REGION}.amazoncognito.com/oauth2/authorize?\` +"
echo "    \`identity_provider=Google&\` +"
echo "    \`client_id=\${CLIENT_ID}&\` +"
echo "    \`response_type=code&\` +"
echo "    \`scope=openid+email+profile&\` +"
echo "    \`redirect_uri=\${encodeURIComponent(window.location.origin + '/callback')}\`;"
echo ""
echo "Amplify 사용 시:"
echo "  import { signInWithRedirect } from 'aws-amplify/auth';"
echo "  await signInWithRedirect({ provider: 'Google' });"
