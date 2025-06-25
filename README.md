# K-PaaS Theater MSA - 멀티클러스터 서비스메시 교육 플랫폼

이 프로젝트는 **K-PaaS 교육용** MSA(Microservices Architecture) 샘플 애플리케이션으로, **NaverCloud Platform**과 **NHN Cloud NKS**의 **Istio 서비스메시**를 활용한 **멀티클라우드 트래픽 관리 및 장애 복구**를 실습할 수 있는 샘플 프로젝트입니다.

## 📋 프로젝트 개요

```
┌─────────────────────────────────────────────────────────────┐
│          Istio DestinationRule/VirtualService 기반           │
│             멀티클라우드 서비스메시 트래픽 관리               │
├─────────────────────────────────────────────────────────────┤
│  NaverCloud Platform    │    NHN Cloud NKS                  │
│  (Istio Pre-installed)  │    (Istio Pre-installed)          │
│  ┌─────────────────────┐│    ┌─────────────────────┐        │
│  │   User Service      ││    │   Movie Service     │        │
│  │   Movie Service     ││    │   Booking Service   │        │
│  │   Booking Service   ││    │   User Service      │        │
│  │   API Gateway       ││    │   Redis (실제)       │        │
│  │   Redis Service     ││    │                     │        │
│  └─────────────────────┘│    └─────────────────────┘        │
│           │              │              │                   │
│    ┌───────────────┐     │     ┌───────────────┐          │
│    │EASTWESTGATEWAY│◄────┼──────►│EASTWESTGATEWAY│          │
│    └───────────────┘     │     └───────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

### 🎯 주요 특징
- **간단한 MSA 구조**: 교육용으로 복잡성 최소화
- **Istio 네이티브 트래픽 관리**: DestinationRule과 VirtualService를 통한 서비스메시 기반 로드 밸런싱
- **EASTWESTGATEWAY**: 클러스터 간 자동 서비스 디스커버리 및 투명한 멀티클러스터 통신
- **멀티클라우드 환경**: Naver Cloud + NHN Cloud 환경 최적화
- **가중치 기반 트래픽 분산**: 서비스별 차별화된 트래픽 라우팅 (User: 70%/30%, Movie: 30%/70%, Booking: 50%/50%)
- **카나리 배포 지원**: x-canary 헤더를 통한 특정 클러스터 라우팅
- **Fault Injection**: 지연, 오류, 차단 등 다양한 장애 시나리오 실습
- **Circuit Breaker**: 자동 장애 격리 및 복구 메커니즘 학습
- **실시간 모니터링**: 웹 UI를 통한 트래픽 분산 및 장애 상황 시각화
- **실제 동작 확인**: REST API 테스트 및 장애 복구 과정 체험

## 🏗️ 아키텍처

### 마이크로서비스 구성
```
API Gateway (8080)
    ├── User Service (8081)    - 사용자 관리
    ├── Movie Service (8082)   - 영화 정보 관리  
    ├── Booking Service (8083) - 예약 관리
    └── Redis (6379)          - 데이터 저장소
```

### Istio 서비스메시 트래픽 관리
- **DestinationRule**: 클러스터별 subset 정의 및 ROUND_ROBIN 로드밸런싱
- **VirtualService**: 가중치 기반 트래픽 분산 및 카나리 배포
- **서비스별 차별화된 트래픽 비율**: 각 서비스의 특성에 맞는 클러스터 분산
- **Envoy 네이티브 처리**: 애플리케이션 코드 수정 없이 인프라 레벨 트래픽 관리

## 📁 파일 구조

```
deploy/                          # 애플리케이션 배포 관련 파일
├── namespace.yaml                # 네임스페이스 및 설정 (Istio injection 활성화)
├── redis.yaml                   # Redis 데이터 저장소 (자동 초기 데이터)
├── redis-ctx1-service.yaml      # CTX1 Redis Service (멀티클러스터 접근)
├── redis-multicluster.yaml      # Redis 멀티클러스터 설정
├── user-service-ctx1.yaml       # 사용자 서비스 CTX1
├── user-service-ctx2.yaml       # 사용자 서비스 CTX2
├── movie-service-ctx1.yaml      # 영화 서비스 CTX1
├── movie-service-ctx2.yaml      # 영화 서비스 CTX2
├── booking-service-ctx1.yaml    # 예약 서비스 CTX1
├── booking-service-ctx2.yaml    # 예약 서비스 CTX2
├── api-gateway-ctx1.yaml        # API 게이트웨이 (CTX1 전용)
├── rbac.yaml                    # API Gateway용 서비스 계정 및 권한 설정
├── ui-configmap.yaml            # UI 파일 (Istio 설정 표시)
├── istio-destinationrules.yaml  # DestinationRule (클러스터별 subset)
├── istio-virtualservices.yaml   # VirtualService (가중치 기반 라우팅)
├── build-images.sh              # Harbor 이미지 빌드 스크립트
├── update-deployment-images.sh  # Deployment YAML 이미지 태그 일괄 변경 스크립트
├── deploy-ctx1.sh               # CTX1 클러스터 전용 배포 스크립트
├── deploy-ctx2.sh               # CTX2 클러스터 전용 배포 스크립트
├── deploy-all.sh                # 멀티클라우드 통합 배포 스크립트
└── cleanup.sh                   # 샘플 배포 일괄 삭제 스크립트

practice/                        # Fault Injection 실습 관련 파일
├── fault-injection-demo.sh      # 장애 주입 교육 스크립트 (리팩토링)
├── 01-initial/                  # 초기 상태 (Round Robin + 기본 트래픽)
│   ├── destinationrules.yaml   # 기본 DestinationRule
│   ├── virtualservices.yaml    # 기본 VirtualService
│   └── kustomization.yaml      # 통합 배포 설정
├── 02-circuit-breaker/          # Circuit Breaker 실습
│   ├── destinationrules.yaml   # Circuit Breaker DestinationRule
│   └── kustomization.yaml      # Circuit Breaker 적용 설정
├── 03-delay-fault/              # 지연 장애 실습
│   ├── virtualservices.yaml    # Movie Service 지연 VirtualService
│   └── kustomization.yaml      # 지연 장애 적용 설정
├── 04-error-fault/              # 오류 장애 실습
│   ├── virtualservices.yaml    # User Service 오류 VirtualService
│   └── kustomization.yaml      # 오류 장애 적용 설정
├── 05-block-fault/              # 차단 장애 실습
│   ├── virtualservices.yaml    # Booking Service 차단 VirtualService
│   └── kustomization.yaml      # 차단 장애 적용 설정
└── 99-scenarios/                # 복합 장애 실습
    ├── multi-service-fault.yaml # 다중 서비스 복합 장애
    └── kustomization.yaml       # 복합 장애 적용 설정

프로젝트 루트/
├── README.md                   # 이 파일
├── history.md                  # 개발 히스토리 및 향후 계획
└── issue.md                    # 문제 해결 과정 기록
```

## 📋 사전 요구사항 및 제약조건

### 필수 환경 조건
- **Kubernetes 클러스터**: 2개 (NaverCloud Platform, NHN Cloud NKS)
- **Istio 사전 설치**: 각 클러스터에 Istio가 설치되어 있어야 함
- **EASTWESTGATEWAY 구성**: 클러스터 간 통신을 위해 사전 구성되어 있어야 함
- **cp-gateway 존재**: `istio-system` 네임스페이스에 cp-gateway가 구성되어 있어야 함
- **Harbor Registry**: 컨테이너 이미지 저장소 (harbor.{{DOMAIN}} 형태)
- **Docker**: 이미지 빌드 및 푸시를 위한 Docker 엔진

### 제약 조건

#### 1. 클러스터 Context 명명 규칙
```bash
# 필수: kubectl context 이름을 다음과 같이 설정해야 함
kubectl config rename-context <original-context-1> ctx1
kubectl config rename-context <original-context-2> ctx2

# 확인
kubectl config get-contexts
```

#### 2. 노드 라벨링 요구사항
```bash
# ctx1 클러스터의 모든 노드에 라벨 필수 적용
kubectl label nodes <node-name> cluster-name=ctx1 --context=ctx1

# ctx2 클러스터의 모든 노드에 라벨 필수 적용  
kubectl label nodes <node-name> cluster-name=ctx2 --context=ctx2
```

#### 3. 네트워크 접근 요구사항
- **외부 도메인**: `theater.{{DOMAIN}}` 형태로 환경별 설정 필요
- **포트 개방**: 80, 443 포트가 외부에서 접근 가능해야 함
- **DNS 해결**: 설정한 도메인이 해결 가능해야 함

#### 4. 서비스 배포 제약사항
- **멀티클러스터 배포**: 모든 서비스가 양쪽 클러스터에 배포됨
  - ctx1: API Gateway (외부 접근점) + User/Movie/Booking Services
  - ctx2: Redis (실제 배포) + User/Movie/Booking Services
- **Redis 아키텍처**: 멀티클러스터 서비스메시 교육 목적
  - CTX1: Redis Service만 존재 (엔드포인트 없음)
  - CTX2: 실제 Redis Deployment + Service
  - EastWestGateway를 통한 투명한 멀티클러스터 접근
- **초기 데이터**: Redis 시작 시 자동으로 사용자/영화 데이터 생성
- **네임스페이스**: 모든 리소스는 `theater-msa` 네임스페이스에 배포

#### 5. Istio 설정 요구사항
- **VirtualService**: `istio-system` 네임스페이스에 배포해야 함
- **Gateway**: 기존 `cp-gateway` 재사용 (새로 생성하지 않음)
- **호스트명**: `theater.{{DOMAIN}}` 템플릿 형태로 환경별 설정

#### 6. 권한 요구사항
```bash
# 각 클러스터에서 다음 권한이 필요함
- pods, services, deployments: get, list, create, update, delete
- namespaces: get, list, create
- virtualservices, destinationrules: get, list, create, update, delete
- nodes: get, list, patch (라벨링용)
```

## 🚀 교육용 빠른 시작 가이드

### 1. 사전 준비 확인

#### 환경 설정
```bash
# 작업 디렉토리로 이동
cd deploy/

# 도메인 환경변수 설정
export DOMAIN="27.96.156.180.nip.io"
echo "배포 도메인: https://theater.$DOMAIN"
```

#### 클러스터 연결 확인
```bash
# kubectl 버전 확인
kubectl version --client

# 멀티클러스터 컨텍스트 확인
kubectl config get-contexts | grep -E "(ctx1|ctx2)"

# 각 클러스터 연결 테스트
kubectl cluster-info --context=ctx1
kubectl cluster-info --context=ctx2
```

### 2. 이미지 빌드 및 배포

#### Harbor Registry 이미지 빌드
```bash
# 1. Harbor 로그인 (K-PaaS의 Harbor)
docker login harbor.${DOMAIN}
# 또는 podman login harbor.${DOMAIN}

# 2. 모든 서비스 이미지 빌드 및 푸시 (자동화)
./build-images.sh ${DOMAIN}

# 3. Deployment YAML 이미지 태그 업데이트
./update-deployment-images.sh ${DOMAIN}
```

### 3. 멀티클러스터 서비스 배포

#### 방법 1: 자동 배포 스크립트
```bash
# 전체 멀티클러스터 통합 배포 (CTX1 + CTX2)
export DOMAIN="27.96.156.180.nip.io"
./deploy-all.sh

# 배포 상태 확인
kubectl get pods -n theater-msa --context=ctx1 -o wide
kubectl get pods -n theater-msa --context=ctx2 -o wide
```

#### 배포 후 검증
```bash
# 각 클러스터에서 Pod 분산 상태 확인
kubectl get pods -n theater-msa -o wide --show-labels --context=ctx1
kubectl get pods -n theater-msa -o wide --show-labels --context=ctx2

# VirtualService 가중치 설정 확인
kubectl get vs -n theater-msa -o yaml --context=ctx1 | grep -A 3 weight

# 실제 트래픽 분산 테스트
for i in {1..10}; do
  curl -s http://theater.$DOMAIN/users/ | head -1
  sleep 1
done
```

### 4. 배포 상태 확인
```bash
# 모든 Pod 상태 및 클러스터 분산 확인
kubectl get pods -n theater-msa -o wide --show-labels

# 서비스 확인
kubectl get svc -n theater-msa

# DestinationRule 배포 확인
kubectl get dr -n theater-msa

# VirtualService 배포 확인  
kubectl get vs -n theater-msa

# Istio 사이드카 주입 확인
kubectl get pods -n theater-msa -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'

# 외부 접근용 VirtualService 확인
kubectl get vs -n istio-system theater-msa
```

### 4. 웹 UI를 통한 실시간 모니터링

#### 교육용 웹 인터페이스 접근
```bash
# 배포된 애플리케이션 접근
echo "🌐 웹 UI: https://theater.$DOMAIN"

# 브라우저에서 접근하여 다음 기능 확인:
# - 실시간 트래픽 분산 신호등 (CTX1/CTX2)
# - 서비스별 가중치 설정 현황
# - 클러스터별 배포 상태
# - 실시간 트래픽 히스토리
```

#### UI 구성 요소 설명
- **상단 신호등**: 각 서비스별 실시간 트래픽 라우팅 표시
  - 🟢 녹  색: 해당하는 클러스터로 트래픽 라우팅
  - 🔴 빨간색: 다른 클러스터로 트래픽 라우팅
- **가중치 설정**: 현재 VirtualService 가중치 설정값
- **클러스터별 Pod 배포 현황**: 클러스터별 Pod 배포 현황

### 5. 🚨 Fault Injection 실습

Fault Injection 실습은 **명시적인 YAML 파일 기반**으로 운영되어 각 상태를 명확하게 확인할 수 있습니다.

#### 실습 환경 준비
```bash
# practice 디렉토리로 이동
cd ../practice/

# 사용 가능한 명령어 확인
./fault-injection-demo.sh --help

# 🎯 권장 학습 순서:
# 1. reset  → 초기 상태 확인
# 2. setup  → Circuit Breaker 적용
# 3. delay  → 지연 장애 실습
# 4. error  → 오류 장애 실습
# 5. block  → 차단 장애 실습
# 6. chaos  → 복합 장애 실습
```

#### 📁 실습 폴더 구조
```
practice/
├── 01-initial/          # 초기 상태 (Round Robin + 기본 트래픽)
├── 02-circuit-breaker/  # Circuit Breaker 실습
├── 03-delay-fault/      # Movie Service 지연 장애
├── 04-error-fault/      # User Service 오류 장애
├── 05-block-fault/      # Booking Service 차단 장애
└── 99-scenarios/        # 복합 장애 시나리오
```

#### Step 1: 초기 상태 확인
```bash
# 기본 Round Robin + 기본 트래픽 분산으로 초기화
./fault-injection-demo.sh reset

# 적용되는 설정:
# - DestinationRule: Round Robin 로드밸런싱
# - VirtualService: 기본 가중치 분산 (70:30, 30:70, 50:50)
# - Circuit Breaker: 비활성화
```

#### Step 2: Circuit Breaker 설정 적용
```bash
# Circuit Breaker DestinationRule 적용
./fault-injection-demo.sh setup

# 적용되는 설정 (02-circuit-breaker/):
# - Connection Pool 제한
# - Outlier Detection 활성화
# - 연속 실패 시 30초 자동 격리
```

#### Step 3: 지연 장애 실습
```bash
# Movie Service CTX2에 3초 지연 주입
./fault-injection-demo.sh delay

# 적용되는 설정 (03-delay-fault/virtualservices.yaml):
# - Movie Service CTX2: 70% 요청에 3초 지연
# - 웹 UI에서 Movie 섹션 새로고침 시 간헐적 지연 확인
```

#### Step 4: 오류 장애 실습
```bash
# User Service에 30% HTTP 500 오류 주입
./fault-injection-demo.sh error

# 적용되는 설정 (04-error-fault/virtualservices.yaml):
# - User Service: 30% 확률로 HTTP 500 오류
# - x-circuit-test 헤더: 90% 오류율로 Circuit Breaker 테스트

# Circuit Breaker 집중 테스트
curl -k -H "x-circuit-test: true" https://theater.${DOMAIN}/users/
```

#### Step 5: 차단 장애 실습
```bash
# Booking Service CTX2 클러스터 완전 차단
./fault-injection-demo.sh block

# 적용되는 설정 (05-block-fault/virtualservices.yaml):
# - Booking Service: 100% CTX1으로 라우팅 (CTX2 차단)
# - 웹 UI에서 신호등이 모두 녹색(CTX1)으로 변화 확인
```

#### Step 6: 복합 장애 실습 (고급)
```bash
# 모든 서비스에 동시 장애 주입
./fault-injection-demo.sh chaos

# 적용되는 설정 (99-scenarios/multi-service-fault.yaml):
# - User Service: 30% HTTP 500 오류
# - Movie Service: CTX2에 3초 지연
# - Booking Service: CTX2 완전 차단
# ⚠️ 시스템 전체가 불안정한 상태가 됩니다!
```

#### 상태 확인 및 모니터링
```bash
# 현재 적용된 설정 상태 확인
./fault-injection-demo.sh status

# 실제 API 테스트 (5회씩 자동 실행)
./fault-injection-demo.sh test

# 수동 테스트
curl -k https://theater.${DOMAIN}/users/
curl -k https://theater.${DOMAIN}/movies/
curl -k https://theater.${DOMAIN}/bookings/
```

#### 복구 방법
```bash
# 초기 상태로 완전 복원
./fault-injection-demo.sh reset

# 이전 단계로 되돌리기
./fault-injection-demo.sh setup   # Circuit Breaker만 적용된 상태
./fault-injection-demo.sh delay   # 지연 장애 상태
./fault-injection-demo.sh error   # 오류 장애 상태
./fault-injection-demo.sh block   # 차단 장애 상태
```

#### 🎓 교육적 효과

##### 명시적 설정 관리
- **투명성**: 각 시나리오의 YAML 파일을 직접 확인 가능
- **재현성**: 언제든 동일한 상태로 복원 가능
- **학습성**: 실제 Istio 설정 파일을 보며 학습

##### 실무 적용성
```bash
# 실제 운영 환경에서 사용하는 방식과 동일
kubectl apply -k practice/03-delay-fault/    # 지연 장애 적용
kubectl apply -k practice/01-initial/        # 정상 상태 복원
```

##### 단계별 학습
1. **기본 이해**: Round Robin → Circuit Breaker 차이점
2. **장애 시뮬레이션**: 지연, 오류, 차단 각각의 특성
3. **복합 시나리오**: 실제 운영에서 발생할 수 있는 복합 장애
4. **복구 전략**: 상황에 맞는 적절한 복구 방법

### 6. API 테스트 및 검증

#### 기본 API 동작 확인
```bash
# 사용자 목록 조회
curl https://theater.$DOMAIN/users/

# 영화 목록 조회  
curl https://theater.$DOMAIN/movies/

# 예약 목록 조회
curl https://theater.$DOMAIN/bookings/
```

#### 카나리 배포 테스트
```bash
# 일반 트래픽 (가중치 분산)
curl https://theater.$DOMAIN/users/

# 카나리 트래픽 (CTX1 강제 라우팅)
curl -H "x-canary: true" https://theater.$DOMAIN/users/
```

## 🧪 시연 시나리오

### 1. Istio 서비스메시 확인
```bash
# Envoy 사이드카 주입 확인
kubectl get pods -n theater-msa -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'

# Istio 프록시 상태 확인
kubectl exec -n theater-msa deployment/user-service -c istio-proxy -- pilot-agent request GET stats/prometheus | grep envoy_cluster

# 서비스메시 구성 확인
istioctl proxy-config cluster deployment/user-service.theater-msa
```

### 2. EASTWESTGATEWAY를 통한 멀티클러스터 통신 확인
```bash
# 클라우드별 노드 라벨 확인
kubectl get nodes --show-labels | grep cloud-provider

# 서비스별 Pod 분산 상태 확인 (각 클러스터에서)
kubectl get pods -n theater-msa -o wide

# EASTWESTGATEWAY 상태 확인
kubectl get svc istio-eastwestgateway -n istio-system

# 멀티클러스터 서비스 디스커버리 확인
istioctl proxy-config endpoints deployment/user-service.theater-msa

# 원격 클러스터 서비스 접근 확인 (자동 프록시 경유)
kubectl exec -n theater-msa deployment/user-service -- curl http://movie-service.theater-msa.svc.cluster.local:8082/
```

### 3. API 테스트 (cp-gateway 경유)
```bash
# 환경별 도메인 설정 확인
echo "http://theater.$DOMAIN"

# 사용자 생성
curl -X POST -H "Content-Type: application/json" \
  -d '{"name":"홍길동","email":"hong@example.com"}' \
  http://theater.$DOMAIN/users/

# 영화 추가
curl -X POST -H "Content-Type: application/json" \
  -d '{"title":"어벤져스","genre":"액션","year":2019}' \
  http://theater.$DOMAIN/movies/

# 예약 생성
curl -X POST -H "Content-Type: application/json" \
  -d '{"userId":"user-id","movieId":"movie-id","seats":2}' \
  http://theater.$DOMAIN/bookings/

# VirtualService 라우팅 확인
kubectl get vs -n istio-system theater-msa
```

### 4. 관측성 도구 확인
```bash
# Kiali 대시보드 접근 (사전 설치된 경우)
kubectl port-forward svc/kiali 20001:20001 -n istio-system

# Jaeger 추적 확인 (사전 설치된 경우)
kubectl port-forward svc/jaeger 16686:16686 -n istio-system

# Prometheus 메트릭 확인
kubectl port-forward svc/prometheus 9090:9090 -n istio-system
```

### 5. Istio 트래픽 관리 시연
```bash
# DestinationRule 확인 (클러스터별 subset 정의)
kubectl get destinationrules -n theater-msa
kubectl describe destinationrule user-service-dr -n theater-msa

# VirtualService 확인 (가중치 기반 트래픽 분산)
kubectl get virtualservices -n theater-msa
kubectl describe virtualservice user-service-vs -n theater-msa

# 현재 트래픽 분산 설정 확인
kubectl get vs user-service-vs -n theater-msa -o yaml | grep -A 10 weight

# 트래픽 분산 비율 실시간 변경 (User Service 예시)
kubectl patch virtualservice user-service-vs -n theater-msa --type='merge' -p='
{
  "spec": {
    "http": [{
      "match": [{
        "headers": {
          "x-canary": {"exact": "true"}
        }
      }],
      "route": [{
        "destination": {"host": "user-service", "subset": "ctx2"},
        "weight": 100
      }]
    }, {
      "route": [
        {"destination": {"host": "user-service", "subset": "ctx1"}, "weight": 90},
        {"destination": {"host": "user-service", "subset": "ctx2"}, "weight": 10}
      ]
    }]
  }
}'

# 카나리 배포 테스트 (ctx2로 100% 라우팅)
curl -H "x-canary: true" http://theater.$DOMAIN/users/

# 일반 트래픽 테스트 (가중치 분산)
curl http://theater.$DOMAIN/users/

# 서비스별 트래픽 분산 확인
kubectl get vs -n theater-msa -o custom-columns=NAME:.metadata.name,WEIGHTS:.spec.http[0].route[*].weight

# Envoy 프록시 설정 확인
istioctl proxy-config cluster deployment/user-service.theater-msa
istioctl proxy-config endpoints deployment/user-service.theater-msa

# 트래픽 분산 상태 실시간 모니터링
istioctl proxy-config listeners deployment/user-service.theater-msa --port 8081

# cp-gateway 설정 확인
kubectl get gateway cp-gateway -n istio-system -o yaml
```

## 🔧 운영 및 관리

### 상태 모니터링
```bash
# Pod 상태 실시간 확인
kubectl get pods -n theater-msa -w

# 로그 확인
kubectl logs -n theater-msa -l app=api-gateway --tail=50
kubectl logs -n theater-msa -l app=user-service --tail=50

# 리소스 사용량 확인
kubectl top pods -n theater-msa
```

### 스케일링 (시연용)
```bash
# 수동 스케일링
kubectl scale deployment user-service --replicas=3 -n theater-msa

# 스케일링 상태 확인
kubectl get pods -n theater-msa -l app=user-service
```

### 업데이트 시연
```bash
# 이미지 업데이트
kubectl set image deployment/user-service user-service=user-service:v2.0.0 -n theater-msa

# 롤아웃 상태 확인
kubectl rollout status deployment/user-service -n theater-msa
```

## 🌐 멀티클라우드 설정

### ctx1 클러스터 설정 (User + API Gateway Service)
```bash
# ctx1 클러스터 접속
kubectl config use-context ctx1

# 노드에 클러스터 라벨 추가
kubectl label nodes <node-name> cluster-name=ctx1

# ctx1에 배포될 서비스들 (cp-gateway 위치)
# - User Service (user-service.yaml)
# - API Gateway (api-gateway.yaml) 
# - Redis (shared, preferred)

# 배포 확인
kubectl get pods -n theater-msa -o wide
```

### ctx2 클러스터 설정 (Movie + Booking Service)
```bash
# ctx2 클러스터 접속
kubectl config use-context ctx2

# 노드에 클러스터 라벨 추가
kubectl label nodes <node-name> cluster-name=ctx2

# ctx2에 배포될 서비스들
# - Movie Service (movie-service.yaml)
# - Booking Service (booking-service.yaml)
# - Redis (shared, preferred)

# 서비스 분산 배치 확인
kubectl get pods -n theater-msa -o wide
```

## 🛠️ 트러블슈팅

### 제약조건 관련 문제

#### 1. Context 이름 문제
```bash
# 문제: context 이름이 ctx1, ctx2가 아닌 경우
Error: context "my-cluster" not found

# 해결: context 이름 변경
kubectl config get-contexts
kubectl config rename-context <original-name> ctx1
kubectl config rename-context <original-name> ctx2
```

#### 2. 노드 라벨 누락 문제
```bash
# 문제: Pod이 Pending 상태에서 머무는 경우
0/3 nodes are available: 3 node(s) didn't match Pod's node affinity

# 해결: 노드 라벨 확인 및 추가
kubectl get nodes --show-labels | grep cluster-name
kubectl label nodes <node-name> cluster-name=ctx1  # 또는 ctx2
```

#### 3. DestinationRule/VirtualService 설정 문제
```bash
# 문제: 트래픽이 한 클러스터로만 라우팅되는 경우
# 원인: 클러스터 라벨 불일치 또는 subset 정의 오류

# 해결: 클러스터 라벨 확인
kubectl get pods -n theater-msa --show-labels | grep cluster

# DestinationRule subset 확인
kubectl describe dr user-service-dr -n theater-msa

# VirtualService 라우팅 규칙 확인
kubectl describe vs user-service-vs -n theater-msa
```

#### 4. VirtualService 배포 네임스페이스 문제
```bash
# 문제: 내부 서비스 VirtualService가 잘못된 네임스페이스에 배포
# 내부 서비스: theater-msa 네임스페이스
# 외부 접근: istio-system 네임스페이스

# 올바른 배포 확인
kubectl get vs -n theater-msa  # 내부 서비스 라우팅
kubectl get vs -n istio-system # 외부 Gateway 라우팅
```

#### 5. 도메인 접근 불가
```bash
# 문제: 설정한 도메인 접근 실패
curl: (6) Could not resolve host

# 해결: 도메인 설정 및 DNS 확인
echo $DOMAIN  # 도메인 변수 확인
nslookup theater.$DOMAIN
kubectl get gateway cp-gateway -n istio-system

# VirtualService 호스트명 확인
kubectl get vs theater-msa -n istio-system -o yaml | grep hosts
```

#### 6. 카나리 배포 동작 안함
```bash
# 문제: x-canary 헤더 라우팅이 동작하지 않는 경우

# 해결: VirtualService 매치 규칙 확인
kubectl get vs user-service-vs -n theater-msa -o yaml | grep -A 5 "x-canary"

# 테스트 요청
curl -v -H "x-canary: true" http://theater.$DOMAIN/users/

# Envoy 설정 확인
istioctl proxy-config route deployment/user-service.theater-msa
```

### 일반적인 문제해결
```bash
# Pod 실패 시 상세 정보 확인
kubectl describe pod <pod-name> -n theater-msa

# 이벤트 확인
kubectl get events -n theater-msa --sort-by=.metadata.creationTimestamp

# 서비스 연결 테스트
kubectl exec -it <pod-name> -n theater-msa -- wget -qO- http://redis:6379

# EASTWESTGATEWAY 상태 확인
kubectl get svc istio-eastwestgateway -n istio-system
```

### 배포 검증 체크리스트
```bash
# 1. Context 이름 확인
kubectl config current-context  # ctx1 또는 ctx2여야 함

# 2. 노드 라벨 확인
kubectl get nodes --show-labels | grep cluster-name

# 3. 서비스 배포 위치 확인
kubectl get pods -n theater-msa -o wide --show-labels

# 4. DestinationRule 배포 확인
kubectl get dr -n theater-msa
kubectl describe dr user-service-dr -n theater-msa | grep -A 10 subsets

# 5. VirtualService 배포 확인
kubectl get vs -n theater-msa  # 내부 서비스 라우팅
kubectl get vs -n istio-system # 외부 Gateway 라우팅

# 6. 트래픽 분산 설정 확인
kubectl get vs -n theater-msa -o custom-columns=NAME:.metadata.name,WEIGHTS:.spec.http[-1].route[*].weight

# 7. Envoy 사이드카 주입 확인
kubectl get pods -n theater-msa -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'

# 8. 서비스메시 연결 확인
istioctl proxy-config endpoints deployment/user-service.theater-msa

# 9. 외부 접근 확인
curl -I http://theater.$DOMAIN

# 10. 카나리 배포 테스트
curl -H "x-canary: true" http://theater.$DOMAIN/users/
```

### 리소스 정리

#### 자동 정리 스크립트 사용 (권장)
```bash
# 모든 클러스터(ctx1, ctx2)에서 일괄 삭제 (기본값)
./cleanup.sh
./cleanup.sh --all

# 개별 클러스터에서만 삭제
./cleanup.sh --ctx1     # CTX1에서만 삭제
./cleanup.sh --ctx2     # CTX2에서만 삭제

# 현재 컨텍스트에서만 삭제
./cleanup.sh --current

# 도움말 확인
./cleanup.sh --help
```

#### 수동 정리 방법
```bash
# 각 클러스터에서 Kustomize를 사용한 일괄 삭제
kubectl config use-context ctx1
kubectl delete -k .

kubectl config use-context ctx2
kubectl delete -k .

# 또는 네임스페이스 삭제 (각 클러스터에서)
kubectl delete namespace theater-msa --context ctx1
kubectl delete namespace theater-msa --context ctx2

# 외부 VirtualService 삭제 (istio-system)
kubectl delete vs theater-msa -n istio-system --context ctx1
```

#### 정리 완료 확인
```bash
# 멀티클러스터 남은 리소스 확인
kubectl get all,vs,dr -n theater-msa --context=ctx1
kubectl get all,vs,dr -n theater-msa --context=ctx2

# 외부 VirtualService 확인
kubectl get vs -n istio-system theater-msa --context=ctx1

# 네임스페이스 확인
kubectl get namespace theater-msa --context=ctx1
kubectl get namespace theater-msa --context=ctx2
```

---

## ⚠️ 중요 알림

이 **Istio DestinationRule/VirtualService 기반 MSA** 시연 환경은 NaverCloud와 NHN Cloud의 **사전 설치된 Istio와 EASTWESTGATEWAY**를 활용하여 복잡한 설정 없이 즉시 **멀티클라우드 서비스메시의 트래픽 관리 핵심 기능**들을 시연할 수 있도록 구성되었습니다.

### 필수 준수사항
1. **Context 명명**: 반드시 `ctx1`, `ctx2`로 설정해야 함
2. **노드 라벨링**: 각 클러스터 노드에 `cluster-name=ctx1/ctx2` 라벨 필수
3. **클러스터 라벨**: 서비스 Pod에 `cluster: ctx1/ctx2` 라벨 필수 (DestinationRule subset 매칭용)
4. **도메인 설정**: `theater.{{DOMAIN}}` 템플릿을 환경에 맞게 치환 필요
5. **네임스페이스 구분**: 
   - 내부 서비스 트래픽 관리: `theater-msa` 네임스페이스
   - 외부 Gateway 접근: `istio-system` 네임스페이스
6. **Gateway 재사용**: 기존 `cp-gateway` 사용 (새로 생성 금지)

### Istio 네이티브 트래픽 관리 동작 원리
- **DestinationRule**: `cluster: ctx1/ctx2` 라벨을 기반으로 클러스터별 subset 정의
- **VirtualService**: 서비스별 차별화된 가중치로 트래픽 분산 (User: 70%/30%, Movie: 30%/70%, Booking: 50%/50%)
- **Envoy 프록시**: 애플리케이션 코드 수정 없이 자동 로드밸런싱 및 트래픽 분산
- **EASTWESTGATEWAY**: 클러스터 간 투명한 서비스 디스커버리 및 통신

**클러스터 간 서비스 호출 흐름 (Istio 기반):**
- API Gateway → VirtualService → DestinationRule → ctx1/ctx2 User Service
- User Service → VirtualService → DestinationRule → ctx1/ctx2 Movie Service  
- EASTWESTGATEWAY를 통한 투명한 멀티클러스터 통신