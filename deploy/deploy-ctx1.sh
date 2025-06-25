#!/bin/bash

# Theater MSA - CTX1 클러스터 배포 스크립트
# NaverCloud Platform 클러스터용 (User Service + API Gateway)

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수들
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 현재 컨텍스트 확인
check_context() {
    local current_context=$(kubectl config current-context 2>/dev/null || echo "unknown")
    if [ "$current_context" != "ctx1" ]; then
        log_warning "현재 컨텍스트가 ctx1이 아닙니다: $current_context"
        log_info "ctx1 컨텍스트로 전환합니다..."
        kubectl config use-context ctx1
        if [ $? -ne 0 ]; then
            log_error "ctx1 컨텍스트로 전환할 수 없습니다. 컨텍스트가 설정되어 있는지 확인하세요."
            exit 1
        fi
    fi
    log_success "CTX1 컨텍스트 확인 완료"
}

# 노드 라벨 확인
check_node_labels() {
    log_info "노드 라벨 확인 중..."
    local ctx1_nodes=$(kubectl get nodes -l cluster-name=ctx1 --no-headers | wc -l)
    if [ $ctx1_nodes -eq 0 ]; then
        log_error "cluster-name=ctx1 라벨이 설정된 노드를 찾을 수 없습니다."
        log_info "다음 명령어로 노드에 라벨을 설정하세요:"
        kubectl get nodes --no-headers | awk '{print "kubectl label nodes " $1 " cluster-name=ctx1"}'
        exit 1
    fi
    log_success "CTX1 노드 $ctx1_nodes개 확인됨"
}

# 이미지 확인
check_images() {
    log_info "Harbor 이미지 접근성 확인 중..."
    
    # DOMAIN 환경변수 확인
    if [ -z "$DOMAIN" ]; then
        log_warning "DOMAIN 환경변수가 설정되지 않았습니다."
        read -p "DOMAIN을 입력하세요 (예: 27.96.156.180.nip.io): " DOMAIN
        export DOMAIN
    fi
    
    log_info "사용할 도메인: $DOMAIN"
    log_info "Harbor Registry: harbor.$DOMAIN"
    
    # 이미지 존재 여부는 배포 시 확인되므로 여기서는 경고만 표시
    log_warning "배포 전 다음 명령어로 이미지를 빌드했는지 확인하세요:"
    echo "  ./build-images.sh $DOMAIN"
}

# CTX1 전용 리소스 배포
deploy_ctx1_resources() {
    log_info "=== CTX1 클러스터 리소스 배포 시작 ==="
    
    # 1. 기본 네임스페이스 및 권한
    log_info "1. 기본 네임스페이스 및 권한 설정..."
    kubectl apply -f namespace.yaml
    kubectl apply -f rbac.yaml
    
    # 2. UI 설정
    log_info "2. UI ConfigMap 배포..."
    kubectl apply -f ui-configmap.yaml
    
    # 3. Redis Service (CTX2의 Redis를 멀티클러스터로 접근)
    log_info "3. Redis Service 배포..."
    kubectl apply -f redis-ctx1-service.yaml
    
    # 4. User Service (CTX1 전용)
    log_info "4. User Service 배포..."
    kubectl apply -f user-service-ctx1.yaml
    
    # 5. Movie Service (CTX1 전용)
    log_info "5. Movie Service 배포..."
    kubectl apply -f movie-service-ctx1.yaml
    
    # 6. Booking Service (CTX1 전용)
    log_info "6. Booking Service 배포..."
    kubectl apply -f booking-service-ctx1.yaml
    
    # 7. API Gateway (ctx1 전용)
    log_info "7. API Gateway 배포..."
    kubectl apply -f api-gateway-ctx1.yaml
    
    # 8. Istio 트래픽 관리 (DestinationRule & VirtualService)
    log_info "8. Istio DestinationRule 배포..."
    kubectl apply -f istio-destinationrules.yaml
    
    log_info "9. Istio VirtualService 배포..."
    kubectl apply -f istio-virtualservices.yaml
    
    # 9. 외부 접근용 VirtualService (istio-system 네임스페이스)
    log_info "10. 외부 접근용 VirtualService 배포..."
    if [ -f "istio-virtualservice.yaml" ]; then
        # 도메인 교체 및 적용
        if [ -n "$DOMAIN" ]; then
            sed "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" istio-virtualservice.yaml | kubectl apply -f -
            log_success "외부 VirtualService 배포 완료 (theater.$DOMAIN)"
        else
            log_warning "DOMAIN 환경변수가 설정되지 않았습니다. 외부 접근이 제한될 수 있습니다."
            kubectl apply -f istio-virtualservice.yaml
        fi
    else
        log_info "외부 VirtualService 파일이 없습니다. 기존 게이트웨이 설정을 사용합니다."
    fi
    
    # 10. Istio Gateway (필요시)
    if [ -f "istio-gateway.yaml" ]; then
        log_info "11. Istio Gateway 배포..."
        kubectl apply -f istio-gateway.yaml
    else
        log_info "11. 기존 cp-gateway 사용 (istio-gateway.yaml 없음)"
    fi
    
    log_success "CTX1 리소스 배포 완료!"
}

# 배포 상태 확인
check_deployment_status() {
    log_info "=== 배포 상태 확인 ==="
    
    # Pod 상태 확인
    log_info "Pod 상태 확인 중..."
    kubectl get pods -n theater-msa -o wide
    
    echo
    
    # 서비스 확인
    log_info "서비스 확인 중..."
    kubectl get svc -n theater-msa
    
    echo
    
    # Istio 리소스 확인
    log_info "Istio 리소스 확인 중..."
    kubectl get destinationrules,virtualservices -n theater-msa
    kubectl get virtualservices -n istio-system 2>/dev/null | grep -E "(theater|msa)" || log_warning "외부 VirtualService가 배포되지 않았습니다."
    
    echo
    
    # 사이드카 주입 확인
    log_info "Istio 사이드카 주입 확인..."
    kubectl get pods -n theater-msa -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}' | column -t
    
    echo
    
    # 실패한 Pod 확인
    local failed_pods=$(kubectl get pods -n theater-msa --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
    if [ $failed_pods -gt 0 ]; then
        log_warning "실패한 Pod가 있습니다:"
        kubectl get pods -n theater-msa --field-selector=status.phase!=Running
        
        echo
        log_info "문제 해결을 위해 다음 명령어를 실행하세요:"
        echo "  kubectl describe pod <pod-name> -n theater-msa"
        echo "  kubectl logs <pod-name> -n theater-msa"
    else
        log_success "모든 Pod가 정상 실행 중입니다!"
    fi
}

# 외부 접근 정보 표시
show_access_info() {
    log_info "=== 외부 접근 정보 ==="
    
    if [ -n "$DOMAIN" ]; then
        echo "🌐 외부 접근 URL:"
        echo "  Theater MSA: https://theater.$DOMAIN"
        echo "  API 엔드포인트:"
        echo "    - 사용자: https://theater.$DOMAIN/users/"
        echo "    - 영화: https://theater.$DOMAIN/movies/"
        echo "    - 예약: https://theater.$DOMAIN/bookings/"
        
        echo
        echo "🧪 테스트 명령어:"
        echo "  curl -k https://theater.$DOMAIN/users/"
        echo "  curl -k -H 'x-canary: true' https://theater.$DOMAIN/users/"
    else
        log_warning "DOMAIN이 설정되지 않아 외부 접근 URL을 표시할 수 없습니다."
    fi
    
    echo
    echo "📊 로컬 포트 포워딩:"
    echo "  kubectl port-forward svc/api-gateway 8080:8080 -n theater-msa"
    echo "  브라우저: http://localhost:8080"
}

# 메인 함수
main() {
    log_info "Theater MSA - CTX1 클러스터 배포 스크립트"
    echo "=================================================="
    log_info "CTX1 배포 구성: User Service + API Gateway + 공유 서비스"
    echo
    
    # 사전 확인
    check_context
    check_node_labels
    check_images
    
    echo
    
    # 배포 확인
    log_warning "CTX1 클러스터에 Theater MSA를 배포하시겠습니까?"
    read -p "계속하려면 'y'를 입력하세요 (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "배포가 취소되었습니다."
        exit 0
    fi
    
    # 배포 실행
    deploy_ctx1_resources
    
    echo
    
    # 배포 완료 대기
    log_info "Pod 시작 대기 중... (30초)"
    sleep 30
    
    # 상태 확인
    check_deployment_status
    
    echo
    
    # 접근 정보 표시
    show_access_info
    
    echo
    log_success "=== CTX1 배포 완료 ==="
    log_info "CTX2 클러스터 배포는 다음 명령어를 실행하세요:"
    echo "  ./deploy-ctx2.sh"
}

# 도움말
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "CTX1 클러스터 배포 스크립트"
    echo
    echo "사용법: $0"
    echo
    echo "환경변수:"
    echo "  DOMAIN    Harbor Registry 도메인 (예: 27.96.156.180.nip.io)"
    echo
    echo "사전 요구사항:"
    echo "  - kubectl 컨텍스트 'ctx1' 설정"
    echo "  - 노드에 'cluster-name=ctx1' 라벨 설정"
    echo "  - Harbor Registry에 이미지 업로드 완료"
    echo
    echo "배포되는 서비스:"
    echo "  - User Service (CTX1 전용)"
    echo "  - Movie Service (CTX1 전용)"
    echo "  - Booking Service (CTX1 전용)"
    echo "  - API Gateway"
    echo "  - Redis Service (멀티클러스터 접근)"
    echo "  - Istio DestinationRule & VirtualService"
    exit 0
fi

# 스크립트 실행
main "$@"