#!/bin/bash
# ===========================================
# Step 6: Lambda Triggers 설정
# ===========================================
# 관련 Q&A: Q5 (내부 사용자 자동 판별), Q6 (Lambda Trigger 구현)
#
# 이 스크립트가 하는 일:
# - IAM 역할 생성 (Lambda 실행용)
# - Lambda 함수 3개 생성 및 배포
#   1) PreSignUp: 가입 시 이메일 도메인 검증 (보안)
#   2) PostConfirmation: 가입 후 내부/외부 사용자 자동 판별, 그룹 할당
#   3) PreTokenGeneration: 토큰에 커스텀 클레임 추가
# - Cognito User Pool에 Lambda Trigger 연결
#
# ⚠️ 보안 주의사항:
# - PreSignUp Lambda는 자가등록 허용 시 필수입니다
# - ALLOWED_SIGNUP_DOMAINS 환경변수를 반드시 설정하세요
#
# Lambda Trigger 제약사항:
# - 타임아웃: 5초 (Cognito 제한)
# - 동기 호출 (외부 API 호출 시 타임아웃 주의)
# - 실패 시 재시도 없음 (가입 자체가 실패)
#
# 참고 문서:
# - https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-identity-pools-working-with-aws-lambda-triggers.html
# - https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-post-confirmation.html
# - https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-pre-token-generation.html
# ===========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
source "${SCRIPT_DIR}/config.env"

LAMBDA_DIR="${PROJECT_DIR}/lambda"
POLICY_DIR="${LAMBDA_DIR}/policies"

# 필수 변수 확인
if [ -z "${USER_POOL_ID}" ] || [ -z "${USER_POOL_ARN}" ]; then
  echo "❌ Error: USER_POOL_ID 또는 USER_POOL_ARN이 설정되지 않았습니다."
  exit 1
fi

echo "=========================================="
echo "Step 6: Lambda Triggers 설정"
echo "=========================================="

# Lambda 함수 이름 생성
PRE_SIGN_UP_FUNCTION="${LAMBDA_PREFIX}-PreSignUp"
POST_CONFIRMATION_FUNCTION="${LAMBDA_PREFIX}-PostConfirmation"
PRE_TOKEN_GEN_FUNCTION="${LAMBDA_PREFIX}-PreTokenGeneration"

# ---------------------------------------------
# IAM 역할 생성
# ---------------------------------------------
echo ""
echo "1. Creating IAM Role for Lambda..."

# Trust Policy 생성
cat > "${POLICY_DIR}/trust-policy.json" << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Lambda 권한 Policy 생성
cat > "${POLICY_DIR}/lambda-policy.json" << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cognito-idp:AdminAddUserToGroup",
        "cognito-idp:AdminUpdateUserAttributes",
        "cognito-idp:AdminGetUser"
      ],
      "Resource": "${USER_POOL_ARN}"
    }
  ]
}
EOF

# IAM 역할 생성
aws iam create-role \
  --role-name "${LAMBDA_ROLE_NAME}" \
  --assume-role-policy-document file://${POLICY_DIR}/trust-policy.json \
  --description "Role for Cognito Lambda Triggers" \
  --region "${AWS_REGION}" 2>/dev/null || echo "   (Role already exists, continuing...)"

# 정책 연결
aws iam put-role-policy \
  --role-name "${LAMBDA_ROLE_NAME}" \
  --policy-name "${LAMBDA_ROLE_NAME}-Policy" \
  --policy-document file://${POLICY_DIR}/lambda-policy.json

LAMBDA_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${LAMBDA_ROLE_NAME}"

echo "   ✅ IAM Role 생성 완료: ${LAMBDA_ROLE_NAME}"

# 역할 전파 대기
echo "   Waiting for IAM role propagation..."
sleep 10

# ---------------------------------------------
# Lambda 함수 1: Pre Sign-Up (보안 - 도메인 검증)
# ---------------------------------------------
echo ""
echo "2. Creating ${PRE_SIGN_UP_FUNCTION} Lambda (Security: Domain Validation)..."

# 허용 도메인 확인
if [ -z "${ALLOWED_SIGNUP_DOMAINS}" ]; then
  echo "   ⚠️  WARNING: ALLOWED_SIGNUP_DOMAINS is not set in config.env"
  echo "   ⚠️  All signups will be BLOCKED until this is configured!"
fi

# Lambda 코드 패키징
cd "${LAMBDA_DIR}"
zip -j pre_sign_up.zip pre_sign_up.py

# Lambda 함수 생성
aws lambda create-function \
  --function-name "${PRE_SIGN_UP_FUNCTION}" \
  --runtime python3.12 \
  --role "${LAMBDA_ROLE_ARN}" \
  --handler pre_sign_up.lambda_handler \
  --zip-file fileb://${LAMBDA_DIR}/pre_sign_up.zip \
  --timeout 5 \
  --memory-size 128 \
  --environment "{\"Variables\":{\"ALLOWED_SIGNUP_DOMAINS\":\"${ALLOWED_SIGNUP_DOMAINS}\"}}" \
  --description "Cognito Pre Sign-Up - Email domain validation (Security)" \
  --region "${AWS_REGION}" 2>/dev/null || echo "   (Function already exists, updating...)"

# Cognito 호출 권한 추가
aws lambda add-permission \
  --function-name "${PRE_SIGN_UP_FUNCTION}" \
  --statement-id CognitoInvoke \
  --action lambda:InvokeFunction \
  --principal cognito-idp.amazonaws.com \
  --source-arn "${USER_POOL_ARN}" \
  --region "${AWS_REGION}" 2>/dev/null || echo "   (Permission already exists)"

echo "   ✅ ${PRE_SIGN_UP_FUNCTION} Lambda 생성 완료"

# ---------------------------------------------
# Lambda 함수 2: Post Confirmation
# ---------------------------------------------
echo ""
echo "3. Creating ${POST_CONFIRMATION_FUNCTION} Lambda..."

# Lambda 코드 패키징
cd "${LAMBDA_DIR}"
zip -j post_confirmation.zip post_confirmation.py

# Lambda 함수 생성
aws lambda create-function \
  --function-name "${POST_CONFIRMATION_FUNCTION}" \
  --runtime python3.12 \
  --role "${LAMBDA_ROLE_ARN}" \
  --handler post_confirmation.lambda_handler \
  --zip-file fileb://${LAMBDA_DIR}/post_confirmation.zip \
  --timeout 5 \
  --memory-size 128 \
  --environment "{\"Variables\":{\"INTERNAL_EMAIL_DOMAINS\":\"${INTERNAL_EMAIL_DOMAINS}\",\"EMPLOYEE_ID_PREFIX\":\"${EMPLOYEE_ID_PREFIX}\"}}" \
  --description "Cognito Post Confirmation - Auto classify internal/external users" \
  --region "${AWS_REGION}" 2>/dev/null || echo "   (Function already exists, updating...)"

# Cognito 호출 권한 추가
aws lambda add-permission \
  --function-name "${POST_CONFIRMATION_FUNCTION}" \
  --statement-id CognitoInvoke \
  --action lambda:InvokeFunction \
  --principal cognito-idp.amazonaws.com \
  --source-arn "${USER_POOL_ARN}" \
  --region "${AWS_REGION}" 2>/dev/null || echo "   (Permission already exists)"

echo "   ✅ ${POST_CONFIRMATION_FUNCTION} Lambda 생성 완료"

# ---------------------------------------------
# Lambda 함수 3: Pre Token Generation
# ---------------------------------------------
echo ""
echo "4. Creating ${PRE_TOKEN_GEN_FUNCTION} Lambda..."

# Lambda 코드 패키징
zip -j pre_token_generation.zip pre_token_generation.py

# Lambda 함수 생성
aws lambda create-function \
  --function-name "${PRE_TOKEN_GEN_FUNCTION}" \
  --runtime python3.12 \
  --role "${LAMBDA_ROLE_ARN}" \
  --handler pre_token_generation.lambda_handler \
  --zip-file fileb://${LAMBDA_DIR}/pre_token_generation.zip \
  --timeout 5 \
  --memory-size 128 \
  --description "Cognito Pre Token Generation - Add custom claims to token" \
  --region "${AWS_REGION}" 2>/dev/null || echo "   (Function already exists, updating...)"

# Cognito 호출 권한 추가
aws lambda add-permission \
  --function-name "${PRE_TOKEN_GEN_FUNCTION}" \
  --statement-id CognitoInvoke \
  --action lambda:InvokeFunction \
  --principal cognito-idp.amazonaws.com \
  --source-arn "${USER_POOL_ARN}" \
  --region "${AWS_REGION}" 2>/dev/null || echo "   (Permission already exists)"

echo "   ✅ ${PRE_TOKEN_GEN_FUNCTION} Lambda 생성 완료"

# ---------------------------------------------
# User Pool에 Lambda Trigger 연결
# ---------------------------------------------
echo ""
echo "5. Connecting Lambda Triggers to User Pool..."

PRE_SIGN_UP_ARN="arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:${PRE_SIGN_UP_FUNCTION}"
POST_CONFIRMATION_ARN="arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:${POST_CONFIRMATION_FUNCTION}"
PRE_TOKEN_GEN_ARN="arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:${PRE_TOKEN_GEN_FUNCTION}"

aws cognito-idp update-user-pool \
  --user-pool-id "${USER_POOL_ID}" \
  --lambda-config "{
    \"PreSignUp\": \"${PRE_SIGN_UP_ARN}\",
    \"PostConfirmation\": \"${POST_CONFIRMATION_ARN}\",
    \"PreTokenGeneration\": \"${PRE_TOKEN_GEN_ARN}\"
  }" \
  --region "${AWS_REGION}"

echo "   ✅ Lambda Triggers 연결 완료"

# zip 파일 정리
rm -f pre_sign_up.zip post_confirmation.zip pre_token_generation.zip

echo ""
echo "=========================================="
echo "✅ Lambda Triggers 설정 완료!"
echo "=========================================="
echo ""
echo "| 순서 | Trigger               | Lambda Function                | 기능                          |"
echo "|------|----------------------|--------------------------------|-------------------------------|"
echo "| 1    | Pre Sign-Up          | ${PRE_SIGN_UP_FUNCTION}        | 이메일 도메인 검증 (보안)     |"
echo "| 2    | Post Confirmation    | ${POST_CONFIRMATION_FUNCTION}  | 내부/외부 사용자 자동 판별    |"
echo "| 3    | Pre Token Generation | ${PRE_TOKEN_GEN_FUNCTION}      | 토큰에 커스텀 클레임 추가     |"
echo ""
echo "⚠️  보안 주의사항:"
echo "   - ALLOWED_SIGNUP_DOMAINS 환경변수가 설정되어 있어야 회원가입이 가능합니다"
echo "   - 현재 설정된 허용 도메인: ${ALLOWED_SIGNUP_DOMAINS:-'(미설정 - 모든 가입 차단됨)'}"
echo ""
echo "다음 단계: ./07-create-test-users.sh"
