// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/*
    SubscriptionPaymentToken
        - 구독 결제 전용 ERC20 토큰
        - ERC721 구독 컨트랙트만 transferFrom 가능 ( ERC20 호환성 제한 )
        - Permit 통한 최초 승인 비용 ( 별도 Approve 트랜잭션 ) 제거
*/

contract SubscriptionPaymentToken is ERC20Permit, Ownable {
    // 구독 NFT 컨트랙트 주소
    address public subscriptionNFT;

    // 오류 정의
    error UnauthorizedCaller();

    event SubscriptionNFTUpdated(
        address indexed oldNFT,
        address indexed newNFT
    );

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply
    ) ERC20(name_, symbol_) ERC20Permit(name_) Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
    }

    // ERC721 구독 컨트랙트 주소 설정 (정책적 연결)
    function setSubscriptionNFT(address nft) external onlyOwner {
        address old = subscriptionNFT;
        subscriptionNFT = nft;
        emit SubscriptionNFTUpdated(old, nft);
    }

    // transferFrom ( subscriptionNFT만 호출 가능 )
    // ERC20 표준과 스팩은 동일하지만 과제 요구사항의 조건부 허용을 위해 호환성 제한
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        if (msg.sender != subscriptionNFT) {
            revert UnauthorizedCaller();
        }

        return super.transferFrom(from, to, amount);
    }
}
