# Subscribe Ticket Report

1. 개요
프로젝트는 ERC-20 기반 결제 토큰과 ERC-721 기반 구독권( NFT )을 이용
온체인에서 구독 서비스를 구현하는 스마트 컨트랙트 과제

설계의 핵심 목표
    - 구독 상태 NFT 표현
    - 결제자(payer)와 NFT 소유자(owner) 분리
    - 서명 기반 동의(Signature Authorization)

2. 컨트랙트 명세
2.1 SubscriptionPaymentToken (ERC20)
    역할
        - 구독 결제에 사용되는 ERC20 표준을 따르는 토큰
        - 특정 ERC-721 컨트랙트(SubscriptionNFT)만 transferFrom 호출 가능

    주요 특징
        - ERC-20 표준 준수 ( 과제 요구사항에 따라 transferFrom 호출자 제한 )
        - Permit 지원 (초기 approve 트랜잭션 제거)
        - Mint / Burn 불가 (고정 공급)
        - ERC-721 컨트랙트 주소 설정 가능

    주요 함수
        setSubscriptionNFT(address) 
            구독 NFT 컨트랙트 지정
        transferFrom(from, to, amount)
            SubscriptionNFT만 호출 가능

    설계 의도
        - 결제 권한을 NFT 컨트랙트로 제한
        - 사용자 → 토큰 → NFT 구조로 책임 분리
        - Permit을 통해 최초 승인 가스 비용 제거

2.2 SubscriptionNFT (ERC-721)
    역할
        - 구독 상태를 표현하는 ERC-721 기반 구독권 컨트랙트
        - 사업자(Owner)가 구독 생성·청구·관리를 수행하는 모델
        - NFT 소유권과 결제 책임(payer)을 분리하여 유연한 구독 구조 제공

    주요 특징
        - ERC-721 표준 준수
        - 구독 단위를 NFT로 표현 (1 NFT = 1 구독)
        - 서명 기반 동의(Signature Authorization)
        - 결제 실패 시 자동 구독 중단 및 NFT 회수
        - NFT 소유권과 결제자(payer) 분리 가능

3. 테스트 코드 명세
3.1 SubscriptionPaymentToken 테스트
    검증 항목
        - 초기 공급량 mint 확인
        - subscriptionNFT 주소 설정
        - subscriptionNFT 외 transferFrom 호출 시 revert 확인


3.2 SubscriptionNFT 테스트
    검증 항목
        - subscribe 시 NFT mint   
        - ping 접근 제어
        - unsubscribe 시 NFT 회수
        - claim 시 revert-free 보장   
        - assign 시 payer 변경

4. 미비사항 및 고려사항
    미비사항 ( 추가 기능 구현 필요 )
        - 서명 nonce 기반 replay 방지 미적용
        - 서명의 chainId 미포함되어 멀티체인 환경에서 재사용 가능성 존재
        - 구독 기간 만료 후, 자동 해지

    사업자 측 고려사항
        - 결제 실패 고객 처리 ( 정책 또는 기능 )
        - NFT 회수 후 재사용 정책

    사용자 측 고려사항
        - 토큰 잔고 부족 시 구독 종료
