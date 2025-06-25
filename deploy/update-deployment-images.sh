#!/bin/bash

# Deployment YAML 파일의 이미지 태그를 Harbor Registry로 일괄 변경하는 스크립트
# 사용법: ./update-deployment-images.sh [DOMAIN]
# 예시: ./update-deployment-images.sh 27.96.156.180.nip.io

set -e

# 도메인 설정
if [ -n "$1" ]; then
    DOMAIN="$1"
elif [ -n "$DOMAIN" ]; then
    echo "환경변수 DOMAIN 사용: $DOMAIN"
else
    read -p "Harbor 도메인을 입력하세요 (예: 27.96.156.180.nip.io): " DOMAIN
fi

if [ -z "$DOMAIN" ]; then
    echo "도메인이 필요합니다."
    exit 1
fi

HARBOR_REGISTRY="harbor.${DOMAIN}"
PROJECT_NAME="theater-msa"

echo "=== Deployment YAML 이미지 태그 업데이트 ==="
echo "Registry: ${HARBOR_REGISTRY}/${PROJECT_NAME}"
echo "Domain: ${DOMAIN}"
echo ""

# 백업 생성
echo ">>> 백업 생성 중..."
for FILE in api-gateway-ctx1.yaml user-service-ctx1.yaml user-service-ctx2.yaml movie-service-ctx1.yaml movie-service-ctx2.yaml booking-service-ctx1.yaml booking-service-ctx2.yaml; do
    if [ -f "${FILE}" ]; then
        cp "${FILE}" "${FILE}.bak"
        echo "  ✓ ${FILE} 백업 완료"
    fi
done

echo ""
echo ">>> 이미지 태그 업데이트 중..."

# API Gateway 이미지 업데이트 (CTX1 only)
if [ -f "api-gateway-ctx1.yaml" ]; then
    sed -i.tmp "s|image: theater-msa/api-gateway:latest|image: ${HARBOR_REGISTRY}/${PROJECT_NAME}/api-gateway:latest|g" api-gateway-ctx1.yaml
    sed -i.tmp "s|image: theater-msa/api-gateway:.*|image: ${HARBOR_REGISTRY}/${PROJECT_NAME}/api-gateway:latest|g" api-gateway-ctx1.yaml
    sed -i.tmp "s|image: api-gateway:latest|image: ${HARBOR_REGISTRY}/${PROJECT_NAME}/api-gateway:latest|g" api-gateway-ctx1.yaml
    sed -i.tmp "s|image: api-gateway:.*|image: ${HARBOR_REGISTRY}/${PROJECT_NAME}/api-gateway:latest|g" api-gateway-ctx1.yaml
    echo "  ✓ api-gateway-ctx1.yaml 업데이트 완료"
fi

# User Service 이미지 업데이트 (CTX1 & CTX2)
for CTX in ctx1 ctx2; do
    if [ -f "user-service-${CTX}.yaml" ]; then
        sed -i.tmp "s|image: theater-msa/user-service:latest|image: ${HARBOR_REGISTRY}/${PROJECT_NAME}/user-service:latest|g" user-service-${CTX}.yaml
        sed -i.tmp "s|image: theater-msa/user-service:.*|image: ${HARBOR_REGISTRY}/${PROJECT_NAME}/user-service:latest|g" user-service-${CTX}.yaml
        sed -i.tmp "s|image: user-service:latest|image: ${HARBOR_REGISTRY}/${PROJECT_NAME}/user-service:latest|g" user-service-${CTX}.yaml
        sed -i.tmp "s|image: user-service:.*|image: ${HARBOR_REGISTRY}/${PROJECT_NAME}/user-service:latest|g" user-service-${CTX}.yaml
        echo "  ✓ user-service-${CTX}.yaml 업데이트 완료"
    fi
done

# Movie Service 이미지 업데이트 (CTX1 & CTX2)
for CTX in ctx1 ctx2; do
    if [ -f "movie-service-${CTX}.yaml" ]; then
        sed -i.tmp "s|image: theater-msa/movie-service:latest|image: ${HARBOR_REGISTRY}/${PROJECT_NAME}/movie-service:latest|g" movie-service-${CTX}.yaml
        sed -i.tmp "s|image: theater-msa/movie-service:.*|image: ${HARBOR_REGISTRY}/${PROJECT_NAME}/movie-service:latest|g" movie-service-${CTX}.yaml
        sed -i.tmp "s|image: movie-service:latest|image: ${HARBOR_REGISTRY}/${PROJECT_NAME}/movie-service:latest|g" movie-service-${CTX}.yaml
        sed -i.tmp "s|image: movie-service:.*|image: ${HARBOR_REGISTRY}/${PROJECT_NAME}/movie-service:latest|g" movie-service-${CTX}.yaml
        echo "  ✓ movie-service-${CTX}.yaml 업데이트 완료"
    fi
done

# Booking Service 이미지 업데이트 (CTX1 & CTX2)
for CTX in ctx1 ctx2; do
    if [ -f "booking-service-${CTX}.yaml" ]; then
        sed -i.tmp "s|image: theater-msa/booking-service:latest|image: ${HARBOR_REGISTRY}/${PROJECT_NAME}/booking-service:latest|g" booking-service-${CTX}.yaml
        sed -i.tmp "s|image: theater-msa/booking-service:.*|image: ${HARBOR_REGISTRY}/${PROJECT_NAME}/booking-service:latest|g" booking-service-${CTX}.yaml
        sed -i.tmp "s|image: booking-service:latest|image: ${HARBOR_REGISTRY}/${PROJECT_NAME}/booking-service:latest|g" booking-service-${CTX}.yaml
        sed -i.tmp "s|image: booking-service:.*|image: ${HARBOR_REGISTRY}/${PROJECT_NAME}/booking-service:latest|g" booking-service-${CTX}.yaml
        echo "  ✓ booking-service-${CTX}.yaml 업데이트 완료"
    fi
done

# 임시 파일 정리
rm -f *.tmp

echo ""
echo "=== 업데이트 완료 ==="
echo "변경된 이미지 태그:"
echo "  - api-gateway: ${HARBOR_REGISTRY}/${PROJECT_NAME}/api-gateway:latest"
echo "  - user-service: ${HARBOR_REGISTRY}/${PROJECT_NAME}/user-service:latest"
echo "  - movie-service: ${HARBOR_REGISTRY}/${PROJECT_NAME}/movie-service:latest"
echo "  - booking-service: ${HARBOR_REGISTRY}/${PROJECT_NAME}/booking-service:latest"

echo ""
echo "백업 파일:"
for FILE in api-gateway-ctx1.yaml user-service-ctx1.yaml user-service-ctx2.yaml movie-service-ctx1.yaml movie-service-ctx2.yaml booking-service-ctx1.yaml booking-service-ctx2.yaml; do
    if [ -f "${FILE}.bak" ]; then
        echo "  - ${FILE}.bak"
    fi
done

echo ""
echo "복원하려면:"
echo "for f in *.yaml.bak; do mv \"\$f\" \"\${f%.bak}\"; done"
echo ""
echo "배포하려면:"
echo "./deploy-ctx1.sh  # CTX1 클러스터 배포"
echo "./deploy-ctx2.sh  # CTX2 클러스터 배포"
echo "./deploy-all.sh   # 멀티클러스터 통합 배포"
echo ""
echo "개별 배포:"
echo "kubectl apply -f api-gateway-ctx1.yaml"
echo "kubectl apply -f user-service-ctx1.yaml"
echo "kubectl apply -f user-service-ctx2.yaml"
echo "kubectl apply -f movie-service-ctx1.yaml"
echo "kubectl apply -f movie-service-ctx2.yaml"
echo "kubectl apply -f booking-service-ctx1.yaml"
echo "kubectl apply -f booking-service-ctx2.yaml"