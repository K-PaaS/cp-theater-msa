#!/bin/bash

# 장애 주입 교육 시연 스크립트 (리팩토링 버전)
# K-PaaS 영화관 MSA 샘플 - Fault Injection Demo

set -e

# 색상 설정
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 로그 함수
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

step() {
    echo -e "${PURPLE}[STEP] $1${NC}"
}

# 도메인 설정
DOMAIN=${DOMAIN:-"27.96.156.180.nip.io"}
APP_URL="https://theater.$DOMAIN"

# 사용법
usage() {
    echo "사용법: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "COMMANDS:"
    echo "  reset           초기 상태로 완전 복원 (Round Robin DR + 기본 VS)"
    echo "  setup           Circuit Breaker 설정 적용"
    echo "  delay           Movie Service 지연 장애 주입"
    echo "  error           User Service HTTP 500 오류 주입"
    echo "  block           Booking Service CTX2 클러스터 차단"
    echo "  chaos           다중 서비스 복합 장애 주입"
    echo "  status          현재 설정 상태 확인"
    echo "  test            장애 주입 테스트 (curl 요청)"
    echo ""
    echo "OPTIONS:"
    echo "  --context CTX   kubectl context 지정 (기본값: ctx1)"
    echo "  --help          이 도움말 표시"
    echo ""
    echo "🎯 학습 순서 (권장):"
    echo "  1. $0 reset     # 초기 상태 확인"
    echo "  2. $0 setup     # Circuit Breaker 적용"
    echo "  3. $0 delay     # 지연 장애 실습"
    echo "  4. $0 error     # 오류 장애 실습"
    echo "  5. $0 block     # 차단 장애 실습"
    echo "  6. $0 chaos     # 복합 장애 실습"
    echo ""
    echo "📊 모니터링:"
    echo "  웹 UI: $APP_URL"
    echo "  상태 확인: $0 status"
    echo "  테스트: $0 test"
}

# kubectl context 설정
KUBECTL_CONTEXT="ctx1"

# 파라미터 파싱
while [[ $# -gt 0 ]]; do
    case $1 in
        --context)
            KUBECTL_CONTEXT="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        -*)
            error "알 수 없는 옵션: $1"
            usage
            exit 1
            ;;
        *)
            COMMAND="$1"
            shift
            ;;
    esac
done

# kubectl 래퍼 함수
k() {
    kubectl --context="$KUBECTL_CONTEXT" "$@"
}

# DestinationRule 정리 함수
cleanup_existing_destinationrules() {
    step "기존 DestinationRule 정리 중..."
    
    # 기존 기본 DestinationRule 삭제
    local basic_drs=("user-service-dr" "movie-service-dr" "booking-service-dr")
    for dr in "${basic_drs[@]}"; do
        if k get dr $dr -n theater-msa &>/dev/null; then
            log "기존 DestinationRule 삭제: $dr"
            k delete dr $dr -n theater-msa 2>/dev/null || true
        fi
    done
    
    # Circuit Breaker DestinationRule 삭제
    local cb_drs=("user-service-circuit-breaker" "movie-service-circuit-breaker" "booking-service-circuit-breaker")
    for dr in "${cb_drs[@]}"; do
        if k get dr $dr -n theater-msa &>/dev/null; then
            log "Circuit Breaker DestinationRule 삭제: $dr"
            k delete dr $dr -n theater-msa 2>/dev/null || true
        fi
    done
    
    info "DestinationRule 정리 완료"
}

# 시나리오별 적용 함수들
apply_reset() {
    step "🔄 초기 상태로 완전 복원"
    
    # 1. 모든 기존 DR 정리
    cleanup_existing_destinationrules
    
    # 2. 기본 설정 적용
    log "Round Robin DestinationRule + 기본 VirtualService 적용 중..."
    k apply -k 01-initial/
    
    log "✅ 초기 상태로 복원 완료"
    info "모든 서비스가 기본 트래픽 분산으로 동작합니다:"
    echo "  - User Service: 70% CTX1, 30% CTX2"
    echo "  - Movie Service: 30% CTX1, 70% CTX2"  
    echo "  - Booking Service: 50% CTX1, 50% CTX2"
    echo "  - Load Balancing: Round Robin"
    echo "  - Circuit Breaker: 비활성화"
}

apply_setup() {
    step "⚙️  Circuit Breaker 설정 적용"
    
    # 1. 기존 기본 DR 삭제 (충돌 방지)
    cleanup_existing_destinationrules
    
    # 2. Circuit Breaker 설정 적용
    log "Circuit Breaker DestinationRule 배포 중..."
    k apply -k 02-circuit-breaker/
    
    log "✅ Circuit Breaker 설정 적용 완료"
    info "모든 서비스에 Circuit Breaker 정책 적용됨:"
    echo "  - Connection Pool 제한"
    echo "  - Outlier Detection 활성화"
    echo "  - 연속 실패 시 자동 격리 (30초)"
    warn "이제 Fault Injection 실습을 진행할 수 있습니다."
}

apply_delay() {
    step "⏰ Movie Service 지연 장애 주입"
    log "Movie Service CTX2에 3초 지연 장애 적용 중..."
    
    k apply -k 03-delay-fault/
    
    log "✅ 지연 장애 주입 완료"
    info "Movie Service 트래픽 분산:"
    echo "  - CTX1 (30%): 즉시 응답"
    echo "  - CTX2 (70%): 3초 지연 응답"
    warn "웹 UI에서 Movie 섹션 새로고침 시 간헐적 지연을 확인하세요: $APP_URL"
}

apply_error() {
    step "💥 User Service HTTP 500 오류 주입"
    log "User Service에 30% 확률로 HTTP 500 오류 적용 중..."
    
    k apply -k 04-error-fault/
    
    log "✅ 오류 장애 주입 완료"
    info "User Service 응답 분포:"
    echo "  - 70%: 정상 응답"
    echo "  - 30%: HTTP 500 오류"
    warn "웹 UI에서 User 섹션 새로고침 시 간헐적 오류를 확인하세요: $APP_URL"
    info "Circuit Breaker 동작 확인: x-circuit-test 헤더로 90% 오류율 테스트 가능"
}

apply_block() {
    step "🚫 Booking Service CTX2 클러스터 차단"
    log "Booking Service 트래픽을 CTX1으로만 라우팅 설정 중..."
    
    k apply -k 05-block-fault/
    
    log "✅ 클러스터 차단 완료"
    info "Booking Service 트래픽 분산:"
    echo "  - CTX1: 100% (모든 트래픽)"
    echo "  - CTX2: 0% (완전 차단)"
    warn "웹 UI에서 Booking Service 신호등이 모두 녹색(CTX1)으로 변하는 것을 확인하세요: $APP_URL"
}

apply_chaos() {
    step "🌪️  다중 서비스 복합 장애 주입"
    log "모든 서비스에 동시 장애 적용 중..."
    warn "적용될 장애:"
    echo "  - User Service: 30% HTTP 500 오류"
    echo "  - Movie Service: CTX2에 3초 지연"
    echo "  - Booking Service: CTX2 완전 차단"
    
    read -p "계속 진행하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "복합 장애 주입이 취소되었습니다."
        return 0
    fi
    
    k apply -k 99-scenarios/
    
    log "✅ 복합 장애 주입 완료"
    error "⚠️  시스템이 매우 불안정한 상태입니다!"
    info "모든 서비스에서 동시 다발적 장애 발생 중"
    warn "웹 UI에서 모든 섹션의 다양한 장애 상황을 확인하세요: $APP_URL"
    echo ""
    echo "💡 복구 방법:"
    echo "  - 특정 장애만 해제: $0 delay|error|block"
    echo "  - 완전 복구: $0 reset"
}

# State validation 함수
validate_environment() {
    step "환경 검증 중..."
    
    # 1. 클러스터 연결 확인
    if ! k get nodes >/dev/null 2>&1; then
        error "Kubernetes 클러스터 연결 실패"
        return 1
    fi
    
    # 2. 네임스페이스 확인
    if ! k get namespace theater-msa >/dev/null 2>&1; then
        error "theater-msa 네임스페이스가 존재하지 않습니다"
        return 1
    fi
    
    # 3. 기본 서비스 확인
    local services=("user-service" "movie-service" "booking-service")
    for svc in "${services[@]}"; do
        if ! k get service $svc -n theater-msa >/dev/null 2>&1; then
            error "서비스 $svc가 존재하지 않습니다"
            return 1
        fi
    done
    
    info "환경 검증 완료"
    return 0
}

# Rollback 함수  
rollback_scenario() {
    local scenario=$1
    
    step "🔄 $scenario 시나리오 롤백 중..."
    
    case $scenario in
        "delay")
            log "Movie Service 지연 장애 제거 중..."
            # VirtualService를 기본 상태로 복원
            kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: movie-service-vs
  namespace: theater-msa
spec:
  hosts:
  - movie-service
  http:
  - match:
    - headers:
        x-canary:
          exact: "true"
    route:
    - destination:
        host: movie-service
        subset: ctx1
      weight: 100
  - route:
    - destination:
        host: movie-service
        subset: ctx1
      weight: 30
    - destination:
        host: movie-service
        subset: ctx2
      weight: 70
EOF
            ;;
        "error")
            log "User Service 오류 장애 제거 중..."
            # 기본 VirtualService 복원
            kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: user-service-vs
  namespace: theater-msa
spec:
  hosts:
  - user-service
  http:
  - match:
    - headers:
        x-canary:
          exact: "true"
    route:
    - destination:
        host: user-service
        subset: ctx2
      weight: 100
  - route:
    - destination:
        host: user-service
        subset: ctx1
      weight: 70
    - destination:
        host: user-service
        subset: ctx2
      weight: 30
EOF
            ;;
        "block")
            log "Booking Service 차단 장애 제거 중..."
            # 기본 VirtualService 복원
            kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: booking-service-vs
  namespace: theater-msa
spec:
  hosts:
  - booking-service
  http:
  - match:
    - headers:
        x-canary:
          exact: "true"
    route:
    - destination:
        host: booking-service
        subset: ctx1
      weight: 100
  - route:
    - destination:
        host: booking-service
        subset: ctx1
      weight: 50
    - destination:
        host: booking-service
        subset: ctx2
      weight: 50
EOF
            ;;
    esac
    
    info "$scenario 시나리오 롤백 완료"
}

# 상태 확인
check_status() {
    step "📊 현재 설정 상태 확인"
    
    # 환경 검증 먼저 수행
    if ! validate_environment; then
        error "환경 검증 실패"
        return 1
    fi
    
    echo ""
    info "🔧 DestinationRule 상태:"
    if k get dr user-service-dr -n theater-msa >/dev/null 2>&1; then
        echo "  ✅ 기본 DestinationRule (Round Robin)"
    elif k get dr user-service-circuit-breaker -n theater-msa >/dev/null 2>&1; then
        echo "  ⚙️  Circuit Breaker DestinationRule"
    else
        echo "  ❌ DestinationRule 없음"
    fi
    
    echo ""
    info "🌐 VirtualService 트래픽 분산:"
    k get vs -n theater-msa -o custom-columns=NAME:.metadata.name,WEIGHTS:.spec.http[-1].route[*].weight 2>/dev/null || echo "  ❌ VirtualService 정보 조회 실패"
    
    echo ""
    info "🚨 장애 주입 상태:"
    
    # User Service 오류 확인
    if k get vs user-service-vs -n theater-msa -o yaml 2>/dev/null | grep -q "abort:" ; then
        echo "  💥 User Service: HTTP 500 오류 주입 활성화"
    else
        echo "  ✅ User Service: 정상"
    fi
    
    # Movie Service 지연 확인  
    if k get vs movie-service-vs -n theater-msa -o yaml 2>/dev/null | grep -q "delay:" ; then
        echo "  ⏰ Movie Service: 지연 장애 주입 활성화"
    else
        echo "  ✅ Movie Service: 정상"
    fi
    
    # Booking Service 차단 확인
    local booking_subsets=$(k get vs booking-service-vs -n theater-msa -o jsonpath='{.spec.http[-1].route[*].destination.subset}' 2>/dev/null || echo "")
    if [[ "$booking_subsets" == "ctx1" && ! "$booking_subsets" =~ ctx2 ]]; then
        echo "  🚫 Booking Service: CTX2 차단 활성화"
    elif [ -z "$booking_subsets" ]; then
        echo "  ❌ Booking Service: 설정 오류"
    else
        echo "  ✅ Booking Service: 정상"
    fi
    
    echo ""
    info "📱 모니터링 URL: $APP_URL"
}

# 테스트 실행
run_test() {
    step "🧪 장애 주입 테스트 실행"
    
    echo ""
    info "각 서비스 API 테스트 (5회씩):"
    
    echo ""
    echo "👤 User Service 테스트:"
    for i in {1..5}; do
        printf "  요청 $i: "
        response=$(curl -k -s -w "HTTP_%{http_code}_%{time_total}s" "$APP_URL/users/" 2>&1)
        echo "$response" | grep -o "HTTP_[0-9]*_[0-9.]*s" || echo "연결 실패"
        sleep 1
    done
    
    echo ""
    echo "🎬 Movie Service 테스트:"
    for i in {1..5}; do
        printf "  요청 $i: "
        response=$(curl -k -s -w "HTTP_%{http_code}_%{time_total}s" "$APP_URL/movies/" 2>&1)
        echo "$response" | grep -o "HTTP_[0-9]*_[0-9.]*s" || echo "연결 실패"
        sleep 1
    done
    
    echo ""
    echo "📝 Booking Service 테스트:"
    for i in {1..5}; do
        printf "  요청 $i: "
        response=$(curl -k -s -w "HTTP_%{http_code}_%{time_total}s" "$APP_URL/bookings/" 2>&1)
        echo "$response" | grep -o "HTTP_[0-9]*_[0-9.]*s" || echo "연결 실패"
        sleep 1
    done
    
    echo ""
    info "🔍 Circuit Breaker 전용 테스트 (x-circuit-test 헤더):"
    for i in {1..3}; do
        printf "  고집중 오류 테스트 $i: "
        response=$(curl -k -s -w "HTTP_%{http_code}_%{time_total}s" -H "x-circuit-test: true" "$APP_URL/users/" 2>&1)
        echo "$response" | grep -o "HTTP_[0-9]*_[0-9.]*s" || echo "연결 실패"
        sleep 1
    done
    
    echo ""
    warn "⏱️  응답 시간이 3초 이상이면 지연 장애가 활성화된 상태입니다."
    warn "🚨 HTTP_500 응답이 보이면 오류 장애가 활성화된 상태입니다."
    info "📊 자세한 상태는 '$0 status' 명령으로 확인하세요."
}

# 메인 실행
case "${COMMAND:-help}" in
    reset)
        apply_reset
        ;;
    setup)
        apply_setup
        ;;
    delay)
        apply_delay
        ;;
    error)
        apply_error
        ;;
    block)
        apply_block
        ;;
    chaos)
        apply_chaos
        ;;
    status)
        check_status
        ;;
    test)
        run_test
        ;;
    help|*)
        usage
        ;;
esac

echo ""
info "💡 다음 단계: '$0 status'로 현재 상태 확인 또는 '$0 test'로 동작 테스트"