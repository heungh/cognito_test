#!/bin/bash
# ===========================================
# Step 4: Resource Server 및 M2M Client 생성
# ===========================================
# 관련 Q&A: Q2 (Client Credentials Flow)
#
# 이 스크립트가 하는 일:
# - Resource Server 생성 (Custom Scope 정의)
# - Client Credentials Flow용 App Client 생성 (서버 간 통신)
#
# Client Credentials Flow 설명:
# - 사용자 컨텍스트 없이 서버 간 통신에 사용
# - Resource Server의 Custom Scope 필요
# - openid scope 사용 불가
#
# 참고 문서:
# - https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-define-resource-servers.html
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
echo "Step 4: Resource Server 및 M2M Client 생성"
echo "=========================================="

# ---------------------------------------------
# Resource Server 생성
# ---------------------------------------------
echo ""
echo "1. Creating Resource Server..."

aws cognito-idp create-resource-server \
  --user-pool-id "${USER_POOL_ID}" \
  --identifier "${RESOURCE_SERVER_IDENTIFIER}" \
  --name "${USER_POOL_NAME} API Server" \
  --scopes '[
    {"ScopeName": "read", "ScopeDescription": "Read access to API"},
    {"ScopeName": "write", "ScopeDescription": "Write access to API"}
  ]' \
  --region "${AWS_REGION}"

echo "   ✅ Resource Server 생성 완료"
echo "      Identifier: ${RESOURCE_SERVER_IDENTIFIER}"
echo "      Scopes: ${RESOURCE_SERVER_IDENTIFIER}/read, ${RESOURCE_SERVER_IDENTIFIER}/write"

# ---------------------------------------------
# App Client 3: 서버 간 통신용 (Client Credentials)
# ---------------------------------------------
echo ""
echo "2. Creating Server-to-Server Client (Client Credentials Flow)..."

SERVER_CLIENT_RESULT=$(aws cognito-idp create-user-pool-client \
  --user-pool-id "${USER_POOL_ID}" \
  --client-name "${USER_POOL_NAME}-ServerToServer" \
  --generate-secret \
  --explicit-auth-flows "ALLOW_REFRESH_TOKEN_AUTH" \
  --allowed-o-auth-flows "client_credentials" \
  --allowed-o-auth-scopes "${RESOURCE_SERVER_IDENTIFIER}/read" "${RESOURCE_SERVER_IDENTIFIER}/write" \
  --allowed-o-auth-flows-user-pool-client \
  --region "${AWS_REGION}")

SERVER_CLIENT_ID=$(echo $SERVER_CLIENT_RESULT | jq -r '.UserPoolClient.ClientId')
SERVER_CLIENT_SECRET=$(echo $SERVER_CLIENT_RESULT | jq -r '.UserPoolClient.ClientSecret')

echo "   ✅ Server-to-Server Client 생성 완료"
echo "      Client ID: ${SERVER_CLIENT_ID}"

# 환경 변수 파일에 저장
cat >> "${SCRIPT_DIR}/config.env" << EOF
SERVER_CLIENT_ID=${SERVER_CLIENT_ID}
SERVER_CLIENT_SECRET=${SERVER_CLIENT_SECRET}
EOF

echo ""
echo "=========================================="
echo "✅ Resource Server 및 M2M Client 생성 완료!"
echo "=========================================="
echo ""
echo "Client Credentials Flow 테스트 방법:"
echo ""
echo "curl -X POST \\"
echo "  https://\${COGNITO_DOMAIN}.auth.${AWS_REGION}.amazoncognito.com/oauth2/token \\"
echo "  -H 'Content-Type: application/x-www-form-urlencoded' \\"
echo "  -d 'grant_type=client_credentials' \\"
echo "  -d 'client_id=\${SERVER_CLIENT_ID}' \\"
echo "  -d 'client_secret=\${SERVER_CLIENT_SECRET}' \\"
echo "  -d 'scope=${RESOURCE_SERVER_IDENTIFIER}/read ${RESOURCE_SERVER_IDENTIFIER}/write'"
echo ""
echo "다음 단계: ./05-create-groups.sh"
