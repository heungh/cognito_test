#!/bin/bash
# ===========================================
# 전체 프로비저닝 스크립트
# ===========================================
# 모든 Cognito 리소스를 순차적으로 생성합니다.
#
# 사전 요구사항:
# 1. AWS CLI 설치 및 구성
# 2. config.env 파일 설정 (config.env.example 참조)
# 3. 적절한 IAM 권한
#
# 사용법:
#   ./provision-all.sh
# ===========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Amazon Cognito 전체 프로비저닝 시작"
echo "=========================================="
echo ""

# config.env 확인
if [ ! -f "${SCRIPT_DIR}/config.env" ]; then
  echo "❌ Error: config.env 파일이 없습니다."
  echo "   cp config.env.example config.env 후 설정값을 수정하세요."
  exit 1
fi

source "${SCRIPT_DIR}/config.env"

# 필수 변수 확인
if [ -z "${AWS_ACCOUNT_ID}" ] || [ "${AWS_ACCOUNT_ID}" == "your-account-id" ]; then
  echo "❌ Error: AWS_ACCOUNT_ID가 설정되지 않았습니다."
  echo "   config.env 파일을 수정하세요."
  exit 1
fi

echo "설정 확인:"
echo "  - AWS Account ID: ${AWS_ACCOUNT_ID}"
echo "  - AWS Region: ${AWS_REGION}"
echo "  - User Pool Name: ${USER_POOL_NAME}"
echo "  - Domain Prefix: ${DOMAIN_PREFIX}"
echo ""
read -p "계속 진행하시겠습니까? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "취소되었습니다."
  exit 0
fi

# 실행 권한 부여
chmod +x "${SCRIPT_DIR}"/*.sh

echo ""
echo "=========================================="
echo "Step 1/7: User Pool 생성"
echo "=========================================="
"${SCRIPT_DIR}/01-create-user-pool.sh"

echo ""
echo "=========================================="
echo "Step 2/7: Domain 생성"
echo "=========================================="
"${SCRIPT_DIR}/02-create-domain.sh"

echo ""
echo "=========================================="
echo "Step 3/7: App Clients 생성"
echo "=========================================="
"${SCRIPT_DIR}/03-create-app-clients.sh"

echo ""
echo "=========================================="
echo "Step 4/7: Resource Server 생성"
echo "=========================================="
"${SCRIPT_DIR}/04-create-resource-server.sh"

echo ""
echo "=========================================="
echo "Step 5/7: Groups 생성"
echo "=========================================="
"${SCRIPT_DIR}/05-create-groups.sh"

echo ""
echo "=========================================="
echo "Step 6/7: Lambda Triggers 설정"
echo "=========================================="
"${SCRIPT_DIR}/06-setup-lambda-triggers.sh"

echo ""
echo "=========================================="
echo "Step 7/7: 테스트 사용자 생성"
echo "=========================================="
"${SCRIPT_DIR}/07-create-test-users.sh"

echo ""
echo "=========================================="
echo "🎉 전체 프로비저닝 완료!"
echo "=========================================="
echo ""

# config.env 다시 로드 (생성된 리소스 ID 포함)
source "${SCRIPT_DIR}/config.env"

echo "생성된 리소스 요약:"
echo ""
echo "User Pool"
echo "  - ID: ${USER_POOL_ID}"
echo "  - Domain: ${COGNITO_DOMAIN}.auth.${AWS_REGION}.amazoncognito.com"
echo ""
echo "App Clients"
echo "  - Web App: ${WEB_CLIENT_ID}"
echo "  - Mobile App: ${MOBILE_CLIENT_ID}"
echo "  - Server-to-Server: ${SERVER_CLIENT_ID}"
echo ""
echo "Groups"
echo "  - admin-group, internal-users, external-users, pending-approval"
echo ""
echo "Lambda Triggers"
echo "  - ${LAMBDA_PREFIX}-PostConfirmation"
echo "  - ${LAMBDA_PREFIX}-PreTokenGeneration"
echo ""
echo "테스트 사용자 4명 생성 완료"
echo ""
echo "=========================================="
echo "다음 단계:"
echo "  - Google 소셜 로그인 연동: ./08-setup-google-idp.sh"
echo "  - 리소스 정리: ./cleanup.sh"
echo "=========================================="
